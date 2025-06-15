#!/bin/bash

# Cross-Platform Utility Functions
# Provides unified interfaces for platform-specific operations
# Source this file from other scripts: source "$(dirname "$0")/platform-utils.sh"

set -e

# Colors for output (using portable ANSI escape codes)
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Platform detection
detect_platform() {
    case "$OSTYPE" in
        darwin*)
            echo "macos"
            ;;
        linux*)
            echo "linux"
            ;;
        msys*|cygwin*)
            echo "windows"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Cross-platform package installation
install_package() {
    local package="$1"
    local platform=$(detect_platform)
    
    if command -v "$package" >/dev/null 2>&1; then
        return 0  # Already installed
    fi
    
    echo -e "${BLUE}Installing $package...${NC}"
    
    case "$platform" in
        macos)
            if command -v brew >/dev/null 2>&1; then
                brew install "$package"
            else
                echo -e "${RED}Error: Homebrew not found. Please install $package manually.${NC}" >&2
                return 1
            fi
            ;;
        linux)
            if command -v apt-get >/dev/null 2>&1; then
                sudo apt-get update && sudo apt-get install -y "$package"
            elif command -v yum >/dev/null 2>&1; then
                sudo yum install -y "$package"
            elif command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y "$package"
            elif command -v pacman >/dev/null 2>&1; then
                sudo pacman -S --noconfirm "$package"
            else
                echo -e "${RED}Error: No supported package manager found. Please install $package manually.${NC}" >&2
                return 1
            fi
            ;;
        *)
            echo -e "${RED}Error: Unsupported platform. Please install $package manually.${NC}" >&2
            return 1
            ;;
    esac
}

# Cross-platform file hashing
hash_file() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}Error: File '$file' not found${NC}" >&2
        return 1
    fi
    
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | cut -d' ' -f1
    else
        echo -e "${RED}Error: No hash command available (sha256sum or shasum)${NC}" >&2
        return 1
    fi
}

# Cross-platform hash generation for multiple files
hash_files() {
    local temp_file=$(mktemp)
    local exit_code=0
    
    for file in "$@"; do
        if [[ -f "$file" ]]; then
            hash_file "$file" >> "$temp_file" || exit_code=1
        else
            echo -e "${YELLOW}Warning: Skipping missing file '$file'${NC}" >&2
        fi
    done
    
    if [[ $exit_code -eq 0 ]] && [[ -s "$temp_file" ]]; then
        if command -v sha256sum >/dev/null 2>&1; then
            sha256sum "$temp_file" | cut -d' ' -f1
        elif command -v shasum >/dev/null 2>&1; then
            shasum -a 256 "$temp_file" | cut -d' ' -f1
        else
            echo -e "${RED}Error: No hash command available${NC}" >&2
            exit_code=1
        fi
    else
        echo "fallback-$(date +%s)"
    fi
    
    rm -f "$temp_file"
    return $exit_code
}

# Cross-platform directory hashing (for cache keys)
hash_directory() {
    local dir="$1"
    local pattern="${2:-*.swift}"
    
    if [[ ! -d "$dir" ]]; then
        echo -e "${RED}Error: Directory '$dir' not found${NC}" >&2
        return 1
    fi
    
    local files=()
    while IFS= read -r -d '' file; do
        files+=("$file")
    done < <(find "$dir" -name "$pattern" -type f -print0 2>/dev/null | sort -z)
    
    if [[ ${#files[@]} -eq 0 ]]; then
        echo "empty-$(date +%s)"
        return 0
    fi
    
    hash_files "${files[@]}"
}

# Cross-platform timeout execution
run_with_timeout() {
    local timeout_seconds="$1"
    shift
    
    if command -v timeout >/dev/null 2>&1; then
        timeout "${timeout_seconds}s" "$@"
    elif command -v gtimeout >/dev/null 2>&1; then
        gtimeout "${timeout_seconds}s" "$@"
    else
        echo -e "${YELLOW}Warning: No timeout command available, running without timeout${NC}" >&2
        "$@"
    fi
}

# Cross-platform date parsing (ISO 8601)
parse_iso_date() {
    local timestamp="$1"
    
    # Try Python first (most reliable)
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import datetime
import sys
try:
    # Handle both 'Z' and timezone offset formats
    ts = '$timestamp'.replace('Z', '+00:00')
    dt = datetime.datetime.fromisoformat(ts)
    print(int(dt.timestamp()))
except Exception as e:
    sys.exit(1)
" 2>/dev/null && return 0
    fi
    
    # Fallback to platform-specific date commands
    if command -v gdate >/dev/null 2>&1; then
        # GNU date (if available via coreutils on macOS)
        gdate -d "$timestamp" +%s 2>/dev/null
    elif [[ "$(detect_platform)" == "macos" ]]; then
        # BSD date (macOS)
        date -j -f "%Y-%m-%dT%H:%M:%SZ" "$timestamp" +%s 2>/dev/null
    else
        # GNU date (Linux)
        date -d "$timestamp" +%s 2>/dev/null
    fi
}

# Cross-platform memory usage (returns MB)
get_memory_usage_mb() {
    local platform=$(detect_platform)
    
    case "$platform" in
        macos)
            if command -v vm_stat >/dev/null 2>&1; then
                local vm_stat_output=$(vm_stat 2>/dev/null)
                local page_size=$(vm_stat | grep "page size of" | grep -o '[0-9]*' || echo "4096")
                
                local free_pages=$(echo "$vm_stat_output" | grep "Pages free:" | grep -o '[0-9]*' || echo "0")
                local inactive_pages=$(echo "$vm_stat_output" | grep "Pages inactive:" | grep -o '[0-9]*' || echo "0")
                local total_pages=$(echo "$vm_stat_output" | grep "Pages active:" | grep -o '[0-9]*' || echo "0")
                
                local available_bytes=$((($free_pages + $inactive_pages) * $page_size))
                local available_mb=$((available_bytes / 1024 / 1024))
                
                echo "$available_mb"
            else
                echo "0"
            fi
            ;;
        linux)
            if [[ -f /proc/meminfo ]]; then
                local available_kb=$(grep "MemAvailable:" /proc/meminfo | awk '{print $2}' 2>/dev/null || echo "0")
                local available_mb=$((available_kb / 1024))
                echo "$available_mb"
            else
                echo "0"
            fi
            ;;
        *)
            echo "0"
            ;;
    esac
}

# Cross-platform base64 encoding
encode_base64() {
    local input="$1"
    local platform=$(detect_platform)
    
    if [[ -f "$input" ]]; then
        # Encode file (cross-platform compatible)
        base64 < "$input"
    else
        # Encode string
        echo "$input" | base64
    fi
}

# Cross-platform base64 decoding
decode_base64() {
    local input="$1"
    local platform=$(detect_platform)
    
    case "$platform" in
        macos)
            echo "$input" | base64 -D
            ;;
        *)
            echo "$input" | base64 -d
            ;;
    esac
}

# Standardized ISO 8601 timestamp
iso_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Cross-platform temporary file creation
create_temp_file() {
    local prefix="${1:-tmp}"
    
    if command -v mktemp >/dev/null 2>&1; then
        mktemp -t "${prefix}.XXXXXX"
    else
        # Fallback for systems without mktemp
        local temp_file="/tmp/${prefix}.$$.$RANDOM"
        touch "$temp_file"
        echo "$temp_file"
    fi
}

# Cross-platform temporary directory creation
create_temp_dir() {
    local prefix="${1:-tmp}"
    
    if command -v mktemp >/dev/null 2>&1; then
        mktemp -d -t "${prefix}.XXXXXX"
    else
        # Fallback for systems without mktemp
        local temp_dir="/tmp/${prefix}.$$.$RANDOM"
        mkdir -p "$temp_dir"
        echo "$temp_dir"
    fi
}

# Check if running in CI environment
is_ci() {
    [[ -n "$CI" ]] || [[ -n "$GITHUB_ACTIONS" ]] || [[ -n "$TRAVIS" ]] || [[ -n "$JENKINS_URL" ]] || [[ -n "$BUILDKITE" ]]
}

# Platform information for debugging
platform_info() {
    echo "Platform Information:"
    echo "  OS Type: $OSTYPE"
    echo "  Platform: $(detect_platform)"
    echo "  Architecture: $(uname -m)"
    echo "  Kernel: $(uname -s) $(uname -r)"
    echo "  CI Environment: $(is_ci && echo "Yes" || echo "No")"
    echo ""
    echo "Available Commands:"
    local commands=("sha256sum" "shasum" "timeout" "gtimeout" "gdate" "python3" "brew" "apt-get" "yum")
    for cmd in "${commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            echo "  ✅ $cmd: $(command -v "$cmd")"
        else
            echo "  ❌ $cmd: not found"
        fi
    done
}

