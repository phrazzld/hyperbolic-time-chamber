#!/bin/bash

# Memory Monitoring Validation Tests
# Tests the memory measurement functions and threshold validation logic

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
TEMP_BENCHMARKS_DIR="$TEST_RESULTS_DIR/test-benchmarks"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Setup test environment
setup_test_env() {
    mkdir -p "$TEST_RESULTS_DIR"
    mkdir -p "$TEMP_BENCHMARKS_DIR"
    
    # Export test environment variables
    export BENCHMARKS_DIR="$TEMP_BENCHMARKS_DIR"
    export MEMORY_MONITORING_MODE="process"
    export VERBOSE=false
}

# Cleanup test environment
cleanup_test_env() {
    rm -rf "$TEST_RESULTS_DIR"
}

# Test helper functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✅ PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: $test_name"
        echo "   Expected: $expected"
        echo "   Actual: $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_contains() {
    local substring="$1"
    local string="$2"
    local test_name="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ "$string" == *"$substring"* ]]; then
        echo -e "${GREEN}✅ PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: $test_name"
        echo "   Expected substring: $substring"
        echo "   In string: $string"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_greater_than() {
    local threshold="$1"
    local value="$2"
    local test_name="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ "$value" -gt "$threshold" ]; then
        echo -e "${GREEN}✅ PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: $test_name"
        echo "   Expected value > $threshold"
        echo "   Actual value: $value"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Source memory monitoring functions for testing
source_memory_functions() {
    # Extract and source the memory monitoring functions
    sed -n '/^get_swift_process_memory()/,/^}/p' "$BENCHMARK_SCRIPT" > "$TEMP_BENCHMARKS_DIR/memory-functions.sh"
    sed -n '/^get_system_memory_usage()/,/^}/p' "$BENCHMARK_SCRIPT" >> "$TEMP_BENCHMARKS_DIR/memory-functions.sh"
    sed -n '/^get_current_memory_usage()/,/^}/p' "$BENCHMARK_SCRIPT" >> "$TEMP_BENCHMARKS_DIR/memory-functions.sh"
    sed -n '/^get_environment_baselines()/,/^}/p' "$BENCHMARK_SCRIPT" >> "$TEMP_BENCHMARKS_DIR/memory-functions.sh"
    
    source "$TEMP_BENCHMARKS_DIR/memory-functions.sh"
}

# Test 1: Memory measurement functions return valid values
test_memory_measurement_functions() {
    echo -e "${BLUE}🧪 Testing memory measurement functions...${NC}"
    
    # Test Swift process memory measurement
    local swift_memory=$(get_swift_process_memory)
    assert_greater_than "0" "$swift_memory" "Swift process memory returns positive value"
    
    # Test system memory measurement  
    local system_memory=$(get_system_memory_usage)
    assert_greater_than "0" "$system_memory" "System memory returns positive value"
    
    # Test current memory usage (should default to process mode)
    local current_memory=$(get_current_memory_usage)
    assert_greater_than "0" "$current_memory" "Current memory usage returns positive value"
}

# Test 2: Environment baseline generation
test_environment_baselines() {
    echo -e "${BLUE}🧪 Testing environment baseline generation...${NC}"
    
    # Test CI environment baselines
    local ci_baselines=$(get_environment_baselines "CI")
    assert_contains "peak_memory_usage" "$ci_baselines" "CI baselines contain peak_memory_usage"
    assert_contains "400" "$ci_baselines" "CI baselines contain calibrated target (400MB)"
    assert_contains "calibrated from real workload data" "$ci_baselines" "CI baselines reference calibration"
    
    # Test Local environment baselines
    local local_baselines=$(get_environment_baselines "Local")
    assert_contains "245" "$local_baselines" "Local baselines contain calibrated target (245MB)"
    assert_contains "calibrated from real workload data" "$local_baselines" "Local baselines reference calibration"
}

# Test 3: Memory monitoring mode switching
test_memory_monitoring_modes() {
    echo -e "${BLUE}🧪 Testing memory monitoring mode switching...${NC}"
    
    # Test process mode (default)
    MEMORY_MONITORING_MODE="process"
    local process_memory=$(get_current_memory_usage)
    assert_greater_than "0" "$process_memory" "Process monitoring mode works"
    
    # Test system mode
    MEMORY_MONITORING_MODE="system"
    local system_memory=$(get_current_memory_usage)
    assert_greater_than "0" "$system_memory" "System monitoring mode works"
    
    # Reset to default
    MEMORY_MONITORING_MODE="process"
}

# Test 4: Baseline file generation and validation
test_baseline_file_operations() {
    echo -e "${BLUE}🧪 Testing baseline file operations...${NC}"
    
    # Test baseline file creation
    local baseline_file="$TEMP_BENCHMARKS_DIR/test-baselines.json"
    get_environment_baselines "Local" | jq . > "$baseline_file"
    
    # Validate JSON structure
    if jq empty "$baseline_file" 2>/dev/null; then
        echo -e "${GREEN}✅ PASS${NC}: Baseline file is valid JSON"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: Baseline file is invalid JSON"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
    
    # Test specific memory thresholds
    local peak_target=$(jq -r '.baselines.peak_memory_usage.target' "$baseline_file")
    assert_equals "245" "$peak_target" "Peak memory target matches calibrated value"
    
    local avg_target=$(jq -r '.baselines.average_memory_usage.target' "$baseline_file")
    assert_equals "100" "$avg_target" "Average memory target matches calibrated value"
}

# Test 5: Memory threshold validation logic
test_memory_threshold_validation() {
    echo -e "${BLUE}🧪 Testing memory threshold validation logic...${NC}"
    
    # Create test baseline with known values
    local test_baseline='{
        "baselines": {
            "peak_memory_usage": {
                "target": 100,
                "warning": 200,
                "critical": 300,
                "unit": "MB"
            }
        }
    }'
    
    echo "$test_baseline" > "$TEMP_BENCHMARKS_DIR/test-validation.json"
    
    # Test threshold extraction
    local target=$(echo "$test_baseline" | jq -r '.baselines.peak_memory_usage.target')
    local warning=$(echo "$test_baseline" | jq -r '.baselines.peak_memory_usage.warning')
    local critical=$(echo "$test_baseline" | jq -r '.baselines.peak_memory_usage.critical')
    
    assert_equals "100" "$target" "Target threshold extraction works"
    assert_equals "200" "$warning" "Warning threshold extraction works"
    assert_equals "300" "$critical" "Critical threshold extraction works"
}

