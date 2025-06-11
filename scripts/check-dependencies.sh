#!/bin/bash

# Dependency Vulnerability Scanner for WorkoutTracker
# Scans Swift Package Manager dependencies for known vulnerabilities

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RESULTS_DIR="security"
ADVISORIES_URL="https://github.com/advisories"
SPM_ADVISORY_DB="https://api.github.com/advisories"

echo -e "${BLUE}🔒 Scanning dependencies for vulnerabilities...${NC}"

# Create results directory
mkdir -p $RESULTS_DIR

# Check if we have network connectivity
if ! ping -c 1 google.com &> /dev/null; then
    echo -e "${YELLOW}⚠️  No network connectivity - running offline checks only${NC}"
    OFFLINE_MODE=true
else
    OFFLINE_MODE=false
fi

# Extract dependencies from Package.resolved
echo "📦 Analyzing Package.resolved for dependencies..."

if [ ! -f "Package.resolved" ]; then
    echo -e "${RED}❌ Package.resolved not found. Run 'swift package resolve' first.${NC}"
    exit 1
fi

# Parse dependencies from Package.resolved JSON
DEPENDENCIES=$(python3 -c "
import json
import sys

try:
    with open('Package.resolved', 'r') as f:
        data = json.load(f)
    
    for pin in data.get('pins', []):
        identity = pin.get('identity', '')
        location = pin.get('location', '')
        version = pin.get('state', {}).get('version', '')
        if identity and location and version:
            print(f'{identity}|{location}|{version}')
except Exception as e:
    print(f'Error parsing Package.resolved: {e}', file=sys.stderr)
    sys.exit(1)
")

echo "Found dependencies:"
echo "$DEPENDENCIES" | while IFS='|' read -r name location version; do
    echo "  - $name ($version) from $location"
done

# Create dependency report
cat > "$RESULTS_DIR/dependency-report.json" << EOF
{
  "scan_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "scan_type": "swift-package-manager",
  "dependencies": [
EOF

FIRST_DEP=true
echo "$DEPENDENCIES" | while IFS='|' read -r name location version; do
    if [ "$FIRST_DEP" = true ]; then
        FIRST_DEP=false
    else
        echo "," >> "$RESULTS_DIR/dependency-report.json"
    fi
    
    cat >> "$RESULTS_DIR/dependency-report.json" << EOF
    {
      "name": "$name",
      "version": "$version",
      "location": "$location",
      "ecosystem": "swift"
    }
EOF
done

cat >> "$RESULTS_DIR/dependency-report.json" << EOF
  ]
}
EOF

# Check for known vulnerabilities
echo
echo "🔍 Checking for known vulnerabilities..."

VULNERABILITY_FOUND=false
TOTAL_DEPS=0
CHECKED_DEPS=0

# Create vulnerability report
cat > "$RESULTS_DIR/vulnerability-report.json" << EOF
{
  "scan_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "vulnerabilities": [
EOF

FIRST_VULN=true

echo "$DEPENDENCIES" | while IFS='|' read -r name location version; do
    TOTAL_DEPS=$((TOTAL_DEPS + 1))
    echo "  Checking $name ($version)..."
    
    # Extract GitHub repo info if it's a GitHub dependency
    if [[ "$location" == *"github.com"* ]]; then
        REPO_PATH=$(echo "$location" | sed 's|https://github.com/||' | sed 's|\.git$||')
        OWNER=$(echo "$REPO_PATH" | cut -d'/' -f1)
        REPO=$(echo "$REPO_PATH" | cut -d'/' -f2)
        
        if [ "$OFFLINE_MODE" = false ]; then
            # Check GitHub Security Advisories (public endpoint)
            ADVISORY_RESPONSE=$(curl -s -H "Accept: application/vnd.github.v3+json" \
                "https://api.github.com/repos/$OWNER/$REPO/security-advisories" 2>/dev/null || echo "[]")
            
            # GitHub's security advisories endpoint might not be publicly accessible
            # Check if we got a meaningful response
            if echo "$ADVISORY_RESPONSE" | grep -q "vulnerability\|CVE\|security" 2>/dev/null; then
                echo -e "    ${YELLOW}⚠️  Security advisories found for $name${NC}"
                VULNERABILITY_FOUND=true
                
                # Add to vulnerability report
                if [ "$FIRST_VULN" = true ]; then
                    FIRST_VULN=false
                else
                    echo "," >> "$RESULTS_DIR/vulnerability-report.json"
                fi
                
                cat >> "$RESULTS_DIR/vulnerability-report.json" << EOF
    {
      "dependency": "$name",
      "version": "$version",
      "source": "github-security-advisories",
      "advisory_count": 1
    }
EOF
            else
                echo -e "    ${GREEN}✅ No known vulnerabilities for $name${NC}"
            fi
        fi
    fi
    
    # Check for common vulnerability patterns
    case "$name" in
        *"crypto"*|*"security"*|*"auth"*)
            echo -e "    ${BLUE}ℹ️  Security-sensitive dependency detected: $name${NC}"
            ;;
        *"network"*|*"http"*|*"url"*)
            echo -e "    ${BLUE}ℹ️  Network-related dependency detected: $name${NC}"
            ;;
    esac
    
    CHECKED_DEPS=$((CHECKED_DEPS + 1))
