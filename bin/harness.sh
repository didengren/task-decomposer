#!/bin/sh
# Harness CLI - Self-contained task management
# No external dependencies on .harness

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
export SKILL_DIR

. "${SKILL_DIR}/lib/common.sh"

export PATH="${SCRIPT_DIR}:${PATH}"

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

cmd_list() {
    phase="${1:-}"
    
    if [ -n "$phase" ]; then
        info "Listing tasks for Phase $phase"
        list_tasks_by_phase "$phase"
    else
        info "Listing all tasks"
        list_all_tasks
    fi
}

cmd_show() {
    task_id="$1"
    
    if [ -z "$task_id" ]; then
        die "Usage: harness.sh show <task_id>"
    fi
    
    if ! task_exists "$task_id"; then
        die "Task not found: $task_id"
    fi
    
    task-parser.sh details "$task_id"
}

cmd_status() {
    task_id="$1"
    new_status="$2"
    
    if [ -z "$task_id" ]; then
        die "Usage: harness.sh status <task_id> [status]"
    fi
    
    if ! task_exists "$task_id"; then
        die "Task not found: $task_id"
    fi
    
    if [ -n "$new_status" ]; then
        case "$new_status" in
            pending|in_progress|completed|blocked)
                set_task_status "$task_id" "$new_status"
                success "Status updated: $task_id -> $new_status"
                ;;
            *)
                die "Invalid status: $new_status (valid: pending, in_progress, completed, blocked)"
                ;;
        esac
    else
        status=$(get_task_status "$task_id")
        echo "$status"
    fi
}

cmd_start() {
    force=false
    task_id=""
    
    for arg in "$@"; do
        case "$arg" in
            --force|-f)
                force=true
                ;;
            *)
                task_id="$arg"
                ;;
        esac
    done
    
    if [ -z "$task_id" ]; then
        die "Usage: harness.sh start [--force] <task_id>"
    fi
    
    if ! task_exists "$task_id"; then
        die "Task not found: $task_id"
    fi
    
    deps=$(dep-graph.sh deps "$task_id")
    unmet=""
    for dep in $deps; do
        if [ -n "$dep" ]; then
            dep_status=$(get_task_status "$dep")
            if [ "$dep_status" != "completed" ]; then
                unmet="${unmet}${dep} (${dep_status}), "
            fi
        fi
    done
    
    if [ -n "$unmet" ] && [ "$force" = false ]; then
        error "Unmet dependencies: ${unmet%, *}"
        warn "Use 'harness.sh start --force $task_id' to override"
        exit 1
    fi
    
    if [ -n "$unmet" ] && [ "$force" = true ]; then
        warn "Force starting with unmet dependencies: ${unmet%, *}"
    fi
    
    set_task_status "$task_id" "in_progress"
    success "Started task: $task_id"
    
    cmd_show "$task_id"
}

cmd_complete() {
    task_id="$1"
    
    if [ -z "$task_id" ]; then
        die "Usage: harness.sh complete <task_id>"
    fi
    
    if ! task_exists "$task_id"; then
        die "Task not found: $task_id"
    fi
    
    set_task_status "$task_id" "completed"
    success "Completed task: $task_id"
    
    echo ""
    info "Tasks now ready:"
    dep-graph.sh ready | head -5
}

cmd_progress() {
    dep-graph.sh progress
}

cmd_tree() {
    task_id="$1"
    
    if [ -n "$task_id" ]; then
        dep-graph.sh tree "$task_id"
    else
        info "Dependency tree for Phase 1 tasks:"
        for task in $(list_tasks_by_phase 1); do
            dep-graph.sh tree "$task"
        done
    fi
}

cmd_ready() {
    info "Tasks ready to execute:"
    ready=$(dep-graph.sh ready)
    if [ -n "$ready" ]; then
        echo "$ready"
    else
        echo "(none)"
    fi
}

cmd_blocked() {
    info "Blocked tasks:"
    blocked=$(dep-graph.sh blocked)
    if [ -n "$blocked" ]; then
        echo "$blocked"
    else
        echo "(none)"
    fi
}

