Here’s a **Technical Implementation Guide** for **AutoAgent**, derived directly from the PRD. It covers architecture, code structure, GitHub Actions behavior, and future extensibility.

---

# **AutoAgent Technical Implementation Guide**

**Version:** 0.1
**Date:** 2025-09-10
**Status:** Draft

---

## **1. Overview**

AutoAgent is a **composable GitHub Action** that integrates with `cursor-agent` (and future agents) to run **AI-driven checks and custom prompts** on a repository during **Pull Request workflows**.

This guide describes the **technical details** required to implement AutoAgent, including:

* Action structure (`action.yml`, composite steps, and internal scripts)
* Agent installation logic
* Execution flow for rules and custom prompts
* PR comment output
* Future extensibility for multiple agent types

---

## **2. Core Components**

| Component             | Description                                                            |
| --------------------- | ---------------------------------------------------------------------- |
| **`action.yml`**      | Defines the GitHub Action inputs, defaults, and steps.                 |
| **Agent Installer**   | Shell logic to install `cursor-agent` or other supported agents.       |
| **Prompt Runner**     | Executes predefined rules and custom prompts using the selected agent. |
| **Result Aggregator** | Collects outputs and formats them for GitHub PR comments.              |
| **PR Commenter**      | Posts results back to the GitHub Pull Request.                         |

---

## **3. GitHub Action Inputs**

AutoAgent supports **five inputs**, as defined in the PRD.

| Input           | Type           | Required | Default   | Description                                                                   |
| --------------- | -------------- | -------- | --------- | ----------------------------------------------------------------------------- |
| `rules`         | YAML/JSON List | ✅ Yes    | N/A       | Predefined rules to execute.                                                  |
| `custom`        | String         | ❌ No     | `""`      | Custom prompt to append at the end of predefined rules.                       |
| `action`        | Enum           | ✅ Yes    | `comment` | Determines what to do with the result (currently `comment` only).             |
| `install-agent` | Boolean        | ❌ No     | `true`    | If `true` or omitted, install the selected agent automatically.               |
| `agent`         | String         | ❌ No     | `cursor`  | Agent to use for execution (`cursor` default, future: `claude`, `gpt`, etc.). |

---

## **4. High-Level Architecture**

```
+-----------------------------------+
| GitHub Workflow (YAML)           |
|-----------------------------------|
| Uses erans/autoagent@v1    |
| with:                             |
|   rules: [owasp-check, code-review]
|   custom: "Custom SQL optimization check"
|   action: "comment"
|   install-agent: true
|   agent: cursor                   |
+-----------------------------------+
                |
                v
+-----------------------------------+
| AutoAgent (Composite Action)     |
|-----------------------------------|
| 1. Install Agent (if enabled)    |
| 2. Execute Rules (sequential)    |
| 3. Execute Custom Prompt (if any)|
| 4. Aggregate Results             |
| 5. Post PR Comment               |
+-----------------------------------+
```

---

## **5. Implementation Steps**

### **5.1 Repository Structure**

```
autoagent/
├── action.yml
├── scripts/
│   ├── install_agent.sh
│   ├── run_prompts.sh
│   └── post_comment.sh
└── rules/
    ├── owasp-check.prompt
    ├── code-review.prompt
    └── refactor-suggestions.prompt
```

---

### **5.2 Agent Installation Logic**

The `install_agent.sh` script installs the selected agent based on the `agent` input.

**File:** `scripts/install_agent.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

AGENT="${1:-cursor}"

echo "Installing agent: $AGENT"

case "$AGENT" in
  cursor)
    curl -sSL https://cursor.sh/install | bash
    ;;
  *)
    echo "Unsupported agent: $AGENT"
    exit 1
    ;;
esac

echo "Agent $AGENT installed successfully."
```

**Action Step:**

```yaml
- name: Install Agent (if enabled)
  if: ${{ inputs.install-agent == 'true' }}
  run: scripts/install_agent.sh "${{ inputs.agent }}"
```

---

### **5.3 Rules Execution**

The `run_prompts.sh` script will:

1. Parse the `rules` input (YAML or JSON).
2. Sequentially execute each rule's prompt file using the selected agent.
3. Append results to a temporary `results.json` file.

**File:** `scripts/run_prompts.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

RULES="${1:-}"
CUSTOM_PROMPT="${2:-}"
AGENT="${3:-cursor}"
RESULT_FILE="results.json"

echo "Running rules with agent: $AGENT"
> "$RESULT_FILE"

for RULE in $(echo "$RULES" | yq -r '.[]'); do
  PROMPT_FILE="rules/${RULE}.prompt"
  if [ ! -f "$PROMPT_FILE" ]; then
    echo "Rule file not found: $RULE"
    exit 1
  fi

  echo "Executing rule: $RULE"
  OUTPUT=$($AGENT-agent run --prompt-file "$PROMPT_FILE")
  jq -n --arg rule "$RULE" --arg output "$OUTPUT" \
    '{rule: $rule, output: $output}' >> "$RESULT_FILE"
done

# Run custom prompt if provided
if [ -n "$CUSTOM_PROMPT" ]; then
  echo "Executing custom prompt..."
  OUTPUT=$($AGENT-agent run --prompt "$CUSTOM_PROMPT")
  jq -n --arg rule "custom" --arg output "$OUTPUT" \
    '{rule: $rule, output: $output}' >> "$RESULT_FILE"
fi

echo "Results saved to $RESULT_FILE"
```

