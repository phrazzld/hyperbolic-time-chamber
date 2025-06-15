#!/bin/bash

# =============================================================================
# Spell Checking Script
# 
# Checks spelling in user-facing strings, documentation comments, and markdown
# files using codespell with project-specific configuration.
# =============================================================================

set -euo pipefail

# Configuration
SPELLING_DIR="spelling"
IGNORE_WORDS="$SPELLING_DIR/ignore-words.txt"
SPELLING_REPORT="$SPELLING_DIR/spelling-report.txt"

# File patterns to check
SOURCE_PATTERNS=(
    "Sources/**/*.swift"
    "*.md"
    "scripts/*.sh"
    "docs/*.md"
    "CLAUDE.md"
)

# File patterns to skip
SKIP_PATTERNS=(
    "*.plist"
    "*.json"
    "*.doccarchive"
    "build/*"
    ".build/*"
    "coverage/*"
    "complexity/*"
    "security/*"
    "spelling/*"
    ".git/*"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}📝 $1${NC}"
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

# Check if codespell is available
check_dependencies() {
    log_info "Checking spell-checking dependencies..."
    
    if ! command -v codespell &> /dev/null; then
        log_error "codespell not found. Please install: brew install codespell"
        exit 1
    fi
    
    log_success "codespell $(codespell --version) available"
}

# Initialize spelling configuration
setup_spelling_config() {
    log_info "Setting up spell-checking configuration..."
    
    # Create spelling directory
    mkdir -p "$SPELLING_DIR"
    
    # Add to .gitignore if not already present
    if [ -f ".gitignore" ] && ! grep -q "^${SPELLING_DIR}/" .gitignore; then
        echo "${SPELLING_DIR}/" >> .gitignore
        log_info "Added ${SPELLING_DIR}/ to .gitignore"
    fi
    
    # Create project-specific ignore words list
    cat > "$IGNORE_WORDS" << 'EOF'
# Project-specific technical terms and proper nouns
SwiftUI
iOS
macOS
Xcode
JSON
MVVM
ViewModel
ViewModels
UIKit
UIActivityViewController
ExerciseSet
ExerciseEntry
WorkoutTracker
DataStore
ContentView
AddEntryView
HistoryView
ActivityView
UUID
Codable
Identifiable
ObservableObject
TabView
NavigationTitle
reps
Bool
Int
TextField
VStack
HStack
ForEach
OnDelete
IndexSet
DocC
API
APIs
GitHub
TestFlight
kg
lbs
iTunes
App Store
CI
CD
XCTest
async
await
struct
enum
func
var
let
init
deinit
URL
URLSession
FileManager
DocumentDirectory
UserDefaults
NSCoding
NSSecureCoding
plist
Info.plist
Bundle
CFBundleDisplayName
LSRequiresIPhoneOS
UILaunchScreen
UISceneDelegate
AppDelegate
SceneDelegate
JSONDecoder
JSONEncoder
ISO8601DateFormatter
DispatchQueue
alamofire
pointfreeco
EOF
    
    
    log_success "Spell-checking configuration created"
}

# Run spell checking on all relevant files
run_spell_check() {
    log_info "Running spell check on project files..."
    
    local exit_code=0
    local issues_found=0
    
    # Create file list for checking
    local temp_file_list=$(mktemp)
    
    # Find all files to check
    for pattern in "${SOURCE_PATTERNS[@]}"; do
        # Use find with -path to match glob patterns
        case "$pattern" in
            "Sources/**/*.swift")
                find Sources/ -name "*.swift" -type f >> "$temp_file_list" 2>/dev/null || true
                ;;
            "*.md")
                find . -maxdepth 1 -name "*.md" -type f >> "$temp_file_list" 2>/dev/null || true
                ;;
            "scripts/*.sh")
                find scripts/ -name "*.sh" -type f >> "$temp_file_list" 2>/dev/null || true
                ;;
            "docs/*.md")
                find docs/ -name "*.md" -type f >> "$temp_file_list" 2>/dev/null || true
                ;;
            "CLAUDE.md")
                [ -f "CLAUDE.md" ] && echo "CLAUDE.md" >> "$temp_file_list"
                ;;
        esac
    done
    
    # Remove duplicates and ensure files exist
    sort "$temp_file_list" | uniq > "${temp_file_list}.sorted"
    mv "${temp_file_list}.sorted" "$temp_file_list"
    
    # Build skip patterns for codespell
    local skip_args=""
    for pattern in "${SKIP_PATTERNS[@]}"; do
        skip_args="$skip_args --skip=$pattern"
    done
    
    # Run codespell with custom configuration
    local spell_output
    if spell_output=$(codespell \
        --ignore-words="$IGNORE_WORDS" \
        $skip_args \
        --check-filenames \
        --quiet-level=2 \
        $(cat "$temp_file_list" | tr '\n' ' ') 2>&1); then
        
        log_success "No spelling errors found!"
        echo "No spelling errors detected." > "$SPELLING_REPORT"
    else
        issues_found=$(echo "$spell_output" | wc -l | tr -d ' ')
        log_warning "Found $issues_found potential spelling issues"
        
        # Save detailed report
        {
            echo "=== SPELLING CHECK REPORT ==="
            echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
            echo ""
            echo "Issues found: $issues_found"
            echo ""
            echo "$spell_output"
            echo ""
            echo "=== RECOMMENDED ACTIONS ==="
            echo "1. Review each flagged word for accuracy"
            echo "2. Fix actual misspellings in source files"
            echo "3. Add technical terms to ignore-words.txt if correct"
            echo "4. Re-run spell check to verify fixes"
        } > "$SPELLING_REPORT"
        
        # Display summary
        echo "$spell_output" | head -10
        if [ "$issues_found" -gt 10 ]; then
            echo "... and $((issues_found - 10)) more issues"
        fi
        
        exit_code=1
    fi
    
    # Clean up
    rm -f "$temp_file_list"
    
    return $exit_code
}

