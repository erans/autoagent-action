# AutoAgent Project Structure

AutoAgent is a composable GitHub Action that integrates with multiple AI agents (Cursor CLI, Claude Code, Gemini CLI, Codex CLI, Amp Code, and OpenCode) to run automated code analysis and prompts on repositories as part of Pull Request workflows.

## Project Overview

AutoAgent provides a standardized way to run AI-driven code analysis in GitHub Actions, offering predefined security checks, code reviews, and refactoring suggestions, plus support for custom prompts. It automatically installs the required AI agent and posts structured results back to the PR as comments.

## Directory Structure

### Root Files

| File | Purpose |
|------|---------|
| `action.yml` | GitHub Action definition with inputs, outputs, and execution steps |
| `README.md` | User documentation with usage examples and configuration options |
| `results.json` | Temporary file storing analysis results in JSON format |
| `test.sh` | Comprehensive test script that validates the entire implementation |
| `test-simple.sh` | Lightweight test script for syntax validation and basic functionality |

### `/docs/` - Documentation

| File | Purpose |
|------|---------|
| `prd.md` | Product Requirements Document defining features, inputs, and behavior |
| `tech-prd.md` | Technical Implementation Guide with architecture and code structure details |

### `/rules/` - AI Agent Prompts

Contains predefined prompt templates that guide the AI agent's analysis:

| File | Purpose |
|------|---------|
| `base.prompt` | Shared initialization context for all agents running in GitHub Actions |
| `code-review.prompt` | Comprehensive code review focusing on quality, architecture, performance, and maintainability |
| `owasp-check.prompt` | Security analysis based on OWASP Top 10 guidelines |
| `refactor-suggestions.prompt` | Code smell detection and refactoring opportunity identification |
| `comment.prompt` | Output formatting instructions for PR comments (concise, actionable, with compare links) |

### `/scripts/` - Core Implementation

Contains the main execution logic for the GitHub Action:

| File | Purpose |
|------|---------|
| `install_agent.sh` | Installs the specified AI agent (supports Cursor, Claude, Gemini, Codex, Amp, OpenCode) |
| `run_prompts.py` | Python-based execution engine for rules and custom prompts using the selected agent |
| `post_comment.sh` | Posts analysis results as formatted comments to the GitHub PR |

## File Types and Their Roles

### Configuration Files

- **`action.yml`**: Defines the GitHub Action interface with 5 inputs:
  - `rules`: YAML/JSON list of predefined rules to execute (optional, defaults to empty array)
  - `custom`: Optional custom prompt string
  - `action`: Output action type (currently only "comment")
  - `install-agent`: Boolean flag for automatic agent installation
  - `agent`: Agent type selection (defaults to "cursor")

### Shell Scripts

All scripts follow bash best practices with `set -euo pipefail` for error handling:

- **`install_agent.sh`**: Handles agent installation with support for multiple agent types (cursor, claude, gemini, codex, amp, opencode)
- **`run_prompts.py`**: Python-based core execution engine that:
  - Parses rule inputs (YAML/JSON) or handles empty rules
  - Combines base context with rule-specific prompts
  - Appends comment formatting instructions to all prompts
  - Executes analysis using the selected agent
  - Aggregates results into JSON format
  - Supports running only custom prompts without predefined rules
- **`post_comment.sh`**: Formats and posts results to GitHub PR using the GitHub CLI

### Prompt Files

- **`.prompt` files**: Plain text templates that define specific analysis tasks
- Each prompt is designed to work with the base context to provide consistent GitHub Actions environment awareness
- Prompts are modular and can be combined or used independently

### Test Files

- **`test.sh`**: Full integration test including file structure, permissions, and execution
- **`test-simple.sh`**: Syntax validation and basic functionality testing without requiring agent installation

### Documentation Files

- **`prd.md`**: Product specification with user stories, acceptance criteria, and configuration examples
- **`tech-prd.md`**: Technical implementation details, architecture diagrams, and extensibility plans

## Workflow Execution Flow

1. **Trigger**: GitHub Action runs on PR events (opened, synchronize, reopened)
2. **Agent Installation**: `install_agent.sh` installs the specified AI agent if enabled
3. **Rule Execution**: `run_prompts.sh` processes each predefined rule:
   - Loads base context from `rules/base.prompt`
   - Appends rule-specific prompt
   - Executes using the selected agent
   - Captures output in JSON format
4. **Custom Prompt**: If provided, executes custom prompt with same base context
5. **Result Posting**: `post_comment.sh` formats results and posts to PR as structured comment

## Key Features

- **Modular Design**: Each component (installation, execution, posting) is separate and testable
- **Multi-Agent Support**: Architecture supports multiple AI agents (Cursor, Claude, Gemini, Codex, Amp, OpenCode)
- **Error Handling**: Comprehensive error checking and graceful failure modes
- **Input Validation**: Validates rule formats, custom prompt length limits, and required dependencies
- **Structured Output**: Results are formatted as readable GitHub PR comments with proper markdown escaping

## Supported AI Agents

### Cursor CLI
- **Installation**: Official installer from cursor.sh
- **API Key**: `CURSOR_API_KEY`
- **Default Model**: `gpt-5`

### Claude Code
- **Installation**: npm package `@anthropic-ai/claude-code`
- **API Key**: `ANTHROPIC_API_KEY`
- **Default Model**: `claude-sonnet-4-20250514`

### Gemini CLI
- **Installation**: npm package `@google/gemini-cli`
- **API Key**: `GOOGLE_API_KEY`
- **Default Model**: `pro`

### Codex CLI
- **Installation**: npm package `@openai/codex`
- **API Key**: `OPENAI_API_KEY`
- **Default Model**: `gpt-5`

### Amp Code
- **Installation**: npm package `@sourcegraph/amp`
- **API Key**: `AMP_API_KEY`
- **Default Model**: `sonnet-4`

### OpenCode
- **Installation**: npm package `@opencode/cli`
- **Multi-Provider Support**: Supports 75+ models across multiple providers
- **API Keys**: Multiple keys supported based on model provider:
  - `ANTHROPIC_API_KEY` for Anthropic Claude models
  - `OPENAI_API_KEY` for OpenAI models
  - `GOOGLE_API_KEY` for Google Gemini models
  - `GROQ_API_KEY` for Groq models
  - `COHERE_API_KEY` for Cohere models
  - `MISTRAL_API_KEY` for Mistral models
- **Default Model**: `anthropic/claude-sonnet-4-20250514`
- **Model Format**: `provider/model` (e.g., `openai/gpt-4`, `google/gemini-pro`)
- **Special Features**:
  - Automatic provider detection from model string
  - Quiet mode for clean CI/CD output
  - Flexible configuration for different environments

## Dependencies

- **GitHub CLI** (`gh`): Required for posting PR comments
- **JSON processing**: `jq` for JSON parsing and manipulation
- **YAML processing**: `yq` (optional, falls back to `jq`)
- **Python 3**: Required for the main execution engine
- **Node.js**: Required for npm-based agents (Claude, Gemini, Codex, OpenCode)
- **AI Agents**: One of the supported agents listed above

## Extensibility

The project is designed for easy extension:

- **New Agents**: Add support in `install_agent.sh` and `run_prompts.py`
- **New Rules**: Create additional `.prompt` files in `/rules/`
- **New Actions**: Extend `action.yml` and add new output handlers
- **Custom Prompts**: Support for team-specific analysis requirements

This architecture provides a solid foundation for AI-driven code analysis in GitHub Actions while maintaining simplicity and extensibility.
