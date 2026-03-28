#!/bin/sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

TMP_BASE_DIR="${TMPDIR:-/tmp}"
TMP_BASE_DIR="${TMP_BASE_DIR%/}"
TMP_DIR="$(mktemp -d "${TMP_BASE_DIR}/task-decomposer-verify.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

run_npm_without_dry_run() {
    (
        unset npm_config_dry_run
        npm "$@"
    )
}

create_custom_project() {
    project_root="$1"
    mkdir -p "${project_root}/.tasks" "${project_root}/.plans" "${project_root}/.templates" "${project_root}/nested/worktree"

    cat > "${project_root}/.skill.yaml" <<'EOF'
paths:
  tasks_dir: .tasks
  plans_dir: .plans
  task_template: .templates/task.json.example

documents:
  spec: .plans/spec.md
  tasks: .plans/tasks.md
  default_docs_to_read:
    - .plans/spec.md
    - .plans/tasks.md
EOF

    cat > "${project_root}/.plans/spec.md" <<'EOF'
# custom spec
EOF

    cat > "${project_root}/.plans/tasks.md" <<'EOF'
# custom tasks
EOF

    cat > "${project_root}/.templates/task.json.example" <<'EOF'
id: PHASE-X-Y-Z
EOF

    cat > "${project_root}/.tasks/PHASE-1-1-1.yaml" <<'EOF'
id: PHASE-1-1-1
type: test
title: Multi word validation command
priority: high
phase: 1
dependencies: []
validation:
  commands:
    - python3 -c "print('command with spaces works')"
status: pending
EOF

    cat > "${project_root}/.tasks/PHASE-1-1-2.yaml" <<'EOF'
id: PHASE-1-1-2
type: test
title: Workflow validation failure
priority: high
phase: 1
dependencies:
  - PHASE-1-1-1
validation:
  commands:
    - python3 -c "import sys; sys.exit(1)"
status: pending
EOF
}

