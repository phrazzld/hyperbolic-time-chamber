#!/bin/bash

# =============================================================================
# Code Complexity Analysis Script
# 
# Analyzes Swift codebase using lizard complexity analyzer and generates
# comprehensive reports with configurable thresholds for CI/CD integration.
# =============================================================================

set -euo pipefail

# Configuration - Complexity thresholds based on current codebase analysis
COMPLEXITY_DIR="complexity"
MAX_CYCLOMATIC_COMPLEXITY=8      # Current max is 3, set reasonable threshold
MAX_FUNCTION_LENGTH=20           # Current max is 15, allow some growth
MAX_FUNCTION_PARAMETERS=5        # Current max is 3, reasonable limit
MAX_NLOC_PER_FILE=100           # Current max is 69, reasonable limit

# Analysis target directories
SOURCE_DIRS=("Sources/")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}🔍 $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if lizard is available
check_dependencies() {
    if ! command -v lizard &> /dev/null; then
        # Try to activate venv if lizard not in PATH
        if [ -f ".venv/bin/activate" ]; then
            log_info "Activating virtual environment for lizard..."
            source .venv/bin/activate
        else
            log_error "lizard not found. Please install: pip install lizard"
            exit 1
        fi
    fi
}

# Initialize complexity reporting directory
setup_output_dir() {
    log_info "Setting up complexity analysis output directory..."
    
    # Clean and create complexity directory
    rm -rf "$COMPLEXITY_DIR"
    mkdir -p "$COMPLEXITY_DIR"
    
    # Add to .gitignore if not already present
    if [ -f ".gitignore" ] && ! grep -q "^${COMPLEXITY_DIR}/" .gitignore; then
        echo "${COMPLEXITY_DIR}/" >> .gitignore
        log_info "Added ${COMPLEXITY_DIR}/ to .gitignore"
    fi
}

# Generate complexity analysis reports
generate_reports() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    log_info "Analyzing code complexity..."
    
    # Source directories to analyze
    local all_sources=""
    for dir in "${SOURCE_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            all_sources="$all_sources $dir"
        fi
    done
    
    if [ -z "$all_sources" ]; then
        log_error "No source directories found to analyze"
        exit 1
    fi
    
    # Generate main complexity report
    lizard $all_sources \
        --languages swift \
        --CCN $MAX_CYCLOMATIC_COMPLEXITY \
        --length $MAX_FUNCTION_LENGTH \
        --arguments $MAX_FUNCTION_PARAMETERS \
        --verbose > "$COMPLEXITY_DIR/complexity-report.txt" || true
    
    # Generate JSON report for tooling integration
    lizard $all_sources \
        --languages swift \
        --output_file "$COMPLEXITY_DIR/complexity-report.json" || true
    
    # Generate CSV report for data analysis
    lizard $all_sources \
        --languages swift \
        --csv \
        --output_file "$COMPLEXITY_DIR/complexity-report.csv" || true
    
    # Generate HTML report for human consumption
    lizard $all_sources \
        --languages swift \
        --html \
        --output_file "$COMPLEXITY_DIR/complexity-report.html" || true
    
    # Generate detailed analysis with threshold violations
    {
        echo "# Code Complexity Analysis Report"
        echo "Generated: $timestamp"
        echo ""
        echo "## Configuration"
        echo "- Max Cyclomatic Complexity: $MAX_CYCLOMATIC_COMPLEXITY"
        echo "- Max Function Length: $MAX_FUNCTION_LENGTH"
        echo "- Max Function Parameters: $MAX_FUNCTION_PARAMETERS" 
        echo "- Max NLOC per File: $MAX_NLOC_PER_FILE"
        echo ""
        echo "## Analysis Results"
        echo ""
    } > "$COMPLEXITY_DIR/analysis-summary.md"
    
    # Append main report to summary
    cat "$COMPLEXITY_DIR/complexity-report.txt" >> "$COMPLEXITY_DIR/analysis-summary.md"
}

