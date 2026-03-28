#!/bin/sh
# Task Decomposer Common Library - Self-contained utility functions
# Supports multi-project configuration via skill.yaml and .skill.yaml

set -e

# ============================================================================
# Configuration System
# ============================================================================

get_skill_dir() {
    if [ -n "${SKILL_DIR:-}" ]; then
        echo "$SKILL_DIR"
        return
    fi
    script_dir="$(cd "$(dirname "$0")" && pwd)"
    if [ -f "${script_dir}/SKILL.md" ]; then
        echo "$script_dir"
    else
        dirname "$script_dir"
    fi
}

detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "linux" ;;
        Darwin*)    echo "macos" ;;
        CYGWIN*)    echo "windows" ;;
        MINGW*)     echo "windows" ;;
        MSYS*)      echo "windows" ;;
        *)          echo "unknown" ;;
    esac
}

# ============================================================================
# JSON Parser (using Python - zero dependency, available on all systems)
# ============================================================================

json_get() {
    file="$1"
    key="$2"
    default="${3:-}"
    
    if [ ! -f "$file" ]; then
        echo "$default"
        return
    fi
    
    python3 -c "
import json
import sys
try:
    with open('$file', 'r') as f:
        data = json.load(f)
    keys = '$key'.split('.')
    result = data
    for k in keys:
        if isinstance(result, dict) and k in result:
            result = result[k]
        else:
            result = None
            break
    if result is not None and result != '':
        if isinstance(result, list):
            for item in result:
                print(item)
        elif isinstance(result, bool):
            print('true' if result else 'false')
        else:
            print(result)
    else:
        print('$default')
except Exception as e:
    print('$default', file=sys.stderr)
    sys.exit(0)
" 2>/dev/null || echo "$default"
}

json_get_array() {
    file="$1"
    key="$2"
    
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    python3 -c "
import json
import sys
try:
    with open('$file', 'r') as f:
        data = json.load(f)
    keys = '$key'.split('.')
    result = data
    for k in keys:
        if isinstance(result, dict) and k in result:
            result = result[k]
        else:
            result = []
            break
    if isinstance(result, list):
        for item in result:
            print(item)
except Exception as e:
    sys.exit(1)
" 2>/dev/null
}

# ============================================================================
# YAML Parser (legacy support)
# ============================================================================
parse_yaml_value() {
    file="$1"
    key="$2"
    default="${3:-}"
    
    if [ ! -f "$file" ]; then
        echo "$default"
        return
    fi
    
    value=$(grep "^${key}:" "$file" 2>/dev/null | head -1 | sed "s/^${key}: *//" | sed 's/^"//' | sed 's/"$//')
    
    if [ -n "$value" ]; then
        echo "$value"
    else
        echo "$default"
    fi
}

