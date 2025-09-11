Here’s the **updated PRD for AutoAgent**, now including a new optional property called **`agent`**, which defaults to `"cursor"`. This property provides flexibility for supporting multiple AI agents in the future while maintaining backward compatibility.

---

# **AutoAgent PRD**

**Version:** 0.4
**Owner:** \[Your Name]
**Date:** 2025-09-10
**Status:** Draft

---

## **1. Overview**

**AutoAgent** is a **Composable GitHub Action** that integrates with AI agents like [Cursor CLI](https://cursor.sh) to run prompts on a repository as part of **Pull Request workflows**.

It simplifies the process of running AI-based analysis on PRs by:

* Automatically installing and configuring the agent (default: `cursor-agent`).
* Running **predefined rules** or **custom prompts**.
* Posting actionable results back to the PR as comments.

---

## **2. Goals**

* Provide a **single, reusable GitHub Action** for AI-driven PR analysis.
* Allow teams to **declare rules and custom prompts**.
* Offer **pluggable agent support**, starting with `cursor`.
* Automate installation of the selected agent unless explicitly disabled.

---

## **3. Non-Goals**

* Automatic PR merging or approval.
* Replacing dedicated static analysis tools.
* Multi-agent orchestration (future roadmap).

---

## **4. Key Features**

| Feature                     | Description                                                                      |
| --------------------------- | -------------------------------------------------------------------------------- |
| **Predefined Rules**        | Run curated rules like OWASP security checks or refactoring suggestions.         |
| **Custom Prompt Support**   | Extend analysis with team-specific custom instructions.                          |
| **Shared Setup Context**    | A consistent initialization prompt for all agents running inside GitHub Actions. |
| **Agent Auto Installation** | Automatically installs the agent unless explicitly disabled.                     |
| **Multiple Agents Support** | Introduce an `agent` property to select which agent to use (future-ready).       |
| **PR Comment Output**       | Post results back to GitHub PR comments in a structured format.                  |

---

## **5. Configuration Example**

```yaml
name: AutoAgent Checks

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

> **Notes:**
>
> * `install-agent` is **optional** and defaults to `true`.
> * `agent` is **optional** and defaults to `cursor`.
>   Future supported values might include `claude`, `gpt`, etc.

---

## **6. Inputs Schema (`action.yml`)**

### **Inputs Definition**

```yaml
name: "AutoAgent"
description: "Composable GitHub Action to run AI agent prompts (default: cursor-agent) on a repository"
author: "Eran Sandler"

inputs:
  rules:
    description: >
      A YAML or JSON list of predefined rules to run.
      Example:
      - owasp-check
      - code-review
    required: true
    type: string

  custom:
    description: >
      A custom prompt string that will be appended to the predefined rules.
      Used for additional, team-specific AI checks.
    required: false
    type: string
    default: ""

  action:
    description: >
      Determines what to do with the result.
      Currently supported: "comment".
      Future options may include "status-check", "slack", etc.
    required: true
    type: string
    default: "comment"

  install-agent:
    description: >
      Boolean flag to control whether to install the selected agent automatically.
      Defaults to true if not provided.
      Set to false if the agent is already available on the runner.
    required: false
    type: boolean
    default: true

  agent:
    description: >
      Specifies which agent to use for analysis.
      Current default is "cursor".
      Future supported values may include "claude", "gpt", etc.
    required: false
    type: string
    default: "cursor"
```

---

### **Schema Rules**

| Input           | Type                           | Required | Default    | Validation                        |
| --------------- | ------------------------------ | -------- | ---------- | --------------------------------- |
| `rules`         | String (YAML/JSON list)        | ✅ Yes    | N/A        | Must match predefined rule names. |
| `custom`        | String (plain text / Markdown) | ❌ No     | `""`       | Max length 5000 characters.       |
| `action`        | Enum (`comment`)               | ✅ Yes    | `comment`  | Only `"comment"` supported in v1. |
| `install-agent` | Boolean                        | ❌ No     | `true`     | Must be `true` or `false`.        |
| `agent`         | String                         | ❌ No     | `"cursor"` | Must match supported agent names. |

---

## **7. Behavior for `install-agent` and `agent`**

| Scenario                              | Behavior                                                            |
| ------------------------------------- | ------------------------------------------------------------------- |
| `install-agent` omitted               | Installs selected agent (default: `cursor-agent`).                  |
| `install-agent: true`                 | Installs the agent explicitly.                                      |
| `install-agent: false`                | Skips installation and assumes agent is pre-installed.              |
| `agent: cursor` (default)             | Runs `cursor-agent`.                                                |
| `agent` set to another value (future) | Installs and configures the specified agent (e.g., `claude-agent`). |

---

## **8. Predefined Rules**

| Rule Name              | Description                                     |
| ---------------------- | ----------------------------------------------- |
| `owasp-check`          | Security scan based on OWASP Top 10 guidelines. |
| `refactor-suggestions` | Detects code smells and suggests refactors.     |
| `code-review`          | Performs a general AI-driven code review.       |

Rules are bundled into AutoAgent and versioned alongside the action.

---

## **9. Shared Initialization Prompt**

Every run injects a **shared setup prompt** to the selected agent to ensure consistent behavior:

```
You are running inside a GitHub Actions workflow.
You have access to these tools: git, bash, node, etc.
Your task is to analyze this repository's files in the context of this pull request.
```

This ensures agents like `cursor-agent` have clear context for their tasks.

---

## **10. Output Behavior**

### **Comment Output (default for v1)**

Posts a structured GitHub PR comment:

```
### AutoAgent Results

**Rule:** owasp-check  
> No critical security issues detected.

**Rule:** custom  
> Found 2 inefficient SQL queries that may cause performance issues.
```

---

## **11. Workflow Execution Flow**

1. **Trigger:** PR opened or updated.
2. **Checkout Repo:** Repo code pulled into runner.
3. **Install Agent:**

   * Auto-install selected agent if `install-agent` is `true` or omitted.
   * Skip if explicitly set to `false`.
4. **Run Rules:** Execute predefined rules sequentially.
5. **Run Custom Prompt:** If provided, append at the end.
6. **Output Results:** Post aggregated results as PR comment.

---

## **12. Example `action.yml` (Full)**

```yaml
name: "AutoAgent"
description: "Composable GitHub Action to run AI agent prompts on a repository"
author: "Eran Sandler"

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
      run: |
        if [ "${{ inputs.agent }}" = "cursor" ]; then
          echo "Installing cursor-agent..."
          curl -sSL https://cursor.sh/install | bash
        else
          echo "Installing agent: ${{ inputs.agent }} (future support)"
        fi

    - name: Execute Rules
      run: |
        echo "Running AutoAgent with rules: ${{ inputs.rules }}"
        echo "Custom prompt: ${{ inputs.custom }}"
        echo "Using agent: ${{ inputs.agent }}"
        # Placeholder for actual agent execution logic
```

---

## **13. Acceptance Criteria**

* **Default behavior:** Installs and runs `cursor-agent` with no extra configuration.
* `install-agent: false` skips installation and assumes the agent is already in `$PATH`.
* `agent` defaults to `"cursor"` but can be swapped for other supported agents in future versions.
* Clear error message if the specified agent is missing or not installed.
