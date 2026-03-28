#!/bin/sh
# Task Creator - Create task JSON files from plan documents
# Self-contained, uses skill's own lib

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
export SKILL_DIR

. "${SKILL_DIR}/lib/common.sh"

TASKS_DIR="$(get_tasks_dir)"
TEMPLATE_FILE="$(get_task_template)"

value_in_list() {
    value="$1"
    list="$2"
    
    while IFS= read -r item; do
        if [ -n "$item" ] && [ "$item" = "$value" ]; then
            return 0
        fi
    done <<EOF
$list
EOF
    return 1
}

normalize_dependencies() {
    input="$1"
    
    if [ -z "$input" ] || [ "$input" = "[]" ]; then
        return 0
    fi
    
    if echo "$input" | grep -q '^\['; then
        echo "$input" | sed 's/^\[//' | sed 's/\]$//' | tr ',' '\n' | sed 's/^ *//' | sed 's/ *$//' | awk 'NF { print }'
    else
        printf "%s\n" "$input"
    fi
}

print_banner() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║              Task Creator - Manual Task Helper            ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    echo "Note: This script is a helper for creating task files."
    echo "      The main task decomposition is done by AI reading docs/plans/"
    echo "      and generating tasks in docs/tasks/"
    echo ""
}

create_task() {
    task_id="$1"
    title="$2"
    type="$3"
    priority="$4"
    phase="$5"
    dependencies="$6"
    description="$7"
    files="$8"
    acceptance_criteria="$9"
    implementation_steps="${10}"
    validation_commands="${11}"
    valid_types=$(get_config_list "validation.valid_types" "feat
fix
refactor
test
docs")
    valid_priorities=$(get_config_list "validation.valid_priorities" "high
medium
low")
    default_docs=$(get_default_docs_to_read)
    spec_file="$(get_spec_file)"
    spec_context="${spec_file#$(get_project_root)/}"
    
    task_file="${TASKS_DIR}/${task_id}.json"
    
    if ! validate_task_id "$task_id"; then
        error "Invalid task ID: $task_id"
        return 1
    fi
    
    if ! value_in_list "$type" "$valid_types"; then
        error "Invalid task type: $type"
        return 1
    fi
    
    if ! value_in_list "$priority" "$valid_priorities"; then
        error "Invalid priority: $priority"
        return 1
    fi
    
    if ! echo "$phase" | grep -qE '^[0-9]+$'; then
        error "Invalid phase: $phase"
        return 1
    fi
    
    expected_phase=$(get_phase_from_task_id "$task_id")
    if [ "$phase" != "$expected_phase" ]; then
        error "Phase does not match task ID: $task_id -> $expected_phase"
        return 1
    fi
    
    mkdir -p "$TASKS_DIR"
    
    if [ -f "$task_file" ]; then
        warn "Task file already exists: $task_file"
        return 1
    fi
    
    # Convert dependencies to JSON array
    deps_json="[]"
    if [ -n "$dependencies" ] && [ "$dependencies" != "[]" ]; then
        deps_json=$(echo "$dependencies" | sed 's/^\[//' | sed 's/\]$//' | tr ',' '\n' | sed 's/^ *//' | sed 's/ *$//' | awk 'NF { printf "\"%s\", ", $0 }' | sed 's/, $//')
        deps_json="[$deps_json]"
    fi
    
    # Convert files to JSON array
    files_json="[]"
    if [ -n "$files" ]; then
        files_json=$(echo "$files" | tr ',' '\n' | sed 's/^ *//' | sed 's/ *$//' | awk 'NF { printf "\"%s\", ", $0 }' | sed 's/, $//')
        files_json="[$files_json]"
    fi
    
    # Convert acceptance criteria to JSON array
    criteria_json="[]"
    if [ -n "$acceptance_criteria" ]; then
        criteria_json=$(echo "$acceptance_criteria" | tr '|' '\n' | awk 'NF { gsub(/^[[:space:]]+|[[:space:]]+$/, ""); printf "\"%s\", ", $0 }' | sed 's/, $//')
        criteria_json="[$criteria_json]"
    fi
    
    # Convert implementation steps to JSON array of objects
    steps_json="[]"
    if [ -n "$implementation_steps" ]; then
        steps_json=$(echo "$implementation_steps" | tr '|' '\n' | awk 'NF { gsub(/^[[:space:]]+|[[:space:]]+$/, ""); printf "{\"step\": \"%s\"}, ", $0 }' | sed 's/, $//')
        steps_json="[$steps_json]"
    fi
    
    # Convert validation commands to JSON array
    cmds_json="[]"
    if [ -n "$validation_commands" ]; then
        cmds_json=$(echo "$validation_commands" | tr '|' '\n' | awk 'NF { gsub(/^[[:space:]]+|[[:space:]]+$/, ""); gsub(/"/, "\\\""); printf "\"%s\", ", $0 }' | sed 's/, $//')
        cmds_json="[$cmds_json]"
    fi
    
    # Convert docs_to_read to JSON array
    docs_json="[]"
    if [ -n "$default_docs" ]; then
        docs_json=$(printf "%s\n" "$default_docs" | awk 'NF { printf "\"%s\", ", $0 }' | sed 's/, $//')
        docs_json="[$docs_json]"
    fi
    
    cat > "$task_file" << EOF
{
  "id": "${task_id}",
  "type": "${type}",
  "title": "${title}",
  "priority": "${priority}",
  "phase": ${phase},
  "dependencies": ${deps_json},
  "docs_to_read": ${docs_json},
  "spec": {
    "description": "${description}",
    "files": ${files_json},
    "context": ["${spec_context}"]
  },
  "acceptance_criteria": ${criteria_json},
  "implementation": {
    "steps": ${steps_json},
    "notes": ""
  },
  "validation": {
    "commands": ${cmds_json},
    "manual_checks": []
  },
  "status": "pending"
}
EOF
    
    success "Created: $task_file"
}

batch_create_phase() {
    print_banner
    error "Batch creation is deprecated."
    echo ""
    echo "Please use AI to read docs/plans/ and generate tasks:"
    echo "  1. Read docs/plans/spec.md and docs/plans/tasks.md"
    echo "  2. Understand the document structure (any format is OK)"
    echo "  3. Generate task files in docs/tasks/"
    echo ""
    echo "This approach is more flexible and doesn't require specific document format."
}

show_task_template() {
    if [ -f "$TEMPLATE_FILE" ]; then
        cat "$TEMPLATE_FILE"
    else
        echo "Template file not found: $TEMPLATE_FILE"
    fi
}

main() {
    action="${1:-help}"
    shift || true
    
    case "$action" in
        create)
            if [ $# -lt 11 ]; then
                echo "Usage: $0 create <task_id> <title> <type> <priority> <phase> <deps> <description> <files> <criteria> <steps> <commands>"
                exit 1
            fi
            create_task "$@"
            ;;
        template)
            show_task_template
            ;;
        help|--help|-h)
            print_banner
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  create <args>     Create a single task file"
            echo "  template          Show task template"
            echo "  help              Show this help"
            echo ""
            echo "Note: For batch task creation, please ask AI to:"
            echo "  1. Read docs/plans/spec.md and docs/plans/tasks.md"
            echo "  2. Understand the document structure (any format)"
            echo "  3. Generate task files in docs/tasks/"
            echo ""
            echo "Example:"
            echo "  $0 create PHASE-1-1-1 'Task Title' feat high 1 '[]' 'Description' 'src/app.py' 'Tests pass' 'Implement feature' 'pytest tests/'"
            ;;
        *)
            error "Unknown command: $action"
            echo "Run '$0 help' for usage"
            exit 1
            ;;
    esac
}

main "$@"
