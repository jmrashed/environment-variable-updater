#!/bin/bash

# Environment Variable Encryption Tool
# Encrypts/decrypts sensitive environment variables

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.json"

# Default sensitive keys
SENSITIVE_KEYS=("PASSWORD" "SECRET" "KEY" "TOKEN" "API_KEY" "PRIVATE" "CREDENTIAL")

show_usage() {
    cat << EOF
Environment Variable Encryption Tool

Usage: $0 <command> [OPTIONS]

Commands:
  encrypt   Encrypt sensitive variables in .env file
  decrypt   Decrypt sensitive variables in .env file
  list      List sensitive variables

Options:
  -i, --input <file>     Input .env file (default: .env)
  -o, --output <file>    Output file (default: overwrite input)
  -k, --key <key>        Encryption key (or set ENV_ENCRYPT_KEY)
  -s, --sensitive <keys> Comma-separated list of sensitive keys
  -a, --algorithm <alg>  Encryption algorithm (default: aes-256-cbc)
  -h, --help             Show this help

Examples:
  $0 encrypt -i .env.local -k mykey123
  $0 decrypt -i .env.encrypted -o .env.decrypted
  $0 list -i .env.server

EOF
}

# Check dependencies
check_dependencies() {
    if ! command -v openssl >/dev/null 2>&1; then
        echo "Error: openssl is required but not installed" >&2
        exit 1
    fi
}

# Load sensitive keys from config
load_sensitive_keys() {
    if [[ -f "$CONFIG_FILE" ]] && command -v jq >/dev/null 2>&1; then
        local config_keys
        config_keys=$(jq -r '.encryption.sensitive_keys[]?' "$CONFIG_FILE" 2>/dev/null || echo "")
        if [[ -n "$config_keys" ]]; then
            readarray -t SENSITIVE_KEYS <<< "$config_keys"
        fi
    fi
}

# Check if key is sensitive
is_sensitive_key() {
    local key="$1"
    local pattern
    
    for pattern in "${SENSITIVE_KEYS[@]}"; do
        if [[ "$key" =~ $pattern ]]; then
            return 0
        fi
    done
    return 1
}

# Encrypt value
encrypt_value() {
    local value="$1"
    local key="$2"
    local algorithm="${3:-aes-256-cbc}"
    
    echo -n "$value" | openssl enc -"$algorithm" -base64 -pass pass:"$key" 2>/dev/null
}

# Decrypt value
decrypt_value() {
    local encrypted_value="$1"
    local key="$2"
    local algorithm="${3:-aes-256-cbc}"
    
    echo -n "$encrypted_value" | openssl enc -d -"$algorithm" -base64 -pass pass:"$key" 2>/dev/null
}

# Encrypt environment file
encrypt_env_file() {
    local input_file="$1"
    local output_file="$2"
    local encryption_key="$3"
    local algorithm="$4"
    
    echo "Encrypting sensitive variables in: $input_file"
    
    local temp_file=$(mktemp)
    local encrypted_count=0
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            echo "$line" >> "$temp_file"
            continue
        fi
        
        if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Remove quotes from value
            value=$(echo "$value" | sed 's/^"\(.*\)"$/\1/')
            
            if is_sensitive_key "$key"; then
                local encrypted_value
                encrypted_value=$(encrypt_value "$value" "$encryption_key" "$algorithm")
                if [[ $? -eq 0 ]]; then
                    echo "${key}=ENC[${encrypted_value}]" >> "$temp_file"
                    ((encrypted_count++))
                    echo "  Encrypted: $key"
                else
                    echo "  Warning: Failed to encrypt $key, keeping original" >&2
                    echo "$line" >> "$temp_file"
                fi
            else
                echo "$line" >> "$temp_file"
            fi
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$input_file"
    
    mv "$temp_file" "$output_file"
    echo "Encryption completed: $encrypted_count variables encrypted"
}

