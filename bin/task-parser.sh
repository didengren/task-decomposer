#!/bin/sh
# Task Parser - Parse JSON/YAML task files
# Self-contained, no external dependencies

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
export SKILL_DIR

. "${SKILL_DIR}/lib/common.sh"

parse_field() {
    task_id="$1"
    field="$2"
    task_file="$(get_task_file "$task_id")"
    
    if [ ! -f "$task_file" ]; then
        error "Task file not found: $task_file"
        return 1
    fi
    
    case "$task_file" in
        *.json)
            json_get "$task_file" "$field"
            ;;
        *.yaml)
            grep "^${field}:" "$task_file" | head -1 | sed "s/^${field}: *//" | sed 's/^"//' | sed 's/"$//'
            ;;
    esac
}

parse_array() {
    task_id="$1"
    field="$2"
    task_file="$(get_task_file "$task_id")"
    
    if [ ! -f "$task_file" ]; then
        return 1
    fi
    
    case "$task_file" in
        *.json)
            json_get_array "$task_file" "$field"
            ;;
        *.yaml)
            inline=$(grep "^${field}:" "$task_file" | head -1 | sed "s/^${field}: *//")
            
            if echo "$inline" | grep -q '^\['; then
                echo "$inline" | sed 's/^\[//' | sed 's/\]$//' | tr ',' '\n' | sed 's/^ *//' | sed 's/ *$//' | awk 'NF { print }'
            else
                awk "
                    /^${field}:/ { in_array=1; next }
                    /^[a-z_]+:\$/ { in_array=0 }
                    in_array && /^  - / { print substr(\$0, 5) }
                " "$task_file"
            fi
            ;;
    esac
}

parse_files() {
    task_id="$1"
    task_file="$(get_task_file "$task_id")"
    
    if [ ! -f "$task_file" ]; then
        return 1
    fi
    
    case "$task_file" in
        *.json)
            json_get_array "$task_file" "spec.files"
            ;;
        *.yaml)
            awk '
                /^spec:/ { in_spec=1 }
                /^  files:/ && in_spec { in_files=1; next }
                in_files && /^    - / { print substr($0, 7) }
                in_files && /^  [a-z]/ { in_files=0 }
                /^[a-z_]+:$/ && !/^spec:/ { in_spec=0 }
            ' "$task_file"
            ;;
    esac
}

parse_acceptance_criteria() {
    task_id="$1"
    task_file="$(get_task_file "$task_id")"
    
    if [ ! -f "$task_file" ]; then
        return 1
    fi
    
    case "$task_file" in
        *.json)
            json_get_array "$task_file" "acceptance_criteria"
            ;;
        *.yaml)
            awk '
                /^acceptance_criteria:/ { in_ac=1; next }
                /^[a-z_]+:$/ { in_ac=0 }
                in_ac && /^  - / { print substr($0, 5) }
            ' "$task_file"
            ;;
    esac
}

parse_validation_commands() {
    task_id="$1"
    task_file="$(get_task_file "$task_id")"
    
    if [ ! -f "$task_file" ]; then
        return 1
    fi
    
    case "$task_file" in
        *.json)
            json_get_array "$task_file" "validation.commands"
            ;;
        *.yaml)
            awk '
                /^validation:/ { in_val=1; next }
                /^[a-z_]+:$/ { in_val=0 }
                /^  commands:/ && in_val { in_cmds=1; next }
                in_cmds && /^    - / { print substr($0, 7) }
                in_cmds && /^  [a-z]/ && !/^  commands:/ { in_cmds=0 }
            ' "$task_file"
            ;;
    esac
}

parse_implementation_steps() {
    task_id="$1"
    task_file="$(get_task_file "$task_id")"
    
    if [ ! -f "$task_file" ]; then
        return 1
    fi
    
    case "$task_file" in
        *.json)
            python3 -c "
import json
with open('$task_file', 'r') as f:
    data = json.load(f)
steps = data.get('implementation', {}).get('steps', [])
for step in steps:
    if isinstance(step, dict):
        print(step.get('step', ''))
    else:
        print(step)
                    "
            ;;
        *.yaml)
            awk '
                /^implementation:/ { in_impl=1; next }
                /^[a-z_]+:$/ { in_impl=0 }
                in_impl && /^  steps:/ { in_steps=1; next }
                in_steps && /^    - step: / { print substr($0, 12) }
            ' "$task_file"
            ;;
    esac
}

