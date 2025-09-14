#!/usr/bin/env bash
set -euo pipefail

echo "DEBUG: Script started at $(date)"
echo "DEBUG: Arguments received: $*"

RULES="${1:-}"
CUSTOM_PROMPT="${2:-}"
AGENT="${3:-cursor}"
SCOPE="${4:-changed}"
RESULT_FILE="results.json"

echo "DEBUG: Parsed arguments - RULES: '$RULES', CUSTOM_PROMPT: '$CUSTOM_PROMPT', AGENT: '$AGENT', SCOPE: '$SCOPE'"

# Get the action directory (where this script is located)
ACTION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "DEBUG: Action directory: $ACTION_DIR"

# Set up environment for different agents
case "$AGENT" in
    cursor)
        export PATH="$HOME/.cursor/bin:$PATH"
        MODEL="${MODEL:-gpt-5}"
        ;;
    claude)
        # Claude Code uses Anthropic models
        MODEL="${MODEL:-claude-sonnet-4-20250514}"
        ;;
    gemini)
        # Gemini CLI uses Google models
        MODEL="${MODEL:-pro}"
        ;;
    codex)
        # Codex CLI uses OpenAI models
        MODEL="${MODEL:-gpt-5}"
        ;;
    amp)
        # Amp Code uses Claude Sonnet by default
        MODEL="${MODEL:-sonnet-4}"
        ;;
esac

echo "DEBUG: Updated PATH: $PATH"

echo "Running rules with agent: $AGENT"
echo "Using model: $MODEL"
echo "Using scope: $SCOPE"

# Get file context based on scope
if [ "$SCOPE" = "all" ]; then
    FILE_CONTEXT="Analyze the entire codebase in this repository."
    CHANGED_FILES=""
    echo "DEBUG: Scope is 'all' - analyzing entire codebase"
else
    echo "DEBUG: Scope is 'changed' - running git diff commands to detect changed files"

    # Try different git diff commands and show debug output
    echo "DEBUG: Trying git diff --name-only origin/main..HEAD"
    CHANGED_FILES=$(git diff --name-only origin/main..HEAD 2>&1) || {
        echo "DEBUG: First git diff command failed with output: $CHANGED_FILES"
        echo "DEBUG: Trying git diff --name-only HEAD~1 HEAD"
        CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD 2>&1) || {
            echo "DEBUG: Second git diff command failed with output: $CHANGED_FILES"
            CHANGED_FILES=""
        }
    }

    echo "DEBUG: Raw git diff output:"
    echo "--- START GIT DIFF OUTPUT ---"
    echo "$CHANGED_FILES"
    echo "--- END GIT DIFF OUTPUT ---"

    # Clean up the output (remove error messages, keep only filenames)
    CHANGED_FILES_CLEAN=$(echo "$CHANGED_FILES" | grep -v "^fatal:" | grep -v "^warning:" | grep -v "^error:" | tr '\n' ' ' | sed 's/[[:space:]]*$//')

    if [ -n "$CHANGED_FILES_CLEAN" ]; then
        FILE_CONTEXT="Focus ONLY on these files changed in this PR: $CHANGED_FILES_CLEAN"
        echo "DEBUG: Scope is 'changed' - found changed files: $CHANGED_FILES_CLEAN"
        echo "DEBUG: Number of changed files: $(echo "$CHANGED_FILES_CLEAN" | wc -w)"
    else
        FILE_CONTEXT="No changed files detected. Analyze the current repository state."
        echo "DEBUG: Scope is 'changed' but no changed files detected"
        echo "DEBUG: Git repository status:"
        git status --porcelain 2>&1 || echo "DEBUG: git status failed"
        echo "DEBUG: Git log (last 3 commits):"
        git log --oneline -3 2>&1 || echo "DEBUG: git log failed"
    fi
    CHANGED_FILES="$CHANGED_FILES_CLEAN"
fi
echo "DEBUG: Final file context: $FILE_CONTEXT"

