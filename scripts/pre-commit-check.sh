#!/bin/bash

# Check for sensitive files
sensitive_files=$(git diff --cached --name-only | grep -E '\.(pem|key|cert|env|secret)')
if [ ! -z "$sensitive_files" ]; then
    echo "Error: Attempting to commit sensitive files:"
    echo "$sensitive_files"
    exit 1
fi

# Check for API keys and secrets
api_keys=$(git diff --cached | grep -E '(api[_-]?key|secret|password|token)["\s]*[:=]\s*["\']?[a-zA-Z0-9]+["\']?')
if [ ! -z "$api_keys" ]; then
    echo "Error: Potential API keys or secrets detected:"
    echo "$api_keys"
    exit 1
fi

# Check for environment variables
env_vars=$(git diff --cached | grep -E 'process\.env\.[A-Z_]+')
if [ ! -z "$env_vars" ]; then
    echo "Error: Environment variables detected in code:"
    echo "$env_vars"
    exit 1
fi

# Check for AI model files
model_files=$(git diff --cached --name-only | grep -E '\.(weights|bin|pt|pth|onnx)')
if [ ! -z "$model_files" ]; then
    echo "Error: AI model files detected:"
    echo "$model_files"
    exit 1
fi

# Check for large files
large_files=$(git diff --cached --name-only | xargs -I{} ls -l {} 2>/dev/null | awk '{if($5>10485760)print $9}')
if [ ! -z "$large_files" ]; then
    echo "Error: Files larger than 10MB detected:"
    echo "$large_files"
    exit 1
fi

exit 0 