run_custom_project_checks() {
    skill_root="$1"
    test_home="$2"
    project_root="$3"
    task_bin="$4"
    label="$5"

    CONFIG_OUTPUT=$(cd "${project_root}/nested/worktree" && HOME="${test_home}" "${task_bin}" config)
    printf '%s\n' "$CONFIG_OUTPUT" | grep "Project Root: ${project_root}" >/dev/null
    printf '%s\n' "$CONFIG_OUTPUT" | grep "Tasks Dir:    ${project_root}/.tasks" >/dev/null
    printf '%s\n' "$CONFIG_OUTPUT" | grep "Project State: .*${label}-custom-project" >/dev/null
    printf '%s\n' "$CONFIG_OUTPUT" | grep "Task Template: ${project_root}/.templates/task.json.example" >/dev/null

    cd "${project_root}"
    HOME="${test_home}" "${task_bin}" init >/dev/null

    SHOW_OUTPUT=$(HOME="${test_home}" "${task_bin}" show PHASE-1-1-1)
    printf '%s\n' "$SHOW_OUTPUT" | grep "Task: PHASE-1-1-1" >/dev/null
    printf '%s\n' "$SHOW_OUTPUT" | grep "Dependencies:" >/dev/null
    printf '%s\n' "$SHOW_OUTPUT" | grep "    (none)" >/dev/null

    TEMPLATE_OUTPUT=$("${skill_root}/scripts/task-creator.sh" template)
    printf '%s\n' "$TEMPLATE_OUTPUT" | grep "id: PHASE-X-Y-Z" >/dev/null

    READY_BEFORE=$(HOME="${test_home}" "${task_bin}" ready)
    printf '%s\n' "$READY_BEFORE" | grep "PHASE-1-1-1" >/dev/null
    if printf '%s\n' "$READY_BEFORE" | grep "PHASE-1-1-2" >/dev/null; then
        echo "dependent task should not be ready before prerequisite completes"
        exit 1
    fi

    "${skill_root}/scripts/task-creator.sh" create \
        PHASE-1-1-3 \
        "Created by task creator" \
        test \
        medium \
        1 \
        "[]" \
        "Task creator generated description" \
        ".tasks/PHASE-1-1-3.json" \
        "Generated acceptance criteria" \
        "Run generated implementation step" \
        "python3 -c \"print('generated validation')\"" >/dev/null
    grep '"docs_to_read":' "${project_root}/.tasks/PHASE-1-1-3.json" >/dev/null
    grep '".plans/spec.md"' "${project_root}/.tasks/PHASE-1-1-3.json" >/dev/null
    grep '".plans/tasks.md"' "${project_root}/.tasks/PHASE-1-1-3.json" >/dev/null
    grep '".tasks/PHASE-1-1-3.json"' "${project_root}/.tasks/PHASE-1-1-3.json" >/dev/null
    grep '".plans/spec.md"' "${project_root}/.tasks/PHASE-1-1-3.json" >/dev/null

    WORKFLOW_OUTPUT=$(HOME="${test_home}" "${skill_root}/scripts/workflow.sh" start PHASE-1-1-1 2>&1)
    printf '%s\n' "$WORKFLOW_OUTPUT" | grep "Title:    Multi word validation command" >/dev/null
    printf '%s\n' "$WORKFLOW_OUTPUT" | grep "Type:     test" >/dev/null
    printf '%s\n' "$WORKFLOW_OUTPUT" | grep "Priority: high" >/dev/null
    printf '%s\n' "$WORKFLOW_OUTPUT" | grep "Phase:    1" >/dev/null

    HOME="${test_home}" "${task_bin}" test PHASE-1-1-1 >/dev/null
    HOME="${test_home}" "${task_bin}" complete PHASE-1-1-1 >/dev/null

    READY_AFTER=$(HOME="${test_home}" "${task_bin}" ready)
    printf '%s\n' "$READY_AFTER" | grep "PHASE-1-1-2" >/dev/null

    HOME="${test_home}" "${task_bin}" start PHASE-1-1-2 >/dev/null

    if HOME="${test_home}" "${skill_root}/scripts/workflow.sh" complete PHASE-1-1-2 >/dev/null 2>&1; then
        echo "workflow complete should fail when validation fails"
        exit 1
    fi

    STATUS_OUTPUT=$(HOME="${test_home}" "${task_bin}" status PHASE-1-1-2)
    [ "$STATUS_OUTPUT" = "in_progress" ]

    HOME="${test_home}" "${task_bin}" status PHASE-1-1-2 blocked >/dev/null
    BLOCKED_STATUS=$(HOME="${test_home}" "${task_bin}" status PHASE-1-1-2)
    [ "$BLOCKED_STATUS" = "blocked" ]

    HOME="${test_home}" "${task_bin}" status PHASE-1-1-2 in_progress >/dev/null

    cat > "${project_root}/.tasks/PHASE-1-9-9.yaml" <<'EOF'
id: PHASE-1-9-9
type: invalid
title: Invalid task
priority: urgent
phase: wrong
dependencies: []
status: broken
EOF
    if HOME="${test_home}" "${task_bin}" validate >/dev/null 2>&1; then
        echo "validate should fail for invalid task metadata"
        exit 1
    fi
    rm -f "${project_root}/.tasks/PHASE-1-9-9.yaml"
}

run_example_project_checks() {
    skill_root="$1"
    test_home="$2"
    project_root="$3"
    task_bin="$4"
    custom_project_root="$5"

    mkdir -p "${project_root}"
    cp -R "${skill_root}/references/example-project/." "${project_root}/"
    mkdir -p "${project_root}/nested/worktree"

    CONFIG_OUTPUT=$(cd "${project_root}/nested/worktree" && HOME="${test_home}" "${task_bin}" config)
    printf '%s\n' "$CONFIG_OUTPUT" | grep "Project Root: ${project_root}" >/dev/null
    printf '%s\n' "$CONFIG_OUTPUT" | grep "Tasks Dir:    ${project_root}/docs/tasks" >/dev/null

    cd "${project_root}"
    HOME="${test_home}" "${task_bin}" init >/dev/null

    SHOW_OUTPUT=$(HOME="${test_home}" "${task_bin}" show PHASE-1-1-1)
    printf '%s\n' "$SHOW_OUTPUT" | grep "Task: PHASE-1-1-1" >/dev/null
    printf '%s\n' "$SHOW_OUTPUT" | grep "Dependencies:" >/dev/null
    printf '%s\n' "$SHOW_OUTPUT" | grep "    (none)" >/dev/null
    printf '%s\n' "$SHOW_OUTPUT" | grep "Files:" >/dev/null
    printf '%s\n' "$SHOW_OUTPUT" | grep "Docs to Read (AI development prerequisite):" >/dev/null

    READY_BEFORE=$(HOME="${test_home}" "${task_bin}" ready)
    printf '%s\n' "$READY_BEFORE" | grep "PHASE-1-1-1" >/dev/null
    if printf '%s\n' "$READY_BEFORE" | grep "PHASE-1-1-2" >/dev/null; then
        echo "example dependent task should not be ready before prerequisite completes"
        exit 1
    fi

    HOME="${test_home}" "${task_bin}" test PHASE-1-1-1 >/dev/null
    HOME="${test_home}" "${task_bin}" complete PHASE-1-1-1 >/dev/null

    READY_AFTER=$(HOME="${test_home}" "${task_bin}" ready)
    printf '%s\n' "$READY_AFTER" | grep "PHASE-1-1-2" >/dev/null
    HOME="${test_home}" "${task_bin}" test PHASE-1-1-2 >/dev/null

    cd "${custom_project_root}"
    ISOLATED_STATUS=$(HOME="${test_home}" "${task_bin}" status PHASE-1-1-1)
    [ "$ISOLATED_STATUS" = "completed" ]
}

