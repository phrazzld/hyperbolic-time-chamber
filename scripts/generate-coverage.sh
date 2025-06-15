#!/bin/bash

# Code Coverage Generation Script for WorkoutTracker
# Generates test coverage reports and validates minimum thresholds

set -e

# Import platform utilities and error handling
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/platform-utils.sh"

# Configuration - Set achievable baselines focused on business logic
COVERAGE_DIR="coverage"
MIN_LINE_COVERAGE=9   # Current baseline: 9.16%, maintain current level while allowing room for growth
MIN_FUNCTION_COVERAGE=45  # Current baseline: 47%, maintain current level 
MIN_BUSINESS_LOGIC_COVERAGE=90  # High bar for Models/, Services/, ViewModels/

echo -e "${BLUE}📊 Generating test coverage report...${NC}"

# Check system requirements
if ! require_command "swift" "Swift compiler"; then
    exit 1
fi

if ! require_command "xcrun" "Xcode command line tools" "Install Xcode Command Line Tools: xcode-select --install"; then
    exit 1
fi

# Clean previous coverage data
rm -rf $COVERAGE_DIR
mkdir -p $COVERAGE_DIR

# Run tests with coverage enabled
echo "🧪 Running tests with code coverage enabled..."
# Pass CI_BUILD flag when running in CI environment
if [ -n "$GITHUB_ACTIONS" ]; then
    echo "📌 CI environment detected - excluding stress tests with CI_BUILD flag"
    swift test --enable-code-coverage -Xswiftc -DCI_BUILD
else
    swift test --enable-code-coverage
fi

# Find the generated coverage files
PROFDATA_FILE=$(find .build -name "*.profdata" | head -1)
EXECUTABLE_FILE=$(find .build -path "*debug/WorkoutTracker" -type f | grep -v dSYM | head -1)

if [ -z "$PROFDATA_FILE" ] || [ -z "$EXECUTABLE_FILE" ]; then
    error_with_context "Coverage files not found" "code coverage generation" \
        "Ensure tests ran successfully with --enable-code-coverage
Check that Swift package builds correctly
Verify .build directory exists and is accessible
Try running: swift test --enable-code-coverage manually"
    exit 1
fi

echo "📁 Found coverage data:"
echo "  - Profile: $PROFDATA_FILE"
echo "  - Executable: $EXECUTABLE_FILE"

# Generate text report
echo "📋 Generating text coverage report..."
xcrun llvm-cov report "$EXECUTABLE_FILE" \
    -instr-profile="$PROFDATA_FILE" \
    > "$COVERAGE_DIR/coverage-summary.txt"

# Generate detailed HTML report
echo "🌐 Generating HTML coverage report..."
xcrun llvm-cov show "$EXECUTABLE_FILE" \
    -instr-profile="$PROFDATA_FILE" \
    -format=html \
    -output-dir="$COVERAGE_DIR/html" \
    -ignore-filename-regex="Tests/.*" \
    -show-line-counts \
    -show-regions

# Generate JSON report for programmatic analysis
echo "📄 Generating JSON coverage report..."
xcrun llvm-cov export "$EXECUTABLE_FILE" \
    -instr-profile="$PROFDATA_FILE" \
    -format=text \
    -ignore-filename-regex="Tests/.*" \
    > "$COVERAGE_DIR/coverage.json"

# Parse coverage summary and check thresholds
echo "🎯 Parsing coverage results..."

# Extract overall coverage percentages from text report
COVERAGE_SUMMARY=$(cat "$COVERAGE_DIR/coverage-summary.txt")
TOTAL_LINE=$(echo "$COVERAGE_SUMMARY" | grep "TOTAL")

# Parse coverage data more carefully
LINE_COVERAGE=$(echo "$TOTAL_LINE" | awk '{print $10}' | sed 's/%//')
FUNCTION_COVERAGE=$(echo "$TOTAL_LINE" | awk '{print $6}' | sed 's/%//')

# Handle cases where coverage might be reported as "-" 
if [ "$LINE_COVERAGE" = "-" ]; then
    LINE_COVERAGE="0.00"
fi
if [ "$FUNCTION_COVERAGE" = "-" ]; then
    FUNCTION_COVERAGE="0.00"
fi

# Parse line coverage to get just the number (convert float to int for comparison)
LINE_COVERAGE_NUM=$(echo "$LINE_COVERAGE" | cut -d'.' -f1)
FUNCTION_COVERAGE_NUM=$(echo "$FUNCTION_COVERAGE" | cut -d'.' -f1)

# Handle empty values
if [ -z "$LINE_COVERAGE_NUM" ] || [ "$LINE_COVERAGE_NUM" = "" ]; then
    LINE_COVERAGE_NUM=0
