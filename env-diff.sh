#!/bin/bash

# Environment Diff Tool
# Shows differences between environment files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_usage() {
    cat << EOF
Environment Diff Tool

Usage: $0 [OPTIONS] <file1> <file2>

Options:
  -s, --side-by-side    Show side-by-side comparison
  -c, --context <n>     Show n lines of context (default: 3)
  -i, --ignore-case     Ignore case differences
  -w, --ignore-whitespace  Ignore whitespace differences
  -h, --help            Show this help

Examples:
  $0 .env.local .env.server
  $0 --side-by-side .env .env.backup.20231201_120000
  $0 -c 5 .env.local .env.production

EOF
}

# Parse arguments
SIDE_BY_SIDE=false
CONTEXT=3
IGNORE_CASE=false
IGNORE_WHITESPACE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--side-by-side)
            SIDE_BY_SIDE=true
            shift
            ;;
        -c|--context)
            CONTEXT="$2"
            shift 2
            ;;
        -i|--ignore-case)
            IGNORE_CASE=true
            shift
            ;;
        -w|--ignore-whitespace)
            IGNORE_WHITESPACE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
        *)
            if [[ -z "${FILE1:-}" ]]; then
                FILE1="$1"
            elif [[ -z "${FILE2:-}" ]]; then
                FILE2="$1"
            else
                echo "Too many arguments" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate arguments
if [[ -z "${FILE1:-}" ]] || [[ -z "${FILE2:-}" ]]; then
    echo "Error: Two files required" >&2
    show_usage
    exit 1
fi

if [[ ! -f "$FILE1" ]]; then
    echo "Error: File not found: $FILE1" >&2
    exit 1
fi

if [[ ! -f "$FILE2" ]]; then
    echo "Error: File not found: $FILE2" >&2
    exit 1
fi

# Build diff options
DIFF_OPTS=()
[[ "$IGNORE_CASE" == true ]] && DIFF_OPTS+=("-i")
[[ "$IGNORE_WHITESPACE" == true ]] && DIFF_OPTS+=("-w")

if [[ "$SIDE_BY_SIDE" == true ]]; then
    DIFF_OPTS+=("--side-by-side" "--width=120")
else
    DIFF_OPTS+=("-u" "-C" "$CONTEXT")
fi

# Show file headers
echo -e "${BLUE}Comparing:${NC}"
echo -e "  ${GREEN}File 1:${NC} $FILE1"
echo -e "  ${GREEN}File 2:${NC} $FILE2"
echo

# Perform diff
if diff "${DIFF_OPTS[@]}" "$FILE1" "$FILE2"; then
    echo -e "${GREEN}Files are identical${NC}"
else
    echo -e "\n${YELLOW}Legend:${NC}"
    if [[ "$SIDE_BY_SIDE" == true ]]; then
        echo -e "  ${RED}<${NC} Only in $FILE1"
        echo -e "  ${GREEN}>${NC} Only in $FILE2"
        echo -e "  ${YELLOW}|${NC} Different"
    else
        echo -e "  ${RED}-${NC} Removed from $FILE1"
        echo -e "  ${GREEN}+${NC} Added to $FILE2"
    fi
fi