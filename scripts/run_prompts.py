#!/usr/bin/env python3
"""
AutoAgent Python Runner - Composable architecture for running AI agent prompts
Replaces run_prompts.sh with better maintainability and error handling
"""

import os
import sys
import json
import yaml
import subprocess
import tempfile
import logging
from pathlib import Path
from typing import List, Dict, Optional, Union
import argparse

# Configure logging based on environment variable
def setup_logging():
    """Setup logging level based on LOGGING_LEVEL environment variable"""
    logging_level = os.environ.get('LOGGING_LEVEL', 'info').lower()

    if logging_level == 'debug':
        level = logging.DEBUG
        format_str = 'DEBUG: %(message)s'
    else:
        level = logging.INFO
        format_str = '%(message)s'

    logging.basicConfig(
        level=level,
        format=format_str,
        force=True  # Override any existing configuration
    )

    return logging.getLogger(__name__)

logger = setup_logging()


class GitAnalyzer:
    """Handles git operations for detecting changed files"""

    @staticmethod
    def get_changed_files() -> List[str]:
        """Get changed files using multiple fallback strategies"""
        logger.info("Detecting changed files using multiple strategies")

        strategies = [
            GitAnalyzer._try_merge_base,
            GitAnalyzer._try_three_dot_syntax,
            GitAnalyzer._try_two_dot_syntax,
            GitAnalyzer._try_github_api,
            GitAnalyzer._try_merge_commit,
            GitAnalyzer._try_single_commit
        ]

        for strategy in strategies:
            try:
                files = strategy()
                if files:
                    logger.info(f"Successfully detected {len(files)} changed files")
                    return files
            except Exception as e:
                logger.debug(f"Strategy {strategy.__name__} failed: {e}")
                continue

        logger.warning("No changed files detected with any strategy")
        return []

    @staticmethod
    def _try_merge_base() -> List[str]:
        """Strategy 1: Use merge-base with explicit calculation"""
        logger.debug("Strategy 1: Using merge-base with explicit calculation")

        # Fetch references
        subprocess.run(['git', 'fetch', 'origin', 'main:main'],
                      capture_output=True, check=False)

        # Get merge base
        result = subprocess.run(
            ['git', 'merge-base', 'HEAD', 'main'],
            capture_output=True, text=True, check=False
        )

        if result.returncode == 0:
            merge_base = result.stdout.strip()
            logger.debug(f"Found merge-base: {merge_base}")

            # Get changed files
            result = subprocess.run(
                ['git', 'diff', '--name-only', merge_base, 'HEAD'],
                capture_output=True, text=True, check=True
            )

            files = [f.strip() for f in result.stdout.split('\n') if f.strip()]
            logger.debug(f"Merge-base diff result: {files}")
            return files

        raise Exception("Could not determine merge-base")

    @staticmethod
    def _try_three_dot_syntax() -> List[str]:
        """Strategy 2: Three-dot syntax for merge-base"""
        logger.debug("Strategy 2: Trying git diff --name-only origin/main...HEAD")

        result = subprocess.run(
            ['git', 'diff', '--name-only', 'origin/main...HEAD'],
            capture_output=True, text=True, check=True
        )

        files = [f.strip() for f in result.stdout.split('\n') if f.strip()]
        return files

    @staticmethod
    def _try_two_dot_syntax() -> List[str]:
        """Strategy 3: Two-dot syntax"""
        logger.debug("Strategy 3: Trying git diff --name-only origin/main..HEAD")

        result = subprocess.run(
            ['git', 'diff', '--name-only', 'origin/main..HEAD'],
            capture_output=True, text=True, check=True
        )

        files = [f.strip() for f in result.stdout.split('\n') if f.strip()]
        return files

    @staticmethod
    def _try_github_api() -> List[str]:
        """Strategy 4: GitHub API fallback"""
        logger.debug("Strategy 4: Using GitHub API to get changed files")

        pr_number = os.environ.get('GITHUB_EVENT_NUMBER')
        repo = os.environ.get('GITHUB_REPOSITORY')

        if not pr_number or not repo:
            raise Exception("Missing GitHub environment variables")

        result = subprocess.run([
            'gh', 'api', f'repos/{repo}/pulls/{pr_number}/files',
            '--jq', '.[].filename'
        ], capture_output=True, text=True, check=True)

        files = [f.strip() for f in result.stdout.split('\n') if f.strip()]
        return files

    @staticmethod
    def _try_merge_commit() -> List[str]:
        """Strategy 5: Merge commit detection"""
        logger.debug("Strategy 5: Checking if HEAD is a merge commit")

        # Check if HEAD is a merge commit
        result = subprocess.run(
            ['git', 'show', '--format=%P', '-s', 'HEAD'],
            capture_output=True, text=True, check=True
        )

        parents = result.stdout.strip().split()
        if len(parents) > 1:
            logger.debug("HEAD is a merge commit, getting files from merge")

            result = subprocess.run(
                ['git', 'diff-tree', '--no-commit-id', '--name-only', '-r', 'HEAD'],
                capture_output=True, text=True, check=True
            )

            files = [f.strip() for f in result.stdout.split('\n') if f.strip()]
            return files

        raise Exception("HEAD is not a merge commit")

    @staticmethod
    def _try_single_commit() -> List[str]:
        """Strategy 6: Single commit diff fallback"""
        logger.debug("Strategy 6: Final fallback - single commit diff")

        result = subprocess.run(
            ['git', 'diff', '--name-only', 'HEAD~1', 'HEAD'],
            capture_output=True, text=True, check=True
        )

        files = [f.strip() for f in result.stdout.split('\n') if f.strip()]
        return files

    @staticmethod
    def get_file_context(scope: str) -> str:
        """Generate file context string based on scope"""
        if scope == "all":
            return "Analyze the entire codebase in this repository."
        else:
            changed_files = GitAnalyzer.get_changed_files()
            if changed_files:
                files_str = " ".join(changed_files)
                return f"Focus ONLY on these files changed in this PR: {files_str}"
            else:
                return "No changed files detected. Analyze the current repository state."