parse_docs_to_read() {
    task_id="$1"
    task_file="$(get_task_file "$task_id")"
    
    if [ ! -f "$task_file" ]; then
        return 1
    fi
    
    case "$task_file" in
        *.json)
            json_get_array "$task_file" "docs_to_read"
            ;;
        *.yaml)
            awk '
                /^docs_to_read:/ { in_docs=1; next }
                /^[a-z_]+:$/ { in_docs=0 }
                in_docs && /^  - / { print substr($0, 5) }
            ' "$task_file"
            ;;
    esac
}

print_task_summary() {
    task_id="$1"
    
    if ! task_exists "$task_id"; then
        error "Task not found: $task_id"
        return 1
    fi
    
    title=$(parse_field "$task_id" "title")
    type=$(parse_field "$task_id" "type")
    priority=$(parse_field "$task_id" "priority")
    phase=$(parse_field "$task_id" "phase")
    status=$(get_task_status "$task_id")
    
    echo "Task: $task_id"
    echo "  Title: $title"
    echo "  Type: $type"
    echo "  Priority: $priority"
    echo "  Phase: $phase"
    echo "  Status: $status"
    
    echo ""
    echo "  Dependencies:"
    deps=$(parse_array "$task_id" "dependencies")
    if [ -n "$deps" ]; then
        echo "$deps" | while read -r dep; do
            if [ -n "$dep" ]; then
                dep_status=$(get_task_status "$dep")
                echo "    - $dep [$dep_status]"
            fi
        done
    else
        echo "    (none)"
    fi
    
    echo ""
    echo "  Files:"
    files=$(parse_files "$task_id")
    if [ -n "$files" ]; then
        echo "$files" | while read -r f; do
            if [ -n "$f" ]; then
                echo "    - $f"
            fi
        done
    else
        echo "    (none)"
    fi
}

print_task_details() {
    task_id="$1"
    
    print_task_summary "$task_id"
    
    echo ""
    echo "  Docs to Read (AI development prerequisite):"
    docs=$(parse_docs_to_read "$task_id")
    if [ -n "$docs" ]; then
        echo "$docs" | while read -r d; do
            if [ -n "$d" ]; then
                echo "    - $d"
            fi
        done
    else
        echo "    (none)"
    fi
    
    echo ""
    echo "  Acceptance Criteria:"
    criteria=$(parse_acceptance_criteria "$task_id")
    if [ -n "$criteria" ]; then
        echo "$criteria" | while read -r c; do
            if [ -n "$c" ]; then
                echo "    - $c"
            fi
        done
    fi
    
    echo ""
    echo "  Implementation Steps:"
    steps=$(parse_implementation_steps "$task_id")
    if [ -n "$steps" ]; then
        echo "$steps" | while read -r s; do
            if [ -n "$s" ]; then
                echo "    - $s"
            fi
        done
    fi
    
    echo ""
    echo "  Validation Commands:"
    cmds=$(parse_validation_commands "$task_id")
    if [ -n "$cmds" ]; then
        echo "$cmds" | while read -r cmd; do
            if [ -n "$cmd" ]; then
                echo "    $ $cmd"
            fi
        done
    fi
}

main() {
    action="${1:-help}"
    shift || true
    
    case "$action" in
        field)
            parse_field "$@"
            ;;
        array)
            parse_array "$@"
            ;;
        files)
            parse_files "$@"
            ;;
        deps|dependencies)
            parse_array "$1" "dependencies"
            ;;
        criteria)
            parse_acceptance_criteria "$@"
            ;;
        commands)
            parse_validation_commands "$@"
            ;;
        steps)
            parse_implementation_steps "$@"
            ;;
        docs)
            parse_docs_to_read "$@"
            ;;
        summary)
            print_task_summary "$@"
            ;;
        details)
            print_task_details "$@"
            ;;
        status)
            get_task_status "$@"
            ;;
        help|*)
            echo "Usage: $0 <action> <task_id> [args]"
            echo ""
            echo "Actions:"
            echo "  field <task_id> <field>     - Parse a single field"
            echo "  array <task_id> <field>     - Parse an array field"
            echo "  files <task_id>             - List task files"
            echo "  deps <task_id>              - List task dependencies"
            echo "  criteria <task_id>          - List acceptance criteria"
            echo "  commands <task_id>          - List validation commands"
            echo "  steps <task_id>             - List implementation steps"
            echo "  docs <task_id>              - List docs to read before development"
            echo "  summary <task_id>           - Print task summary"
            echo "  details <task_id>           - Print full task details"
            echo "  status <task_id>            - Get task status"
            ;;
    esac
}

if [ "${0##*/}" = "task-parser.sh" ]; then
    main "$@"
fi
