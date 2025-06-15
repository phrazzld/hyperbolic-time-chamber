#!/bin/bash

# @testable Import Validation Script
# Detects @testable import usage in release-compatible contexts

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Validating @testable import usage...${NC}"

# Configuration
RELEASE_COMPATIBLE_DIRS=(
    "Tests/TestConfiguration"
)

# Track violations
VIOLATIONS_FOUND=0
TOTAL_FILES_CHECKED=0

# Function to check a file for @testable import violations
check_file() {
    local file="$1"
    local violations=$(grep -n "@testable\s\+import" "$file" || true)
    
    if [ -n "$violations" ]; then
        echo -e "${RED}❌ @testable import violation in $file:${NC}"
        echo "$violations" | while IFS=: read -r line_num line_content; do
            echo -e "${YELLOW}   Line $line_num:${NC} $line_content"
        done
        echo
        return 1
    fi
    
    return 0
}

# Check each release-compatible directory
for dir in "${RELEASE_COMPATIBLE_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        echo -e "${YELLOW}⚠️  Directory $dir not found - skipping${NC}"
        continue
    fi
    
    echo "📂 Checking directory: $dir"
    
    # Find all Swift files in the directory
    while IFS= read -r -d '' swift_file; do
        TOTAL_FILES_CHECKED=$((TOTAL_FILES_CHECKED + 1))
        
        if ! check_file "$swift_file"; then
            VIOLATIONS_FOUND=$((VIOLATIONS_FOUND + 1))
        fi
    done < <(find "$dir" -name "*.swift" -type f -print0)
done

# Results summary
echo -e "${BLUE}📊 Validation Summary:${NC}"
echo "   - Files checked: $TOTAL_FILES_CHECKED"
echo "   - Violations found: $VIOLATIONS_FOUND"

if [ $VIOLATIONS_FOUND -eq 0 ]; then
    echo -e "${GREEN}✅ No @testable import violations found!${NC}"
    echo
    echo -e "${GREEN}🎉 All test modules are release-build compatible${NC}"
    exit 0
else
    echo -e "${RED}❌ Found $VIOLATIONS_FOUND @testable import violation(s)${NC}"
    echo
    echo -e "${YELLOW}🔧 How to fix @testable import violations:${NC}"
    echo
    echo "1. **Make types public** in the main module:"
    echo "   public struct ExerciseEntry: Identifiable, Codable { ... }"
    echo
    echo "2. **Add public initializers** for test data creation:"
    echo "   public init(exerciseName: String, date: Date, sets: [ExerciseSet]) { ... }"
    echo
    echo "3. **Replace @testable import** with regular import:"
    echo "   - @testable import WorkoutTracker"
    echo "   + import WorkoutTracker"
    echo
    echo "4. **Test release build compatibility:**"
    echo "   swift build -c release && swift test -c release"
    echo
    echo -e "${BLUE}📖 For detailed guidance, see CLAUDE.md Testing Guidelines${NC}"
    echo
    exit 1
fi