class PromptBuilder:
    """Handles prompt construction and management"""

    def __init__(self, action_dir: str):
        self.action_dir = Path(action_dir)
        self.rules_dir = self.action_dir / "rules"

    def load_base_prompt(self) -> str:
        """Load and expand base prompt with environment variables"""
        base_file = self.rules_dir / "base.prompt"
        if not base_file.exists():
            raise FileNotFoundError(f"Base prompt file not found: {base_file}")

        content = base_file.read_text()
        # Expand environment variables
        return os.path.expandvars(content)

    def load_rule_prompt(self, rule_name: str) -> str:
        """Load rule-specific prompt"""
        rule_file = self.rules_dir / f"{rule_name}.prompt"
        if not rule_file.exists():
            available = [f.stem for f in self.rules_dir.glob("*.prompt")]
            raise FileNotFoundError(
                f"Rule file not found: {rule_file}\n"
                f"Available rules: {', '.join(available)}"
            )

        return rule_file.read_text()

    def load_comment_prompt(self) -> str:
        """Load comment formatting prompt"""
        comment_file = self.rules_dir / "comment.prompt"
        if not comment_file.exists():
            raise FileNotFoundError(f"Comment prompt file not found: {comment_file}")

        return comment_file.read_text()

    def build_full_prompt(self, base: str, file_context: str,
                         rule_content: str, comment: str) -> str:
        """Build complete prompt from components"""
        return f"""{base}

## Analysis Scope
{file_context}

You have access to git commands to see changes:
- git diff --name-only origin/main..HEAD (or HEAD~1 HEAD)
- git diff origin/main..HEAD -- <filename>
- git show --name-only HEAD

Use these commands as needed for your analysis.

{rule_content}

{comment}"""


class CustomFileProcessor:
    """Handles custom prompt file processing"""

    @staticmethod
    def resolve_path(file_path: str) -> Path:
        """Resolve custom file path (handle relative paths)"""
        path = Path(file_path)

        # Handle relative paths - resolve relative to workspace
        if not path.is_absolute():
            workspace = os.environ.get('GITHUB_WORKSPACE', os.getcwd())
            path = Path(workspace) / path

        return path.resolve()

    @staticmethod
    def validate_file(file_path: Path) -> bool:
        """Validate custom file exists and is readable"""
        if not file_path.exists():
            logger.error(f"Custom file not found: {file_path}")
            return False

        if not file_path.is_file():
            logger.error(f"Custom file is not a file: {file_path}")
            return False

        if not os.access(file_path, os.R_OK):
            logger.error(f"Custom file not readable: {file_path}")
            return False

        # Check file size (prevent files > 1MB)
        if file_path.stat().st_size > 1048576:
            logger.error(f"Custom file too large (>1MB): {file_path}")
            return False

        return True

    @staticmethod
    def process_file(file_path: str) -> tuple[str, str]:
        """Process custom file and return content and rule name"""
        resolved_path = CustomFileProcessor.resolve_path(file_path)

        if not CustomFileProcessor.validate_file(resolved_path):
            raise ValueError(f"Custom file validation failed for {file_path}")

        content = resolved_path.read_text()
        rule_name = resolved_path.stem  # filename without .prompt extension

        return content, rule_name


class AgentRunner:
    """Handles execution of different AI agents"""

    AGENT_CONFIG = {
        'cursor': {
            'cmd': 'cursor-agent',
            'env_key': 'CURSOR_API_KEY',
            'default_model': 'gpt-5',
            'args': ['-p', '--output-format', 'text', '--force']
        },
        'claude': {
            'cmd': 'claude',
            'env_key': 'ANTHROPIC_API_KEY',
            'default_model': 'claude-sonnet-4-20250514',
            'args': ['--output-format', 'text']
        },
        'gemini': {
            'cmd': 'gemini',
            'env_key': 'GOOGLE_API_KEY',
            'default_model': 'pro',
            'args': ['--output-format', 'text']
        },
        'codex': {
            'cmd': 'codex',
            'env_key': 'OPENAI_API_KEY',
            'default_model': 'gpt-5',
            'args': []
        },
        'amp': {
            'cmd': 'amp',
            'env_key': 'AMP_API_KEY',
            'default_model': 'sonnet-4',
            'args': ['-x']
        },
        'opencode': {
            'cmd': 'opencode',
            'env_key': 'OPENCODE_API_KEY',
            'default_model': 'anthropic/claude-sonnet-4-20250514',
            'args': ['run', '--quiet'],
            'provider_env_mapping': {
                'anthropic': 'ANTHROPIC_API_KEY',
                'openai': 'OPENAI_API_KEY',
                'google': 'GOOGLE_API_KEY',
                'groq': 'GROQ_API_KEY',
                'cohere': 'COHERE_API_KEY',
                'mistral': 'MISTRAL_API_KEY'
            }
        }
    }

    @staticmethod
    def setup_agent_environment(agent: str) -> str:
        """Setup environment and get model for agent"""
        if agent not in AgentRunner.AGENT_CONFIG:
            raise ValueError(f"Unsupported agent: {agent}")

        config = AgentRunner.AGENT_CONFIG[agent]

        # Set up PATH for cursor
        if agent == 'cursor':
            cursor_path = os.path.expanduser("~/.cursor/bin")
            current_path = os.environ.get('PATH', '')
            os.environ['PATH'] = f"{cursor_path}:{current_path}"

        # Get model from environment or use default
        model = os.environ.get('MODEL', config['default_model'])
        logger.info(f"Using agent: {agent}, model: {model}")

        return model

    @staticmethod
    def setup_opencode_environment(model: str) -> dict:
        """Setup environment variables for OpenCode based on the model provider"""
        env = os.environ.copy()
        config = AgentRunner.AGENT_CONFIG['opencode']

        # Extract provider from model (format: provider/model)
        if '/' in model:
            provider = model.split('/')[0]
        else:
            # Default to anthropic if no provider specified
            provider = 'anthropic'
            model = f"anthropic/{model}"

        # Set up environment variable for the specific provider
        provider_env_mapping = config.get('provider_env_mapping', {})
        if provider in provider_env_mapping:
            env_var = provider_env_mapping[provider]
            if env_var in os.environ:
                logger.info(f"Using {env_var} for OpenCode {provider} provider")
            else:
                logger.warning(f"Environment variable {env_var} not found for {provider} provider")
        else:
            logger.warning(f"Unknown provider '{provider}' for OpenCode. Supported: {list(provider_env_mapping.keys())}")

        return env

    @staticmethod
    def execute_agent(agent: str, prompt: str, model: str) -> str:
        """Execute agent with given prompt"""
        if agent not in AgentRunner.AGENT_CONFIG:
            return f"Error: Unsupported agent: {agent}"

        config = AgentRunner.AGENT_CONFIG[agent]
        cmd = config['cmd']

        # Check if agent command exists
        try:
            subprocess.run(['which', cmd], capture_output=True, check=True)
        except subprocess.CalledProcessError:
            return f"Error: {cmd} not found. Please ensure it's installed or set install-agent: true"

        logger.info(f"Executing {agent} with prompt length: {len(prompt)}")
        logger.debug(f"First 200 chars of prompt: {prompt[:200]}")

        # Create temporary file for prompt
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.txt') as temp_file:
            temp_file.write(prompt)
            temp_file_path = temp_file.name

        try:
            # Build command
            cmd_args = [cmd] + config['args']

            # Add model parameter based on agent
            if agent == 'cursor':
                cmd_args.extend(['--model', model])
            elif agent == 'claude':
                cmd_args.extend(['--model', model, '-p', prompt])
                # For claude, don't use temp file, pass prompt directly
                temp_file_path = None
            elif agent == 'gemini':
                cmd_args.extend(['-m', model, '-p', prompt])
                temp_file_path = None
            elif agent == 'codex':
                cmd_args.extend(['-m', model, prompt])
                temp_file_path = None
            elif agent == 'amp':
                cmd_args.append(prompt)
                temp_file_path = None
            elif agent == 'opencode':
                cmd_args.extend(['--model', model, prompt])
                temp_file_path = None

            # Set up environment
            if agent == 'opencode':
                env = AgentRunner.setup_opencode_environment(model)
            else:
                env = os.environ.copy()
                if config['env_key'] in env:
                    if agent == 'cursor':
                        env['CURSOR_API_KEY'] = env[config['env_key']]
                    elif agent == 'amp':
                        env['AMP_API_KEY'] = env[config['env_key']]

            # Execute command
            if temp_file_path and agent == 'cursor':
                # For cursor, use stdin
                with open(temp_file_path, 'r') as f:
                    result = subprocess.run(
                        cmd_args,
                        stdin=f,
                        capture_output=True,
                        text=True,
                        timeout=600,
                        env=env
                    )
            else:
                # For other agents, command already includes prompt
                result = subprocess.run(
                    cmd_args,
                    capture_output=True,
                    text=True,
                    timeout=600,
                    env=env
                )

            if result.returncode == 0:
                output = result.stdout.strip()
                logger.info(f"Agent execution completed, output length: {len(output)}")
                return output
            else:
                error_msg = f"Agent execution failed with return code {result.returncode}"
                if result.stderr:
                    error_msg += f": {result.stderr}"
                logger.error(error_msg)
                return f"Error: {error_msg}"

        except subprocess.TimeoutExpired:
            return "Error: Agent execution timed out after 600 seconds"
        except Exception as e:
            return f"Error: Failed to execute {agent}: {str(e)}"

        finally:
            # Clean up temporary file
            if temp_file_path and os.path.exists(temp_file_path):
                os.unlink(temp_file_path)


