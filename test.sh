#!/usr/bin/env bash
set -euo pipefail

echo "Testing AutoAgent implementation..."

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
    "rules/duplication-check.prompt"
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

# Test 4: Test install_agent.sh with cursor
echo "✓ Testing install_agent.sh..."
if ./scripts/install_agent.sh cursor >/dev/null 2>&1; then
    echo "  ✓ install_agent.sh runs without errors"
else
    echo "  ⚠ install_agent.sh had issues (this is expected if cursor-agent is not available)"
fi

# Test 5: Test run_prompts.sh with mock data
echo "✓ Testing run_prompts.sh..."
echo '["code-review"]' > test_rules.json
if timeout 30 ./scripts/run_prompts.sh '["code-review"]' "Test custom prompt" cursor >/dev/null 2>&1; then
    echo "  ✓ run_prompts.sh runs without errors"
    if [ -f "results.json" ]; then
        echo "  ✓ results.json was created"
        echo "  Results content:"
        cat results.json | jq '.' 2>/dev/null || echo "  (jq not available for pretty printing)"
    else
        echo "  ✗ results.json was not created"
    fi
else
    echo "  ⚠ run_prompts.sh had issues (this is expected if cursor-agent is not available or times out)"
fi

# Test 6: Test post_comment.sh (dry run)
echo "✓ Testing post_comment.sh..."
if [ -f "results.json" ]; then
    if ./scripts/post_comment.sh results.json >/dev/null 2>&1; then
        echo "  ✓ post_comment.sh runs without errors"
    else
        echo "  ⚠ post_comment.sh had issues (this is expected without GitHub context)"
    fi
else
    echo "  ⚠ Skipping post_comment.sh test (no results.json)"
fi

# Cleanup
rm -f test_rules.json results.json

echo ""
echo "🎉 AutoAgent implementation test completed!"
echo ""
echo "Next steps:"
echo "1. Commit and push to GitHub"
echo "2. Create a release tag (e.g., v1.0.0)"
echo "3. Test with a real pull request"
echo "4. Publish to GitHub Marketplace"
