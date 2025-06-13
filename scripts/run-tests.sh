#!/bin/bash

# Intelligent Test Execution Script
# Respects TestConfiguration parallelization settings based on environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default options
COVERAGE_ENABLED=false
TIMEOUT_ENABLED=false
TIMEOUT_SECONDS=180
VERBOSE=false
FILTER=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --coverage)
            COVERAGE_ENABLED=true
            shift
            ;;
        --timeout)
            TIMEOUT_ENABLED=true
            if [[ $2 =~ ^[0-9]+$ ]]; then
                TIMEOUT_SECONDS=$2
                shift
            fi
            shift
            ;;
        --filter)
            FILTER="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --coverage           Enable code coverage reporting"
            echo "  --timeout [SECONDS]  Enable test timeout (default: 180s)"
            echo "  --filter PATTERN     Run only tests matching pattern"
            echo "  --verbose            Enable verbose output"
            echo "  --help               Show this help message"
            echo ""
            echo "Environment-aware test execution:"
            echo "  - CI: Sequential execution, reduced datasets, CI_BUILD flag"
            echo "  - Local: Parallel execution, full datasets"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Environment detection
if [ -n "$GITHUB_ACTIONS" ] || [ -n "$CI_BUILD" ]; then
    IS_CI=true
    ENV_NAME="CI"
else
    IS_CI=false
    ENV_NAME="Local"
fi

echo -e "${BLUE}🧪 Running tests in $ENV_NAME environment...${NC}"

# Build Swift test command based on environment and TestConfiguration
SWIFT_CMD="swift test"

# Add coverage flag if requested
if [ "$COVERAGE_ENABLED" = true ]; then
    SWIFT_CMD="$SWIFT_CMD --enable-code-coverage"
    echo "📊 Code coverage enabled"
fi

# Add filter if specified
if [ -n "$FILTER" ]; then
    SWIFT_CMD="$SWIFT_CMD --filter \"$FILTER\""
    echo "🔍 Filter: $FILTER"
fi

# Environment-specific configuration based on TestConfiguration
if [ "$IS_CI" = true ]; then
    # CI Configuration: Sequential execution, CI_BUILD flag
    echo "⚙️  CI Configuration:"
    echo "   - Execution: Sequential (better resource management)"
    echo "   - Compilation: CI_BUILD flag (excludes stress tests)"
    echo "   - Datasets: Reduced sizes for faster execution"
    SWIFT_CMD="$SWIFT_CMD -Xswiftc -DCI_BUILD"
    
    # Note: NOT adding --parallel for CI to ensure sequential execution
    # This respects TestConfiguration.useParallelExecution = false for CI
else
    # Local Configuration: Parallel execution, full test suite
    echo "⚙️  Local Configuration:"
    echo "   - Execution: Parallel (max performance)"
    echo "   - Test Suite: Complete (including stress tests)"
    echo "   - Datasets: Full sizes for comprehensive testing"
    SWIFT_CMD="$SWIFT_CMD --parallel"
fi

if [ "$VERBOSE" = true ]; then
    echo "🔧 Executing: $SWIFT_CMD"
fi

# Execute tests with optional timeout
if [ "$TIMEOUT_ENABLED" = true ]; then
    echo "⏰ Timeout: ${TIMEOUT_SECONDS}s"
    
    if command -v gtimeout &> /dev/null; then
        # Use GNU timeout (macOS with coreutils)
        TIMEOUT_CMD="gtimeout ${TIMEOUT_SECONDS}s"
    elif command -v timeout &> /dev/null; then
        # Use standard timeout (Linux)
        TIMEOUT_CMD="timeout ${TIMEOUT_SECONDS}s"
    else
        echo -e "${YELLOW}⚠️  Timeout command not available, running without timeout${NC}"
        TIMEOUT_CMD=""
    fi
    
    if [ -n "$TIMEOUT_CMD" ]; then
        eval "$TIMEOUT_CMD $SWIFT_CMD"
        EXIT_CODE=$?
        
        if [ $EXIT_CODE -eq 124 ] || [ $EXIT_CODE -eq 143 ]; then
            echo -e "${RED}❌ Tests timed out after ${TIMEOUT_SECONDS} seconds${NC}"
            echo -e "${YELLOW}💡 Consider:${NC}"
            echo "   - Reducing test dataset sizes in CI"
            echo "   - Optimizing slow test algorithms"
            echo "   - Using sequential execution in resource-constrained environments"
            exit 1
        elif [ $EXIT_CODE -ne 0 ]; then
            echo -e "${RED}❌ Tests failed with exit code $EXIT_CODE${NC}"
            exit $EXIT_CODE
        fi
    else
        eval "$SWIFT_CMD"
    fi
else
    eval "$SWIFT_CMD"
fi

# Parse test results for summary
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed in $ENV_NAME environment!${NC}"
    
    # Report execution strategy used
    if [ "$IS_CI" = true ]; then
        echo -e "${BLUE}📈 Execution Summary:${NC}"
        echo "   - Strategy: Sequential (CI-optimized)"
        echo "   - Resource Usage: Minimized for CI constraints"
        echo "   - Test Coverage: Focused (stress tests excluded)"
    else
        echo -e "${BLUE}📈 Execution Summary:${NC}"
        echo "   - Strategy: Parallel (maximum performance)"
        echo "   - Test Coverage: Complete (all test categories)"
        echo "   - Resource Usage: Optimized for local development"
    fi
else
    echo -e "${RED}❌ Tests failed in $ENV_NAME environment${NC}"
    exit 1
fi