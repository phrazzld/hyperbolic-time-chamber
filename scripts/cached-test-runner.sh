#!/bin/bash

# Cached Test Runner for CI Optimization
# Implements intelligent test result caching and selective execution

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CACHE_DIR=".test-cache"
CACHE_VERSION="1.0"
MAX_CACHE_AGE_HOURS=168  # 7 days
DEFAULT_TIMEOUT=180

# Options
FORCE_FULL_RUN=false
ENABLE_COVERAGE=false
VERBOSE=false
TIMEOUT_SECONDS=$DEFAULT_TIMEOUT

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --source-hash)
            SOURCE_HASH="$2"
            shift 2
            ;;
        --force-full)
            FORCE_FULL_RUN=true
            shift
            ;;
        --coverage)
            ENABLE_COVERAGE=true
            shift
            ;;
        --timeout)
            TIMEOUT_SECONDS="$2"
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
            echo "  --source-hash HASH    Use specific source hash for cache key"
            echo "  --force-full          Force full test execution (ignore cache)"
            echo "  --coverage            Enable code coverage reporting"
            echo "  --timeout SECONDS     Set test timeout (default: ${DEFAULT_TIMEOUT}s)"
            echo "  --verbose             Enable verbose output"
            echo "  --help                Show this help message"
            echo ""
            echo "Intelligent test caching:"
            echo "  - Detects changed files to run only affected tests"
            echo "  - Caches test results for unchanged code"
            echo "  - Validates cache integrity and freshness"
            echo "  - Falls back to full test run if cache is invalid"
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

echo -e "${BLUE}🚀 Starting cached test execution in $ENV_NAME environment...${NC}"

# Generate source hash if not provided
if [ -z "$SOURCE_HASH" ]; then
    if [ "$VERBOSE" = true ]; then
        echo "🔍 Generating source hash..."
    fi
    
    # Platform-specific hash command detection
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - use shasum
        HASH_CMD="shasum -a 256"
        HASH_EXTRACT_CMD="cut -d' ' -f1"
    else
        # Linux - use sha256sum
        HASH_CMD="sha256sum"
        HASH_EXTRACT_CMD="cut -d' ' -f1"
    fi
    
    # Generate hash with platform-appropriate command
    SOURCE_HASH=$(find Sources Tests -name "*.swift" -exec $HASH_CMD {} \; 2>/dev/null | $HASH_CMD | $HASH_EXTRACT_CMD || echo "fallback-$(date +%s)")
fi

CACHE_FILE="$CACHE_DIR/results-$SOURCE_HASH.json"
METADATA_FILE="$CACHE_DIR/metadata-$SOURCE_HASH.json"

if [ "$VERBOSE" = true ]; then
    echo "📋 Cache Configuration:"
    echo "   - Source Hash: $SOURCE_HASH"
    echo "   - Cache File: $CACHE_FILE"
    echo "   - Cache Directory: $CACHE_DIR"
    echo "   - Max Cache Age: ${MAX_CACHE_AGE_HOURS}h"
fi

# Create cache directory
mkdir -p "$CACHE_DIR"

# Check for valid cached results
check_cache_validity() {
    local cache_file="$1"
    local metadata_file="$2"
    
    # Check if cache files exist
    if [ ! -f "$cache_file" ] || [ ! -f "$metadata_file" ]; then
        if [ "$VERBOSE" = true ]; then
            echo "❌ Cache files not found"
        fi
        return 1
    fi
    
    # Validate JSON format
    if ! jq . "$cache_file" >/dev/null 2>&1; then
        echo "❌ Invalid cache JSON format"
        return 1
    fi
    
    if ! jq . "$metadata_file" >/dev/null 2>&1; then
        echo "❌ Invalid metadata JSON format"
        return 1
    fi
    
    # Check cache version
    local cache_version=$(jq -r '.cache_version // "unknown"' "$metadata_file")
    if [ "$cache_version" != "$CACHE_VERSION" ]; then
        echo "❌ Cache version mismatch: $cache_version != $CACHE_VERSION"
        return 1
    fi
    
    # Check cache age (handle both macOS and Linux date formats)
    local cache_timestamp=$(jq -r '.timestamp // "1970-01-01T00:00:00Z"' "$metadata_file")
    local cache_epoch
    local current_epoch=$(date +%s)
    
    # Try different date parsing methods for cross-platform compatibility
    if command -v gdate >/dev/null 2>&1; then
        # GNU date (if available via coreutils)
        cache_epoch=$(gdate -d "$cache_timestamp" +%s 2>/dev/null || echo "0")
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS date (BSD date)
        cache_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$cache_timestamp" +%s 2>/dev/null || echo "0")
    else
        # Linux date (GNU date)
        cache_epoch=$(date -d "$cache_timestamp" +%s 2>/dev/null || echo "0")
    fi
    
    local age_hours=$(( (current_epoch - cache_epoch) / 3600 ))
    
    if [ "$age_hours" -gt "$MAX_CACHE_AGE_HOURS" ]; then
        echo "❌ Cache too old: ${age_hours}h > ${MAX_CACHE_AGE_HOURS}h"
        return 1
    fi
    
    # Verify environment compatibility
    local cached_env=$(jq -r '.environment // "unknown"' "$metadata_file")
    if [ "$cached_env" != "$ENV_NAME" ]; then
        echo "❌ Environment mismatch: cached=$cached_env, current=$ENV_NAME"
        return 1
    fi
    
    if [ "$VERBOSE" = true ]; then
        echo "✅ Cache validation passed"
        echo "   - Age: ${age_hours}h"
        echo "   - Environment: $cached_env"
        echo "   - Version: $cache_version"
    fi
    
    return 0
}

