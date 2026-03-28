#!/bin/sh
# Package Skill - Create distributable .skill package
# Creates a .skill.tar.gz file for distribution

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
SKILL_NAME=$(basename "$SKILL_DIR")

print_banner() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║              Skill Packager                               ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
}

validate_skill() {
    if [ ! -f "${SKILL_DIR}/SKILL.md" ]; then
        echo "Error: SKILL.md not found in ${SKILL_DIR}"
        exit 1
    fi
    
    if ! grep -q "^name:" "${SKILL_DIR}/SKILL.md" 2>/dev/null; then
        echo "Error: SKILL.md missing 'name' in frontmatter"
        exit 1
    fi
    
    if ! grep -q "^description:" "${SKILL_DIR}/SKILL.md" 2>/dev/null; then
        echo "Error: SKILL.md missing 'description' in frontmatter"
        exit 1
    fi
    
    echo "✓ Skill validation passed"
}

get_skill_info() {
    SKILL_NAME=$(grep "^name:" "${SKILL_DIR}/SKILL.md" | head -1 | sed 's/^name: *//' | sed 's/^"//' | sed 's/"$//')
    VERSION=$(grep "^version:" "${SKILL_DIR}/skill.yaml" 2>/dev/null | sed 's/^version: *//' || echo "1.0.0")
}

package_tar() {
    output_dir="${1:-${SKILL_DIR}/..}"
    output_file="${output_dir}/${SKILL_NAME}.skill.tar.gz"
    
    echo "Creating package: ${output_file}"
    
    cd "$(dirname "$SKILL_DIR")"
    
    tar -czvf "$output_file" \
        --exclude="${SKILL_NAME}/state" \
        --exclude="${SKILL_NAME}/.git" \
        --exclude="${SKILL_NAME}/.github" \
        --exclude="${SKILL_NAME}/.qoder" \
        --exclude="${SKILL_NAME}/*.log" \
        --exclude="${SKILL_NAME}/__pycache__" \
        --exclude="${SKILL_NAME}/.DS_Store" \
        --exclude="${SKILL_NAME}/.gitignore" \
        --exclude="${SKILL_NAME}/*.tgz" \
        "$(basename "$SKILL_DIR")"
    
    echo ""
    echo "✓ Package created: ${output_file}"
    echo "  Size: $(ls -lh "$output_file" | awk '{print $5}')"
    echo "  Contents:"
    tar -tzvf "$output_file" | head -20
    echo "  ..."
}

package_zip() {
    output_dir="${1:-${SKILL_DIR}/..}"
    output_file="${output_dir}/${SKILL_NAME}.skill.zip"
    
    echo "Creating package: ${output_file}"
    
    cd "$(dirname "$SKILL_DIR")"
    
    zip -r "$output_file" "$(basename "$SKILL_DIR")" \
        -x "${SKILL_NAME}/state/*" \
        -x "${SKILL_NAME}/.git/*" \
        -x "${SKILL_NAME}/.github/*" \
        -x "${SKILL_NAME}/.qoder/*" \
        -x "${SKILL_NAME}/*.log" \
        -x "${SKILL_NAME}/__pycache__/*" \
        -x "${SKILL_NAME}/.DS_Store" \
        -x "${SKILL_NAME}/.gitignore" \
        -x "${SKILL_NAME}/*.tgz"
    
    echo ""
    echo "✓ Package created: ${output_file}"
    echo "  Size: $(ls -lh "$output_file" | awk '{print $5}')"
}

show_info() {
    echo ""
    echo "Skill Information"
    echo "================="
    echo "  Name:    ${SKILL_NAME}"
    echo "  Version: ${VERSION}"
    echo "  Path:    ${SKILL_DIR}"
    echo ""
}

main() {
    action="${1:-tar}"
    output_dir="${2:-}"
    
    print_banner
    
    validate_skill
    get_skill_info
    show_info
    
    case "$action" in
        tar|targz)
            package_tar "$output_dir"
            ;;
        zip)
            package_zip "$output_dir"
            ;;
        all|both)
            package_tar "$output_dir"
            echo ""
            package_zip "$output_dir"
            ;;
        info)
            show_info
            ;;
        help|--help|-h)
            echo "Usage: $0 <command> [output_dir]"
            echo ""
            echo "Commands:"
            echo "  tar, targz   Create .skill.tar.gz package (default)"
            echo "  zip          Create .skill.zip package"
            echo "  all, both    Create both tar.gz and zip packages"
            echo "  info         Show skill information"
            echo "  help         Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 tar                    # Create tar.gz package"
            echo "  $0 zip                    # Create zip package"
            echo "  $0 all                    # Create both"
            echo "  $0 tar /tmp               # Output to /tmp"
            ;;
        *)
            echo "Unknown command: $action"
            echo "Run '$0 help' for usage"
            exit 1
            ;;
    esac
}

main "$@"
