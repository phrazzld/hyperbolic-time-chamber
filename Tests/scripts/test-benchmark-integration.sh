#!/bin/bash

# Benchmark CI Performance Integration Tests
# End-to-end validation of the benchmark system

set -e

# Colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
BENCHMARK_SCRIPT="$PROJECT_ROOT/scripts/benchmark-ci-performance.sh"
TEST_RESULTS_DIR="$PROJECT_ROOT/.test-results"
TEMP_BENCHMARKS_DIR="$TEST_RESULTS_DIR/integration-benchmarks"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Setup test environment
setup_test_env() {
    mkdir -p "$TEST_RESULTS_DIR"
    mkdir -p "$TEMP_BENCHMARKS_DIR"
    
    # Override benchmarks directory for testing
    export BENCHMARKS_DIR="$TEMP_BENCHMARKS_DIR"
}

# Cleanup test environment
cleanup_test_env() {
    rm -rf "$TEST_RESULTS_DIR"
}

# Test helper functions
assert_file_exists() {
    local file_path="$1"
    local test_name="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ -f "$file_path" ]; then
        echo -e "${GREEN}✅ PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: $test_name"
        echo "   File not found: $file_path"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_json_valid() {
    local file_path="$1"
    local test_name="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if jq empty "$file_path" 2>/dev/null; then
        echo -e "${GREEN}✅ PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: $test_name"
        echo "   Invalid JSON in: $file_path"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_json_contains_key() {
    local file_path="$1"
    local key_path="$2"
    local test_name="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    local value=$(jq -r "$key_path" "$file_path" 2>/dev/null)
    if [ "$value" != "null" ] && [ "$value" != "" ]; then
        echo -e "${GREEN}✅ PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: $test_name"
        echo "   Key not found: $key_path in $file_path"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test 1: Benchmark script collection-only mode
test_collection_only_mode() {
    echo -e "${BLUE}🧪 Testing collection-only mode...${NC}"
    
    # Run benchmark in collection-only mode
    if "$BENCHMARK_SCRIPT" --collect-only >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}: Collection-only mode executes without errors"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: Collection-only mode failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
    
    # Check that results file was created
    assert_file_exists "$TEMP_BENCHMARKS_DIR/latest-results.json" "Results file created"
    
    # Validate results JSON structure
    if [ -f "$TEMP_BENCHMARKS_DIR/latest-results.json" ]; then
        assert_json_valid "$TEMP_BENCHMARKS_DIR/latest-results.json" "Results JSON is valid"
        assert_json_contains_key "$TEMP_BENCHMARKS_DIR/latest-results.json" ".metrics.peak_memory_usage" "Results contain peak memory usage"
        assert_json_contains_key "$TEMP_BENCHMARKS_DIR/latest-results.json" ".metrics.average_memory_usage" "Results contain average memory usage"
        assert_json_contains_key "$TEMP_BENCHMARKS_DIR/latest-results.json" ".environment" "Results contain environment info"
    fi
}

# Test 2: Baseline initialization
test_baseline_initialization() {
    echo -e "${BLUE}🧪 Testing baseline initialization...${NC}"
    
    # Remove existing baselines to test initialization
    rm -f "$TEMP_BENCHMARKS_DIR/baselines.json"
    
    # Run benchmark to trigger baseline initialization
    if "$BENCHMARK_SCRIPT" --collect-only >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}: Baseline initialization executes without errors"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: Baseline initialization failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
    
    # Check that baseline file was created
    assert_file_exists "$TEMP_BENCHMARKS_DIR/baselines.json" "Baseline file created"
    
    # Validate baseline JSON structure and calibrated values
    if [ -f "$TEMP_BENCHMARKS_DIR/baselines.json" ]; then
        assert_json_valid "$TEMP_BENCHMARKS_DIR/baselines.json" "Baseline JSON is valid"
        assert_json_contains_key "$TEMP_BENCHMARKS_DIR/baselines.json" ".baselines.peak_memory_usage.target" "Baseline contains peak memory target"
        
        # Check for calibrated values
        local peak_target=$(jq -r '.baselines.peak_memory_usage.target' "$TEMP_BENCHMARKS_DIR/baselines.json")
        if [ "$peak_target" = "245" ]; then
            echo -e "${GREEN}✅ PASS${NC}: Baseline contains calibrated peak memory target (245MB)"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}❌ FAIL${NC}: Baseline peak memory target incorrect (expected: 245, got: $peak_target)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
        TESTS_RUN=$((TESTS_RUN + 1))
    fi
}

# Test 3: Report-only mode
test_report_only_mode() {
    echo -e "${BLUE}🧪 Testing report-only mode...${NC}"
    
    # First ensure we have data to report on
    "$BENCHMARK_SCRIPT" --collect-only >/dev/null 2>&1
    
    # Run benchmark in report-only mode (may exit with non-zero due to critical metrics)
    "$BENCHMARK_SCRIPT" --report-only >/dev/null 2>&1
    local report_exit_code=$?
    
    # Report-only mode should execute (exit code 0 or 1 are both valid - 1 indicates critical metrics)
    if [ "$report_exit_code" -eq 0 ] || [ "$report_exit_code" -eq 1 ]; then
        echo -e "${GREEN}✅ PASS${NC}: Report-only mode executes without errors (exit code: $report_exit_code)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: Report-only mode failed with unexpected exit code: $report_exit_code"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}