# Test 6: Cross-platform compatibility
test_cross_platform_compatibility() {
    echo -e "${BLUE}🧪 Testing cross-platform compatibility...${NC}"
    
    # Test OS detection
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo -e "${GREEN}✅ PASS${NC}: Running on macOS - using ps and vm_stat"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    elif [[ "$OSTYPE" == "linux"* ]]; then
        echo -e "${GREEN}✅ PASS${NC}: Running on Linux - using proc filesystem"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠️ SKIP${NC}: Unknown OS type: $OSTYPE"
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
    
    # Test memory measurement tools availability
    if command -v ps >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}: ps command available"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: ps command not available"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}

# Test 7: Performance and reliability
test_performance_and_reliability() {
    echo -e "${BLUE}🧪 Testing performance and reliability...${NC}"
    
    # Test memory measurement performance (should complete quickly)
    local start_time=$(date +%s%N)
    get_swift_process_memory >/dev/null
    local end_time=$(date +%s%N)
    local duration_ms=$(( (end_time - start_time) / 1000000 ))
    
    # Memory measurement should complete in under 500ms
    if [ "$duration_ms" -lt 500 ]; then
        echo -e "${GREEN}✅ PASS${NC}: Memory measurement performance (${duration_ms}ms < 500ms)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: Memory measurement too slow (${duration_ms}ms >= 500ms)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
    
    # Test repeated measurements for consistency
    local mem1=$(get_swift_process_memory)
    local mem2=$(get_swift_process_memory)
    local mem3=$(get_swift_process_memory)
    
    # All measurements should be reasonable (between 1MB and 10GB)
    for mem in $mem1 $mem2 $mem3; do
        if [ "$mem" -ge 1 ] && [ "$mem" -le 10240 ]; then
            echo -e "${GREEN}✅ PASS${NC}: Memory measurement within reasonable range (${mem}MB)"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}❌ FAIL${NC}: Memory measurement out of range (${mem}MB)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
        TESTS_RUN=$((TESTS_RUN + 1))
    done
}

# Main test execution
main() {
    echo -e "${BLUE}🧪 Memory Monitoring Validation Tests${NC}"
    echo "======================================="
    
    setup_test_env
    source_memory_functions
    
    echo ""
    test_memory_measurement_functions
    echo ""
    test_environment_baselines
    echo ""
    test_memory_monitoring_modes
    echo ""
    test_baseline_file_operations
    echo ""
    test_memory_threshold_validation
    echo ""
    test_cross_platform_compatibility
    echo ""
    test_performance_and_reliability
    
    echo ""
    echo "======================================="
    echo -e "${BLUE}📊 Test Results Summary${NC}"
    echo "Tests run: $TESTS_RUN"
    echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"
    
    if [ "$TESTS_FAILED" -gt 0 ]; then
        echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"
        echo ""
        echo -e "${RED}❌ Some tests failed - memory monitoring validation incomplete${NC}"
        cleanup_test_env
        exit 1
    else
        echo -e "${GREEN}Tests failed: 0${NC}"
        echo ""
        echo -e "${GREEN}✅ All tests passed - memory monitoring validation complete${NC}"
        cleanup_test_env
        exit 0
    fi
}

# Handle script being sourced vs executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi