#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "🔧 Setting up git-secrets..."

# Check if git-secrets is installed
if ! command -v git-secrets &> /dev/null; then
    echo -e "${RED}❌ git-secrets is not installed${NC}"
    echo "Installing git-secrets..."
    
    # For macOS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install git-secrets
    # For Ubuntu/Debian
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt-get install git-secrets
    else
        echo -e "${RED}❌ Unsupported OS. Please install git-secrets manually.${NC}"
        exit 1
    fi
fi

# Initialize git-secrets
git secrets --install

# Add common patterns
git secrets --add 'api[_-]?key["\s]*[=:]\s*["\w]+'
git secrets --add 'private[_-]?key["\s]*[=:]\s*["\w]+'
git secrets --add 'secret["\s]*[=:]\s*["\w]+'
git secrets --add 'password["\s]*[=:]\s*["\w]+'
git secrets --add 'token["\s]*[=:]\s*["\w]+'
git secrets --add 'auth["\s]*[=:]\s*["\w]+'
git secrets --add 'credential["\s]*[=:]\s*["\w]+'

# Add blockchain-specific patterns
git secrets --add '0x[a-fA-F0-9]{64}' # Private keys
git secrets --add 'mnemonic["\s]*[=:]\s*["\w\s]+' # Mnemonics
git secrets --add 'seed["\s]*[=:]\s*["\w]+' # Seeds

# Add environment file patterns
git secrets --add '\.env'
git secrets --add '\.env\.[a-zA-Z]+'

# Add certificate patterns
git secrets --add '\.pem'
git secrets --add '\.key'
git secrets --add '\.cert'
git secrets --add '\.crt'
git secrets --add '\.p12'
git secrets --add '\.pfx'
git secrets --add '\.keystore'
git secrets --add '\.jks'

# Add AWS patterns (if needed)
git secrets --add 'AKIA[0-9A-Z]{16}'
git secrets --add 'aws[_-]?access[_-]?key[_-]?id'
git secrets --add 'aws[_-]?secret[_-]?access[_-]?key'

# Add Google Cloud patterns (if needed)
git secrets --add 'AIza[0-9A-Za-z-_]{35}'
git secrets --add 'google[_-]?api[_-]?key'

# Add GitHub patterns (if needed)
git secrets --add 'gh[_-]?token'
git secrets --add 'github[_-]?token'
git secrets --add 'github[_-]?secret'

echo -e "${GREEN}✅ git-secrets setup complete${NC}"
echo "The following patterns are now being checked:"
git secrets --list 