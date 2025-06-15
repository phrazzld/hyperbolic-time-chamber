#!/bin/bash

# =============================================================================
# Documentation Generation Script
# 
# Generates comprehensive API documentation using Swift-DocC and creates
# both local HTML documentation and deployable documentation archives.
# =============================================================================

set -euo pipefail

# Configuration
DOCS_DIR="docs"
DOCC_ARCHIVE_DIR="$DOCS_DIR/archive"
DOCC_HTML_DIR="$DOCS_DIR/html"
PACKAGE_NAME="WorkoutTracker"
SCHEME_NAME="WorkoutTracker"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}📚 $1${NC}"
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

# Check if we have the necessary tools
check_dependencies() {
    log_info "Checking documentation generation dependencies..."
    
    # Check for Xcode command line tools
    if ! command -v swift &> /dev/null; then
        log_error "Swift compiler not found. Please install Xcode command line tools."
        exit 1
    fi
    
    # Check for xcodebuild (needed for DocC generation)
    if ! command -v xcodebuild &> /dev/null; then
        log_error "xcodebuild not found. Please install Xcode."
        exit 1
    fi
    
    # Verify we're in a Swift package directory
    if [ ! -f "Package.swift" ]; then
        log_error "Package.swift not found. Please run from the root of the Swift package."
        exit 1
    fi
    
    log_success "All dependencies available"
}

# Initialize documentation output directory
setup_output_dir() {
    log_info "Setting up documentation output directory..."
    
    # Clean and create docs directory structure
    rm -rf "$DOCS_DIR"
    mkdir -p "$DOCC_ARCHIVE_DIR"
    mkdir -p "$DOCC_HTML_DIR"
    
    # Add to .gitignore if not already present
    if [ -f ".gitignore" ]; then
        if ! grep -q "^${DOCS_DIR}/" .gitignore; then
            echo "${DOCS_DIR}/" >> .gitignore
            log_info "Added ${DOCS_DIR}/ to .gitignore"
        fi
    fi
    
    log_success "Documentation directories created"
}

# Generate documentation using Swift Package Manager symbol graph
generate_swift_package_docs() {
    log_info "Generating symbol graph using Swift Package Manager..."
    
    # Clean any existing build artifacts
    swift package clean >/dev/null 2>&1 || true
    
    # Generate symbol graph (available in Swift 5.9+)
    local symbol_output="$DOCS_DIR/symbol-graph.json"
    
    if swift package dump-symbol-graph \
        --pretty-print \
        --minimum-access-level internal \
        --emit-extension-block-symbols > "$symbol_output" 2>&1; then
        
        # Check if we actually got symbol graph content (not just build output)
        if grep -q '"metadata"' "$symbol_output" 2>/dev/null; then
            log_success "Symbol graph generated successfully"
            return 0
        else
            log_warning "Symbol graph generation produced build output only"
            # Clean up the invalid file
            rm -f "$symbol_output"
            return 1
        fi
    else
        log_warning "Swift Package Manager symbol graph generation failed"
        return 1
    fi
}

# Generate documentation by extracting existing comments
generate_extracted_docs() {
    log_info "Extracting documentation from source comments..."
    
    local docs_content_dir="$DOCC_HTML_DIR"
    mkdir -p "$docs_content_dir"
    
    # Extract documentation from Swift files
    local doc_index="$docs_content_dir/index.html"
    
    # Create HTML documentation from existing comments
    cat > "$doc_index" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WorkoutTracker Documentation</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 40px; }
        .container { max-width: 900px; margin: 0 auto; }
        .header { border-bottom: 2px solid #007AFF; padding-bottom: 20px; margin-bottom: 30px; }
        .module { margin-bottom: 40px; padding: 20px; background: #f8f9fa; border-radius: 8px; }
        .type-header { color: #007AFF; font-size: 1.5em; margin-bottom: 10px; }
        .doc-comment { margin: 15px 0; line-height: 1.6; }
        .code { background: #f1f1f1; padding: 2px 6px; border-radius: 3px; font-family: 'SF Mono', monospace; }
        .example { background: #f8f8f8; padding: 15px; border-left: 4px solid #007AFF; margin: 10px 0; }
        pre { background: #f8f8f8; padding: 15px; border-radius: 6px; overflow-x: auto; }
        .nav { background: #007AFF; color: white; padding: 10px 0; margin: -40px -40px 40px -40px; }
        .nav h1 { margin: 0; padding: 0 40px; font-size: 1.8em; }
        .toc { background: white; border: 1px solid #ddd; border-radius: 6px; padding: 20px; margin-bottom: 30px; }
        .toc ul { list-style-type: none; padding-left: 0; }
        .toc li { margin: 8px 0; }
        .toc a { color: #007AFF; text-decoration: none; }
        .toc a:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <div class="nav">
        <h1>WorkoutTracker API Documentation</h1>
    </div>
    <div class="container">
        <div class="header">
            <p>Comprehensive API documentation for the WorkoutTracker iOS application.</p>
            <p><strong>Architecture:</strong> MVVM Pattern with SwiftUI</p>
        </div>
        
        <div class="toc">
            <h2>Quick Navigation</h2>
            <ul>
                <li><a href="#models">📦 Data Models</a></li>
                <li><a href="#viewmodels">🧠 ViewModels</a></li>
                <li><a href="#views">📱 Views</a></li>
                <li><a href="#services">⚙️ Services</a></li>
            </ul>
        </div>
EOF
    
    # Extract documentation from each Swift file
    local modules=("Models" "ViewModels" "Views" "Services")
    local module_ids=("models" "viewmodels" "views" "services")
    local module_emojis=("📦" "🧠" "📱" "⚙️")
    
    for i in "${!modules[@]}"; do
        local module="${modules[$i]}"
        local module_id="${module_ids[$i]}"
        local emoji="${module_emojis[$i]}"
        
        echo "<div class='module' id='$module_id'>" >> "$doc_index"
        echo "<h2 class='type-header'>$emoji $module</h2>" >> "$doc_index"
        
        # Find Swift files in this module
        local module_path="Sources/WorkoutTracker/$module"
        if [ -d "$module_path" ]; then
            for swift_file in "$module_path"/*.swift; do
                if [ -f "$swift_file" ]; then
                    extract_file_docs "$swift_file" >> "$doc_index"
                fi
            done
        fi
        
        echo "</div>" >> "$doc_index"
    done
    
    # Close HTML
    echo "</div></body></html>" >> "$doc_index"
    
    log_success "HTML documentation generated from source comments"
    return 0
}

# Extract documentation from a single Swift file
extract_file_docs() {
    local file="$1"
    local filename=$(basename "$file" .swift)
    local relative_path=${file#Sources/WorkoutTracker/}
    
    echo "<h3>$filename</h3>"
    echo "<p><code>$relative_path</code></p>"
    
    # Extract triple-slash comments and the line following them
    local in_doc_block=false
    local current_doc=""
    local next_line_is_code=false
    
    while IFS= read -r line; do
        # Check for documentation comment
        if [[ $line =~ ^[[:space:]]*///[[:space:]]*(.*) ]]; then
            local doc_content="${BASH_REMATCH[1]}"
            if [ "$in_doc_block" = false ]; then
                in_doc_block=true
                current_doc="<div class='doc-comment'>"
            fi
            
            # Handle code blocks in documentation
            if [[ $doc_content =~ ^\`\`\` ]]; then
                current_doc+="<pre><code>"
            elif [[ $doc_content =~ \`\`\`$ ]]; then
                current_doc+="</code></pre>"
            else
                # Convert inline code
                doc_content=$(echo "$doc_content" | sed 's/`\([^`]*\)`/<span class="code">\1<\/span>/g')
                current_doc+="$doc_content<br>"
            fi
            next_line_is_code=true
        elif [ "$next_line_is_code" = true ] && [[ $line =~ ^[[:space:]]*(struct|class|enum|func|var|let)[[:space:]] ]]; then
            # This is the code being documented
            local code_line=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/</\&lt;/g' | sed 's/>/\&gt;/g')
            current_doc+="</div><pre><code>$code_line</code></pre>"
            echo "$current_doc"
            in_doc_block=false
            current_doc=""
            next_line_is_code=false
        elif [ "$in_doc_block" = true ] && [[ ! $line =~ ^[[:space:]]*/// ]]; then
            # End of documentation block without code
            current_doc+="</div>"
            echo "$current_doc"
            in_doc_block=false
            current_doc=""
            next_line_is_code=false
        fi
    done < "$file"
    
    # Handle any remaining documentation
    if [ "$in_doc_block" = true ]; then
        current_doc+="</div>"
        echo "$current_doc"
    fi
}

# Convert DocC archive to static HTML
convert_to_html() {
    log_info "Converting DocC archive to static HTML..."
    
    local doccarchive=$(find "$DOCC_ARCHIVE_DIR" -name "*.doccarchive" -type d | head -1)
    
    if [ -n "$doccarchive" ] && [ -d "$doccarchive" ]; then
        # Use docc to convert archive to static HTML
        if command -v docc &> /dev/null; then
            docc process-archive transform-for-static-hosting \
                "$doccarchive" \
                --output-path "$DOCC_HTML_DIR" \
                --hosting-base-path "${PACKAGE_NAME}"
            
            log_success "DocC archive converted to static HTML"
        else
            # Fallback: copy the archive content directly
            log_warning "docc command not available, copying archive contents..."
            cp -R "$doccarchive"/* "$DOCC_HTML_DIR/" 2>/dev/null || true
        fi
        
        return 0
    else
        log_error "No DocC archive found to convert"
        return 1
    fi
}

# Generate summary documentation
generate_summary() {
    log_info "Generating documentation summary..."
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local summary_file="$DOCS_DIR/README.md"
    
    # Count Swift files and extract basic metrics
    local swift_files=$(find Sources/ -name "*.swift" | wc -l | tr -d ' ')
    local documented_structs=$(grep -r "^/// " Sources/ --include="*.swift" | grep -E "(struct|class|enum)" | wc -l | tr -d ' ')
    local total_doc_comments=$(grep -r "^/// " Sources/ --include="*.swift" | wc -l | tr -d ' ')
    
    {
        echo "# WorkoutTracker Documentation"
        echo ""
        echo "Generated: $timestamp"
        echo ""
        echo "## Overview"
        echo ""
        echo "This documentation provides comprehensive API reference for the WorkoutTracker iOS application,"
        echo "a SwiftUI-based workout tracking app with local data persistence and export capabilities."
        echo ""
        echo "## Documentation Stats"
        echo ""
        echo "- **Swift Files**: $swift_files"
        echo "- **Documented Types**: $documented_structs" 
        echo "- **Documentation Comments**: $total_doc_comments"
        echo ""
        echo "## Architecture"
        echo ""
        echo "The app follows MVVM (Model-View-ViewModel) architecture:"
        echo ""
        echo "- **Models**: Data structures (ExerciseEntry, ExerciseSet)"
        echo "- **Views**: SwiftUI user interface components"
        echo "- **ViewModels**: Business logic and state management"
        echo "- **Services**: Data persistence and external integrations"
        echo ""
        echo "## Browse Documentation"
        echo ""
        echo "### Generated Documentation"
        echo ""
        
        # Check what documentation was generated
        if [ -d "$DOCC_HTML_DIR" ] && [ "$(ls -A $DOCC_HTML_DIR 2>/dev/null)" ]; then
            echo "- 📁 **Static HTML**: [Open Documentation](html/index.html)"
        fi
        
        if [ -d "$DOCC_ARCHIVE_DIR" ] && [ "$(ls -A $DOCC_ARCHIVE_DIR 2>/dev/null)" ]; then
            echo "- 📦 **DocC Archive**: Available in \`docs/archive/\` directory"
        fi
        
        echo ""
        echo "### Quick Reference"
        echo ""
        echo "**Core Types:**"
        echo "- \`ExerciseEntry\`: Represents a complete exercise with multiple sets"
        echo "- \`ExerciseSet\`: Individual set data (reps, weight, notes)"
        echo "- \`WorkoutViewModel\`: Central state management and business logic"
        echo "- \`DataStore\`: Local persistence and data export functionality"
        echo ""
        echo "**Key Views:**"
        echo "- \`ContentView\`: Main tab navigation interface"
        echo "- \`HistoryView\`: Browse and manage past workout entries"
        echo "- \`AddEntryView\`: Create new exercise entries with multiple sets"
        echo "- \`ActivityView\`: iOS-specific sharing interface"
        echo ""
        echo "## Development"
        echo ""
        echo "### Generating Documentation Locally"
        echo ""
        echo "\`\`\`bash"
        echo "# Generate all documentation"
        echo "./scripts/generate-docs.sh"
        echo ""
        echo "# Preview documentation (opens browser)"
        echo "swift package --disable-sandbox preview-documentation --target WorkoutTracker"
        echo "\`\`\`"
        echo ""
        echo "### Documentation Standards"
        echo ""
        echo "- Use triple-slash (\`///\`) comments for public APIs"
        echo "- Include usage examples for complex functions"
        echo "- Document all public properties and methods"
        echo "- Explain architectural patterns and design decisions"
        echo ""
        echo "---"
        echo ""
        echo "*Documentation generated using Swift-DocC*"
    } > "$summary_file"
    
    # Display summary to console
    cat "$summary_file"
    
    log_success "Documentation summary generated at $summary_file"
}

# Main execution
main() {
    log_info "Starting documentation generation for $PACKAGE_NAME..."
    
    check_dependencies
    setup_output_dir
    
    # Try symbol graph generation first
    generate_swift_package_docs || log_warning "Symbol graph generation failed"
    
    # Always generate extracted documentation as fallback
    generate_extracted_docs || {
        log_error "Documentation extraction failed"
        exit 1
    }
    
    generate_summary
    
    log_success "Documentation generation completed successfully!"
    log_info "Documentation available in: $DOCS_DIR/"
    
    # Offer to open documentation
    if [ -f "$DOCC_HTML_DIR/index.html" ]; then
        log_info "To view documentation: open $DOCC_HTML_DIR/index.html"
    fi
}

# Run main function
main "$@"