# Decrypt environment file
decrypt_env_file() {
    local input_file="$1"
    local output_file="$2"
    local encryption_key="$3"
    local algorithm="$4"
    
    echo "Decrypting sensitive variables in: $input_file"
    
    local temp_file=$(mktemp)
    local decrypted_count=0
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            echo "$line" >> "$temp_file"
            continue
        fi
        
        if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=ENC\[([^]]+)\]$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local encrypted_value="${BASH_REMATCH[2]}"
            
            local decrypted_value
            decrypted_value=$(decrypt_value "$encrypted_value" "$encryption_key" "$algorithm")
            if [[ $? -eq 0 ]]; then
                # Quote value if it contains spaces or special characters
                if [[ "$decrypted_value" =~ [[:space:]\$\`\\] ]]; then
                    echo "${key}=\"${decrypted_value}\"" >> "$temp_file"
                else
                    echo "${key}=${decrypted_value}" >> "$temp_file"
                fi
                ((decrypted_count++))
                echo "  Decrypted: $key"
            else
                echo "  Warning: Failed to decrypt $key, keeping encrypted" >&2
                echo "$line" >> "$temp_file"
            fi
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$input_file"
    
    mv "$temp_file" "$output_file"
    echo "Decryption completed: $decrypted_count variables decrypted"
}

# List sensitive variables
list_sensitive_vars() {
    local input_file="$1"
    
    echo "Sensitive variables in: $input_file"
    echo "Patterns: ${SENSITIVE_KEYS[*]}"
    echo
    
    local found_count=0
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)= ]]; then
            local key="${BASH_REMATCH[1]}"
            
            if is_sensitive_key "$key"; then
                if [[ "$line" =~ ENC\[ ]]; then
                    echo "  $key (encrypted)"
                else
                    echo "  $key (plaintext)"
                fi
                ((found_count++))
            fi
        fi
    done < "$input_file"
    
    echo
    echo "Found $found_count sensitive variables"
}

# Main function
main() {
    local command=""
    local input_file=".env"
    local output_file=""
    local encryption_key="${ENV_ENCRYPT_KEY:-}"
    local algorithm="aes-256-cbc"
    local custom_sensitive=""
    
    [[ $# -eq 0 ]] && { show_usage; exit 1; }
    
    command="$1"
    shift
    
    case "$command" in
        encrypt|decrypt|list)
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Error: Unknown command: $command" >&2
            show_usage
            exit 1
            ;;
    esac
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--input)
                input_file="$2"
                shift 2
                ;;
            -o|--output)
                output_file="$2"
                shift 2
                ;;
            -k|--key)
                encryption_key="$2"
                shift 2
                ;;
            -s|--sensitive)
                custom_sensitive="$2"
                shift 2
                ;;
            -a|--algorithm)
                algorithm="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                echo "Error: Unknown option: $1" >&2
                exit 1
                ;;
        esac
    done
    
    # Set default output file
    [[ -z "$output_file" ]] && output_file="$input_file"
    
    # Validate input file
    [[ ! -f "$input_file" ]] && { echo "Error: Input file not found: $input_file" >&2; exit 1; }
    
    # Load configuration
    load_sensitive_keys
    
    # Override sensitive keys if provided
    if [[ -n "$custom_sensitive" ]]; then
        IFS=',' read -ra SENSITIVE_KEYS <<< "$custom_sensitive"
    fi
    
    # Check dependencies
    check_dependencies
    
    # Execute command
    case "$command" in
        encrypt|decrypt)
            [[ -z "$encryption_key" ]] && { echo "Error: Encryption key required (use -k or set ENV_ENCRYPT_KEY)" >&2; exit 1; }
            
            if [[ "$command" == "encrypt" ]]; then
                encrypt_env_file "$input_file" "$output_file" "$encryption_key" "$algorithm"
            else
                decrypt_env_file "$input_file" "$output_file" "$encryption_key" "$algorithm"
            fi
            ;;
        list)
            list_sensitive_vars "$input_file"
            ;;
    esac
}

main "$@"