# Detect changed files to determine affected test suites
detect_changed_files() {
    local changed_files=""
    
    if [ -n "$GITHUB_ACTIONS" ]; then
        # In GitHub Actions, compare with previous commit
        if [ -n "$GITHUB_EVENT_BEFORE" ] && [ "$GITHUB_EVENT_BEFORE" != "0000000000000000000000000000000000000000" ]; then
            changed_files=$(git diff --name-only "$GITHUB_EVENT_BEFORE" HEAD 2>/dev/null || echo "")
        else
            # Fallback to comparing with HEAD~1
            changed_files=$(git diff --name-only HEAD~1 HEAD 2>/dev/null || echo "")
        fi
    else
        # Local development - compare with main branch
        changed_files=$(git diff --name-only main...HEAD 2>/dev/null || echo "")
    fi
    
    if [ -z "$changed_files" ]; then
        # Fallback - assume all files changed
        changed_files="Sources/ Tests/"
    fi
    
    echo "$changed_files"
}

# Determine which test suites to run based on changed files
determine_test_scope() {
    local changed_files="$1"
    local test_scopes=""
    
    # Always run unit tests if any source files changed
    if echo "$changed_files" | grep -q "Sources/\|Tests/.*Tests\.swift"; then
        test_scopes="$test_scopes unit"
    fi
    
    # Run integration tests if core logic or integration tests changed
    if echo "$changed_files" | grep -q "Sources/.*\(ViewModel\|Service\|DataStore\)\|Tests/.*Integration"; then
        test_scopes="$test_scopes integration"
    fi
    
    # Run performance tests if performance-critical code changed
    if echo "$changed_files" | grep -q "Sources/.*\(DataStore\|Service\)\|Tests/.*Performance"; then
        test_scopes="$test_scopes performance"
    fi
    
    # If no specific scopes detected, run all tests
    if [ -z "$test_scopes" ]; then
        test_scopes="all"
    fi
    
    echo "$test_scopes"
}

