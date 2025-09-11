#!/usr/bin/env bash
set -euo pipefail

echo "DEBUG: Script started at $(date)"
echo "DEBUG: Arguments received: $*"

RULES="${1:-}"
CUSTOM_PROMPT="${2:-}"
AGENT="${3:-cursor}"
RESULT_FILE="results.json"

echo "DEBUG: Parsed arguments - RULES: '$RULES', CUSTOM_PROMPT: '$CUSTOM_PROMPT', AGENT: '$AGENT'"

# Get the action directory (where this script is located)
ACTION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "DEBUG: Action directory: $ACTION_DIR"

# Ensure cursor-agent is in PATH
export PATH="$HOME/.cursor/bin:$PATH"
echo "DEBUG: Updated PATH: $PATH"

# Set default model if not provided
MODEL="${MODEL:-gpt-5}"

echo "Running rules with agent: $AGENT"
echo "Using model: $MODEL"

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
    
    # Combine base prompt with rule-specific prompt and comment formatting
    echo "DEBUG: About to combine prompts..."
    FULL_PROMPT="$(cat "$BASE_PROMPT_FILE")

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
                echo "DEBUG: PATH: $PATH"
                echo "DEBUG: Which cursor-agent: $(which cursor-agent)"
                echo "DEBUG: Starting cursor-agent execution..."
                
                # Try the correct cursor-agent syntax
                echo "DEBUG: Using correct cursor-agent syntax..."
                echo "DEBUG: Command: timeout 60 cursor-agent --print --output-format text --model \"$MODEL\" \"[PROMPT]\""
                echo "DEBUG: Environment check - CURSOR_API_KEY length: ${#CURSOR_API_KEY}"
                
                # Try with explicit API key
                OUTPUT=$(CURSOR_API_KEY="$CURSOR_API_KEY" timeout 60 cursor-agent --print --output-format text --model "$MODEL" "$FULL_PROMPT" 2>&1 || echo "Error: Failed to execute cursor-agent")
                
                # If that fails, try without model flag
                if [[ "$OUTPUT" == *"Error: Failed to execute cursor-agent"* ]]; then
                    echo "DEBUG: Model flag failed, trying without model..."
                    echo "DEBUG: Command: timeout 60 cursor-agent --print --output-format text \"[PROMPT]\""
                    OUTPUT=$(CURSOR_API_KEY="$CURSOR_API_KEY" timeout 60 cursor-agent --print --output-format text "$FULL_PROMPT" 2>&1 || echo "Error: Failed to execute cursor-agent")
                fi
                
                # If that fails, try with agent command
                if [[ "$OUTPUT" == *"Error: Failed to execute cursor-agent"* ]]; then
                    echo "DEBUG: Print flag failed, trying with agent command..."
                    echo "DEBUG: Command: timeout 60 cursor-agent agent --print --output-format text \"[PROMPT]\""
                    OUTPUT=$(CURSOR_API_KEY="$CURSOR_API_KEY" timeout 60 cursor-agent agent --print --output-format text "$FULL_PROMPT" 2>&1 || echo "Error: All cursor-agent methods failed")
                fi
                
                echo "DEBUG: Raw cursor-agent output:"
                echo "--- START RAW OUTPUT ---"
                echo "$OUTPUT"
                echo "--- END RAW OUTPUT ---"
                echo "DEBUG: Output length: ${#OUTPUT}"
            else
                OUTPUT="Error: cursor-agent not found. Please ensure it's installed or set install-agent: true"
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
    
    # Combine base prompt with custom prompt and comment formatting
    FULL_CUSTOM_PROMPT="$(cat "$BASE_PROMPT_FILE")

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
                
                # Try the correct cursor-agent syntax for custom prompt
                echo "DEBUG: Using correct cursor-agent syntax for custom prompt..."
                echo "DEBUG: Command: timeout 60 cursor-agent --print --output-format text --model \"$MODEL\" \"[CUSTOM_PROMPT]\""
                
                # Try with explicit API key
                OUTPUT=$(CURSOR_API_KEY="$CURSOR_API_KEY" timeout 60 cursor-agent --print --output-format text --model "$MODEL" "$FULL_CUSTOM_PROMPT" 2>&1 || echo "Error: Failed to execute cursor-agent")
                
                # If that fails, try without model flag
                if [[ "$OUTPUT" == *"Error: Failed to execute cursor-agent"* ]]; then
                    echo "DEBUG: Model flag failed for custom prompt, trying without model..."
                    OUTPUT=$(CURSOR_API_KEY="$CURSOR_API_KEY" timeout 60 cursor-agent --print --output-format text "$FULL_CUSTOM_PROMPT" 2>&1 || echo "Error: Failed to execute cursor-agent")
                fi
                
                # If that fails, try with agent command
                if [[ "$OUTPUT" == *"Error: Failed to execute cursor-agent"* ]]; then
                    echo "DEBUG: Print flag failed for custom prompt, trying with agent command..."
                    OUTPUT=$(CURSOR_API_KEY="$CURSOR_API_KEY" timeout 60 cursor-agent agent --print --output-format text "$FULL_CUSTOM_PROMPT" 2>&1 || echo "Error: All cursor-agent methods failed")
                fi
                
                echo "DEBUG: Raw custom prompt output:"
                echo "--- START CUSTOM OUTPUT ---"
                echo "$OUTPUT"
                echo "--- END CUSTOM OUTPUT ---"
                echo "DEBUG: Custom output length: ${#OUTPUT}"
            else
                OUTPUT="Error: cursor-agent not found. Please ensure it's installed or set install-agent: true"
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