# Check for complexity threshold violations
check_thresholds() {
    log_info "Checking complexity thresholds..."
    
    local violations=0
    local warning_file="$COMPLEXITY_DIR/threshold-violations.txt"
    
    # Check for threshold violations in the main report
    if [ -f "$COMPLEXITY_DIR/complexity-report.txt" ]; then
        # Extract violations from lizard output
        local violation_count=$(grep -c "EXCEEDED" "$COMPLEXITY_DIR/complexity-report.txt" || echo "0")
        
        if [ "$violation_count" -gt 0 ]; then
            violations=$((violations + violation_count))
            {
                echo "=== COMPLEXITY THRESHOLD VIOLATIONS ==="
                echo "Found $violation_count complexity violations:"
                echo ""
                grep "EXCEEDED" "$COMPLEXITY_DIR/complexity-report.txt" || true
                echo ""
            } > "$warning_file"
        fi
        
        # Check for high complexity functions manually
        local high_complexity_functions=$(awk '
            /^[ ]*[0-9]+[ ]+[0-9]+/ {
                ccn = $2
                if (ccn > '"$MAX_CYCLOMATIC_COMPLEXITY"') {
                    print "High complexity (CCN=" ccn "): " $0
                }
            }
        ' "$COMPLEXITY_DIR/complexity-report.txt" 2>/dev/null || echo "")
        
        if [ -n "$high_complexity_functions" ]; then
            {
                echo "=== HIGH COMPLEXITY FUNCTIONS ==="
                echo "$high_complexity_functions"
                echo ""
            } >> "$warning_file"
            violations=$((violations + 1))
        fi
    fi
    
    return $violations
}

# Generate complexity summary
generate_summary() {
    log_info "Generating complexity summary..."
    
    local summary_file="$COMPLEXITY_DIR/complexity-summary.txt"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Extract key metrics from lizard output
    local total_functions=0
    local avg_ccn="0.0"
    local total_nloc=0
    local warnings=0
    
    if [ -f "$COMPLEXITY_DIR/complexity-report.txt" ]; then
        # Parse the summary line from lizard output (last line with data)
        local summary_line=$(grep "^[ ]*[0-9]" "$COMPLEXITY_DIR/complexity-report.txt" | tail -1)
        if [ -n "$summary_line" ]; then
            # Extract metrics from the summary line
            total_nloc=$(echo "$summary_line" | awk '{print $1}')
            avg_ccn=$(echo "$summary_line" | awk '{print $3}')
            total_functions=$(echo "$summary_line" | awk '{print $5}')
        fi
        
        # Check for threshold exceeded message
        if grep -q "No thresholds exceeded" "$COMPLEXITY_DIR/complexity-report.txt"; then
            warnings=0
        else
            warnings=$(grep -c "EXCEEDED" "$COMPLEXITY_DIR/complexity-report.txt" || echo "0")
        fi
    fi
    
    {
        echo "=== CODE COMPLEXITY SUMMARY ==="
        echo "Analysis Timestamp: $timestamp"
        echo ""
        echo "📊 Overall Metrics:"
        echo "  Total NLOC: $total_nloc"
        echo "  Total Functions: $total_functions"
        echo "  Average Cyclomatic Complexity: $avg_ccn"
        echo "  Threshold Violations: $warnings"
        echo ""
        echo "🎯 Configured Thresholds:"
        echo "  Max Cyclomatic Complexity: $MAX_CYCLOMATIC_COMPLEXITY"
        echo "  Max Function Length: $MAX_FUNCTION_LENGTH"
        echo "  Max Function Parameters: $MAX_FUNCTION_PARAMETERS"
        echo "  Max NLOC per File: $MAX_NLOC_PER_FILE"
        echo ""
        echo "📁 Generated Reports:"
        echo "  📄 Text Report: complexity/complexity-report.txt"
        echo "  🌐 HTML Report: complexity/complexity-report.html"
        echo "  📊 JSON Report: complexity/complexity-report.json"
        echo "  📈 CSV Report: complexity/complexity-report.csv"
        echo "  📝 Analysis Summary: complexity/analysis-summary.md"
        
        if [ -f "$COMPLEXITY_DIR/threshold-violations.txt" ]; then
            echo "  ⚠️  Violations: complexity/threshold-violations.txt"
        fi
    } > "$summary_file"
    
    # Display summary to console
    cat "$summary_file"
}

# Main execution
main() {
    log_info "Starting code complexity analysis..."
    
    # Activate virtual environment if available
    if [ -f ".venv/bin/activate" ]; then
        source .venv/bin/activate
    fi
    
    check_dependencies
    setup_output_dir
    generate_reports
    
    local violations=0
    check_thresholds || violations=$?
    
    generate_summary
    
    # Exit based on violations (but don't fail CI for now - just warn)
    if [ "$violations" -gt 0 ]; then
        log_warning "Found $violations complexity issues. Review reports for details."
        log_info "Note: Complexity violations are currently informational only."
        # TODO: Enable failing CI after baseline is established
        # exit 1
    else
        log_success "No complexity violations found!"
    fi
    
    log_success "Code complexity analysis completed successfully!"
}

# Run main function
main "$@"