# Testing AutoAgent in Real GitHub Actions

This guide explains how to test the AutoAgent action in real GitHub Actions workflows on pull requests.

## Prerequisites

1. **Fork or Clone the Repository**: You need access to a GitHub repository where you can create pull requests
2. **GitHub CLI**: Install `gh` CLI for easier testing and management
3. **Cursor CLI**: The action will install this automatically, but you can pre-install for faster testing

## Testing Methods

### Method 1: Use the Example Workflow (Recommended)

The repository includes a ready-to-use example workflow at `.github/workflows/example.yml`.

#### Step 1: Set up the workflow
```bash
# Copy the example workflow to your test repository
cp .github/workflows/example.yml /path/to/your/test-repo/.github/workflows/
```

#### Step 2: Create a test branch and make changes
```bash
cd /path/to/your/test-repo
git checkout -b test-autoagent
# Make some code changes (add files, modify existing code, etc.)
git add .
git commit -m "Test changes for AutoAgent"
git push origin test-autoagent
```

#### Step 3: Create a pull request
```bash
gh pr create --title "Test AutoAgent" --body "Testing AutoAgent functionality"
```

#### Step 4: Watch the action run
- Go to the "Actions" tab in your GitHub repository
- Find the "AutoAgent Example" workflow run
- Check the logs to see the agent installation and execution
- Look for the PR comment with the results

### Method 2: Test Different Scenarios

Create multiple test workflows to test different configurations:

#### Test 1: All Rules + Custom Prompt
```yaml
name: AutoAgent - Full Test
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  autoagent:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run AutoAgent
        uses: erans/autoagent@v1
        with:
          rules: |
            - owasp-check
            - code-review
            - refactor-suggestions
          custom: |
            Please check for inefficient SQL queries and suggest optimizations.
          action: comment
          install-agent: true
          agent: cursor
```

#### Test 2: Custom Prompt Only
```yaml
name: AutoAgent - Custom Only
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  autoagent:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run AutoAgent
        uses: erans/autoagent@v1
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

#### Test 3: Single Rule
```yaml
name: AutoAgent - Security Only
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  autoagent:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run AutoAgent
        uses: erans/autoagent@v1
        with:
          rules: |
            - owasp-check
          action: comment
          install-agent: true
          agent: cursor
```

### Method 3: Local Testing with GitHub CLI

You can test the action locally using GitHub CLI to simulate PR events:

```bash
# Create a test repository
gh repo create test-autoagent --public
cd test-autoagent

# Add some test code
echo 'console.log("Hello World");' > test.js
git add .
git commit -m "Initial commit"
git push origin main

# Create a test branch with changes
git checkout -b test-changes
echo 'console.log("Hello World with potential security issue");' > test.js
git add .
git commit -m "Add potential security issue"
git push origin test-changes

# Create PR
gh pr create --title "Test AutoAgent" --body "Testing AutoAgent functionality"
```

## What to Look For

### 1. Action Execution
- **Agent Installation**: Should see "Installing cursor-agent..." in logs
- **Rule Execution**: Should see "Executing rule: [rule-name]" for each rule
- **Custom Prompt**: Should see "Executing custom prompt..." if provided
- **Results**: Should see "Results saved to results.json"

### 2. PR Comments
- **Structured Format**: Comments should follow the format:
  ```
  ### 🤖 AutoAgent Results

  **Rule:** `owasp-check`
  ```
  [Analysis results]

  **Rule:** `custom`
  ```
  [Custom analysis results]
  ```

- **Comment Quality**: Comments should be:
  - Concise (1-2 sentences per rule)
  - Actionable (clear next steps)
  - Include compare links where appropriate

### 3. Error Handling
Test error scenarios:
- Invalid rule names
- Missing custom prompt
- Agent installation failures
- Network issues

## Troubleshooting

### Common Issues

1. **"cursor-agent not found"**
   - Check if `install-agent: true` is set
   - Verify the agent installation step completed successfully

2. **"No rules or custom prompt provided"**
   - Ensure at least one of `rules` or `custom` is provided
   - Check that `rules` is a valid YAML/JSON array

3. **"GitHub CLI (gh) not found"**
   - This is expected in some runner environments
   - The action will show what comment would have been posted

4. **Empty results**
   - Check if the AI agent is responding properly
   - Verify the prompt files are being loaded correctly

### Debug Mode

Add debug output to see what's happening:

```yaml
- name: Debug - Show files
  run: |
    echo "Files in rules directory:"
    ls -la rules/
    echo "Combined prompt preview:"
    head -20 <(cat rules/base.prompt rules/code-review.prompt rules/comment.prompt)
```

## Performance Testing

### Test with Different Repository Sizes
- Small repository (< 10 files)
- Medium repository (10-100 files)
- Large repository (> 100 files)

### Test with Different Code Types
- JavaScript/TypeScript
- Python
- Java
- Go
- Mixed language repositories

## Continuous Testing

Set up automated testing by:

1. **Creating a test repository** with various code samples
2. **Setting up scheduled workflows** to test the action regularly
3. **Using matrix builds** to test different configurations
4. **Monitoring action performance** and success rates

## Example Test Repository Structure

```
test-repo/
├── .github/workflows/
│   └── autoagent-test.yml
├── src/
│   ├── secure-code.js      # Good security practices
│   ├── vulnerable-code.js  # Security issues for testing
│   ├── clean-code.js       # Well-structured code
│   └── messy-code.js       # Code smells for testing
├── tests/
│   └── test-files.js
└── README.md
```

This structure allows you to test different aspects of the AutoAgent analysis across various code quality scenarios.