# Validation function to ensure utilities work correctly
validate_platform_utils() {
    echo -e "${BLUE}Validating platform utilities...${NC}"
    
    local test_file=$(create_temp_file "platform-test")
    echo "test content" > "$test_file"
    
    # Test hash functions
    local hash_result=$(hash_file "$test_file")
    if [[ -n "$hash_result" ]] && [[ "$hash_result" != "fallback-"* ]]; then
        echo -e "${GREEN}✅ File hashing works${NC}"
    else
        echo -e "${RED}❌ File hashing failed${NC}"
    fi
    
    # Test timestamp
    local timestamp=$(iso_timestamp)
    if [[ "$timestamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
        echo -e "${GREEN}✅ ISO timestamp works${NC}"
    else
        echo -e "${RED}❌ ISO timestamp failed: $timestamp${NC}"
    fi
    
    # Test memory usage
    local memory=$(get_memory_usage_mb)
    if [[ "$memory" =~ ^[0-9]+$ ]] && [[ "$memory" -gt 0 ]]; then
        echo -e "${GREEN}✅ Memory monitoring works: ${memory}MB${NC}"
    else
        echo -e "${YELLOW}⚠️  Memory monitoring returned: $memory${NC}"
    fi
    
    # Test platform detection
    local platform=$(detect_platform)
    echo -e "${GREEN}✅ Platform detection: $platform${NC}"
    
    # Clean up
    rm -f "$test_file"
    
    echo -e "${BLUE}Platform utilities validation complete${NC}"
}

# Enhanced Error Handling Functions

# Check if a command exists and provide helpful error messages
require_command() {
    local cmd="$1"
    local description="${2:-$cmd}"
    local install_hint="${3:-}"
    
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${RED}❌ Error: '$cmd' command not found${NC}" >&2
        echo -e "${YELLOW}💡 '$description' is required but not available on this system${NC}" >&2
        
        if [[ -n "$install_hint" ]]; then
            echo -e "${BLUE}🔧 Installation suggestion: $install_hint${NC}" >&2
        else
            suggest_installation "$cmd"
        fi
        
        return 1
    fi
    return 0
}

# Suggest installation commands for common tools
suggest_installation() {
    local cmd="$1"
    local platform=$(detect_platform)
    
    case "$cmd" in
        jq)
            case "$platform" in
                macos) echo -e "${BLUE}🔧 Install with: brew install jq${NC}" >&2 ;;
                linux) echo -e "${BLUE}🔧 Install with: sudo apt-get install jq (Ubuntu/Debian) or sudo yum install jq (RHEL/CentOS)${NC}" >&2 ;;
            esac
            ;;
        python3)
            case "$platform" in
                macos) echo -e "${BLUE}🔧 Install with: brew install python3 or download from python.org${NC}" >&2 ;;
                linux) echo -e "${BLUE}🔧 Install with: sudo apt-get install python3 (Ubuntu/Debian) or sudo yum install python3 (RHEL/CentOS)${NC}" >&2 ;;
            esac
            ;;
        swift)
            echo -e "${BLUE}🔧 Install Swift from: https://swift.org/download/${NC}" >&2
            ;;
        git)
            case "$platform" in
                macos) echo -e "${BLUE}🔧 Install with: brew install git or install Xcode Command Line Tools${NC}" >&2 ;;
                linux) echo -e "${BLUE}🔧 Install with: sudo apt-get install git (Ubuntu/Debian) or sudo yum install git (RHEL/CentOS)${NC}" >&2 ;;
            esac
            ;;
        timeout|gtimeout)
            case "$platform" in
                macos) echo -e "${BLUE}🔧 Install with: brew install coreutils (provides gtimeout)${NC}" >&2 ;;
                linux) echo -e "${BLUE}🔧 Usually available by default. Try: sudo apt-get install coreutils${NC}" >&2 ;;
            esac
            ;;
        *)
            echo -e "${BLUE}🔧 Please install '$cmd' using your system's package manager${NC}" >&2
            ;;
    esac
}