# Test 4: Update baselines mode
test_update_baselines_mode() {
    echo -e "${BLUE}🧪 Testing update baselines mode...${NC}"
    
    # Get original baseline timestamp
    local original_timestamp=$(jq -r '.updated' "$TEMP_BENCHMARKS_DIR/baselines.json" 2>/dev/null || echo "")
    
    # Wait a moment to ensure timestamp difference
    sleep 1
    
    # Run benchmark with update baselines
    if "$BENCHMARK_SCRIPT" --update-baselines --collect-only >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}: Update baselines mode executes without errors"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: Update baselines mode failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
    
    # Check that baseline was updated
    if [ -f "$TEMP_BENCHMARKS_DIR/baselines.json" ]; then
        local new_timestamp=$(jq -r '.updated' "$TEMP_BENCHMARKS_DIR/baselines.json")
        if [ "$new_timestamp" != "$original_timestamp" ]; then
            echo -e "${GREEN}✅ PASS${NC}: Baseline timestamp updated"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}❌ FAIL${NC}: Baseline timestamp not updated"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
        TESTS_RUN=$((TESTS_RUN + 1))
    fi
}

# Test 5: Performance history tracking
test_performance_history() {
    echo -e "${BLUE}🧪 Testing performance history tracking...${NC}"
    
    # Run multiple collections to build history
    for i in {1..3}; do
        "$BENCHMARK_SCRIPT" --collect-only >/dev/null 2>&1
        sleep 1
    done
    
    # Check that history file was created
    assert_file_exists "$TEMP_BENCHMARKS_DIR/performance-history.jsonl" "Performance history file created"
    
    # Validate history contains multiple entries
    if [ -f "$TEMP_BENCHMARKS_DIR/performance-history.jsonl" ]; then
        local line_count=$(wc -l < "$TEMP_BENCHMARKS_DIR/performance-history.jsonl")
        if [ "$line_count" -ge 3 ]; then
            echo -e "${GREEN}✅ PASS${NC}: Performance history contains multiple entries ($line_count lines)"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}❌ FAIL${NC}: Performance history insufficient entries ($line_count lines)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
        TESTS_RUN=$((TESTS_RUN + 1))
        
        # Validate each line is valid JSON
        local valid_json=true
        while read -r line; do
            if ! echo "$line" | jq empty 2>/dev/null; then
                valid_json=false
                break
            fi
        done < "$TEMP_BENCHMARKS_DIR/performance-history.jsonl"
        
        if $valid_json; then
            echo -e "${GREEN}✅ PASS${NC}: Performance history contains valid JSON"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}❌ FAIL${NC}: Performance history contains invalid JSON"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
        TESTS_RUN=$((TESTS_RUN + 1))
    fi
}

# Test 6: Memory monitoring mode validation
test_memory_monitoring_modes() {
    echo -e "${BLUE}🧪 Testing memory monitoring modes...${NC}"
    
    # Test process monitoring mode
    export MEMORY_MONITORING_MODE="process"
    if "$BENCHMARK_SCRIPT" --collect-only >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}: Process monitoring mode works"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: Process monitoring mode failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
    
    # Test system monitoring mode  
    export MEMORY_MONITORING_MODE="system"
    if "$BENCHMARK_SCRIPT" --collect-only >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}: System monitoring mode works"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: System monitoring mode failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
    
    # Reset to default
    export MEMORY_MONITORING_MODE="process"
}

# Test 7: Environment detection and adaptation
test_environment_detection() {
    echo -e "${BLUE}🧪 Testing environment detection...${NC}"
    
    # Test local environment detection (current state)
    if "$BENCHMARK_SCRIPT" --collect-only >/dev/null 2>&1; then
        local detected_env=$(jq -r '.environment' "$TEMP_BENCHMARKS_DIR/latest-results.json")
        if [ "$detected_env" = "Local" ]; then
            echo -e "${GREEN}✅ PASS${NC}: Local environment correctly detected"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}❌ FAIL${NC}: Environment detection incorrect (expected: Local, got: $detected_env)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
        TESTS_RUN=$((TESTS_RUN + 1))
    fi
    
    # Test CI environment simulation
    export GITHUB_ACTIONS="true"
    export GITHUB_RUN_ID="test-12345"
    export GITHUB_WORKFLOW="test-workflow"
    
    if "$BENCHMARK_SCRIPT" --collect-only >/dev/null 2>&1; then
        local detected_env=$(jq -r '.environment' "$TEMP_BENCHMARKS_DIR/latest-results.json")
        if [ "$detected_env" = "CI" ]; then
            echo -e "${GREEN}✅ PASS${NC}: CI environment correctly detected"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}❌ FAIL${NC}: CI environment detection incorrect (expected: CI, got: $detected_env)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
        TESTS_RUN=$((TESTS_RUN + 1))
    fi
    
    # Reset environment
    unset GITHUB_ACTIONS GITHUB_RUN_ID GITHUB_WORKFLOW
}

# Main test execution
main() {
    echo -e "${BLUE}🧪 Benchmark CI Performance Integration Tests${NC}"
    echo "=============================================="
    
    setup_test_env
    
    echo ""
    test_collection_only_mode
    echo ""
    test_baseline_initialization
    echo ""
    test_report_only_mode
    echo ""
    test_update_baselines_mode
    echo ""
    test_performance_history
    echo ""
    test_memory_monitoring_modes
    echo ""
    test_environment_detection
    
    echo ""
    echo "=============================================="
    echo -e "${BLUE}📊 Integration Test Results Summary${NC}"
    echo "Tests run: $TESTS_RUN"
    echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"
    
    if [ "$TESTS_FAILED" -gt 0 ]; then
        echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"
        echo ""
        echo -e "${RED}❌ Some integration tests failed - benchmark system validation incomplete${NC}"
        cleanup_test_env
        exit 1
    else
        echo -e "${GREEN}Tests failed: 0${NC}"
        echo ""
        echo -e "${GREEN}✅ All integration tests passed - benchmark system validation complete${NC}"
        cleanup_test_env
        exit 0
    fi
}

# Handle script being sourced vs executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi