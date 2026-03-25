#!/bin/sh
# Workflow - AI-driven task execution with auto-closed loop
# Self-contained, uses skill's own bin tools

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
export SKILL_DIR

. "${SKILL_DIR}/lib/common.sh"

PROJECT_ROOT="$(get_project_root)"
export PROJECT_ROOT

HARNESS="${SKILL_DIR}/bin/harness.sh"
TASK_PARSER="${SKILL_DIR}/bin/task-parser.sh"
DEP_GRAPH="${SKILL_DIR}/bin/dep-graph.sh"

print_banner() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║           Task Decomposer - Auto-Closed Loop              ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
}

print_step() {
    step_num="$1"
    total="$2"
    message="$3"
    echo ""
    echo "┌─────────────────────────────────────────────────────────┐"
    echo "│ Step ${step_num}/${total}: ${message}"
    echo "└─────────────────────────────────────────────────────────┘"
}

print_success() {
    echo "  ✓ $1"
}

print_error() {
    echo "  ✗ $1"
}

print_info() {
    echo "  → $1"
}

get_next_ready_task() {
    ready_tasks=$("$DEP_GRAPH" ready 2>/dev/null | head -1)
    if [ -n "$ready_tasks" ]; then
        echo "$ready_tasks"
    else
        echo ""
    fi
}

workflow_start() {
    task_id="$1"
    force="${2:-false}"
    
    print_banner
    
    if [ -z "$task_id" ]; then
        print_info "Finding next ready task..."
        task_id=$(get_next_ready_task)
        if [ -z "$task_id" ]; then
            error "No ready tasks found"
            echo ""
            info "Run '${HARNESS} progress' to see current status"
            exit 1
        fi
        print_info "Found task: $task_id"
    fi
    
    if ! task_exists "$task_id"; then
        error "Task not found: $task_id"
        exit 1
    fi
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Task: $task_id"
    echo "═══════════════════════════════════════════════════════════"
    
    total_steps=6
    
    print_step 1 $total_steps "Checking dependencies & starting task"
    
    force_flag=""
    if [ "$force" = "true" ]; then
        force_flag="--force"
        warn "Force mode enabled - skipping dependency check"
    fi
    
    if $HARNESS start $force_flag "$task_id" 2>&1; then
        print_success "Task started successfully"
    else
        print_error "Failed to start task"
        echo ""
        info "Dependencies not satisfied. Options:"
        echo "  1. Complete blocking tasks first"
        echo "  2. Use --force to skip dependency check"
        exit 1
    fi
    
    print_step 2 $total_steps "Loading task details"
    
    title=$("$TASK_PARSER" field "$task_id" "title" 2>/dev/null || echo "")
    type=$("$TASK_PARSER" field "$task_id" "type" 2>/dev/null || echo "")
    priority=$("$TASK_PARSER" field "$task_id" "priority" 2>/dev/null || echo "")
    phase=$("$TASK_PARSER" field "$task_id" "phase" 2>/dev/null || echo "")
    
    echo "  Title:    $title"
    echo "  Type:     $type"
    echo "  Priority: $priority"
    echo "  Phase:    $phase"
    
    print_step 3 $total_steps "Reading required documents"
    
    docs=$("$TASK_PARSER" docs "$task_id" 2>/dev/null || echo "")
    if [ -n "$docs" ]; then
        echo "$docs" | while read -r doc; do
            if [ -n "$doc" ]; then
                print_info "Read: $doc"
            fi
        done
    else
        print_info "No specific docs_to_read defined"
    fi
    
    print_step 4 $total_steps "Implementation steps"
    
    steps=$("$TASK_PARSER" steps "$task_id" 2>/dev/null || echo "")
    if [ -n "$steps" ]; then
        echo "$steps" | while read -r step; do
            if [ -n "$step" ]; then
                print_info "$step"
            fi
        done
    else
        print_info "No implementation steps defined"
    fi
    
    print_step 5 $total_steps "Validation"
    
    validation_cmds=$("$TASK_PARSER" commands "$task_id" 2>/dev/null || echo "")
    if [ -n "$validation_cmds" ]; then
        echo "$validation_cmds" | while read -r cmd; do
            if [ -n "$cmd" ]; then
                print_info "Run: $cmd"
            fi
        done
    else
        print_info "No validation commands defined"
    fi
    
    print_step 6 $total_steps "Ready for AI implementation"
    
    echo ""
    echo "┌─────────────────────────────────────────────────────────┐"
    echo "│ 🤖 AI Implementation Required                           │"
    echo "└─────────────────────────────────────────────────────────┘"
    echo ""
    echo "AI should now:"
    echo "  1. Read the documents listed in Step 3"
    echo "  2. Execute the implementation steps in Step 4"
    echo "  3. Run the validation commands in Step 5"
    echo "  4. Mark task as complete when done"
    echo ""
    echo "To mark complete, run:"
    echo "  $0 complete $task_id"
    echo ""
}

