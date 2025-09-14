#!/usr/bin/env bash
set -euo pipefail

AGENT="${1:-cursor}"

echo "Installing agent: $AGENT"

case "$AGENT" in
  cursor)
    echo "Installing cursor-agent..."
    # Check if cursor-agent is already installed
    if command -v cursor-agent >/dev/null 2>&1; then
      echo "cursor-agent is already installed"
      cursor-agent --version
    else
      # Install cursor-agent using the official installer
      curl -sSL https://cursor.sh/install | bash
      # Add to PATH for current session
      export PATH="$HOME/.cursor/bin:$PATH"
      echo "cursor-agent installed successfully"
      cursor-agent --version
    fi
    ;;
  claude)
    echo "Installing claude-code..."
    # Check if claude is already installed
    if command -v claude >/dev/null 2>&1; then
      echo "claude-code is already installed"
      claude --version
    else
      # Install claude-code using npm
      npm install -g @anthropic-ai/claude-code
      echo "claude-code installed successfully"
      claude --version
    fi
    ;;
  gemini)
    echo "Installing gemini-cli..."
    # Check if gemini is already installed
    if command -v gemini >/dev/null 2>&1; then
      echo "gemini-cli is already installed"
      gemini --version
    else
      # Install gemini-cli using npm
      npm install -g @google/gemini-cli
      echo "gemini-cli installed successfully"
      gemini --version
    fi
    ;;
  codex)
    echo "Installing codex-cli..."
    # Check if codex is already installed
    if command -v codex >/dev/null 2>&1; then
      echo "codex-cli is already installed"
      codex --version
    else
      # Install codex-cli using npm
      npm install -g @openai/codex
      echo "codex-cli installed successfully"
      codex --version
    fi
    ;;
  amp)
    echo "Installing amp-code..."
    # Check if amp is already installed
    if command -v amp >/dev/null 2>&1; then
      echo "amp-code is already installed"
      amp --version
    else
      # Install amp-code using npm
      npm install -g @sourcegraph/amp
      echo "amp-code installed successfully"
      amp --version
    fi
    ;;
  *)
    echo "Error: Unsupported agent: $AGENT"
    echo "Supported agents: cursor, claude, gemini, codex, amp"
    exit 1
    ;;
esac

echo "Agent $AGENT installation completed."