# Validate inputs
if [ -z "$RULES" ] && [ -z "$CUSTOM_PROMPT" ]; then
    echo "Error: No rules or custom prompt provided"
    exit 1
fi

# Check if custom prompt is too long (5000 character limit as per PRD)
if [ ${#CUSTOM_PROMPT} -gt 5000 ]; then
    echo "Error: Custom prompt exceeds 5000 character limit (current: ${#CUSTOM_PROMPT})"
    exit 1
fi

# Initialize results file
echo "[]" > "$RESULT_FILE"

# Function to add result to JSON array
add_result() {
    local rule="$1"
    local output="$2"
    local temp_file=$(mktemp)
    
    # Debug: Show what we're adding
    echo "Adding result for rule: $rule"
    echo "Output length: ${#output} characters"
    echo "First 100 chars: ${output:0:100}"
    
    # Use raw input to preserve newlines and special characters
    jq --arg rule "$rule" --rawfile output <(printf '%s' "$output") '. + [{"rule": $rule, "output": $output}]' "$RESULT_FILE" > "$temp_file"
    mv "$temp_file" "$RESULT_FILE"
}

# Parse rules input (support both YAML and JSON)
echo "DEBUG: About to parse rules input: '$RULES'"
RULES_ARRAY=""

if [ -n "$RULES" ]; then
    echo "DEBUG: Rules input is not empty, parsing..."
# Try to parse as YAML first, then JSON
if command -v yq >/dev/null 2>&1; then
        echo "DEBUG: Using yq to parse YAML"
    # Parse as YAML using yq
    RULES_ARRAY=$(echo "$RULES" | yq -r '.[]' 2>/dev/null || echo "")
elif command -v jq >/dev/null 2>&1; then
        echo "DEBUG: Using jq to parse JSON"
    # Parse as JSON using jq
    RULES_ARRAY=$(echo "$RULES" | jq -r '.[]' 2>/dev/null || echo "")
else
        echo "DEBUG: No yq or jq found, treating as space-separated list"
    # Fallback: treat as space-separated list
    RULES_ARRAY="$RULES"
fi

    echo "DEBUG: Parsed rules array: '$RULES_ARRAY'"
    if [ -z "$RULES_ARRAY" ] && [ "$RULES" != "[]" ]; then
    echo "Error: Could not parse rules input. Please provide valid YAML or JSON array."
    echo "Example: '[\"owasp-check\", \"code-review\"]'"
    exit 1
    fi
else
    echo "DEBUG: No rules input provided"
fi

# Execute each rule (if any)
if [ -n "$RULES_ARRAY" ]; then
echo "$RULES_ARRAY" | while read -r RULE; do
    if [ -z "$RULE" ]; then
        continue
    fi
    
    PROMPT_FILE="$ACTION_DIR/rules/${RULE}.prompt"
    if [ ! -f "$PROMPT_FILE" ]; then
        echo "Error: Rule file not found: $PROMPT_FILE"
        echo "Available rules: $(ls "$ACTION_DIR/rules"/*.prompt 2>/dev/null | sed 's/.*\///g' | sed 's/\.prompt//g' | tr '\n' ' ' || echo 'none')"
        exit 1
    fi

    echo "Executing rule: $RULE"
    
    # Load base prompt with GitHub Actions context
    BASE_PROMPT_FILE="$ACTION_DIR/rules/base.prompt"
    echo "DEBUG: About to load base prompt file: $BASE_PROMPT_FILE"
    if [ ! -f "$BASE_PROMPT_FILE" ]; then
        echo "Error: Base prompt file not found: $BASE_PROMPT_FILE"
        exit 1
    fi
    echo "DEBUG: Base prompt file found, loading content..."
    
    # Load comment prompt for output formatting
    COMMENT_PROMPT_FILE="$ACTION_DIR/rules/comment.prompt"
    echo "DEBUG: About to load comment prompt file: $COMMENT_PROMPT_FILE"
    if [ ! -f "$COMMENT_PROMPT_FILE" ]; then
        echo "Error: Comment prompt file not found: $COMMENT_PROMPT_FILE"
        exit 1
    fi
    echo "DEBUG: Comment prompt file found, loading content..."
    
    # Combine base prompt with scope context, rule-specific prompt and comment formatting
    echo "DEBUG: About to combine prompts..."
    FULL_PROMPT="$(cat "$BASE_PROMPT_FILE")

## Analysis Scope
$FILE_CONTEXT

You have access to git commands to see changes:
- git diff --name-only origin/main..HEAD (or HEAD~1 HEAD)
- git diff origin/main..HEAD -- <filename>
- git show --name-only HEAD

Use these commands as needed for your analysis.

$(cat "$PROMPT_FILE")

$(cat "$COMMENT_PROMPT_FILE")"
    echo "DEBUG: Prompts combined, total length: ${#FULL_PROMPT}"
    
    # Execute the rule using the selected agent
    case "$AGENT" in
        cursor)
            if command -v cursor-agent >/dev/null 2>&1; then
                echo "DEBUG: Executing cursor-agent with prompt length: ${#FULL_PROMPT}"
                echo "DEBUG: First 200 chars of prompt:"
                echo "${FULL_PROMPT:0:200}"
                echo "DEBUG: --- END PROMPT PREVIEW ---"
                echo "DEBUG: Cursor-agent version:"
                cursor-agent --version || echo "Version check failed"
                echo "DEBUG: Environment variables:"
                echo "DEBUG: CURSOR_API_KEY is set: $([ -n "${CURSOR_API_KEY:-}" ] && echo "YES" || echo "NO")"
                echo "DEBUG: MODEL: $MODEL"
                echo "DEBUG: Starting cursor-agent execution..."

                # Create a temporary file for the prompt to handle multi-line text properly
                PROMPT_FILE_TEMP=$(mktemp)
                echo "$FULL_PROMPT" > "$PROMPT_FILE_TEMP"
                echo "DEBUG: Created temporary prompt file: $PROMPT_FILE_TEMP"

                # Execute cursor-agent with -p flag
                OUTPUT=$(CURSOR_API_KEY="$CURSOR_API_KEY" timeout 300 cursor-agent -p --output-format text --model "$MODEL" --force < "$PROMPT_FILE_TEMP" 2>&1 || echo "Error: Failed to execute cursor-agent")

                # Clean up temporary file
                rm -f "$PROMPT_FILE_TEMP"

                echo "DEBUG: Raw cursor-agent output:"
                echo "--- START RAW OUTPUT ---"
                echo "$OUTPUT"
                echo "--- END RAW OUTPUT ---"
                echo "DEBUG: Output length: ${#OUTPUT}"
            else
                OUTPUT="Error: cursor-agent not found. Please ensure it's installed or set install-agent: true"
            fi
            ;;
        claude)
            if command -v claude >/dev/null 2>&1; then
                echo "DEBUG: Executing claude with prompt length: ${#FULL_PROMPT}"
                echo "DEBUG: First 200 chars of prompt:"
                echo "${FULL_PROMPT:0:200}"
                echo "DEBUG: --- END PROMPT PREVIEW ---"
                echo "DEBUG: Claude version:"
                claude --version || echo "Version check failed"
                echo "DEBUG: Environment variables:"
                echo "DEBUG: ANTHROPIC_API_KEY is set: $([ -n "${ANTHROPIC_API_KEY:-}" ] && echo "YES" || echo "NO")"
                echo "DEBUG: MODEL: $MODEL"
                echo "DEBUG: Starting claude execution..."

                # Create a temporary file for the prompt
                PROMPT_FILE_TEMP=$(mktemp)
                echo "$FULL_PROMPT" > "$PROMPT_FILE_TEMP"
                echo "DEBUG: Created temporary prompt file: $PROMPT_FILE_TEMP"

                # Execute claude with model flag and prompt from file
                OUTPUT=$(timeout 300 claude --model "$MODEL" --output-format text -p "$(cat "$PROMPT_FILE_TEMP")" 2>&1 || echo "Error: Failed to execute claude")

                # Clean up temporary file
                rm -f "$PROMPT_FILE_TEMP"

                echo "DEBUG: Raw claude output:"
                echo "--- START RAW OUTPUT ---"
                echo "$OUTPUT"
                echo "--- END RAW OUTPUT ---"
                echo "DEBUG: Output length: ${#OUTPUT}"
            else
                OUTPUT="Error: claude not found. Please ensure it's installed or set install-agent: true"
            fi
            ;;
        gemini)
            if command -v gemini >/dev/null 2>&1; then
                echo "DEBUG: Executing gemini with prompt length: ${#FULL_PROMPT}"
                echo "DEBUG: First 200 chars of prompt:"
                echo "${FULL_PROMPT:0:200}"
                echo "DEBUG: --- END PROMPT PREVIEW ---"
                echo "DEBUG: Gemini version:"
                gemini --version || echo "Version check failed"
                echo "DEBUG: Environment variables:"
                echo "DEBUG: GOOGLE_API_KEY is set: $([ -n "${GOOGLE_API_KEY:-}" ] && echo "YES" || echo "NO")"
                echo "DEBUG: MODEL: $MODEL"
                echo "DEBUG: Starting gemini execution..."

                # Create a temporary file for the prompt
                PROMPT_FILE_TEMP=$(mktemp)
                echo "$FULL_PROMPT" > "$PROMPT_FILE_TEMP"
                echo "DEBUG: Created temporary prompt file: $PROMPT_FILE_TEMP"

                # Execute gemini with model flag and output format
                OUTPUT=$(timeout 300 gemini -m "$MODEL" --output-format text -p "$(cat "$PROMPT_FILE_TEMP")" 2>&1 || echo "Error: Failed to execute gemini")

                # Clean up temporary file
                rm -f "$PROMPT_FILE_TEMP"

                echo "DEBUG: Raw gemini output:"
                echo "--- START RAW OUTPUT ---"
                echo "$OUTPUT"
                echo "--- END RAW OUTPUT ---"
                echo "DEBUG: Output length: ${#OUTPUT}"
            else
                OUTPUT="Error: gemini not found. Please ensure it's installed or set install-agent: true"
            fi
            ;;
        codex)
            if command -v codex >/dev/null 2>&1; then
                echo "DEBUG: Executing codex with prompt length: ${#FULL_PROMPT}"
                echo "DEBUG: First 200 chars of prompt:"
                echo "${FULL_PROMPT:0:200}"
                echo "DEBUG: --- END PROMPT PREVIEW ---"
                echo "DEBUG: Codex version:"
                codex --version || echo "Version check failed"
                echo "DEBUG: Environment variables:"
                echo "DEBUG: OPENAI_API_KEY is set: $([ -n "${OPENAI_API_KEY:-}" ] && echo "YES" || echo "NO")"
                echo "DEBUG: MODEL: $MODEL"
                echo "DEBUG: Starting codex execution..."

                # Create a temporary file for the prompt
                PROMPT_FILE_TEMP=$(mktemp)
                echo "$FULL_PROMPT" > "$PROMPT_FILE_TEMP"
                echo "DEBUG: Created temporary prompt file: $PROMPT_FILE_TEMP"

                # Execute codex with model flag (non-interactive)
                OUTPUT=$(timeout 300 codex -m "$MODEL" "$(cat "$PROMPT_FILE_TEMP")" 2>&1 || echo "Error: Failed to execute codex")

                # Clean up temporary file
                rm -f "$PROMPT_FILE_TEMP"

                echo "DEBUG: Raw codex output:"
                echo "--- START RAW OUTPUT ---"
                echo "$OUTPUT"
                echo "--- END RAW OUTPUT ---"
                echo "DEBUG: Output length: ${#OUTPUT}"
            else
                OUTPUT="Error: codex not found. Please ensure it's installed or set install-agent: true"
            fi
            ;;
        amp)
            if command -v amp >/dev/null 2>&1; then
                echo "DEBUG: Executing amp with prompt length: ${#FULL_PROMPT}"
                echo "DEBUG: First 200 chars of prompt:"
                echo "${FULL_PROMPT:0:200}"
                echo "DEBUG: --- END PROMPT PREVIEW ---"
                echo "DEBUG: Amp version:"
                amp --version || echo "Version check failed"
                echo "DEBUG: Environment variables:"
                echo "DEBUG: AMP_API_KEY is set: $([ -n "${AMP_API_KEY:-}" ] && echo "YES" || echo "NO")"
                echo "DEBUG: MODEL: $MODEL"
                echo "DEBUG: Starting amp execution..."

                # Create a temporary file for the prompt
                PROMPT_FILE_TEMP=$(mktemp)
                echo "$FULL_PROMPT" > "$PROMPT_FILE_TEMP"
                echo "DEBUG: Created temporary prompt file: $PROMPT_FILE_TEMP"

                # Execute amp with -x flag for execute mode (non-interactive)
                OUTPUT=$(AMP_API_KEY="$AMP_API_KEY" timeout 300 amp -x "$(cat "$PROMPT_FILE_TEMP")" 2>&1 || echo "Error: Failed to execute amp")

                # Clean up temporary file
                rm -f "$PROMPT_FILE_TEMP"

                echo "DEBUG: Raw amp output:"
                echo "--- START RAW OUTPUT ---"
                echo "$OUTPUT"
                echo "--- END RAW OUTPUT ---"
                echo "DEBUG: Output length: ${#OUTPUT}"
            else
                OUTPUT="Error: amp not found. Please ensure it's installed or set install-agent: true"
            fi
            ;;
        *)
            OUTPUT="Error: Unsupported agent: $AGENT"
            ;;
    esac
    
    # Add result to JSON array
    add_result "$RULE" "$OUTPUT"
    echo "Completed rule: $RULE"
