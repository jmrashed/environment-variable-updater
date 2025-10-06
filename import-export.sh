#!/bin/bash

# Import/Export Tool for Environment Variables
# Supports JSON, YAML, and ENV formats

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_usage() {
    cat << EOF
Environment Import/Export Tool

Usage: $0 <command> [OPTIONS]

Commands:
  import    Import from JSON/YAML to .env format
  export    Export from .env to JSON/YAML format

Import Options:
  -i, --input <file>     Input file (JSON/YAML)
  -o, --output <file>    Output .env file (default: .env)
  -f, --format <format>  Input format (json, yaml)

Export Options:
  -i, --input <file>     Input .env file (default: .env)
  -o, --output <file>    Output file
  -f, --format <format>  Output format (json, yaml)
  -p, --pretty           Pretty print JSON output

Examples:
  $0 import -i config.json -o .env.local
  $0 export -i .env.server -o config.yaml -f yaml
  $0 export -f json -p -o environment.json

EOF
}

# Check dependencies
check_dependencies() {
    local missing=()
    
    if ! command -v jq >/dev/null 2>&1; then
        missing+=("jq")
    fi
    
    if ! command -v yq >/dev/null 2>&1; then
        missing+=("yq")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Error: Missing dependencies: ${missing[*]}" >&2
        echo "Please install: sudo apt-get install jq yq" >&2
        exit 1
    fi
}

# Import from JSON
import_json() {
    local input_file="$1"
    local output_file="$2"
    
    echo "Importing from JSON: $input_file -> $output_file"
    
    jq -r 'to_entries[] | "\(.key)=\(.value)"' "$input_file" > "$output_file"
    echo "Import completed successfully"
}

# Import from YAML
import_yaml() {
    local input_file="$1"
    local output_file="$2"
    
    echo "Importing from YAML: $input_file -> $output_file"
    
    yq eval '. as $item ireduce ({}; . * $item) | to_entries | .[] | .key + "=" + .value' "$input_file" > "$output_file"
    echo "Import completed successfully"
}

# Export to JSON
export_json() {
    local input_file="$1"
    local output_file="$2"
    local pretty="$3"
    
    echo "Exporting to JSON: $input_file -> $output_file"
    
    local json_content="{"
    local first=true
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Remove quotes from value
            value=$(echo "$value" | sed 's/^"\(.*\)"$/\1/')
            
            if [[ "$first" == true ]]; then
                first=false
            else
                json_content+=","
            fi
            
            json_content+="\"$key\":\"$value\""
        fi
    done < "$input_file"
    
    json_content+="}"
    
    if [[ "$pretty" == true ]]; then
        echo "$json_content" | jq '.' > "$output_file"
    else
        echo "$json_content" > "$output_file"
    fi
    
    echo "Export completed successfully"
}

# Export to YAML
export_yaml() {
    local input_file="$1"
    local output_file="$2"
    
    echo "Exporting to YAML: $input_file -> $output_file"
    
    # First convert to JSON, then to YAML
    local temp_json=$(mktemp)
    export_json "$input_file" "$temp_json" false
    yq eval -P '.' "$temp_json" > "$output_file"
    rm "$temp_json"
    
    echo "Export completed successfully"
}

# Main function
main() {
    local command=""
    local input_file=""
    local output_file=""
    local format=""
    local pretty=false
    
    [[ $# -eq 0 ]] && { show_usage; exit 1; }
    
    command="$1"
    shift
    
    case "$command" in
        import|export)
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
            -f|--format)
                format="$2"
                shift 2
                ;;
            -p|--pretty)
                pretty=true
                shift
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
    
    # Set defaults
    if [[ "$command" == "import" ]]; then
        [[ -z "$output_file" ]] && output_file=".env"
    else
        [[ -z "$input_file" ]] && input_file=".env"
    fi
    
    # Validate required arguments
    [[ -z "$input_file" ]] && { echo "Error: Input file required" >&2; exit 1; }
    [[ -z "$output_file" ]] && { echo "Error: Output file required" >&2; exit 1; }
    [[ ! -f "$input_file" ]] && { echo "Error: Input file not found: $input_file" >&2; exit 1; }
    
    # Auto-detect format if not specified
    if [[ -z "$format" ]]; then
        case "$input_file" in
            *.json) format="json" ;;
            *.yaml|*.yml) format="yaml" ;;
            *.env|.env*) format="env" ;;
            *)
                if [[ "$command" == "export" ]]; then
                    case "$output_file" in
                        *.json) format="json" ;;
                        *.yaml|*.yml) format="yaml" ;;
                        *) format="json" ;;
                    esac
                else
                    echo "Error: Cannot auto-detect format. Please specify with -f" >&2
                    exit 1
                fi
                ;;
        esac
    fi
    
    # Check dependencies
    check_dependencies
    
    # Execute command
    case "$command" in
        import)
            case "$format" in
                json) import_json "$input_file" "$output_file" ;;
                yaml) import_yaml "$input_file" "$output_file" ;;
                *) echo "Error: Unsupported import format: $format" >&2; exit 1 ;;
            esac
            ;;
        export)
            case "$format" in
                json) export_json "$input_file" "$output_file" "$pretty" ;;
                yaml) export_yaml "$input_file" "$output_file" ;;
                *) echo "Error: Unsupported export format: $format" >&2; exit 1 ;;
            esac
            ;;
    esac
}

main "$@"