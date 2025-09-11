#!/usr/bin/env bash
set -euo pipefail

# AutoAgent Test Repository Setup Script
# This script helps you set up a test repository for testing AutoAgent

echo "🚀 Setting up AutoAgent test repository..."

# Check if gh CLI is installed
if ! command -v gh >/dev/null 2>&1; then
    echo "❌ GitHub CLI (gh) is not installed. Please install it first:"
    echo "   https://cli.github.com/"
    exit 1
fi

# Check if user is authenticated
if ! gh auth status >/dev/null 2>&1; then
    echo "❌ Not authenticated with GitHub CLI. Please run: gh auth login"
    exit 1
fi

# Get repository name from user
read -p "Enter test repository name (default: autoagent-test): " REPO_NAME
REPO_NAME=${REPO_NAME:-autoagent-test}

echo "📁 Creating repository: $REPO_NAME"

# Create repository
gh repo create "$REPO_NAME" --public --description "Test repository for AutoAgent GitHub Action"

# Clone the repository
git clone "https://github.com/$(gh api user --jq .login)/$REPO_NAME.git"
cd "$REPO_NAME"

echo "📝 Creating test files..."

# Create test files with various code quality scenarios
mkdir -p src tests

# Good code example
cat > src/good-code.js << 'EOF'
/**
 * Well-structured authentication module
 */
class AuthService {
    constructor(apiKey) {
        this.apiKey = apiKey;
        this.isAuthenticated = false;
    }

