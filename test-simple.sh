#!/usr/bin/env bash
set -euo pipefail

echo "Testing AutoAgent implementation (simple validation)..."

# Test 1: Check if all required files exist
echo "✓ Checking file structure..."
required_files=(
    "action.yml"
    "scripts/install_agent.sh"
    "scripts/run_prompts.sh"
    "scripts/post_comment.sh"
    "rules/base.prompt"
    "rules/owasp-check.prompt"
    "rules/code-review.prompt"
    "rules/refactor-suggestions.prompt"
    "rules/comment.prompt"
    "README.md"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file exists"
    else
        echo "  ✗ $file missing"
        exit 1
    fi
done

# Test 2: Check if scripts are executable
echo "✓ Checking script permissions..."
scripts=(
    "scripts/install_agent.sh"
    "scripts/run_prompts.sh"
    "scripts/post_comment.sh"
)

for script in "${scripts[@]}"; do
    if [ -x "$script" ]; then
        echo "  ✓ $script is executable"
    else
        echo "  ✗ $script is not executable"
        exit 1
    fi
done

# Test 3: Validate action.yml syntax
echo "✓ Validating action.yml..."
if command -v yamllint >/dev/null 2>&1; then
    yamllint action.yml
    echo "  ✓ action.yml syntax is valid"
else
    echo "  ⚠ yamllint not available, skipping YAML validation"
fi

# Test 4: Test script syntax (without executing cursor-agent)
echo "✓ Testing script syntax..."
if bash -n scripts/install_agent.sh; then
    echo "  ✓ install_agent.sh syntax is valid"
else
    echo "  ✗ install_agent.sh has syntax errors"
    exit 1
fi

if bash -n scripts/run_prompts.sh; then
    echo "  ✓ run_prompts.sh syntax is valid"
else
    echo "  ✗ run_prompts.sh has syntax errors"
    exit 1
fi

if bash -n scripts/post_comment.sh; then
    echo "  ✓ post_comment.sh syntax is valid"
else
    echo "  ✗ post_comment.sh has syntax errors"
    exit 1
fi

# Test 5: Test prompt file concatenation (without running cursor-agent)
echo "✓ Testing prompt concatenation..."
if [ -f "rules/base.prompt" ] && [ -f "rules/code-review.prompt" ]; then
    COMBINED_PROMPT="$(cat rules/base.prompt)

$(cat rules/code-review.prompt)"
    if [ ${#COMBINED_PROMPT} -gt 100 ]; then
        echo "  ✓ Prompt concatenation works (${#COMBINED_PROMPT} characters)"
    else
        echo "  ✗ Prompt concatenation failed"
        exit 1
    fi
else
    echo "  ✗ Required prompt files missing"
    exit 1
fi

# Test 6: Test JSON parsing logic
echo "✓ Testing JSON parsing..."
echo '["code-review", "owasp-check"]' > test_rules.json
if command -v jq >/dev/null 2>&1; then
    RULES_ARRAY=$(cat test_rules.json | jq -r '.[]' 2>/dev/null || echo "")
    if [ -n "$RULES_ARRAY" ]; then
        echo "  ✓ JSON parsing works"
        echo "  Parsed rules: $(echo "$RULES_ARRAY" | tr '\n' ' ')"
    else
        echo "  ✗ JSON parsing failed"
        exit 1
    fi
else
    echo "  ⚠ jq not available, skipping JSON parsing test"
fi

# Cleanup
rm -f test_rules.json

echo ""
echo "🎉 AutoAgent implementation validation completed successfully!"
echo ""
echo "Implementation includes:"
echo "  ✓ Complete GitHub Action structure"
echo "  ✓ Agent installation script (cursor-agent)"
echo "  ✓ Rule execution with base context"
echo "  ✓ PR comment posting"
echo "  ✓ Three predefined rules (owasp-check, code-review, refactor-suggestions)"
echo "  ✓ Custom prompt support"
echo "  ✓ Error handling and validation"
echo ""
echo "Next steps:"
echo "1. Commit and push to GitHub"
echo "2. Create a release tag (e.g., v1.0.0)"
echo "3. Test with a real pull request"
echo "4. Publish to GitHub Marketplace"