done
fi

# Run custom prompt if provided
if [ -n "$CUSTOM_PROMPT" ]; then
    echo "Executing custom prompt..."
    
    # Load base prompt with GitHub Actions context
    BASE_PROMPT_FILE="$ACTION_DIR/rules/base.prompt"
    if [ ! -f "$BASE_PROMPT_FILE" ]; then
        echo "Error: Base prompt file not found: $BASE_PROMPT_FILE"
        exit 1
    fi
    
    # Load comment prompt for output formatting
    COMMENT_PROMPT_FILE="$ACTION_DIR/rules/comment.prompt"
    if [ ! -f "$COMMENT_PROMPT_FILE" ]; then
        echo "Error: Comment prompt file not found: $COMMENT_PROMPT_FILE"
        exit 1
    fi
    
    # Combine base prompt with scope context, custom prompt and comment formatting
    FULL_CUSTOM_PROMPT="$(cat "$BASE_PROMPT_FILE")

## Analysis Scope
$FILE_CONTEXT

You have access to git commands to see changes:
- git diff --name-only origin/main..HEAD (or HEAD~1 HEAD)
- git diff origin/main..HEAD -- <filename>
- git show --name-only HEAD

Use these commands as needed for your analysis.

${CUSTOM_PROMPT}

$(cat "$COMMENT_PROMPT_FILE")"
    
    # Execute custom prompt using the selected agent
    case "$AGENT" in
        cursor)
            if command -v cursor-agent >/dev/null 2>&1; then
                echo "DEBUG: Executing custom prompt with cursor-agent"
                echo "DEBUG: Custom prompt length: ${#FULL_CUSTOM_PROMPT}"
                echo "DEBUG: First 200 chars of custom prompt:"
                echo "${FULL_CUSTOM_PROMPT:0:200}"
                echo "DEBUG: --- END CUSTOM PROMPT PREVIEW ---"
                echo "DEBUG: Starting custom prompt execution..."

                # Create a temporary file for the custom prompt
                CUSTOM_PROMPT_FILE_TEMP=$(mktemp)
                echo "$FULL_CUSTOM_PROMPT" > "$CUSTOM_PROMPT_FILE_TEMP"
                echo "DEBUG: Created temporary custom prompt file: $CUSTOM_PROMPT_FILE_TEMP"

                # Execute cursor-agent with -p flag
                OUTPUT=$(CURSOR_API_KEY="$CURSOR_API_KEY" timeout 300 cursor-agent -p --output-format text --model "$MODEL" --force < "$CUSTOM_PROMPT_FILE_TEMP" 2>&1 || echo "Error: Failed to execute cursor-agent")

                # Clean up temporary file
                rm -f "$CUSTOM_PROMPT_FILE_TEMP"

                echo "DEBUG: Raw custom prompt output:"
                echo "--- START CUSTOM OUTPUT ---"
                echo "$OUTPUT"
                echo "--- END CUSTOM OUTPUT ---"
                echo "DEBUG: Custom output length: ${#OUTPUT}"
            else
                OUTPUT="Error: cursor-agent not found. Please ensure it's installed or set install-agent: true"
            fi
            ;;
        claude)
            if command -v claude >/dev/null 2>&1; then
                echo "DEBUG: Executing custom prompt with claude"
                echo "DEBUG: Custom prompt length: ${#FULL_CUSTOM_PROMPT}"
                echo "DEBUG: First 200 chars of custom prompt:"
                echo "${FULL_CUSTOM_PROMPT:0:200}"
                echo "DEBUG: --- END CUSTOM PROMPT PREVIEW ---"
                echo "DEBUG: Starting custom prompt execution..."

                # Create a temporary file for the custom prompt
                CUSTOM_PROMPT_FILE_TEMP=$(mktemp)
                echo "$FULL_CUSTOM_PROMPT" > "$CUSTOM_PROMPT_FILE_TEMP"
                echo "DEBUG: Created temporary custom prompt file: $CUSTOM_PROMPT_FILE_TEMP"

                # Execute claude with model flag and prompt from file
                OUTPUT=$(timeout 300 claude --model "$MODEL" --output-format text -p "$(cat "$CUSTOM_PROMPT_FILE_TEMP")" 2>&1 || echo "Error: Failed to execute claude")

                # Clean up temporary file
                rm -f "$CUSTOM_PROMPT_FILE_TEMP"

                echo "DEBUG: Raw custom prompt output:"
                echo "--- START CUSTOM OUTPUT ---"
                echo "$OUTPUT"
                echo "--- END CUSTOM OUTPUT ---"
                echo "DEBUG: Custom output length: ${#OUTPUT}"
            else
                OUTPUT="Error: claude not found. Please ensure it's installed or set install-agent: true"
            fi
            ;;
        gemini)
            if command -v gemini >/dev/null 2>&1; then
                echo "DEBUG: Executing custom prompt with gemini"
                echo "DEBUG: Custom prompt length: ${#FULL_CUSTOM_PROMPT}"
                echo "DEBUG: First 200 chars of custom prompt:"
                echo "${FULL_CUSTOM_PROMPT:0:200}"
                echo "DEBUG: --- END CUSTOM PROMPT PREVIEW ---"
                echo "DEBUG: Starting custom prompt execution..."

                # Create a temporary file for the custom prompt
                CUSTOM_PROMPT_FILE_TEMP=$(mktemp)
                echo "$FULL_CUSTOM_PROMPT" > "$CUSTOM_PROMPT_FILE_TEMP"
                echo "DEBUG: Created temporary custom prompt file: $CUSTOM_PROMPT_FILE_TEMP"

                # Execute gemini with model flag and output format
                OUTPUT=$(timeout 300 gemini -m "$MODEL" --output-format text -p "$(cat "$CUSTOM_PROMPT_FILE_TEMP")" 2>&1 || echo "Error: Failed to execute gemini")

                # Clean up temporary file
                rm -f "$CUSTOM_PROMPT_FILE_TEMP"

                echo "DEBUG: Raw custom prompt output:"
                echo "--- START CUSTOM OUTPUT ---"
                echo "$OUTPUT"
                echo "--- END CUSTOM OUTPUT ---"
                echo "DEBUG: Custom output length: ${#OUTPUT}"
            else
                OUTPUT="Error: gemini not found. Please ensure it's installed or set install-agent: true"
            fi
            ;;
        codex)
            if command -v codex >/dev/null 2>&1; then
                echo "DEBUG: Executing custom prompt with codex"
                echo "DEBUG: Custom prompt length: ${#FULL_CUSTOM_PROMPT}"
                echo "DEBUG: First 200 chars of custom prompt:"
                echo "${FULL_CUSTOM_PROMPT:0:200}"
                echo "DEBUG: --- END CUSTOM PROMPT PREVIEW ---"
                echo "DEBUG: Starting custom prompt execution..."

                # Create a temporary file for the custom prompt
                CUSTOM_PROMPT_FILE_TEMP=$(mktemp)
                echo "$FULL_CUSTOM_PROMPT" > "$CUSTOM_PROMPT_FILE_TEMP"
                echo "DEBUG: Created temporary custom prompt file: $CUSTOM_PROMPT_FILE_TEMP"

                # Execute codex with model flag (non-interactive)
                OUTPUT=$(timeout 300 codex -m "$MODEL" "$(cat "$CUSTOM_PROMPT_FILE_TEMP")" 2>&1 || echo "Error: Failed to execute codex")

                # Clean up temporary file
                rm -f "$CUSTOM_PROMPT_FILE_TEMP"

                echo "DEBUG: Raw custom prompt output:"
                echo "--- START CUSTOM OUTPUT ---"
                echo "$OUTPUT"
                echo "--- END CUSTOM OUTPUT ---"
                echo "DEBUG: Custom output length: ${#OUTPUT}"
            else
                OUTPUT="Error: codex not found. Please ensure it's installed or set install-agent: true"
            fi
            ;;
        amp)
            if command -v amp >/dev/null 2>&1; then
                echo "DEBUG: Executing custom prompt with amp"
                echo "DEBUG: Custom prompt length: ${#FULL_CUSTOM_PROMPT}"
                echo "DEBUG: First 200 chars of custom prompt:"
                echo "${FULL_CUSTOM_PROMPT:0:200}"
                echo "DEBUG: --- END CUSTOM PROMPT PREVIEW ---"
                echo "DEBUG: Starting custom prompt execution..."

                # Create a temporary file for the custom prompt
                CUSTOM_PROMPT_FILE_TEMP=$(mktemp)
                echo "$FULL_CUSTOM_PROMPT" > "$CUSTOM_PROMPT_FILE_TEMP"
                echo "DEBUG: Created temporary custom prompt file: $CUSTOM_PROMPT_FILE_TEMP"

                # Execute amp with -x flag for execute mode (non-interactive)
                OUTPUT=$(AMP_API_KEY="$AMP_API_KEY" timeout 300 amp -x "$(cat "$CUSTOM_PROMPT_FILE_TEMP")" 2>&1 || echo "Error: Failed to execute amp")

                # Clean up temporary file
                rm -f "$CUSTOM_PROMPT_FILE_TEMP"

                echo "DEBUG: Raw custom prompt output:"
                echo "--- START CUSTOM OUTPUT ---"
                echo "$OUTPUT"
                echo "--- END CUSTOM OUTPUT ---"
                echo "DEBUG: Custom output length: ${#OUTPUT}"
            else
                OUTPUT="Error: amp not found. Please ensure it's installed or set install-agent: true"
            fi
            ;;
        *)
            OUTPUT="Error: Unsupported agent: $AGENT"
            ;;
    esac
    
    # Add custom result to JSON array
    add_result "custom" "$OUTPUT"
    echo "Completed custom prompt"
fi

echo "Results saved to $RESULT_FILE"
echo "Results summary:"
jq -r '.[] | "\(.rule): \(.output | length) characters"' "$RESULT_FILE"