---

### **5.4 PR Comment Output**

The `post_comment.sh` script uses GitHub's REST API to post a comment to the PR.

**File:** `scripts/post_comment.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

RESULT_FILE="${1:-results.json}"
PR_NUMBER="${GITHUB_REF##*/}"

COMMENT_BODY="### AutoAgent Results\n"

while read -r LINE; do
  RULE=$(echo "$LINE" | jq -r '.rule')
  OUTPUT=$(echo "$LINE" | jq -r '.output')
  COMMENT_BODY+="\n**Rule:** $RULE\n> $OUTPUT\n"
done < <(jq -c '.[]' "$RESULT_FILE")

gh pr comment "$PR_NUMBER" --body "$COMMENT_BODY"
```

---

## **6. action.yml Definition**

**File:** `action.yml`

```yaml
name: "AutoAgent"
description: "Composable GitHub Action to run AI agent prompts on a repository"
author: "Eran"

inputs:
  rules:
    description: "YAML or JSON list of predefined rules to execute."
    required: true
    type: string

  custom:
    description: "Optional custom prompt appended to the predefined rules."
    required: false
    type: string
    default: ""

  action:
    description: "Determines what to do with the result. Supported: comment"
    required: true
    type: string
    default: "comment"

  install-agent:
    description: "Boolean flag to control whether to install the agent automatically. Defaults to true."
    required: false
    type: boolean
    default: true

  agent:
    description: "Which agent to use. Current default is cursor."
    required: false
    type: string
    default: "cursor"

runs:
  using: "composite"
  steps:
    - name: Install Agent (if enabled)
      if: ${{ inputs.install-agent == 'true' }}
      run: scripts/install_agent.sh "${{ inputs.agent }}"

    - name: Execute Rules and Custom Prompt
      run: scripts/run_prompts.sh "${{ inputs.rules }}" "${{ inputs.custom }}" "${{ inputs.agent }}"

    - name: Post Results as PR Comment
      if: ${{ inputs.action == 'comment' }}
      run: scripts/post_comment.sh results.json
```

---

## **7. Example GitHub Workflow**

```yaml
name: AutoAgent PR Checks

on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  autoagent:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run AutoAgent
        uses: erans/autoagent@v1
        with:
          rules: |
            - owasp-check
            - code-review
          custom: |
            Please check for inefficient SQL queries and suggest optimizations.
          action: comment
          install-agent: true
          agent: cursor
```

---

## **8. Error Handling**

| Error Case                                                | Behavior                                                  |
| --------------------------------------------------------- | --------------------------------------------------------- |
| Rule file not found                                       | Action fails with a descriptive error.                    |
| Agent install failure                                     | Action fails and logs installation output.                |
| Missing pre-installed agent (when `install-agent: false`) | Fail gracefully with a message explaining required setup. |
| Invalid YAML in `rules`                                   | Action stops and prints parsing error.                    |

---

## **9. Extensibility Plan**

### Future Agent Support

* Extend `install_agent.sh` with additional `case` blocks for agents like `claude` or `gpt`.
* Update `run_prompts.sh` to support agent-specific CLI commands.

### Future Actions

* Add `status-check` as a new `action` type to report results via GitHub Checks API.
* Add support for Slack notifications.

---

## **10. Testing Plan**

| Test Case                                       | Expected Result                                    |
| ----------------------------------------------- | -------------------------------------------------- |
| Default run with `cursor` agent                 | Installs agent, runs rules, posts comment.         |
| `install-agent: false` with agent pre-installed | Skips installation, runs rules successfully.       |
| Invalid rule name                               | Fails with clear error message.                    |
| Only custom prompt provided                     | Runs just the custom prompt and posts result.      |
| Future agent selected (not implemented)         | Fails gracefully with "unsupported agent" message. |

---

## **11. Security Considerations**

* Validate all inputs to avoid code injection via prompts.
* Use GitHub-provided tokens (`GITHUB_TOKEN`) securely for PR comment posting.
* Avoid logging sensitive data in prompts or outputs.

---

## **12. Performance Considerations**

* Rules are run sequentially in v1 to simplify output aggregation.
* Future optimization: **parallel execution** of rules using background jobs or matrix builds.

---

## **13. Deployment**

* Publish to GitHub Marketplace under `erans/autoagent`.
* Tag initial release as `v1.0.0`.
* Use semantic versioning for future updates.

---

## **14. Summary**

This guide provides a complete technical path for implementing AutoAgent:

* **Inputs and defaults** are clearly defined.
* **Composite Action design** is modular and future-ready.
* Support for **agent pluggability** ensures long-term scalability.
* The initial version prioritizes simplicity and reliability, with room to evolve into a full multi-agent orchestration platform.
