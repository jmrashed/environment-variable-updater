#!/bin/bash

# Environment Variable Updater v2.0
# Enhanced version with comprehensive features

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.json"
LOG_FILE="${SCRIPT_DIR}/update-env.log"
BACKUP_DIR="${SCRIPT_DIR}/backups"
VERSION="2.0.0"

# Default configuration
DEFAULT_ENVIRONMENTS=("local" "server")
VERBOSE=false
DRY_RUN=false
PRESERVE_COMMENTS=true
ENCRYPT_SENSITIVE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    if [[ "$VERBOSE" == true ]] || [[ "$level" == "ERROR" ]]; then
        case "$level" in
            "ERROR") echo -e "${RED}[ERROR]${NC} $message" >&2 ;;
            "WARN")  echo -e "${YELLOW}[WARN]${NC} $message" ;;
            "INFO")  echo -e "${GREEN}[INFO]${NC} $message" ;;
            "DEBUG") echo -e "${BLUE}[DEBUG]${NC} $message" ;;
        esac
    fi
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    exit "${2:-1}"
}

# Show usage
show_usage() {
    cat << EOF
Environment Variable Updater v$VERSION

Usage: $0 [OPTIONS] <environment>

Arguments:
  environment    Environment to use (local, server, or custom name)

Options:
  -d, --dry-run           Preview changes without applying them
  -v, --verbose           Enable verbose output
  -b, --backup-only       Create backup without updating
  -r, --rollback [file]   Rollback to previous backup or specific file
  -c, --config <file>     Use custom configuration file
  -f, --format <format>   Input format (env, json, yaml)
  -o, --output <file>     Output file (default: .env)
  -e, --encrypt           Encrypt sensitive variables
  -h, --help              Show this help message
  --version               Show version information
  --diff                  Show differences before applying
  --batch <dir>           Process multiple directories

Examples:
  $0 local                    # Update from .env.local
  $0 --dry-run server         # Preview server changes
  $0 --rollback               # Rollback to last backup
  $0 --diff local             # Show differences
  $0 --batch /path/to/projects # Update multiple projects

EOF
}

# Validate environment file format
validate_env_file() {
    local file="$1"
    local line_num=0
    local errors=0
    
    log "DEBUG" "Validating file: $file"
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_num++))
        
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Check key=value format
        if ! [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
            log "WARN" "Invalid format at line $line_num: $line"
            ((errors++))
        fi
    done < "$file"
    
    if [[ $errors -gt 0 ]]; then
        log "ERROR" "Found $errors validation errors in $file"
        return 1
    fi
    
    log "INFO" "File validation passed: $file"
    return 0
}