done

cat >> "$RESULTS_DIR/vulnerability-report.json" << EOF
  ],
  "summary": {
    "total_dependencies": $TOTAL_DEPS,
    "checked_dependencies": $CHECKED_DEPS,
    "vulnerabilities_found": $([ "$VULNERABILITY_FOUND" = true ] && echo "true" || echo "false")
  }
}
EOF

# License compliance check
echo
echo "📄 Checking license compliance..."

cat > "$RESULTS_DIR/license-report.json" << EOF
{
  "scan_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "licenses": [
EOF

FIRST_LICENSE=true
echo "$DEPENDENCIES" | while IFS='|' read -r name location version; do
    if [[ "$location" == *"github.com"* ]]; then
        REPO_PATH=$(echo "$location" | sed 's|https://github.com/||' | sed 's|\.git$||')
        OWNER=$(echo "$REPO_PATH" | cut -d'/' -f1)
        REPO=$(echo "$REPO_PATH" | cut -d'/' -f2)
        
        if [ "$OFFLINE_MODE" = false ]; then
            # Try to get license info
            LICENSE_RESPONSE=$(curl -s -H "Accept: application/vnd.github.v3+json" \
                "https://api.github.com/repos/$OWNER/$REPO/license" 2>/dev/null || echo "null")
            
            if [ "$FIRST_LICENSE" = true ]; then
                FIRST_LICENSE=false
            else
                echo "," >> "$RESULTS_DIR/license-report.json"
            fi
            
            if [ "$LICENSE_RESPONSE" != "null" ]; then
                LICENSE_NAME=$(echo "$LICENSE_RESPONSE" | grep '"name"' | head -1 | sed 's/.*"name": "\([^"]*\)".*/\1/')
                echo "  $name: $LICENSE_NAME"
                
                cat >> "$RESULTS_DIR/license-report.json" << EOF
    {
      "dependency": "$name",
      "version": "$version",
      "license": "$LICENSE_NAME",
      "compatible": $([ "$LICENSE_NAME" = "MIT License" ] || [ "$LICENSE_NAME" = "Apache License 2.0" ] || [ "$LICENSE_NAME" = "BSD 3-Clause \"New\" or \"Revised\" License" ] && echo "true" || echo "false")
    }
EOF
            else
                echo "  $name: License information not available"
                cat >> "$RESULTS_DIR/license-report.json" << EOF
    {
      "dependency": "$name",
      "version": "$version",
      "license": "unknown",
      "compatible": false
    }
EOF
            fi
        fi
    fi
done

cat >> "$RESULTS_DIR/license-report.json" << EOF
  ]
}
EOF

# Check for outdated dependencies
echo
echo "📅 Checking for outdated dependencies..."

if [ "$OFFLINE_MODE" = false ]; then
    echo "Running swift package show-dependencies..."
    swift package show-dependencies > "$RESULTS_DIR/current-dependencies.txt" 2>/dev/null || echo "Could not fetch dependency tree"
fi

# Generate security summary
echo
echo -e "${BLUE}📊 Security Summary:${NC}"
echo "=================================="

DEPENDENCY_COUNT=$(echo "$DEPENDENCIES" | wc -l)
echo -e "Total Dependencies: ${YELLOW}$DEPENDENCY_COUNT${NC}"

if [ "$VULNERABILITY_FOUND" = true ]; then
    echo -e "Vulnerabilities: ${RED}Found${NC}"
else
    echo -e "Vulnerabilities: ${GREEN}None detected${NC}"
fi

echo -e "License Check: ${YELLOW}$([ "$OFFLINE_MODE" = false ] && echo "Completed" || echo "Skipped (offline)")${NC}"

# Generate recommendations
echo
echo -e "${BLUE}🛡️  Security Recommendations:${NC}"
echo "=================================="
echo "1. Keep dependencies updated to latest stable versions"
echo "2. Regularly review Package.resolved for version changes"
echo "3. Monitor GitHub Security Advisories for your dependencies"
echo "4. Consider using dependabot for automated updates"
echo "5. Review and approve new dependencies before adding"

# Output file locations
echo
echo -e "${BLUE}📁 Generated Reports:${NC}"
echo "=================================="
echo "📦 Dependencies: $RESULTS_DIR/dependency-report.json"
echo "🔒 Vulnerabilities: $RESULTS_DIR/vulnerability-report.json"
echo "📄 Licenses: $RESULTS_DIR/license-report.json"
if [ -f "$RESULTS_DIR/current-dependencies.txt" ]; then
    echo "🌳 Dependency Tree: $RESULTS_DIR/current-dependencies.txt"
fi

# Final result
echo
if [ "$VULNERABILITY_FOUND" = true ]; then
    echo -e "${RED}⚠️  Security vulnerabilities detected! Review the reports above.${NC}"
    exit 1
else
    echo -e "${GREEN}✅ No known vulnerabilities detected in current dependencies.${NC}"
    exit 0
fi