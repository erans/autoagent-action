# AutoAgent

> **⚠️ Experimental Project**: This project was created during a hackathon at the Cursor offices on September 10, 2025. Use at your own risk. Future updates will focus on making it production CI/CD ready. 🚧  - Thank you to the Curosr team for hosting!

A composable GitHub Action that integrates with AI agents like [Cursor CLI](https://cursor.com/cli), [Claude Code](https://claude.ai/code), [Gemini CLI](https://github.com/google-gemini/gemini-cli), [Codex CLI](https://github.com/openai/codex), and [Amp Code](https://ampcode.com/) to run prompts on a repository as part of Pull Request workflows.

## Features

- **Predefined Rules**: Run curated rules like OWASP security checks or refactoring suggestions
- **Custom Prompt Support**: Extend analysis with team-specific custom instructions
- **Agent Auto Installation**: Automatically installs the agent unless explicitly disabled
- **Multiple Agents Support**: Supports multiple AI coding agents: `cursor`, `claude`, `gemini`, `codex`, and `amp`
- **Configurable Scope**: Analyze only changed files (fast) or entire codebase (comprehensive)
- **PR Comment Output**: Posts results back to GitHub PR comments in a structured format
- **Composable Python Architecture**: Built with maintainable, modular Python code for better reliability and extensibility
- **Configurable Logging**: Debug mode for troubleshooting with detailed execution information

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
        uses: erans/autoagent@main
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
        uses: erans/autoagent@main
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
        uses: erans/autoagent@main
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
        uses: erans/autoagent@main
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
        uses: erans/autoagent@main
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

### Analysis Scope Configuration

AutoAgent supports two analysis modes controlled by the `scope` parameter:

#### 🚀 **Changed Files Mode (Default)** - `scope: "changed"`

This mode analyzes only files that have been modified in the Pull Request, making it faster and more cost-effective by focusing AI analysis on the actual changes.

**How it works:**
- Automatically detects all files changed in the PR across all commits
- Uses multiple git diff strategies for maximum compatibility
- Provides changed file list context to AI agents
- Falls back to GitHub API when git history is insufficient
- Works with merge commits, rebases, and complex PR scenarios

**Key Benefits:**
- ⚡ **Faster execution** - Only processes changed files
- 💰 **Token efficient** - Reduces API costs significantly
- 🎯 **Focused analysis** - AI concentrates on actual changes
- 🔄 **Auto-detection** - Handles complex git scenarios automatically

**Requirements for Changed Files Mode:**
- Must use `fetch-depth: 0` in checkout action (see examples below)
- Requires GitHub CLI (`gh`) for API fallback
- Works best with proper base branch setup

#### Analyze Only Changed Files (Default - Faster)
```yaml
name: AutoAgent - Changed Files Only

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
        with:
          fetch-depth: 0  # Required for proper changed file detection
      - name: Run AutoAgent on Changed Files
        uses: erans/autoagent@main
        env:
          CURSOR_API_KEY: ${{ secrets.CURSOR_API_KEY }}
        with:
          rules: |
            - owasp-check
            - code-review
          scope: "changed"  # This is the default
          action: comment
          agent: cursor
```

#### 🔍 **Full Codebase Mode** - `scope: "all"`

This mode performs comprehensive analysis of the entire repository codebase, useful for security audits, architectural reviews, or when you need complete coverage.

**When to use:**
- Security audits requiring full codebase review
- Architectural analysis and refactoring suggestions
- Initial code quality assessment
- Compliance reviews and documentation checks

**Trade-offs:**
- ⏱️ **Slower execution** - Processes entire codebase
- 💸 **Higher cost** - Uses more API tokens
- 📊 **Comprehensive coverage** - No missed dependencies or context
- 🔎 **Deep analysis** - Can catch broader architectural issues

#### Analyze Entire Codebase (Comprehensive)
```yaml
name: AutoAgent - Full Codebase Analysis

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
        with:
          fetch-depth: 0  # Required for proper changed file detection
      - name: Run AutoAgent on Entire Codebase
        uses: erans/autoagent@main
        env:
          CURSOR_API_KEY: ${{ secrets.CURSOR_API_KEY }}
        with:
          rules: |
            - owasp-check
            - code-review
          scope: "all"  # Analyze entire codebase
          action: comment
          agent: cursor
```

### Troubleshooting Changed Files Detection

If you see `"No changed files detected"` in the output, enable debug logging first to get detailed information:

```yaml
- name: Run AutoAgent with Debug
  uses: erans/autoagent@main
  with:
    logging: debug  # Enable detailed debugging
    # ... other parameters
```

Then try these solutions based on the debug output:

#### **Issue: Shallow Clone**
```yaml
# ❌ This may cause detection issues
- uses: actions/checkout@v4

# ✅ Use this instead
- uses: actions/checkout@v4
  with:
    fetch-depth: 0  # Required for changed file detection
```

#### **Issue: Missing Base Branch**
The action automatically fetches the base branch, but ensure your workflow runs on pull request events:

```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened]  # All required events
```

#### **Issue: Complex Merge Scenarios**
AutoAgent uses 8 different detection strategies including:
- Merge-base calculation
- GitHub API fallback
- Merge commit detection
- Multiple git diff approaches

Check the debug output to see which strategy succeeded.

#### **Issue: Permissions**
Ensure your workflow has proper permissions:

```yaml
permissions:
  contents: read        # Required for checkout
  pull-requests: write  # Required for comments
  issues: write         # Required for GitHub API
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
        uses: erans/autoagent@main
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
        uses: erans/autoagent@main
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

### Debug Logging Example

Enable debug logging to troubleshoot issues with file detection, agent execution, or other problems:

```yaml
name: AutoAgent with Debug Logging

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
        with:
          fetch-depth: 0  # Required for proper changed file detection
      - name: Run AutoAgent with Debug Output
        uses: erans/autoagent@main
        env:
          CURSOR_API_KEY: ${{ secrets.CURSOR_API_KEY }}
        with:
          rules: |
            - owasp-check
            - code-review
          logging: debug  # Enable detailed debugging output
          agent: cursor
```

**Debug logging includes:**
- Detailed git diff strategies and results
- Changed file detection process
- Agent execution details and prompt lengths
- Rule processing steps and timings
- Error details and troubleshooting information

### Custom Rule Files Examples

AutoAgent supports custom rule files through the `customFiles` parameter, allowing you to create reusable, organization-specific analysis rules.

#### Basic Custom Files Example

```yaml
name: AutoAgent with Custom Rules

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
        with:
          fetch-depth: 0
      - name: Run AutoAgent with Custom Files
        uses: erans/autoagent@main
        env:
          CURSOR_API_KEY: ${{ secrets.CURSOR_API_KEY }}
        with:
          rules: |
            - owasp-check
            - code-review
          customFiles: |
            - .github/rules/team-standards.prompt
            - .github/rules/api-guidelines.prompt
          agent: cursor
```

#### Repository-Specific Rules

Create custom rule files in your repository under `.github/rules/`:

**`.github/rules/team-standards.prompt`**:
```
Review the code for adherence to our team's coding standards:

## API Design Standards
- All API endpoints must use consistent naming (kebab-case)
- Response structures must include status, data, and meta fields
- Error responses must follow RFC 7807 problem details format

## Database Standards
- All queries must use prepared statements
- Table names must be snake_case
- Foreign key relationships must be explicitly defined

## Testing Requirements
- All public methods must have unit tests
- Integration tests required for API endpoints
- Test coverage must be > 80%

Provide specific violations found with file locations and recommended fixes.
```

**`.github/rules/api-guidelines.prompt`**:
```
Analyze the API implementation for compliance with our guidelines:

## REST API Standards
- Proper HTTP status codes usage
- Consistent error handling patterns
- Request/response validation
- Rate limiting implementation

## Security Requirements
- Input sanitization for all endpoints
- Authentication middleware on protected routes
- SQL injection prevention
- XSS protection measures

Report any deviations from these standards with specific remediation steps.
```

#### Shared Organization Rules

Use relative paths to reference shared rules from a parent directory or organization-wide rule repository:

```yaml
- name: Run AutoAgent with Shared Org Rules
  uses: erans/autoagent@main
  env:
    CURSOR_API_KEY: ${{ secrets.CURSOR_API_KEY }}
  with:
    customFiles: |
      - ../shared-rules/org-security.prompt
      - ../shared-rules/performance-standards.prompt
      - .github/rules/local-overrides.prompt
    agent: cursor
```

#### Mixed Rules Configuration

Combine predefined rules, custom files, and custom prompts:

```yaml
- name: Comprehensive AutoAgent Analysis
  uses: erans/autoagent@main
  env:
    CURSOR_API_KEY: ${{ secrets.CURSOR_API_KEY }}
  with:
    rules: |
      - owasp-check
      - secrets-detection
    customFiles: |
      - .github/rules/team-standards.prompt
      - .github/rules/performance-check.prompt
    custom: |
      Additionally, please verify that all new database migrations
      include proper rollback procedures and performance impact analysis.
    agent: cursor
```

#### JSON Format Support

CustomFiles also supports JSON array format:

```yaml
- name: AutoAgent with JSON Custom Files
  uses: erans/autoagent@main
  env:
    CURSOR_API_KEY: ${{ secrets.CURSOR_API_KEY }}
  with:
    customFiles: '["./rules/custom.prompt", ".github/rules/standards.prompt"]'
    agent: cursor
```

#### File Path Resolution

- **Relative paths**: Resolved relative to the repository root (`$GITHUB_WORKSPACE`)
  - `./rules/custom.prompt` → `$GITHUB_WORKSPACE/rules/custom.prompt`
  - `.github/rules/team.prompt` → `$GITHUB_WORKSPACE/.github/rules/team.prompt`
  - `../shared/rule.prompt` → Parent directory of workspace

- **Absolute paths**: Used as-is (with security validation)
  - `/home/runner/work/shared/rule.prompt`

- **Security features**:
  - File existence and readability validation
  - File size limits (max 1MB per file)
  - Path traversal protection
  - Graceful error handling for invalid files

#### Rule Naming in Comments

Custom rule files appear in PR comments using just the filename (without path or `.prompt` extension):

- `.github/rules/team-standards.prompt` appears as `team-standards`
- `../shared/org-security.prompt` appears as `org-security`
- `/absolute/path/api-check.prompt` appears as `api-check`

## Inputs

| Input | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `rules` | String (YAML/JSON list) | ❌ No | `[]` | Predefined rules to execute |
| `custom` | String | ❌ No | `""` | Custom prompt to append to predefined rules |
| `customFiles` | String (YAML/JSON list) | ❌ No | `[]` | Custom .prompt files to execute (supports relative and absolute paths) |
| `action` | Enum | ✅ Yes | `comment` | What to do with results (currently `comment` only) |
| `install-agent` | Boolean | ❌ No | `true` | Whether to install the agent automatically |
| `agent` | String | ❌ No | `cursor` | Which agent to use (`cursor`, `claude`, `gemini`, `codex`, `amp`) |
| `scope` | String | ❌ No | `changed` | Analysis scope: `changed` for PR files only, `all` for entire codebase |
| `logging` | String | ❌ No | `info` | Logging level: `info` for normal output, `debug` for detailed debugging information |

## Predefined Rules

| Rule Name | Description |
|-----------|-------------|
| `owasp-check` | **🔒 Comprehensive security analysis** based on OWASP Top 10 2021 guidelines including broken access control, cryptographic failures, injection vulnerabilities, insecure design, security misconfigurations, vulnerable components, authentication failures, software integrity failures, logging failures, and SSRF. Also covers XSS, CSRF, path traversal, and security headers analysis. |
| `sql-injection` | **💉 SQL injection vulnerability analysis** - Detects SQL, NoSQL, and other injection vulnerabilities across multiple languages (JavaScript, Python, Java, PHP, C#, Go) and frameworks. Covers parameterized queries, ORM security, dynamic query construction, and stored procedure vulnerabilities. |
| `secrets-detection` | **🔑 Advanced secrets detection** - Scans for hardcoded API keys, database credentials, private keys, cloud provider secrets, third-party service keys, cryptographic material, and logging security issues. Features entropy analysis, context evaluation, false positive reduction, and multi-language support across configuration files. |
| `code-review` | **🔍 Comprehensive code quality analysis** - Reviews naming conventions, code structure, architecture patterns, SOLID principles, performance optimization, error handling, input validation, testing quality, security best practices, documentation, and technical debt management. Includes language-specific conventions for JavaScript, Python, Java, C#. |
| `refactor-suggestions` | **♻️ Code refactoring opportunities** - Detects code smells like long methods, duplicate code, poor naming, and suggests refactoring techniques. Includes extended codebase analysis capabilities to find patterns across multiple files. |
| `duplication-check` | **📋 Code duplication detection** - Identifies duplicated code patterns and suggests opportunities to reuse existing implementations across the codebase. |

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
- **Git History** - Use `fetch-depth: 0` in checkout action for proper changed file detection

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
  - Claude: `claude-sonnet-4-20250514` (also supports `claude-opus-4-1-20250805`, `claude-3-5-haiku-20241022`)
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