# Parse YAML nested value (e.g., paths.tasks_dir)
parse_yaml_nested() {
    file="$1"
    path="$2"
    default="${3:-}"
    
    if [ ! -f "$file" ]; then
        echo "$default"
        return
    fi
    
    parent=$(echo "$path" | cut -d. -f1)
    child=$(echo "$path" | cut -d. -f2-)
    
    awk -v parent="$parent" -v child="$child" -v default="$default" '
        function trim_value(value) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            sub(/^"/, "", value)
            sub(/"$/, "", value)
            return value
        }
        $0 ~ "^[[:space:]]*" parent ":[[:space:]]*$" { in_section=1; next }
        in_section && $0 ~ "^[[:space:]]+" child ":[[:space:]]*" {
            value=$0
            sub("^[[:space:]]+" child ":[[:space:]]*", "", value)
            print trim_value(value)
            found=1
            exit
        }
        in_section && $0 ~ "^[^[:space:]][^:]*:[[:space:]]*$" { in_section=0 }
        END { if (!found) print default }
    ' "$file"
}

parse_yaml_list() {
    file="$1"
    path="$2"
    
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    parent=$(echo "$path" | cut -d. -f1)
    child=$(echo "$path" | cut -d. -f2-)
    
    awk -v parent="$parent" -v child="$child" '
        function print_value(value) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            sub(/^"/, "", value)
            sub(/"$/, "", value)
            if (value != "") {
                print value
                found=1
            }
        }
        $0 ~ "^[[:space:]]*" parent ":[[:space:]]*$" { in_parent=1; in_list=0; next }
        in_parent && child != "" && $0 ~ "^[[:space:]]+" child ":[[:space:]]*$" { in_list=1; next }
        in_parent && child == "" && $0 ~ "^[[:space:]]*-[[:space:]]+" {
            value=$0
            sub("^[[:space:]]*-[[:space:]]+", "", value)
            print_value(value)
            next
        }
        in_parent && in_list && $0 ~ "^[[:space:]]*-[[:space:]]+" {
            value=$0
            sub("^[[:space:]]*-[[:space:]]+", "", value)
            print_value(value)
            next
        }
        in_parent && in_list && $0 ~ "^[[:space:]]+[[:alnum:]_]+:[[:space:]]*" { in_list=0; next }
        in_parent && $0 ~ "^[^[:space:]][^:]*:[[:space:]]*$" { in_parent=0; in_list=0 }
        END { if (!found) exit 1 }
    ' "$file"
}

# Get configuration value with fallback chain
# Priority: project config > skill default config > hardcoded default
get_config() {
    key="$1"
    default="${2:-}"
    
    skill_dir="$(get_skill_dir)"
    project_root="$(get_project_root)"
    
    # Try project config first
    project_config="${project_root}/.skill.yaml"
    if [ -f "$project_config" ]; then
        value=$(parse_yaml_nested "$project_config" "$key" "")
        if [ -n "$value" ] && [ "$value" != "" ]; then
            echo "$value"
            return
        fi
    fi
    
    # Try skill default config
    skill_config="${skill_dir}/skill.yaml"
    if [ -f "$skill_config" ]; then
        value=$(parse_yaml_nested "$skill_config" "$key" "")
        if [ -n "$value" ] && [ "$value" != "" ]; then
            echo "$value"
            return
        fi
    fi
    
    # Fallback to default
    echo "$default"
}

get_config_list() {
    key="$1"
    default="${2:-}"
    
    skill_dir="$(get_skill_dir)"
    project_root="$(get_project_root)"
    
    project_config="${project_root}/.skill.yaml"
    if [ -f "$project_config" ]; then
        if value=$(parse_yaml_list "$project_config" "$key" 2>/dev/null); then
            if [ -n "$value" ]; then
                printf "%s\n" "$value"
                return
            fi
        fi
    fi
    
    skill_config="${skill_dir}/skill.yaml"
    if [ -f "$skill_config" ]; then
        if value=$(parse_yaml_list "$skill_config" "$key" 2>/dev/null); then
            if [ -n "$value" ]; then
                printf "%s\n" "$value"
                return
            fi
        fi
    fi
    
    if [ -n "$default" ]; then
        printf "%s\n" "$default"
    fi
}

# ============================================================================
# Project Discovery
# ============================================================================

get_project_root() {
    if [ -n "${PROJECT_ROOT:-}" ]; then
        echo "$PROJECT_ROOT"
        return
    fi
    
    dir="$(pwd)"
    
    # Get markers from config
    skill_dir="$(get_skill_dir)"
    markers="pyproject.toml
package.json
Cargo.toml
go.mod
.git
.skill.yaml
docs/tasks"
    if [ -f "${skill_dir}/skill.yaml" ]; then
        config_markers=$(parse_yaml_list "${skill_dir}/skill.yaml" "project.markers" 2>/dev/null || true)
        if [ -n "$config_markers" ]; then
            markers="$config_markers"
        fi
    fi
    
    while [ "$dir" != "/" ]; do
        for marker in $markers; do
            if [ -e "${dir}/${marker}" ]; then
                echo "$dir"
                return
            fi
        done
        dir="$(dirname "$dir")"
    done
    
    echo "$(pwd)"
}

# ============================================================================
# Path Helpers (Config-driven)
# ============================================================================

get_tasks_dir() {
    root="$(get_project_root)"
    tasks_dir=$(get_config "paths.tasks_dir" "docs/tasks")
    echo "${root}/${tasks_dir}"
}

get_plans_dir() {
    root="$(get_project_root)"
    plans_dir=$(get_config "paths.plans_dir" "docs/plans")
    echo "${root}/${plans_dir}"
}

get_task_template() {
    root="$(get_project_root)"
    template=$(get_config "paths.task_template" "docs/tasks/_template.json.example")
    echo "${root}/${template}"
}

get_state_dir() {
    if [ -n "${TASK_STATE_DIR:-}" ]; then
        echo "$TASK_STATE_DIR"
        return
    fi

    skill_dir="$(get_skill_dir)"
    state_dir=$(get_config "paths.state_dir" "state")

    case "$skill_dir" in
        */node_modules/*)
            if [ -z "${HOME:-}" ]; then
                HOME="${USERPROFILE:-$(cd ~ && pwd)}"
            fi
            echo "${HOME}/.task-decomposer/${state_dir}"
            ;;
        *)
            echo "${skill_dir}/${state_dir}"
            ;;
    esac
}

get_project_state_key() {
    project_root="$(get_project_root)"
    project_name="$(basename "$project_root" | sed 's/[^A-Za-z0-9._-]/_/g')"
    project_hash="$(printf "%s" "$project_root" | cksum | awk '{print $1}')"
    echo "${project_name}-${project_hash}"
}

get_project_state_dir() {
    state_dir="$(get_state_dir)"
    project_key="$(get_project_state_key)"
    echo "${state_dir}/${project_key}"
}

get_spec_file() {
    root="$(get_project_root)"
    spec=$(get_config "documents.spec" "docs/plans/spec.md")
    echo "${root}/${spec}"
}

get_tasks_file() {
    root="$(get_project_root)"
    tasks=$(get_config "documents.tasks" "docs/plans/tasks.md")
    echo "${root}/${tasks}"
}

get_default_docs_to_read() {
    get_config_list "documents.default_docs_to_read" "docs/plans/spec.md
docs/plans/tasks.md"
}

# ============================================================================
# State Management
# ============================================================================

ensure_state_dir() {
    state_dir="$(get_state_dir)"
    project_state_dir="$(get_project_state_dir)"
    mkdir -p "$state_dir" "$project_state_dir"
}

get_task_file() {
    task_id="$1"
    tasks_dir="$(get_tasks_dir)"
    
    # Try JSON first, then YAML for backward compatibility
    if [ -f "${tasks_dir}/${task_id}.json" ]; then
        echo "${tasks_dir}/${task_id}.json"
    elif [ -f "${tasks_dir}/${task_id}.yaml" ]; then
        echo "${tasks_dir}/${task_id}.yaml"
    else
        echo "${tasks_dir}/${task_id}.json"
    fi
}

task_exists() {
    task_id="$1"
    task_file="$(get_task_file "$task_id")"
    [ -f "$task_file" ]
}

get_task_status_file() {
    task_id="$1"
    project_state_dir="$(get_project_state_dir)"
    echo "${project_state_dir}/${task_id}.status"
}

get_legacy_task_status_file() {
    task_id="$1"
    state_dir="$(get_state_dir)"
    echo "${state_dir}/${task_id}.status"
}

get_task_status() {
    task_id="$1"
    status_file="$(get_task_status_file "$task_id")"
    legacy_status_file="$(get_legacy_task_status_file "$task_id")"
    
    if [ -f "$status_file" ]; then
        cat "$status_file"
    elif [ -f "$legacy_status_file" ]; then
        cat "$legacy_status_file"
    else
        task_file="$(get_task_file "$task_id")"
        if [ -f "$task_file" ]; then
            case "$task_file" in
                *.json)
                    json_get "$task_file" "status" "pending"
                    ;;
                *.yaml)
                    yaml_status=$(grep "^status:" "$task_file" 2>/dev/null | sed 's/^status: *//' || echo "")
                    if [ -n "$yaml_status" ]; then
                        echo "$yaml_status"
                    else
                        echo "pending"
                    fi
                    ;;
            esac
        else
            echo "unknown"
        fi
    fi
}

set_task_status() {
    task_id="$1"
    status="$2"
    
    ensure_state_dir
    status_file="$(get_task_status_file "$task_id")"
    legacy_status_file="$(get_legacy_task_status_file "$task_id")"
    echo "$status" > "$status_file"
    if [ -f "$legacy_status_file" ]; then
        rm -f "$legacy_status_file"
    fi
    
    task_file="$(get_task_file "$task_id")"
    if [ -f "$task_file" ]; then
        case "$task_file" in
            *.json)
                python3 -c "
import json
with open('$task_file', 'r') as f:
    data = json.load(f)
data['status'] = '$status'
with open('$task_file', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
                    "
                ;;
            *.yaml)
                if grep -q "^status:" "$task_file"; then
                    case "$(detect_os)" in
                        macos) sed -i '' "s/^status:.*/status: ${status}/" "$task_file" ;;
                        *)     sed -i "s/^status:.*/status: ${status}/" "$task_file" ;;
                    esac
                else
                    echo "status: ${status}" >> "$task_file"
                fi
                ;;
        esac
    fi
}

# ============================================================================
# Task Listing
# ============================================================================

list_all_tasks() {
    tasks_dir="$(get_tasks_dir)"
    # List both JSON and YAML files
    for f in "$tasks_dir"/PHASE-*.json "$tasks_dir"/PHASE-*.yaml; do
        if [ -f "$f" ]; then
            basename "$f" | sed 's/\.json$//' | sed 's/\.yaml$//'
        fi
    done | sort -u
}

list_tasks_by_phase() {
    phase="$1"
    tasks_dir="$(get_tasks_dir)"
    # List both JSON and YAML files
    for f in "$tasks_dir"/PHASE-${phase}-*.json "$tasks_dir"/PHASE-${phase}-*.yaml; do
        if [ -f "$f" ]; then
            basename "$f" | sed 's/\.json$//' | sed 's/\.yaml$//'
        fi
    done | sort -u
}

# ============================================================================
# Validation
# ============================================================================

validate_task_id() {
    task_id="$1"
    pattern=$(get_config "task_id.pattern" "^PHASE-[0-9]+-[0-9]+-[0-9]+\$")
    if echo "$task_id" | grep -qE "$pattern"; then
        return 0
    else
        return 1
    fi
}

get_phase_from_task_id() {
    task_id="$1"
    echo "$task_id" | sed 's/PHASE-\([0-9]*\)-.*/\1/'
}

