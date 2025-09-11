# AutoAgent Testing Checklist

Use this checklist to systematically test all AutoAgent functionality.

## Pre-Test Setup

- [ ] GitHub CLI (`gh`) installed and authenticated
- [ ] Test repository created (use `./setup-test-repo.sh`)
- [ ] AutoAgent action published to GitHub Marketplace or available locally

## Basic Functionality Tests

### 1. Agent Installation
- [ ] Action installs cursor-agent successfully
- [ ] Agent version is displayed in logs
- [ ] No installation errors

### 2. Rule Execution
- [ ] All predefined rules execute without errors
- [ ] Results are captured in JSON format
- [ ] Each rule produces meaningful output

### 3. Custom Prompt Execution
- [ ] Custom prompts execute successfully
- [ ] Custom prompts work without predefined rules
- [ ] Custom prompts work with predefined rules

### 4. PR Comment Posting
- [ ] Comments are posted to the correct PR
- [ ] Comments have proper formatting
- [ ] Comments include all rule results
- [ ] Comments are concise and actionable

## Configuration Tests

### 1. Rules Input
- [ ] Empty rules array `[]` works with custom prompt
- [ ] Single rule works: `["owasp-check"]`
- [ ] Multiple rules work: `["owasp-check", "code-review"]`
- [ ] Invalid rule names fail gracefully
- [ ] YAML format works: `- owasp-check`
- [ ] JSON format works: `["owasp-check"]`

### 2. Custom Prompt
- [ ] Empty custom prompt works with rules
- [ ] Long custom prompt (under 5000 chars) works
- [ ] Custom prompt over 5000 chars fails gracefully
- [ ] Custom prompt with special characters works

### 3. Agent Selection
- [ ] Default agent (cursor) works
- [ ] Agent installation can be disabled
- [ ] Unsupported agents fail gracefully

## Error Handling Tests

### 1. Missing Dependencies
- [ ] Missing GitHub CLI shows helpful error
- [ ] Missing jq shows fallback behavior
- [ ] Missing yq shows fallback behavior

### 2. Invalid Inputs
- [ ] No rules and no custom prompt fails
- [ ] Invalid JSON/YAML fails gracefully
- [ ] Missing prompt files fail gracefully

### 3. Network Issues
- [ ] Agent installation failure is handled
- [ ] GitHub API failures are handled
- [ ] Timeout scenarios are handled

## Output Quality Tests

### 1. Comment Formatting
- [ ] Comments use proper markdown formatting
- [ ] Code blocks are properly escaped
- [ ] Special characters are handled correctly
- [ ] Comments are under GitHub's length limits

### 2. Content Quality
- [ ] Security analysis finds real vulnerabilities
- [ ] Code review identifies quality issues
- [ ] Refactoring suggestions are actionable
- [ ] Custom prompts produce relevant results

### 3. Comment Structure
- [ ] Each rule has its own section
- [ ] Custom prompt results are clearly labeled
- [ ] Footer includes AutoAgent attribution
- [ ] Compare links are included where appropriate

## Performance Tests

### 1. Execution Time
- [ ] Small repositories (< 10 files) complete quickly
- [ ] Medium repositories (10-100 files) complete reasonably
- [ ] Large repositories (> 100 files) don't timeout

### 2. Resource Usage
- [ ] Memory usage is reasonable
- [ ] Disk usage is minimal
- [ ] Network usage is efficient

## Integration Tests

### 1. GitHub Actions Integration
- [ ] Action runs on PR opened
- [ ] Action runs on PR synchronized
- [ ] Action runs on PR reopened
- [ ] Action doesn't run on other events

### 2. Repository Context
- [ ] Action has access to repository files
- [ ] Action can read PR context
- [ ] Action can post comments
- [ ] Action respects repository permissions

## Edge Cases

### 1. Empty PRs
- [ ] PR with no changes handles gracefully
- [ ] PR with only documentation changes works
- [ ] PR with only whitespace changes works

### 2. Large Changes
- [ ] PR with many files works
- [ ] PR with large files works
- [ ] PR with binary files works

### 3. Special Characters
- [ ] Filenames with special characters work
- [ ] Code with special characters works
- [ ] Comments with special characters work

## Regression Tests

### 1. Previous Issues
- [ ] Known bugs don't reoccur
- [ ] Performance regressions don't occur
- [ ] Output quality doesn't degrade

### 2. Version Compatibility
- [ ] Works with different GitHub Actions versions
- [ ] Works with different runner environments
- [ ] Works with different agent versions

## Documentation Tests

### 1. README Examples
- [ ] All examples in README work
- [ ] Configuration options are correct
- [ ] Usage instructions are accurate

### 2. Error Messages
- [ ] Error messages are helpful
- [ ] Error messages include next steps
- [ ] Error messages are user-friendly

## Final Validation

- [ ] All tests pass consistently
- [ ] No false positives or negatives
- [ ] Performance meets expectations
- [ ] User experience is smooth
- [ ] Documentation is complete and accurate

## Test Results Template

```
Test Date: ___________
Tester: ___________
Repository: ___________
PR Number: ___________

Results:
- Agent Installation: ✅/❌
- Rule Execution: ✅/❌
- Custom Prompts: ✅/❌
- PR Comments: ✅/❌
- Error Handling: ✅/❌
- Performance: ✅/❌

Issues Found:
1. [Description]
2. [Description]

Recommendations:
1. [Description]
2. [Description]
```