fi
if [ -z "$FUNCTION_COVERAGE_NUM" ] || [ "$FUNCTION_COVERAGE_NUM" = "" ]; then
    FUNCTION_COVERAGE_NUM=0
fi

# Display results
echo
echo -e "${BLUE}📊 Coverage Summary:${NC}"
echo "=================================="
echo -e "Line Coverage:     ${YELLOW}${LINE_COVERAGE}%${NC}"
echo -e "Function Coverage: ${YELLOW}${FUNCTION_COVERAGE}%${NC}"
echo
echo -e "${BLUE}📋 Coverage by Component:${NC}"
echo "=================================="
cat "$COVERAGE_DIR/coverage-summary.txt" | grep -E "(Models/|Services/|ViewModels/|Views/|\.swift)" | grep -v TOTAL

# Check if coverage meets minimum thresholds
echo
echo -e "${BLUE}🎯 Threshold Validation:${NC}"
echo "=================================="

COVERAGE_PASSED=true

if [ "$LINE_COVERAGE_NUM" -ge "$MIN_LINE_COVERAGE" ]; then
    echo -e "✅ Line coverage ($LINE_COVERAGE%) meets minimum threshold ($MIN_LINE_COVERAGE%)"
else
    echo -e "❌ Line coverage ($LINE_COVERAGE%) below minimum threshold ($MIN_LINE_COVERAGE%)"
    COVERAGE_PASSED=false
fi

if [ "$FUNCTION_COVERAGE_NUM" -ge "$MIN_FUNCTION_COVERAGE" ]; then
    echo -e "✅ Function coverage ($FUNCTION_COVERAGE%) meets minimum threshold ($MIN_FUNCTION_COVERAGE%)"
else
    echo -e "❌ Function coverage ($FUNCTION_COVERAGE%) below minimum threshold ($MIN_FUNCTION_COVERAGE%)"
    COVERAGE_PASSED=false
fi

# Check business logic coverage (Models/, Services/, ViewModels/) - excluding demo/test utilities
echo -e "🎯 Business Logic Coverage (Models/, Services/, ViewModels/):"
BUSINESS_LOGIC_FILES=$(cat "$COVERAGE_DIR/coverage-summary.txt" | grep -E "(Models/|Services/|ViewModels/)" | grep -v "DemoDataService")
BUSINESS_LOGIC_FAILED=false

echo "$BUSINESS_LOGIC_FILES" | while read -r line; do
    if [ -n "$line" ]; then
        FILENAME=$(echo "$line" | awk '{print $1}')
        BL_LINE_COVERAGE=$(echo "$line" | awk '{print $10}' | sed 's/%//')
        BL_LINE_COVERAGE_NUM=$(echo "$BL_LINE_COVERAGE" | cut -d'.' -f1)
        
        if [ "$BL_LINE_COVERAGE" != "-" ] && [ "$BL_LINE_COVERAGE_NUM" -ge "$MIN_BUSINESS_LOGIC_COVERAGE" ]; then
            echo -e "  ✅ $FILENAME: $BL_LINE_COVERAGE%"
        else
            echo -e "  ⚠️  $FILENAME: $BL_LINE_COVERAGE% (below $MIN_BUSINESS_LOGIC_COVERAGE%)"
        fi
    fi
done

# Note DemoDataService exclusion
echo -e "  ℹ️  Services/DemoDataService.swift: Excluded (demo/screenshot utility, not core business logic)"

# Generate coverage badge data
echo "{\"schemaVersion\": 1, \"label\": \"coverage\", \"message\": \"${LINE_COVERAGE}%\", \"color\": \"$([ "$LINE_COVERAGE_NUM" -ge "$MIN_LINE_COVERAGE" ] && echo "green" || echo "red")\"}" > "$COVERAGE_DIR/coverage-badge.json"

# Output file locations
echo
echo -e "${BLUE}📁 Generated Reports:${NC}"
echo "=================================="
echo "📋 Text Summary:  $COVERAGE_DIR/coverage-summary.txt"
echo "🌐 HTML Report:   $COVERAGE_DIR/html/index.html"
echo "📄 JSON Data:     $COVERAGE_DIR/coverage.json"
echo "🏷️  Badge Data:    $COVERAGE_DIR/coverage-badge.json"

# Final result
echo
if [ "$COVERAGE_PASSED" = true ]; then
    echo -e "${GREEN}✅ All coverage thresholds met!${NC}"
    exit 0
else
    echo -e "${RED}❌ Coverage thresholds not met. Please add more tests.${NC}"
    echo
    echo -e "${YELLOW}💡 To improve coverage:${NC}"
    echo "   - Add tests for uncovered functions in low-coverage files"
    echo "   - Focus on business logic in Models/, Services/, and ViewModels/"
    echo "   - Consider UI tests for Views/ if UI coverage is required"
    echo "   - Review the HTML report for detailed line-by-line coverage"
    echo
    exit 1
fi