class ResultManager:
    """Manages result collection and output"""

    def __init__(self):
        self.results = []

    def add_result(self, rule_name: str, output: str):
        """Add a result to the collection"""
        logger.info(f"Adding result for rule: {rule_name}")
        logger.debug(f"Output length: {len(output)} characters")
        logger.debug(f"First 100 chars: {output[:100]}")

        # Check for empty or very short output
        if not output or len(output) < 10:
            logger.warning(f"Rule '{rule_name}' returned empty or very short output")
            if not output:
                output = "⚠️ Warning: No analysis results were returned for this rule. This may indicate a processing error or timeout."

        self.results.append({
            "rule": rule_name,
            "output": output
        })

    def save_results(self, filename: str = "results.json"):
        """Save results to JSON file"""
        with open(filename, 'w') as f:
            json.dump(self.results, f, indent=2)

        logger.info(f"Results saved to {filename}")
        logger.info("Results summary:")
        for result in self.results:
            logger.info(f"  {result['rule']}: {len(result['output'])} characters")


def parse_input_list(input_str: str) -> List[str]:
    """Parse YAML or JSON list input, fallback to space-separated"""
    if not input_str or input_str == "[]":
        return []

    # Try YAML first
    try:
        import yaml
        parsed = yaml.safe_load(input_str)
        if isinstance(parsed, list):
            return [str(item) for item in parsed]
    except:
        pass

    # Try JSON
    try:
        parsed = json.loads(input_str)
        if isinstance(parsed, list):
            return [str(item) for item in parsed]
    except:
        pass

    # Fallback to space-separated
    return input_str.split()


def main():
    parser = argparse.ArgumentParser(description='AutoAgent Python Runner')
    parser.add_argument('rules', nargs='?', default='[]',
                       help='YAML or JSON list of rules to execute')
    parser.add_argument('custom_prompt', nargs='?', default='',
                       help='Custom prompt to execute')
    parser.add_argument('agent', nargs='?', default='cursor',
                       help='Agent to use (cursor, claude, gemini, codex, amp, opencode)')
    parser.add_argument('scope', nargs='?', default='changed',
                       help='Analysis scope (changed, all)')
    parser.add_argument('custom_files', nargs='?', default='[]',
                       help='YAML or JSON list of custom files to execute')

    args = parser.parse_args()

    logger.info("AutoAgent Python Runner started")
    logger.info(f"Arguments - rules: '{args.rules}', custom_prompt: '{args.custom_prompt}', "
               f"agent: '{args.agent}', scope: '{args.scope}', custom_files: '{args.custom_files}'")

    # Get action directory
    action_dir = os.environ.get('GITHUB_ACTION_PATH',
                               os.path.dirname(os.path.dirname(__file__)))
    logger.info(f"Action directory: {action_dir}")

    # Validate inputs
    if not args.rules and not args.custom_prompt and not args.custom_files:
        logger.error("No rules, custom prompt, or custom files provided")
        sys.exit(1)

    # Check custom prompt length
    if len(args.custom_prompt) > 5000:
        logger.error(f"Custom prompt exceeds 5000 character limit (current: {len(args.custom_prompt)})")
        sys.exit(1)

    # Initialize components
    git_analyzer = GitAnalyzer()
    prompt_builder = PromptBuilder(action_dir)
    result_manager = ResultManager()

    # Setup agent environment
    model = AgentRunner.setup_agent_environment(args.agent)

    # Get file context
    file_context = git_analyzer.get_file_context(args.scope)
    logger.info(f"File context: {file_context}")

    # Load base and comment prompts
    try:
        base_prompt = prompt_builder.load_base_prompt()
        comment_prompt = prompt_builder.load_comment_prompt()
    except FileNotFoundError as e:
        logger.error(str(e))
        sys.exit(1)

    # Process rules
    rules_list = parse_input_list(args.rules)
    logger.info(f"Processing {len(rules_list)} rules: {rules_list}")

    for rule in rules_list:
        if not rule:
            continue

        logger.info(f"Executing rule: {rule}")

        try:
            # Load rule prompt
            rule_prompt = prompt_builder.load_rule_prompt(rule)

            # Build full prompt
            full_prompt = prompt_builder.build_full_prompt(
                base_prompt, file_context, rule_prompt, comment_prompt
            )

            # Execute agent
            output = AgentRunner.execute_agent(args.agent, full_prompt, model)

            # Add result
            result_manager.add_result(rule, output)
            logger.info(f"Completed rule: {rule}")

        except FileNotFoundError as e:
            logger.error(str(e))
            sys.exit(1)
        except Exception as e:
            logger.error(f"Error processing rule {rule}: {e}")
            result_manager.add_result(rule, f"Error: {str(e)}")

    # Process custom files
    custom_files_list = parse_input_list(args.custom_files)
    logger.info(f"Processing {len(custom_files_list)} custom files: {custom_files_list}")

    for custom_file in custom_files_list:
        if not custom_file:
            continue

        logger.info(f"Processing custom file: {custom_file}")

        try:
            # Process custom file
            custom_content, rule_name = CustomFileProcessor.process_file(custom_file)

            # Build full prompt
            full_prompt = prompt_builder.build_full_prompt(
                base_prompt, file_context, custom_content, comment_prompt
            )

            # Execute agent
            output = AgentRunner.execute_agent(args.agent, full_prompt, model)

            # Add result
            result_manager.add_result(rule_name, output)
            logger.info(f"Completed custom file: {custom_file}")

        except Exception as e:
            logger.error(f"Error processing custom file {custom_file}: {e}")
            result_manager.add_result(Path(custom_file).stem, f"Error: {str(e)}")

    # Process custom prompt
    if args.custom_prompt:
        logger.info("Executing custom prompt")

        try:
            # Build full prompt
            full_prompt = prompt_builder.build_full_prompt(
                base_prompt, file_context, args.custom_prompt, comment_prompt
            )

            # Execute agent
            output = AgentRunner.execute_agent(args.agent, full_prompt, model)

            # Add result
            result_manager.add_result("custom", output)
            logger.info("Completed custom prompt")

        except Exception as e:
            logger.error(f"Error processing custom prompt: {e}")
            result_manager.add_result("custom", f"Error: {str(e)}")

    # Save results
    result_manager.save_results()

    logger.info("AutoAgent Python Runner completed")


if __name__ == "__main__":
    main()