    async login(username, password) {
        try {
            // Validate input
            if (!username || !password) {
                throw new Error('Username and password are required');
            }

            // Hash password securely
            const hashedPassword = await this.hashPassword(password);
            
            // Make API call
            const response = await fetch('/api/login', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${this.apiKey}`
                },
                body: JSON.stringify({ username, password: hashedPassword })
            });

            if (response.ok) {
                this.isAuthenticated = true;
                return { success: true, token: response.data.token };
            } else {
                throw new Error('Login failed');
            }
        } catch (error) {
            console.error('Login error:', error.message);
            return { success: false, error: error.message };
        }
    }

    async hashPassword(password) {
        // Use proper password hashing
        const crypto = require('crypto');
        return crypto.pbkdf2Sync(password, 'salt', 100000, 64, 'sha512').toString('hex');
    }

    logout() {
        this.isAuthenticated = false;
    }
}

module.exports = AuthService;
EOF

# Vulnerable code example
cat > src/vulnerable-code.js << 'EOF'
// WARNING: This code has security vulnerabilities for testing purposes

function login(username, password) {
    // SQL injection vulnerability
    const query = `SELECT * FROM users WHERE username = '${username}' AND password = '${password}'`;
    
    // Hardcoded credentials
    const adminUser = 'admin';
    const adminPass = 'password123';
    
    // Insecure direct object reference
    if (username === adminUser && password === adminPass) {
        return { role: 'admin', access: 'full' };
    }
    
    // No input validation
    const result = database.query(query);
    return result;
}

// XSS vulnerability
function displayUser(userInput) {
    return `<div>Welcome ${userInput}</div>`;
}

// Insecure deserialization
function processData(data) {
    return eval(data); // Dangerous!
}

// Missing error handling
function getSecretData() {
    const secret = process.env.SECRET_KEY;
    return secret;
}
EOF

# Code with refactoring opportunities
cat > src/refactor-me.js << 'EOF'
// This code needs refactoring

function processUserData(userData) {
    // Long method with multiple responsibilities
    let result = {};
    
    // Validate user data
    if (userData.name && userData.email && userData.age) {
        if (userData.age > 0 && userData.age < 150) {
            if (userData.email.includes('@')) {
                // Process user data
                result.name = userData.name.toUpperCase();
                result.email = userData.email.toLowerCase();
                result.age = userData.age;
                
                // Calculate category
                if (userData.age < 18) {
                    result.category = 'minor';
                } else if (userData.age < 65) {
                    result.category = 'adult';
                } else {
                    result.category = 'senior';
                }
                
                // Generate ID
                result.id = Math.random().toString(36).substr(2, 9);
                
                // Log result
                console.log('User processed:', result);
                
                return result;
            } else {
                console.log('Invalid email');
                return null;
            }
        } else {
            console.log('Invalid age');
            return null;
        }
    } else {
        console.log('Missing required fields');
        return null;
    }
}

// Duplicate code
function processAdminData(adminData) {
    let result = {};
    
    if (adminData.name && adminData.email && adminData.age) {
        if (adminData.age > 0 && adminData.age < 150) {
            if (adminData.email.includes('@')) {
                result.name = adminData.name.toUpperCase();
                result.email = adminData.email.toLowerCase();
                result.age = adminData.age;
                result.category = 'admin';
                result.id = Math.random().toString(36).substr(2, 9);
                console.log('Admin processed:', result);
                return result;
            } else {
                console.log('Invalid email');
                return null;
            }
        } else {
            console.log('Invalid age');
            return null;
        }
    } else {
        console.log('Missing required fields');
        return null;
    }
}
EOF

# Create test files
cat > tests/test-example.js << 'EOF'
const assert = require('assert');

describe('Example Tests', () => {
    it('should pass basic test', () => {
        assert.strictEqual(1 + 1, 2);
    });
    
    it('should handle edge cases', () => {
        // TODO: Add more comprehensive tests
        assert.ok(true);
    });
});
EOF

# Create README
cat > README.md << 'EOF'
# AutoAgent Test Repository

This repository contains various code examples to test the AutoAgent GitHub Action.

## Files

- `src/good-code.js` - Well-structured, secure code
- `src/vulnerable-code.js` - Code with security vulnerabilities (for testing)
- `src/refactor-me.js` - Code that needs refactoring
- `tests/test-example.js` - Basic test files

## Testing AutoAgent

This repository is set up to test different aspects of AutoAgent:

1. **Security Analysis** - The vulnerable code should trigger OWASP security warnings
2. **Code Review** - The refactor-me.js should show code quality issues
3. **Refactoring Suggestions** - Should identify code smells and improvement opportunities

Create a pull request with changes to any of these files to see AutoAgent in action!
EOF

# Create GitHub Actions workflow
mkdir -p .github/workflows
cat > .github/workflows/autoagent-test.yml << 'EOF'
name: AutoAgent Test

on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  autoagent:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run AutoAgent
        uses: erans/autoagent-action@main
        with:
          rules: |
            - owasp-check
            - code-review
            - refactor-suggestions
          custom: |
            Please review this pull request for:
            1. Code quality and best practices
            2. Security vulnerabilities
            3. Performance optimizations
            4. Documentation completeness
          action: comment
          install-agent: true
          agent: cursor
EOF

# Create package.json for Node.js context
cat > package.json << 'EOF'
{
  "name": "autoagent-test",
  "version": "1.0.0",
  "description": "Test repository for AutoAgent",
  "main": "src/index.js",
  "scripts": {
    "test": "node tests/test-example.js"
  },
  "dependencies": {
    "crypto": "^1.0.1"
  }
}
EOF

# Initial commit
git add .
git commit -m "Initial commit with test files for AutoAgent"

# Push to main
git push origin main

echo "✅ Test repository created successfully!"
echo ""
echo "Next steps:"
echo "1. Create a test branch: git checkout -b test-changes"
echo "2. Make some changes to the files"
echo "3. Commit and push: git add . && git commit -m 'Test changes' && git push origin test-changes"
echo "4. Create a PR: gh pr create --title 'Test AutoAgent' --body 'Testing AutoAgent functionality'"
echo "5. Watch the AutoAgent action run and post comments!"
echo ""
echo "Repository URL: https://github.com/$(gh api user --jq .login)/$REPO_NAME"