# Generate spelling summary
generate_summary() {
    log_info "Generating spelling check summary..."
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local summary_file="$SPELLING_DIR/spelling-summary.txt"
    
    # Count files checked
    local swift_files=$(find Sources/ -name "*.swift" | wc -l | tr -d ' ')
    local md_files=$(find . -maxdepth 2 -name "*.md" | wc -l | tr -d ' ')
    local script_files=$(find scripts/ -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')
    local total_files=$((swift_files + md_files + script_files))
    
    # Count ignore word entries
    local ignore_entries=$(grep -v '^#' "$IGNORE_WORDS" | grep -v '^$' | wc -l | tr -d ' ')
    
    # Check if issues were found
    local issues_count=0
    if [ -f "$SPELLING_REPORT" ]; then
        if grep -q "No spelling errors detected" "$SPELLING_REPORT"; then
            issues_count=0
        else
            issues_count=$(grep -c "^[^=].*:.*:" "$SPELLING_REPORT" 2>/dev/null || echo "0")
        fi
    fi
    
    {
        echo "=== SPELL CHECK SUMMARY ==="
        echo "Analysis Timestamp: $timestamp"
        echo ""
        echo "📊 Files Analyzed:"
        echo "  Swift Files: $swift_files"
        echo "  Markdown Files: $md_files"
        echo "  Script Files: $script_files"
        echo "  Total Files: $total_files"
        echo ""
        echo "📖 Ignore Words Status:"
        echo "  Technical Terms Ignored: $ignore_entries"
        echo "  Project-Specific Terms: $(grep -v '^#' "$IGNORE_WORDS" | grep -v '^$' | head -5 | wc -l | tr -d ' ') (showing first 5)"
        echo ""
        echo "🔍 Spelling Analysis:"
        echo "  Issues Found: $issues_count"
        
        if [ "$issues_count" -eq 0 ]; then
            echo "  Status: ✅ All text properly spelled"
        else
            echo "  Status: ⚠️  Issues require review"
        fi
        
        echo ""
        echo "📁 Generated Reports:"
        echo "  📄 Detailed Report: $SPELLING_REPORT"
        echo "  🚫 Ignore List: $IGNORE_WORDS"
        echo ""
        echo "🔧 Configuration:"
        echo "  - Checks Swift source files for user-facing strings"
        echo "  - Validates documentation comments and markdown"
        echo "  - Uses project-specific technical terminology"
        echo "  - Integrates with development workflow"
        
        if [ "$issues_count" -gt 0 ]; then
            echo ""
            echo "📋 Next Steps:"
            echo "  1. Review detailed report: cat $SPELLING_REPORT"
            echo "  2. Fix genuine misspellings in source code"
            echo "  3. Add valid technical terms to ignore-words.txt"
            echo "  4. Re-run spell check to verify fixes"
        fi
    } > "$summary_file"
    
    # Display summary to console
    cat "$summary_file"
    
    log_success "Spelling summary generated at $summary_file"
}

# Main execution
main() {
    log_info "Starting spell check for WorkoutTracker project..."
    
    check_dependencies
    setup_spelling_config
    
    local exit_code=0
    run_spell_check || exit_code=$?
    
    generate_summary
    
    if [ $exit_code -eq 0 ]; then
        log_success "Spell check completed successfully - no issues found!"
    else
        log_warning "Spell check completed with issues found. Review reports for details."
        log_info "Note: Many flagged items may be technical terms that should be added to the dictionary."
    fi
    
    return $exit_code
}

# Run main function
main "$@"