cmd_validate() {
    info "Validating task files..."
    errors=0
    required_fields=$(get_config_list "validation.required_fields" "id
type
title
priority
phase
status")
    valid_types=$(get_config_list "validation.valid_types" "feat
fix
refactor
test
docs")
    valid_priorities=$(get_config_list "validation.valid_priorities" "high
medium
low")
    valid_statuses=$(get_config_list "status.valid_values" "pending
in_progress
completed
blocked")
    
    for task_id in $(list_all_tasks); do
        task_file="$(get_task_file "$task_id")"
        
        if ! validate_task_id "$task_id"; then
            error "$task_id: invalid task ID format"
            errors=$((errors + 1))
        fi
        
        # Check required fields based on file type
        case "$task_file" in
            *.json)
                for field in $required_fields; do
                    value=$(python3 -c "
import json
with open('$task_file', 'r') as f:
    data = json.load(f)
print('present' if '$field' in data else 'missing')
                    " 2>/dev/null || echo "missing")
                    if [ "$value" = "missing" ]; then
                        error "$task_id: missing field '$field'"
                        errors=$((errors + 1))
                    fi
                done
                ;;
            *.yaml)
                for field in $required_fields; do
                    if ! grep -q "^${field}:" "$task_file"; then
                        error "$task_id: missing field '$field'"
                        errors=$((errors + 1))
                    fi
                done
                ;;
        esac
        
        file_id=$(task-parser.sh field "$task_id" "id" 2>/dev/null || echo "")
        task_type=$(task-parser.sh field "$task_id" "type" 2>/dev/null || echo "")
        priority=$(task-parser.sh field "$task_id" "priority" 2>/dev/null || echo "")
        phase=$(task-parser.sh field "$task_id" "phase" 2>/dev/null || echo "")
        status=$(task-parser.sh field "$task_id" "status" 2>/dev/null || echo "")
        
        if [ -n "$file_id" ] && [ "$file_id" != "$task_id" ]; then
            error "$task_id: id field '$file_id' does not match filename"
            errors=$((errors + 1))
        fi
        
        if [ -n "$task_type" ] && ! value_in_list "$task_type" "$valid_types"; then
            error "$task_id: invalid type '$task_type'"
            errors=$((errors + 1))
        fi
        
        if [ -n "$priority" ] && ! value_in_list "$priority" "$valid_priorities"; then
            error "$task_id: invalid priority '$priority'"
            errors=$((errors + 1))
        fi
        
        if [ -n "$status" ] && ! value_in_list "$status" "$valid_statuses"; then
            error "$task_id: invalid status '$status'"
            errors=$((errors + 1))
        fi
        
        expected_phase=$(get_phase_from_task_id "$task_id")
        if [ -n "$phase" ] && ! echo "$phase" | grep -qE '^[0-9]+$'; then
            error "$task_id: invalid phase '$phase'"
            errors=$((errors + 1))
        elif [ -n "$phase" ] && [ "$phase" != "$expected_phase" ]; then
            error "$task_id: phase '$phase' does not match task ID phase '$expected_phase'"
            errors=$((errors + 1))
        fi
        
        deps=$(dep-graph.sh deps "$task_id")
        for dep in $deps; do
            if [ -n "$dep" ] && ! task_exists "$dep"; then
                error "$task_id: dependency '$dep' not found"
                errors=$((errors + 1))
            fi
        done
    done
    
    if [ $errors -eq 0 ]; then
        success "All tasks valid"
    else
        die "Validation failed with $errors errors"
    fi
}

cmd_test() {
    task_id="$1"
    
    if [ -z "$task_id" ]; then
        die "Usage: harness.sh test <task_id>"
    fi
    
    if ! task_exists "$task_id"; then
        die "Task not found: $task_id"
    fi
    
    cmds=$(task-parser.sh commands "$task_id")
    
    if [ -z "$cmds" ]; then
        warn "No validation commands found for $task_id"
        return 0
    fi
    
    info "Running validation commands for $task_id..."
    
    failed=0
    while IFS= read -r cmd; do
        if [ -z "$cmd" ]; then
            continue
        fi
        echo ""
        info "Running: $cmd"
        if eval "$cmd"; then
            success "Passed: $cmd"
        else
            error "Failed: $cmd"
            failed=$((failed + 1))
        fi
    done <<EOF
$cmds
EOF
    
    if [ $failed -eq 0 ]; then
        success "All validations passed for $task_id"
    else
        die "$failed validation(s) failed"
    fi
}

cmd_init() {
    ensure_state_dir
    
    tasks_dir="$(get_tasks_dir)"
    plans_dir="$(get_plans_dir)"
    spec_file="${plans_dir}/spec.md"
    tasks_file="${plans_dir}/tasks.md"
    
    # Check if tasks need to be generated (support both .json and .yaml)
    json_count=$(ls "${tasks_dir}"/PHASE-*.json 2>/dev/null | wc -l | tr -d ' ')
    yaml_count=$(ls "${tasks_dir}"/PHASE-*.yaml 2>/dev/null | wc -l | tr -d ' ')
    task_count=$((json_count + yaml_count))
    
    if [ "$task_count" -eq 0 ]; then
        echo ""
        echo "╔═══════════════════════════════════════════════════════════════╗"
        echo "║              Task Decomposition Required                       ║"
        echo "╚═══════════════════════════════════════════════════════════════╝"
        echo ""
        echo "No task files found in ${tasks_dir}"
        echo ""
        
        # Check if plan documents exist
        if [ -f "$spec_file" ] || [ -f "$tasks_file" ]; then
            echo "Plan documents detected:"
            [ -f "$spec_file" ] && echo "  ✓ ${spec_file}"
            [ -f "$tasks_file" ] && echo "  ✓ ${tasks_file}"
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "AI: Please read the plan documents and generate task files:"
            echo ""
            echo "  1. READ:  Read docs/plans/spec.md and docs/plans/tasks.md"
            echo "  2. PARSE: Understand the structure (Phase -&gt; Subphase -&gt; Task)"
            echo "  3. GENERATE: Create PHASE-X-Y-Z.json files in docs/tasks/"
            echo "  4. VALIDATE: Run 'task validate' to verify"
            echo ""
            echo "Task JSON template:"
            echo "  id: PHASE-X-Y-Z"
            echo "  type: feat|fix|refactor|test|docs"
            echo "  title: Task title"
            echo "  priority: high|medium|low"
            echo "  phase: X"
            echo "  dependencies: []"
            echo "  docs_to_read: [docs/plans/spec.md, docs/plans/tasks.md]"
            echo "  spec: {description, files, context}"
            echo "  acceptance_criteria: []"
            echo "  implementation: {steps, notes}"
            echo "  validation: {commands, manual_checks}"
            echo "  status: pending"
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        else
            echo "No plan documents found. Please create:"
            echo "  - ${spec_file}"
            echo "  - ${tasks_file}"
            echo ""
            echo "See references/example-project/ for examples."
        fi
        echo ""
        return 0
    fi
    
    # Sync existing task status
    info "Syncing task status..."
    
    for task_id in $(list_all_tasks); do
        task_file="$(get_task_file "$task_id")"
        file_status=$(grep "^status:" "$task_file" 2>/dev/null | sed 's/^status: *//' || echo "pending")
        
        if [ -n "$file_status" ]; then
            status_file="$(get_task_status_file "$task_id")"
            echo "$file_status" > "$status_file"
        fi
    done
    
    success "Harness initialized"
    cmd_progress
}

print_usage() {
    cat << 'EOF'
Task Decomposer - Self-contained Task Management CLI

Usage: harness.sh <command> [args]

Commands:
  list [phase]           List all tasks or tasks in a phase
  show <task_id>         Show task details
  status <task_id> [s]   Get or set task status
  start [--force] <task_id>
                         Start a task (checks dependencies)
                         --force: skip dependency check
  complete <task_id>     Mark a task as completed
  progress               Show progress summary
  tree [task_id]         Show dependency tree
  ready                  List tasks ready to execute
  blocked                List blocked tasks
  validate               Validate all task files
  test <task_id>         Run validation commands for a task
  init                   Initialize harness state
  config                 Show current configuration

Examples:
  harness.sh list 1         # List Phase 1 tasks
  harness.sh show PHASE-1-1-1
  harness.sh start PHASE-1-1-1
  harness.sh complete PHASE-1-1-1
  harness.sh progress
  harness.sh tree PHASE-4-2-2
  harness.sh config         # Show configuration

Task ID Format: PHASE-X-Y-Z
  X = Phase number (1-6)
  Y = Sub-phase number
  Z = Task number

EOF
}

main() {
    command="${1:-help}"
    shift || true
    
    case "$command" in
        list|ls)        cmd_list "$@" ;;
        show|info)      cmd_show "$@" ;;
        status)         cmd_status "$@" ;;
        start)          cmd_start "$@" ;;
        complete|done)  cmd_complete "$@" ;;
        progress)       cmd_progress ;;
        tree)           cmd_tree "$@" ;;
        ready)          cmd_ready ;;
        blocked)        cmd_blocked ;;
        validate)       cmd_validate ;;
        test)           cmd_test "$@" ;;
        init)           cmd_init ;;
        config)         show_config ;;
        help|--help|-h) print_usage ;;
        *)
            error "Unknown command: $command"
            print_usage
            exit 1
            ;;
    esac
}

main "$@"