run_install_checks() {
    skill_root="$1"
    label="$2"

    test_home="${TMP_DIR}/${label}-home"
    custom_project="${TMP_DIR}/${label}-custom-project"
    example_project="${TMP_DIR}/${label}-example-project"
    installed_skill_dir="${test_home}/.skills/task-decomposer"

    mkdir -p "${test_home}/.local/bin"
    create_custom_project "${custom_project}"

    HOME="${test_home}" "${skill_root}/scripts/install.sh" install generic >/dev/null
    task_bin="${test_home}/.local/bin/task"

    if [ -d "${installed_skill_dir}/references" ]; then
        echo "default installation should not include references"
        exit 1
    fi

    run_custom_project_checks "${skill_root}" "${test_home}" "${custom_project}" "${task_bin}" "${label}"
    run_example_project_checks "${skill_root}" "${test_home}" "${example_project}" "${task_bin}" "${custom_project}"
}

run_npm_install_checks() {
    if ! command -v npm >/dev/null 2>&1; then
        echo "npm not found, skipping npm installation checks"
        return
    fi

    pack_dir="${TMP_DIR}/npm-pack"
    prefix_dir="${TMP_DIR}/npm-prefix"
    test_home="${TMP_DIR}/npm-home"
    custom_project="${TMP_DIR}/npm-custom-project"
    example_project="${TMP_DIR}/npm-example-project"

    mkdir -p "${pack_dir}" "${prefix_dir}" "${test_home}"
    create_custom_project "${custom_project}"

    PACKAGE_FILE=$(cd "${SKILL_DIR}" && run_npm_without_dry_run pack --pack-destination "${pack_dir}" | tail -1)
    run_npm_without_dry_run install -g "${pack_dir}/${PACKAGE_FILE}" --prefix "${prefix_dir}" >/dev/null

    task_bin="${prefix_dir}/bin/task"
    installed_skill_dir="${prefix_dir}/lib/node_modules/@bicorne/task-decomposer"

    run_custom_project_checks "${installed_skill_dir}" "${test_home}" "${custom_project}" "${task_bin}" "npm"
    run_example_project_checks "${installed_skill_dir}" "${test_home}" "${example_project}" "${task_bin}" "${custom_project}"

    STATE_OUTPUT=$(cd "${custom_project}" && HOME="${test_home}" "${task_bin}" config)
    printf '%s\n' "$STATE_OUTPUT" | grep "State Dir:    ${test_home}/.task-decomposer/state" >/dev/null
}

run_install_checks "${SKILL_DIR}" "repo"

PACKAGE_DIR="${TMP_DIR}/package-output"
EXTRACT_DIR="${TMP_DIR}/package-extracted"
mkdir -p "${PACKAGE_DIR}" "${EXTRACT_DIR}"

"${SKILL_DIR}/scripts/package.sh" tar "${PACKAGE_DIR}" >/dev/null
tar -xzf "${PACKAGE_DIR}/task-decomposer.skill.tar.gz" -C "${EXTRACT_DIR}"

run_install_checks "${EXTRACT_DIR}/task-decomposer" "package"

run_npm_install_checks

echo "All verification checks passed"