# Run a command with enhanced error handling and fallbacks
safe_run() {
    local cmd="$1"
    local description="${2:-command}"
    local fallback_cmd="${3:-}"
    
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}🔧 Running: $cmd${NC}" >&2
    fi
    
    local exit_code
    eval "$cmd"
    exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        echo -e "${RED}❌ Error: $description failed with exit code $exit_code${NC}" >&2
        
        if [[ -n "$fallback_cmd" ]]; then
            echo -e "${YELLOW}🔄 Trying fallback: $fallback_cmd${NC}" >&2
            eval "$fallback_cmd"
            exit_code=$?
            
            if [[ $exit_code -eq 0 ]]; then
                echo -e "${GREEN}✅ Fallback succeeded${NC}" >&2
            else
                echo -e "${RED}❌ Fallback also failed with exit code $exit_code${NC}" >&2
            fi
        fi
    fi
    
    return $exit_code
}

# Enhanced error reporting with context
error_with_context() {
    local error_msg="$1"
    local context="${2:-}"
    local suggestions="${3:-}"
    
    echo -e "${RED}❌ Error: $error_msg${NC}" >&2
    
    if [[ -n "$context" ]]; then
        echo -e "${YELLOW}📍 Context: $context${NC}" >&2
    fi
    
    if [[ -n "$suggestions" ]]; then
        echo -e "${BLUE}💡 Suggestions:${NC}" >&2
        echo "$suggestions" | while IFS= read -r suggestion; do
            if [[ -n "$suggestion" ]]; then
                echo -e "${BLUE}   - $suggestion${NC}" >&2
            fi
        done
    fi
}

# Check system requirements for CI operations
check_ci_requirements() {
    local missing_tools=()
    local warnings=()
    
    echo -e "${BLUE}🔍 Checking CI system requirements...${NC}"
    
    # Essential tools
    local essential_tools=("swift" "git" "jq")
    for tool in "${essential_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    # Recommended tools (warnings only)
    local recommended_tools=("python3" "bc")
    for tool in "${recommended_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            warnings+=("$tool")
        fi
    done
    
    # Report results
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo -e "${RED}❌ Missing essential tools: ${missing_tools[*]}${NC}" >&2
        echo -e "${YELLOW}💡 CI operations may fail without these tools${NC}" >&2
        
        for tool in "${missing_tools[@]}"; do
            suggest_installation "$tool"
        done
        
        return 1
    fi
    
    if [[ ${#warnings[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  Missing recommended tools: ${warnings[*]}${NC}" >&2
        echo -e "${BLUE}💡 Some features may have limited functionality${NC}" >&2
    fi
    
    echo -e "${GREEN}✅ Essential CI requirements satisfied${NC}"
    return 0
}

# Validate file operations with helpful errors
validate_file_operation() {
    local operation="$1"
    local file_path="$2"
    local context="${3:-file operation}"
    
    case "$operation" in
        read)
            if [[ ! -f "$file_path" ]]; then
                error_with_context "File not found: $file_path" "$context" \
                    "Check if the file path is correct
Ensure the file was created by a previous step
Verify file permissions allow reading"
                return 1
            elif [[ ! -r "$file_path" ]]; then
                error_with_context "File not readable: $file_path" "$context" \
                    "Check file permissions: ls -la $file_path
Fix permissions: chmod +r $file_path"
                return 1
            fi
            ;;
        write)
            local dir_path=$(dirname "$file_path")
            if [[ ! -d "$dir_path" ]]; then
                error_with_context "Directory not found: $dir_path" "$context" \
                    "Create directory: mkdir -p $dir_path
Check if the path is correct"
                return 1
            elif [[ ! -w "$dir_path" ]]; then
                error_with_context "Directory not writable: $dir_path" "$context" \
                    "Check directory permissions: ls -la $dir_path
Fix permissions: chmod +w $dir_path"
                return 1
            fi
            ;;
        execute)
            if [[ ! -f "$file_path" ]]; then
                error_with_context "Executable not found: $file_path" "$context"
                return 1
            elif [[ ! -x "$file_path" ]]; then
                error_with_context "File not executable: $file_path" "$context" \
                    "Fix permissions: chmod +x $file_path"
                return 1
            fi
            ;;
    esac
    
    return 0
}

# Export new error handling functions
export -f require_command suggest_installation safe_run error_with_context
export -f check_ci_requirements validate_file_operation

# Export all functions for use in other scripts
export -f detect_platform install_package hash_file hash_files hash_directory
export -f run_with_timeout parse_iso_date get_memory_usage_mb encode_base64 decode_base64
export -f iso_timestamp create_temp_file create_temp_dir is_ci platform_info validate_platform_utils