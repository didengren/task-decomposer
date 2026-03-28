#!/bin/sh
# Dependency Graph - Build and analyze task dependency graph
# Self-contained, no external dependencies

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
export SKILL_DIR

. "${SKILL_DIR}/lib/common.sh"

get_deps() {
    task_id="$1"
    task_file="$(get_task_file "$task_id")"
    
    if [ ! -f "$task_file" ]; then
        return
    fi
    
    case "$task_file" in
        *.json)
            json_get "$task_file" "dependencies" ""
            ;;
        *.yaml)
            awk '
                /^dependencies:/ { in_deps=1; next }
                /^[a-z_]+:$/ { in_deps=0 }
                in_deps && /^  - / { print substr($0, 5) }
            ' "$task_file"
            ;;
    esac
}

check_deps_completed() {
    task_id="$1"
    
    deps=$(get_deps "$task_id")
    if [ -z "$deps" ]; then
        return 0
    fi
    
    for dep in $deps; do
        status=$(get_task_status "$dep")
        if [ "$status" != "completed" ]; then
            return 1
        fi
    done
    
    return 0
}

get_dependents() {
    task_id="$1"
    
    list_all_tasks | while read -r other; do
        deps=$(get_deps "$other")
        for dep in $deps; do
            if [ "$dep" = "$task_id" ]; then
                echo "$other"
                break
            fi
        done
    done
}

find_ready_tasks() {
    list_all_tasks | while read -r task_id; do
        status=$(get_task_status "$task_id")
        if [ "$status" = "pending" ] || [ "$status" = "unknown" ]; then
            if check_deps_completed "$task_id"; then
                echo "$task_id"
            fi
        fi
    done
}

find_blocked_tasks() {
    list_all_tasks | while read -r task_id; do
        status=$(get_task_status "$task_id")
        if [ "$status" != "completed" ]; then
            if ! check_deps_completed "$task_id"; then
                echo "$task_id"
            fi
        fi
    done
}

print_dep_tree() {
    task_id="$1"
    indent="${2:-0}"
    
    prefix=""
    i=0
    while [ $i -lt "$indent" ]; do
        prefix="${prefix}  "
        i=$((i + 1))
    done
    
    status=$(get_task_status "$task_id")
    status_icon="?"
    case "$status" in
        completed) status_icon="✓" ;;
        in_progress) status_icon="►" ;;
        pending) status_icon="○" ;;
        blocked) status_icon="✗" ;;
    esac
    
    echo "${prefix}${status_icon} ${task_id}"
    
    deps=$(get_deps "$task_id")
    for dep in $deps; do
        print_dep_tree "$dep" $((indent + 1))
    done
}

print_reverse_tree() {
    task_id="$1"
    indent="${2:-0}"
    
    prefix=""
    i=0
    while [ $i -lt "$indent" ]; do
        prefix="${prefix}  "
        i=$((i + 1))
    done
    
    status=$(get_task_status "$task_id")
    status_icon="?"
    case "$status" in
        completed) status_icon="✓" ;;
        in_progress) status_icon="►" ;;
        pending) status_icon="○" ;;
        blocked) status_icon="✗" ;;
    esac
    
    echo "${prefix}${status_icon} ${task_id}"
    
    dependents=$(get_dependents "$task_id")
    for dep in $dependents; do
        print_reverse_tree "$dep" $((indent + 1))
    done
}

print_progress() {
    total=0
    completed=0
    in_progress=0
    pending=0
    
    for task_id in $(list_all_tasks); do
        total=$((total + 1))
        status=$(get_task_status "$task_id")
        case "$status" in
            completed) completed=$((completed + 1)) ;;
            in_progress) in_progress=$((in_progress + 1)) ;;
            *) pending=$((pending + 1)) ;;
        esac
    done
    
    blocked=$(find_blocked_tasks | wc -l | tr -d ' ')
    ready=$(find_ready_tasks | wc -l | tr -d ' ')
    
    echo "Progress Summary"
    echo "================"
    echo "Total:       $total"
    echo "Completed:   $completed"
    echo "In Progress: $in_progress"
    echo "Pending:     $pending"
    echo "Ready:       $ready"
    echo "Blocked:     $blocked"
    echo ""
    
    if [ "$total" -gt 0 ]; then
        percent=$((completed * 100 / total))
        bar=""
        filled=$((percent / 5))
        empty=$((20 - filled))
        j=0
        while [ $j -lt "$filled" ]; do
            bar="${bar}█"
            j=$((j + 1))
        done
        j=0
        while [ $j -lt "$empty" ]; do
            bar="${bar}░"
            j=$((j + 1))
        done
        echo "[${bar}] ${percent}%"
    fi
}

main() {
    action="${1:-help}"
    shift || true
    
    case "$action" in
        deps)
            get_deps "$@"
            ;;
        dependents)
            get_dependents "$@"
            ;;
        check-deps)
            if check_deps_completed "$@"; then
                exit 0
            else
                exit 1
            fi
            ;;
        ready)
            find_ready_tasks
            ;;
        blocked)
            find_blocked_tasks
            ;;
        tree)
            print_dep_tree "$@"
            ;;
        rtree)
            print_reverse_tree "$@"
            ;;
        progress)
            print_progress
            ;;
        help|*)
            echo "Usage: $0 <action> [args]"
            echo ""
            echo "Actions:"
            echo "  deps <task_id>         - Get dependencies of a task"
            echo "  dependents <task_id>   - Get tasks that depend on this task"
            echo "  check-deps <task_id>   - Check if all deps completed (exit code)"
            echo "  ready                  - List tasks ready to execute"
            echo "  blocked                - List blocked tasks"
            echo "  tree <task_id>         - Print dependency tree"
            echo "  rtree <task_id>        - Print reverse dependency tree"
            echo "  progress               - Print progress summary"
            ;;
    esac
}

if [ "${0##*/}" = "dep-graph.sh" ]; then
    main "$@"
fi
