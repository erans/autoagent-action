# AutoAgent

> **⚠️ Experimental Project**: This project was created during a hackathon at the Cursor offices on September 10, 2025. Use at your own risk. Future updates will focus on making it production CI/CD ready. 🚧  - Thank you to the Curosr team for hosting!

A composable GitHub Action that integrates with AI agents like [Cursor CLI](https://cursor.com/cli), [Claude Code](https://claude.ai/code), [Gemini CLI](https://github.com/google-gemini/gemini-cli), [Codex CLI](https://github.com/openai/codex), and [Amp Code](https://ampcode.com/) to run prompts on a repository as part of Pull Request workflows.

## Features

- **Predefined Rules**: Run curated rules like OWASP security checks or refactoring suggestions
- **Custom Prompt Support**: Extend analysis with team-specific custom instructions
- **Agent Auto Installation**: Automatically installs the agent unless explicitly disabled
- **Multiple Agents Support**: Supports multiple AI coding agents: `cursor`, `claude`, `gemini`, `codex`, and `amp`
- **PR Comment Output**: Posts results back to GitHub PR comments in a structured format

## Usage

### Basic Example with Cursor

```yaml
name: AutoAgent Checks

on:
  pull_request:
    types: [opened, synchronize, reopened]

permissions:
  contents: read
  pull-requests: write
  issues: write

jobs:
  autoagent:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run AutoAgent
        uses: erans/autoagent@v1
        env:
          CURSOR_API_KEY: ${{ secrets.CURSOR_API_KEY }}
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

### Example with Claude Code

```yaml
name: AutoAgent with Claude

on:
  pull_request:
    types: [opened, synchronize, reopened]

permissions:
  contents: read
  pull-requests: write
  issues: write

jobs:
  autoagent:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run AutoAgent
        uses: erans/autoagent@v1
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        with:
          rules: |
            - owasp-check
            - code-review
          custom: |
            Please check for inefficient SQL queries and suggest optimizations.
          action: comment
          install-agent: true
          agent: claude
```

### Example with Gemini CLI

```yaml
name: AutoAgent with Gemini

on:
  pull_request:
    types: [opened, synchronize, reopened]

permissions:
  contents: read
  pull-requests: write
  issues: write

jobs:
  autoagent:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run AutoAgent
        uses: erans/autoagent@v1
        env:
          GOOGLE_API_KEY: ${{ secrets.GOOGLE_API_KEY }}
        with:
          rules: |
            - owasp-check
            - code-review
          custom: |
            Please check for inefficient SQL queries and suggest optimizations.
          action: comment
          install-agent: true
          agent: gemini
```

### Example with Codex CLI

```yaml
name: AutoAgent with Codex

on:
  pull_request:
    types: [opened, synchronize, reopened]

permissions:
  contents: read
  pull-requests: write
  issues: write

jobs:
  autoagent:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run AutoAgent
        uses: erans/autoagent@v1
        env:
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
        with:
          rules: |
            - owasp-check
            - code-review
          custom: |
            Please check for inefficient SQL queries and suggest optimizations.
          action: comment
          install-agent: true
          agent: codex
```

### Example with Amp Code

```yaml
name: AutoAgent with Amp

on:
  pull_request:
    types: [opened, synchronize, reopened]

permissions:
  contents: read
  pull-requests: write
  issues: write

jobs:
  autoagent:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run AutoAgent
        uses: erans/autoagent@v1
        env:
          AMP_API_KEY: ${{ secrets.AMP_API_KEY }}
        with:
          rules: |
            - owasp-check
            - code-review
          custom: |
            Please check for inefficient SQL queries and suggest optimizations.
          action: comment
          install-agent: true
          agent: amp
```

### Advanced Example

```yaml
name: AutoAgent Security & Quality Checks

on:
  pull_request:
    types: [opened, synchronize, reopened]

permissions:
  contents: read
  pull-requests: write
  issues: write

jobs:
  autoagent:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run AutoAgent
        uses: erans/autoagent@v1
        env:
          CURSOR_API_KEY: ${{ secrets.CURSOR_API_KEY }}
        with:
          rules: |
            - owasp-check
            - code-review
            - refactor-suggestions
            - duplication-check
          custom: |
            Please analyze the database schema changes and ensure they follow our naming conventions.
            Also check for any potential performance issues with the new queries.
          action: comment
          install-agent: true
          agent: cursor
```

### Custom Prompt Only Example

```yaml
name: AutoAgent Custom Analysis

on:
  pull_request:
    types: [opened, synchronize, reopened]

permissions:
  contents: read
  pull-requests: write
  issues: write

jobs:
  autoagent:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run AutoAgent
        uses: erans/autoagent@v1
        env:
          CURSOR_API_KEY: ${{ secrets.CURSOR_API_KEY }}
        with:
          custom: |
            Please review this pull request for:
            1. Code quality and best practices
            2. Security vulnerabilities
            3. Performance optimizations
            4. Documentation completeness
          action: comment
          install-agent: true
          agent: cursor
```

## Inputs

| Input | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `rules` | String (YAML/JSON list) | ❌ No | `[]` | Predefined rules to execute |
| `custom` | String | ❌ No | `""` | Custom prompt to append to predefined rules |
| `action` | Enum | ✅ Yes | `comment` | What to do with results (currently `comment` only) |
| `install-agent` | Boolean | ❌ No | `true` | Whether to install the agent automatically |
| `agent` | String | ❌ No | `cursor` | Which agent to use (`cursor`, `claude`, `gemini`, `codex`, `amp`) |

## Predefined Rules

| Rule Name | Description |
|-----------|-------------|
| `owasp-check` | Security scan based on OWASP Top 10 guidelines |
| `code-review` | Performs a general AI-driven code review |
| `refactor-suggestions` | Detects code smells and suggests refactors |
| `duplication-check` | Identifies code duplication and suggests existing code reuse |

## Output

The action posts structured results to the GitHub PR as comments:

```
### 🤖 AutoAgent Results

**Rule:** `owasp-check`
```
No critical security issues detected.
```

**Rule:** `code-review`
```
Found 2 potential improvements in the authentication logic.
```

**Rule:** `custom`
```
Database queries look optimized. Consider adding indexes for the new columns.
```

---
*Generated by [AutoAgent](https://github.com/erans/autoagent) v1.0*
```

## Requirements

- GitHub CLI (`gh`) must be available in the runner environment
- For YAML parsing: `yq` (optional, falls back to `jq`)
- For JSON parsing: `jq`
- **Node.js** - Required for installing npm-based agents (Claude, Gemini, Codex)
- **API Key** - Required for your chosen agent (see Environment Variables section)

## Environment Variables

### Required (based on agent):

- **`CURSOR_API_KEY`** - Required for Cursor CLI authentication
- **`ANTHROPIC_API_KEY`** - Required for Claude Code authentication
- **`GOOGLE_API_KEY`** - Required for Gemini CLI authentication
- **`OPENAI_API_KEY`** - Required for Codex CLI authentication
- **`AMP_API_KEY`** - Required for Amp Code authentication

### Optional:

- **`MODEL`** - Optional AI model to use. Defaults vary by agent:
  - Cursor: `gpt-5`
  - Claude: `opus` (also supports `sonnet`, `haiku`)
  - Gemini: `pro` (also supports `flash`)
  - Codex: `gpt-5` (also supports `o3`, `o1`)
  - Amp: `sonnet-4` (also supports `gpt-5`)

## Permissions

The action requires the following GitHub token permissions:

```yaml
permissions:
  contents: read
  pull-requests: write
  issues: write
```

Add this to your workflow file to ensure the action can post comments to pull requests.

## Setup

### 1. Add API Key Based on Your Agent

The action requires an API key environment variable to be set as a repository secret based on the agent you choose:

#### For Cursor Agent:

1. **Get your Cursor API key**:
   - Open Cursor IDE
   - Go to Settings (Cmd/Ctrl + ,)
   - Navigate to **General** → **Account**
   - Copy your API key from the account section

2. **Add the secret**: Add `CURSOR_API_KEY` as a repository secret

#### For Claude Code:

1. **Get your Anthropic API key**:
   - Go to [Anthropic Console](https://console.anthropic.com/)
   - Navigate to **API Keys**
   - Create a new API key or copy an existing one

2. **Add the secret**: Add `ANTHROPIC_API_KEY` as a repository secret

#### For Gemini CLI:

1. **Get your Google API key**:
   - Go to [Google AI Studio](https://aistudio.google.com/app/apikey)
   - Create a new API key or use an existing one
   - Alternatively, authenticate with Google login (free tier: 60 requests/minute)

2. **Add the secret**: Add `GOOGLE_API_KEY` as a repository secret

#### For Codex CLI:

1. **Get your OpenAI API key**:
   - Go to [OpenAI Platform](https://platform.openai.com/api-keys)
   - Create a new API key or use an existing one
   - Alternatively, sign in with your ChatGPT account (Plus, Pro, Team, Edu, or Enterprise)

2. **Add the secret**: Add `OPENAI_API_KEY` as a repository secret

#### For Amp Code:

1. **Get your Amp API key**:
   - Go to [Amp Code](https://ampcode.com/)
   - Sign up or log in to your account
   - Run `amp login` in your terminal to authenticate
   - Your API key will be stored locally and can be found in the credentials file

2. **Add the secret**: Add `AMP_API_KEY` as a repository secret

#### Steps to add any secret to your repository:
- Go to your GitHub repository
- Click **Settings** (in the repository toolbar)
- In the left sidebar, click **Secrets and variables** → **Actions**
- Click **New repository secret**
- Name: Use the appropriate key name for your agent
- Value: Paste your API key
- Click **Add secret**

**Important**: The API key must be added as a repository secret, not as an environment variable in the workflow file directly.

### 2. Add Workflow Permissions

Add the permissions block to your workflow file (see Permissions section above).

## Error Handling

The action will fail gracefully with descriptive error messages for:
- Missing rule files
- Agent installation failures
- Invalid input formats
- Missing required tools

## License

MIT License - see LICENSE file for details.
