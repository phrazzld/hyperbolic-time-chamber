#!/bin/bash

# Git Hooks Setup Script
# Installs quality gate git hooks for all developers

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔗 Setting up Git Hooks for WorkoutTracker...${NC}"
echo

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_SOURCE_DIR="$SCRIPT_DIR/git-hooks"
HOOKS_TARGET_DIR="$PROJECT_ROOT/.git/hooks"

# Check if we're in a git repository
if [ ! -d "$PROJECT_ROOT/.git" ]; then
    echo -e "${RED}❌ Error: Not in a git repository${NC}"
    echo "   Please run this script from the project root directory"
    exit 1
fi

# Check if SwiftLint is installed
if ! command -v swiftlint &> /dev/null; then
    echo -e "${YELLOW}⚠️  SwiftLint not found. Installing via Homebrew...${NC}"
    if command -v brew &> /dev/null; then
        brew install swiftlint
        echo -e "${GREEN}✅ SwiftLint installed successfully${NC}"
    else
        echo -e "${RED}❌ Homebrew not found. Please install SwiftLint manually:${NC}"
        echo "   brew install swiftlint"
        echo "   Or visit: https://github.com/realm/SwiftLint#installation"
        exit 1
    fi
fi

# Install git hooks
echo -e "${BLUE}📦 Installing git hooks...${NC}"

for hook_file in "$HOOKS_SOURCE_DIR"/*; do
    if [ -f "$hook_file" ]; then
        hook_name=$(basename "$hook_file")
        target_file="$HOOKS_TARGET_DIR/$hook_name"
        
        echo "  Installing $hook_name..."
        cp "$hook_file" "$target_file"
        chmod +x "$target_file"
        
        echo -e "    ${GREEN}✅ $hook_name installed and made executable${NC}"
    fi
done

echo
echo -e "${GREEN}🎉 Git hooks setup complete!${NC}"
echo
echo -e "${BLUE}📋 Installed hooks:${NC}"
for hook_file in "$HOOKS_TARGET_DIR"/*; do
    if [ -f "$hook_file" ] && [ -x "$hook_file" ]; then
        hook_name=$(basename "$hook_file")
        echo "  - $hook_name (runs on git $hook_name)"
    fi
done

echo
echo -e "${BLUE}🔍 What these hooks do:${NC}"
echo "  - pre-commit: Validates Package.swift syntax, runs SwiftLint and compilation checks"
echo "  - pre-push: Runs all unit tests before pushing to remote repositories"
echo "  - Prevents broken Package.swift, code style violations and compilation errors"
echo "  - Blocks pushes that would break existing functionality"
echo "  - Helps maintain consistent code quality and dependency management"
echo
echo -e "${YELLOW}💡 Tips:${NC}"
echo "  - Hooks run automatically on git commit and git push"
echo "  - Fix any violations and re-commit/re-push"
echo "  - Run 'swiftlint --fix' to auto-correct style issues"
echo "  - Run 'swift test' to run unit tests locally"
echo "  - Use './run.sh' to test builds locally"
echo
echo -e "${GREEN}Happy coding! 🚀${NC}"