# Escape special characters in values
escape_value() {
    local value="$1"
    # Handle quotes and special characters
    if [[ "$value" =~ [[:space:]\$\`\\] ]]; then
        echo "\"$(echo "$value" | sed 's/"/\\"/g')\""
    else
        echo "$value"
    fi
}

# Create backup
create_backup() {
    local source_file="$1"
    local backup_name="${2:-$(date '+%Y%m%d_%H%M%S')}"
    
    [[ ! -d "$BACKUP_DIR" ]] && mkdir -p "$BACKUP_DIR"
    
    if [[ -f "$source_file" ]]; then
        local backup_file="${BACKUP_DIR}/.env.backup.${backup_name}"
        cp "$source_file" "$backup_file"
        log "INFO" "Backup created: $backup_file"
        echo "$backup_file"
    else
        log "WARN" "Source file not found for backup: $source_file"
        return 1
    fi
}

# Rollback functionality
rollback() {
    local backup_file="$1"
    local target_file="${2:-.env}"
    
    if [[ -z "$backup_file" ]]; then
        # Find latest backup
        backup_file=$(ls -t "${BACKUP_DIR}"/.env.backup.* 2>/dev/null | head -n1)
        [[ -z "$backup_file" ]] && error_exit "No backup files found"
    fi
    
    [[ ! -f "$backup_file" ]] && error_exit "Backup file not found: $backup_file"
    
    if [[ "$DRY_RUN" == true ]]; then
        log "INFO" "DRY RUN: Would rollback from $backup_file to $target_file"
        return 0
    fi
    
    cp "$backup_file" "$target_file"
    log "INFO" "Rollback completed from $backup_file"
}

# Show differences
show_diff() {
    local source_file="$1"
    local target_file="$2"
    
    if [[ -f "$target_file" ]]; then
        echo -e "${BLUE}Differences between current .env and $source_file:${NC}"
        diff -u "$target_file" "$source_file" || true
    else
        echo -e "${BLUE}Target file doesn't exist. All variables from $source_file will be added.${NC}"
        cat "$source_file"
    fi
}

# Process environment file
process_env_file() {
    local source_file="$1"
    local target_file="$2"
    local temp_file="${target_file}.tmp"
    
    # Validate source file
    validate_env_file "$source_file" || error_exit "Source file validation failed"
    
    # Create backup
    [[ -f "$target_file" ]] && create_backup "$target_file"
    
    # Initialize temp file
    [[ -f "$target_file" ]] && cp "$target_file" "$temp_file" || touch "$temp_file"
    
    local updated=0
    local added=0
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments (unless preserving comments)
        if [[ -z "$line" ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
            [[ "$PRESERVE_COMMENTS" == true ]] && echo "$line" >> "${temp_file}.new"
            continue
        fi
        
        # Extract key and value
        local key="${line%%=*}"
        local value="${line#*=}"
        
        # Remove quotes from value for processing
        value=$(echo "$value" | sed 's/^"\(.*\)"$/\1/')
        
        # Escape value
        value=$(escape_value "$value")
        
        if grep -q "^${key}=" "$temp_file" 2>/dev/null; then
            # Update existing variable
            if [[ "$DRY_RUN" == true ]]; then
                log "INFO" "DRY RUN: Would update $key"
            else
                sed -i "s/^${key}=.*/${key}=${value}/" "$temp_file"
                log "DEBUG" "Updated: $key"
                ((updated++))
            fi
        else
            # Add new variable
            if [[ "$DRY_RUN" == true ]]; then
                log "INFO" "DRY RUN: Would add $key=$value"
            else
                echo "${key}=${value}" >> "$temp_file"
                log "DEBUG" "Added: $key"
                ((added++))
            fi
        fi
    done < "$source_file"
    
    if [[ "$DRY_RUN" == false ]]; then
        mv "$temp_file" "$target_file"
        log "INFO" "Environment updated: $updated variables updated, $added variables added"
    else
        rm -f "$temp_file"
        log "INFO" "DRY RUN: Would update $updated variables and add $added variables"
    fi
}

# Batch processing
batch_process() {
    local base_dir="$1"
    local environment="$2"
    
    log "INFO" "Starting batch processing in: $base_dir"
    
    find "$base_dir" -name "environment-variable-updater" -type d | while read -r dir; do
        local project_dir="$(dirname "$dir")"
        log "INFO" "Processing project: $project_dir"
        
        cd "$project_dir"
        if [[ -f "environment-variable-updater/.env.$environment" ]]; then
            process_env_file "environment-variable-updater/.env.$environment" ".env"
        else
            log "WARN" "Environment file not found: $project_dir/environment-variable-updater/.env.$environment"
        fi
    done
}

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log "DEBUG" "Loading configuration from: $CONFIG_FILE"
        # Simple JSON parsing for basic config
        if command -v jq >/dev/null 2>&1; then
            PRESERVE_COMMENTS=$(jq -r '.preserve_comments // true' "$CONFIG_FILE")
            VERBOSE=$(jq -r '.verbose // false' "$CONFIG_FILE")
        fi
    fi
}

# Main function
main() {
    local environment=""
    local target_file=".env"
    local show_diff=false
    local backup_only=false
    local rollback_file=""
    local batch_dir=""
    local input_format="env"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -b|--backup-only)
                backup_only=true
                shift
                ;;
            -r|--rollback)
                rollback_file="${2:-}"
                [[ -n "$2" && ! "$2" =~ ^- ]] && shift
                shift
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -f|--format)
                input_format="$2"
                shift 2
                ;;
            -o|--output)
                target_file="$2"
                shift 2
                ;;
            -e|--encrypt)
                ENCRYPT_SENSITIVE=true
                shift
                ;;
            --diff)
                show_diff=true
                shift
                ;;
            --batch)
                batch_dir="$2"
                shift 2
                ;;
            --version)
                echo "Environment Variable Updater v$VERSION"
                exit 0
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                error_exit "Unknown option: $1"
                ;;
            *)
                environment="$1"
                shift
                ;;
        esac
    done
    
    # Load configuration
    load_config
    
    # Initialize logging
    log "INFO" "Environment Variable Updater v$VERSION started"
    
    # Handle rollback
    if [[ -n "$rollback_file" || "$1" == "--rollback" ]]; then
        rollback "$rollback_file" "$target_file"
        exit 0
    fi
    
    # Handle batch processing
    if [[ -n "$batch_dir" ]]; then
        [[ -z "$environment" ]] && error_exit "Environment required for batch processing"
        batch_process "$batch_dir" "$environment"
        exit 0
    fi
    
    # Validate environment argument
    [[ -z "$environment" ]] && error_exit "Environment argument required. Use --help for usage."
    
    # Determine source file
    local source_file="${SCRIPT_DIR}/.env.${environment}"
    [[ ! -f "$source_file" ]] && error_exit "Source file not found: $source_file"
    
    # Handle backup only
    if [[ "$backup_only" == true ]]; then
        create_backup "$target_file"
        exit 0
    fi
    
    # Show differences if requested
    if [[ "$show_diff" == true ]]; then
        show_diff "$source_file" "$target_file"
        echo
        read -p "Continue with update? (y/N): " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
    fi
    
    # Process the environment file
    process_env_file "$source_file" "$target_file"
    
    log "INFO" "Environment Variable Updater completed successfully"
}

# Run main function with all arguments
main "$@"