workflow_complete() {
    task_id="$1"
    skip_validation="${2:-false}"
    
    print_banner
    
    if [ -z "$task_id" ]; then
        error "Task ID required"
        echo "Usage: $0 complete <task_id>"
        exit 1
    fi
    
    if ! task_exists "$task_id"; then
        error "Task not found: $task_id"
        exit 1
    fi
    
    current_status=$(get_task_status "$task_id")
    if [ "$current_status" != "in_progress" ]; then
        warn "Task is not in progress (status: $current_status)"
    fi
    
    echo "═══════════════════════════════════════════════════════════"
    echo "  Completing Task: $task_id"
    echo "═══════════════════════════════════════════════════════════"
    
    if [ "$skip_validation" = "false" ]; then
        echo ""
        echo "Running validation..."
        
        validation_cmds=$("$TASK_PARSER" commands "$task_id" 2>/dev/null || echo "")
        validation_failed=false
        
        if [ -n "$validation_cmds" ]; then
            while IFS= read -r cmd; do
                if [ -z "$cmd" ]; then
                    continue
                fi
                if [ -n "$cmd" ]; then
                    echo "  Running: $cmd"
                    if eval "$cmd" 2>&1; then
                        print_success "Validation passed"
                    else
                        print_error "Validation failed: $cmd"
                        validation_failed=true
                    fi
                fi
            done <<EOF
$validation_cmds
EOF
        fi
        
        if [ "$validation_failed" = "true" ]; then
            echo ""
            error "Validation failed. Task not marked as complete."
            echo "Fix the issues and try again, or use --skip-validation"
            exit 1
        fi
    else
        warn "Skipping validation"
    fi
    
    echo ""
    echo "Marking task as complete..."
    $HARNESS complete "$task_id"
    
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║              ✓ Task Completed Successfully                ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    
    echo "Next ready tasks:"
    $HARNESS ready | head -5
    
    echo ""
    echo "Progress:"
    $HARNESS progress
}

workflow_auto() {
    task_id="$1"
    force="${2:-false}"
    
    print_banner
    echo "🤖 Auto-Closed Loop Mode"
    echo ""
    
    if [ -z "$task_id" ]; then
        task_id=$(get_next_ready_task)
        if [ -z "$task_id" ]; then
            error "No ready tasks found"
            exit 1
        fi
        print_info "Auto-selected task: $task_id"
    fi
    
    echo "═══════════════════════════════════════════════════════════"
    echo "  Auto-Executing: $task_id"
    echo "═══════════════════════════════════════════════════════════"
    
    force_flag=""
    if [ "$force" = "true" ]; then
        force_flag="--force"
    fi
    
    echo ""
    echo "[1/3] Starting task..."
    if $HARNESS start $force_flag "$task_id" 2>&1; then
        print_success "Task started"
    else
        print_error "Failed to start"
        exit 1
    fi
    
    echo ""
    echo "[2/3] Showing task details..."
    $HARNESS show "$task_id"
    
    echo ""
    echo "[3/3] Ready for AI implementation..."
    echo ""
    echo "┌─────────────────────────────────────────────────────────┐"
    echo "│ 🤖 AI should now implement the task                     │"
    echo "└─────────────────────────────────────────────────────────┘"
    echo ""
    echo "After implementation, run:"
    echo "  $0 complete $task_id"
    echo ""
    echo "Or for full auto-loop:"
    echo "  User: 'AI, please implement and complete this task'"
    echo ""
}

