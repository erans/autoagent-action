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
  *)
    echo "Error: Unsupported agent: $AGENT"
    echo "Supported agents: cursor"
    exit 1
    ;;
esac

echo "Agent $AGENT installation completed."