# Execute tests with proper configuration
run_tests() {
    local test_scope="$1"
    local start_time=$(date +%s)
    
    echo -e "${BLUE}🧪 Running tests with scope: $test_scope${NC}"
    
    # Use appropriate test runner based on coverage requirements
    local test_cmd
    if [ "$ENABLE_COVERAGE" = true ]; then
        test_cmd="./scripts/generate-coverage.sh"
    else
        test_cmd="./scripts/run-tests.sh"
        
        if [ "$IS_CI" = true ]; then
            test_cmd="$test_cmd --timeout $TIMEOUT_SECONDS"
        fi
        
        if [ "$VERBOSE" = true ]; then
            test_cmd="$test_cmd --verbose"
        fi
        
        # Add test filtering based on scope for run-tests.sh
        case "$test_scope" in
            unit)
                test_cmd="$test_cmd --filter WorkoutTrackerTests"
                ;;
            integration)
                test_cmd="$test_cmd --filter WorkoutTrackerIntegrationTests"
                ;;
            performance)
                test_cmd="$test_cmd --filter Performance"
                ;;
            all|*)
                # Run all tests (default behavior)
                ;;
        esac
    fi
    
    if [ "$VERBOSE" = true ]; then
        echo "🔧 Executing: $test_cmd"
    fi
    
    # Execute tests and capture output
    local test_output
    local test_exit_code
    
    test_output=$(eval "$test_cmd" 2>&1)
    test_exit_code=$?
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Parse test results
    local total_tests=$(echo "$test_output" | grep -o "Executed [0-9]* tests" | tail -1 | grep -o "[0-9]*" || echo "0")
    local failed_tests=0
    
    if [ $test_exit_code -ne 0 ]; then
        failed_tests=$(echo "$test_output" | grep -o "[0-9]* failed" | head -1 | grep -o "[0-9]*" || echo "1")
    fi
    
    # Store results
    local result_status="passed"
    if [ $test_exit_code -ne 0 ]; then
        result_status="failed"
    fi
    
    # Create test results JSON
    cat > "$CACHE_FILE" << EOF
{
  "cache_version": "$CACHE_VERSION",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "source_hash": "$SOURCE_HASH",
  "environment": "$ENV_NAME",
  "test_scope": "$test_scope",
  "results": {
    "status": "$result_status",
    "exit_code": $test_exit_code,
    "execution_time": $duration,
    "total_tests": $total_tests,
    "failed_tests": $failed_tests
  },
  "output": $(echo "$test_output" | jq -Rs .)
}
EOF
    
    # Create metadata
    cat > "$METADATA_FILE" << EOF
{
  "cache_version": "$CACHE_VERSION",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "source_hash": "$SOURCE_HASH",
  "environment": "$ENV_NAME",
  "test_scope": "$test_scope",
  "system_info": {
    "os": "$(uname -s)",
    "arch": "$(uname -m)",
    "swift_version": "$(swift --version | head -1 || echo 'unknown')"
  }
}
EOF
    
    # Output test results
    echo "$test_output"
    
    # Summary
    if [ $test_exit_code -eq 0 ]; then
        echo -e "${GREEN}✅ Tests completed successfully in ${duration}s ($total_tests tests)${NC}"
        echo -e "${BLUE}📦 Results cached for future runs${NC}"
    else
        echo -e "${RED}❌ Tests failed after ${duration}s ($failed_tests failures out of $total_tests tests)${NC}"
    fi
    
    return $test_exit_code
}

# Use cached results if available and valid
use_cached_results() {
    local cache_file="$1"
    
    echo -e "${GREEN}✅ Using cached test results${NC}"
    
    # Extract and display cached results
    local status=$(jq -r '.results.status' "$cache_file")
    local duration=$(jq -r '.results.execution_time' "$cache_file")
    local total_tests=$(jq -r '.results.total_tests' "$cache_file")
    local failed_tests=$(jq -r '.results.failed_tests' "$cache_file")
    local test_scope=$(jq -r '.test_scope' "$cache_file")
    local timestamp=$(jq -r '.timestamp' "$cache_file")
    
    echo -e "${BLUE}📊 Cached Results Summary:${NC}"
    echo "   - Status: $status"
    echo "   - Test Scope: $test_scope"
    echo "   - Execution Time: ${duration}s"
    echo "   - Total Tests: $total_tests"
    echo "   - Failed Tests: $failed_tests"
    echo "   - Cached: $timestamp"
    
    # Output cached test output if verbose
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}📋 Cached Test Output:${NC}"
        jq -r '.output' "$cache_file"
    fi
    
    # Return appropriate exit code
    local exit_code=$(jq -r '.results.exit_code' "$cache_file")
    return $exit_code
}

# Main execution logic
main() {
    # Check if we should force a full run
    if [ "$FORCE_FULL_RUN" = true ]; then
        echo -e "${YELLOW}⚠️  Forcing full test execution (ignoring cache)${NC}"
        run_tests "all"
        return $?
    fi
    
    # Check for valid cached results
    if check_cache_validity "$CACHE_FILE" "$METADATA_FILE"; then
        echo -e "${GREEN}🎯 Valid cache found for source hash: $SOURCE_HASH${NC}"
        use_cached_results "$CACHE_FILE"
        return $?
    fi
    
    # No valid cache found - analyze what to run
    echo -e "${YELLOW}📂 No valid cache found - analyzing test requirements...${NC}"
    
    local changed_files=$(detect_changed_files)
    local test_scope=$(determine_test_scope "$changed_files")
    
    if [ "$VERBOSE" = true ]; then
        echo "🔍 Changed files analysis:"
        echo "$changed_files" | sed 's/^/   - /'
        echo "🎯 Determined test scope: $test_scope"
    fi
    
    # Run tests and cache results
    run_tests "$test_scope"
    return $?
}

# Execute main function
main "$@"