workflow_status() {
    task_id="$1"
    
    print_banner
    
    if [ -z "$task_id" ]; then
        echo "Overall Progress:"
        echo ""
        $HARNESS progress
        echo ""
        echo "Ready Tasks:"
        $HARNESS ready
        echo ""
        echo "Blocked Tasks:"
        $HARNESS blocked
    else
        if ! task_exists "$task_id"; then
            error "Task not found: $task_id"
            exit 1
        fi
        
        echo "Task Status: $task_id"
        echo ""
        $HARNESS show "$task_id"
        echo ""
        echo "Dependency Tree:"
        $HARNESS tree "$task_id"
    fi
}

workflow_next() {
    print_banner
    
    echo "Finding next recommended task..."
    echo ""
    
    ready_tasks=$($HARNESS ready 2>/dev/null | grep "^PHASE-")
    
    if [ -z "$ready_tasks" ]; then
        echo "No ready tasks found."
        echo ""
        echo "Blocked tasks:"
        $HARNESS blocked
        exit 0
    fi
    
    first_task=$(echo "$ready_tasks" | head -1)
    
    title=$("$TASK_PARSER" field "$first_task" "title" 2>/dev/null || echo "")
    priority=$("$TASK_PARSER" field "$first_task" "priority" 2>/dev/null || echo "")
    
    echo "Recommended: $first_task"
    echo "  Title:    $title"
    echo "  Priority: $priority"
    echo ""
    
    echo "All ready tasks:"
    echo "$ready_tasks" | head -10
    echo ""
    
    echo "To start this task:"
    echo "  $0 start $first_task"
    echo ""
    echo "Or let AI auto-execute:"
    echo "  User: 'Execute the next task'"
}

main() {
    action="${1:-help}"
    shift || true
    
    case "$action" in
        start)
            force="false"
            task_id=""
            for arg in "$@"; do
                case "$arg" in
                    --force|-f) force="true" ;;
                    *) task_id="$arg" ;;
                esac
            done
            workflow_start "$task_id" "$force"
            ;;
        complete)
            skip="false"
            task_id=""
            for arg in "$@"; do
                case "$arg" in
                    --skip-validation) skip="true" ;;
                    *) task_id="$arg" ;;
                esac
            done
            workflow_complete "$task_id" "$skip"
            ;;
        auto)
            force="false"
            task_id=""
            for arg in "$@"; do
                case "$arg" in
                    --force|-f) force="true" ;;
                    *) task_id="$arg" ;;
                esac
            done
            workflow_auto "$task_id" "$force"
            ;;
        status)
            workflow_status "$@"
            ;;
        next)
            workflow_next
            ;;
        help|--help|-h)
            print_banner
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  start [task_id] [--force]     Start a task (auto-select if no ID)"
            echo "  complete <task_id> [--skip]   Complete a task"
            echo "  auto [task_id] [--force]      Auto-closed loop execution"
            echo "  status [task_id]              Show status"
            echo "  next                          Show next recommended task"
            echo "  help                          Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 start                     # Auto-select next ready task"
            echo "  $0 start PHASE-1-1-1         # Start specific task"
            echo "  $0 start PHASE-1-1-1 --force # Skip dependency check"
            echo "  $0 complete PHASE-1-1-1      # Complete task"
            echo "  $0 auto                      # Full auto-loop"
            echo "  $0 status                    # Show overall progress"
            echo "  $0 next                      # Show next recommended task"
            ;;
        *)
            error "Unknown command: $action"
            echo "Run '$0 help' for usage"
            exit 1
            ;;
    esac
}

main "$@"