# ============================================================================
# Output Helpers
# ============================================================================

color_print() {
    color="$1"
    shift
    text="$*"
    
    if [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ]; then
        case "$color" in
            red)     printf "\033[0;31m%s\033[0m\n" "$text" ;;
            green)   printf "\033[0;32m%s\033[0m\n" "$text" ;;
            yellow)  printf "\033[0;33m%s\033[0m\n" "$text" ;;
            blue)    printf "\033[0;34m%s\033[0m\n" "$text" ;;
            cyan)    printf "\033[0;36m%s\033[0m\n" "$text" ;;
            *)       printf "%s\n" "$text" ;;
        esac
    else
        printf "%s\n" "$text"
    fi
}

info() {
    color_print blue "[INFO] $*"
}

success() {
    color_print green "[OK] $*"
}

warn() {
    color_print yellow "[WARN] $*"
}

error() {
    color_print red "[ERROR] $*" >&2
}

die() {
    error "$*"
    exit 1
}

# ============================================================================
# Configuration Info
# ============================================================================

show_config() {
    echo "Task Decomposer Configuration"
    echo "=============================="
    echo ""
    echo "Project Root: $(get_project_root)"
    echo "Skill Dir:    $(get_skill_dir)"
    echo ""
    echo "Paths:"
    echo "  Tasks Dir:    $(get_tasks_dir)"
    echo "  Plans Dir:    $(get_plans_dir)"
    echo "  Task Template: $(get_task_template)"
    echo "  State Dir:    $(get_state_dir)"
    echo "  Project State: $(get_project_state_dir)"
    echo ""
    echo "Documents:"
    echo "  Spec:  $(get_spec_file)"
    echo "  Tasks: $(get_tasks_file)"
    echo ""
    echo "Config Files:"
    project_root="$(get_project_root)"
    skill_dir="$(get_skill_dir)"
    if [ -f "${project_root}/.skill.yaml" ]; then
        echo "  Project Config: ${project_root}/.skill.yaml (active)"
    else
        echo "  Project Config: ${project_root}/.skill.yaml (not found)"
    fi
    if [ -f "${skill_dir}/skill.yaml" ]; then
        echo "  Skill Config:   ${skill_dir}/skill.yaml (active)"
    else
        echo "  Skill Config:   ${skill_dir}/skill.yaml (not found)"
    fi
}
