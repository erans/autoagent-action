#!/usr/bin/env bash
set -euo pipefail

RULES="${1:-}"
CUSTOM_PROMPT="${2:-}"
AGENT="${3:-cursor}"
RESULT_FILE="results.json"

echo "Running rules with agent: $AGENT"

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
    jq --arg rule "$rule" --arg output "$output" '. + [{"rule": $rule, "output": $output}]' "$RESULT_FILE" > "$temp_file"
    mv "$temp_file" "$RESULT_FILE"
}

# Parse rules input (support both YAML and JSON)
RULES_ARRAY=""

if [ -n "$RULES" ]; then
    # Try to parse as YAML first, then JSON
    if command -v yq >/dev/null 2>&1; then
        # Parse as YAML using yq
        RULES_ARRAY=$(echo "$RULES" | yq -r '.[]' 2>/dev/null || echo "")
    elif command -v jq >/dev/null 2>&1; then
        # Parse as JSON using jq
        RULES_ARRAY=$(echo "$RULES" | jq -r '.[]' 2>/dev/null || echo "")
    else
        # Fallback: treat as space-separated list
        RULES_ARRAY="$RULES"
    fi

    if [ -z "$RULES_ARRAY" ] && [ "$RULES" != "[]" ]; then
        echo "Error: Could not parse rules input. Please provide valid YAML or JSON array."
        echo "Example: '[\"owasp-check\", \"code-review\"]'"
        exit 1
    fi
fi

# Execute each rule (if any)
if [ -n "$RULES_ARRAY" ]; then
    echo "$RULES_ARRAY" | while read -r RULE; do
        if [ -z "$RULE" ]; then
            continue
        fi
    
    PROMPT_FILE="rules/${RULE}.prompt"
    if [ ! -f "$PROMPT_FILE" ]; then
        echo "Error: Rule file not found: $PROMPT_FILE"
        echo "Available rules: $(ls rules/*.prompt 2>/dev/null | sed 's/rules\///g' | sed 's/\.prompt//g' | tr '\n' ' ' || echo 'none')"
        exit 1
    fi

    echo "Executing rule: $RULE"
    
    # Load base prompt with GitHub Actions context
    BASE_PROMPT_FILE="rules/base.prompt"
    if [ ! -f "$BASE_PROMPT_FILE" ]; then
        echo "Error: Base prompt file not found: $BASE_PROMPT_FILE"
        exit 1
    fi
    
    # Load comment prompt for output formatting
    COMMENT_PROMPT_FILE="rules/comment.prompt"
    if [ ! -f "$COMMENT_PROMPT_FILE" ]; then
        echo "Error: Comment prompt file not found: $COMMENT_PROMPT_FILE"
        exit 1
    fi
    
    # Combine base prompt with rule-specific prompt and comment formatting
    FULL_PROMPT="$(cat "$BASE_PROMPT_FILE")

$(cat "$PROMPT_FILE")

$(cat "$COMMENT_PROMPT_FILE")"
    
    # Execute the rule using the selected agent
    case "$AGENT" in
        cursor)
            if command -v cursor-agent >/dev/null 2>&1; then
                OUTPUT=$(echo "$FULL_PROMPT" | cursor-agent --print --output-format text 2>&1 || echo "Error: Failed to execute cursor-agent")
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
    BASE_PROMPT_FILE="rules/base.prompt"
    if [ ! -f "$BASE_PROMPT_FILE" ]; then
        echo "Error: Base prompt file not found: $BASE_PROMPT_FILE"
        exit 1
    fi
    
    # Load comment prompt for output formatting
    COMMENT_PROMPT_FILE="rules/comment.prompt"
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
                OUTPUT=$(echo "$FULL_CUSTOM_PROMPT" | cursor-agent --print --output-format text 2>&1 || echo "Error: Failed to execute cursor-agent")
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
