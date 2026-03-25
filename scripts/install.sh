#!/bin/sh
# Task Decomposer Skill Installer
# Supports: Qoder, Trae, Claude Code, Cursor, and generic installation
# Platforms: macOS, Linux, Windows (Git Bash/WSL)
#
# Usage:
#   ./scripts/install.sh install      # Install skill + task command
#   ./scripts/install.sh uninstall    # Remove everything
#   ./scripts/install.sh help         # Show help

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
SKILL_NAME="task-decomposer"

if [ -z "${HOME:-}" ]; then
    HOME="${USERPROFILE:-$(cd ~ && pwd)}"
fi

detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "linux" ;;
        Darwin*)    echo "macos" ;;
        CYGWIN*|MINGW*|MSYS*)    echo "windows" ;;
        *)          echo "unknown" ;;
    esac
}

detect_tool() {
    if [ -n "${QODER:-}" ] || [ -d "$HOME/.qoder" ]; then
        echo "qoder"
    elif [ -n "${TRAE:-}" ] || [ -d "$HOME/.trae-cn" ] || [ -d "$HOME/.trae" ]; then
        echo "trae"
    elif [ -n "${CLAUDE_CODE:-}" ] || [ -d "$HOME/.claude" ]; then
        echo "claude-code"
    elif [ -d "$HOME/.cursor" ]; then
        echo "cursor"
    else
        echo "generic"
    fi
}

get_skill_dir() {
    tool="$1"
    os="$(detect_os)"
    
    case "$tool" in
        qoder)
            echo "$HOME/.qoder/skills"
            ;;
        claude-code)
            echo "$HOME/.claude/skills"
            ;;
        trae)
            if [ -d "$HOME/.trae-cn" ]; then
                echo "$HOME/.trae-cn/skills"
            else
                echo "$HOME/.trae/skills"
            fi
            ;;
        cursor)
            echo "$HOME/.cursor/skills"
            ;;
        *)
            echo "$HOME/.skills"
            ;;
    esac
}

get_bin_dir() {
    os="$(detect_os)"
    
    case "$os" in
        windows)
            if [ -d "$HOME/.local/bin" ]; then
                echo "$HOME/.local/bin"
            elif [ -d "/c/Users/$USER/AppData/Local/Programs" ]; then
                echo "/c/Users/$USER/AppData/Local/Programs/task-cli"
            else
                echo "$HOME/.local/bin"
            fi
            ;;
        *)
            if [ -d "$HOME/.local/bin" ]; then
                echo "$HOME/.local/bin"
            elif [ -w "/usr/local/bin" ]; then
                echo "/usr/local/bin"
            else
                echo "$HOME/.local/bin"
            fi
            ;;
    esac
}

install_skill() {
    skill_install_dir="$1"
    bin_install_dir="$2"
    os="$(detect_os)"
    
    echo "Installing task-decomposer skill..."
    echo "Platform: $os"
    echo ""
    
    mkdir -p "$skill_install_dir"
    
    if [ -d "${skill_install_dir}/${SKILL_NAME}" ]; then
        echo "Removing existing installation..."
        rm -rf "${skill_install_dir}/${SKILL_NAME}"
    fi
    
    cp -r "$SKILL_DIR" "${skill_install_dir}/${SKILL_NAME}"
    rm -rf "${skill_install_dir}/${SKILL_NAME}/references"
    rm -rf "${skill_install_dir}/${SKILL_NAME}/state"
    mkdir -p "${skill_install_dir}/${SKILL_NAME}/state"
    
    chmod +x "${skill_install_dir}/${SKILL_NAME}/bin/"*.sh 2>/dev/null || true
    chmod +x "${skill_install_dir}/${SKILL_NAME}/scripts/"*.sh 2>/dev/null || true
    
    echo "✓ Skill installed to: ${skill_install_dir}/${SKILL_NAME}"
    echo ""
    
    mkdir -p "$bin_install_dir"
    
    cat > "${bin_install_dir}/task" << 'TASK_SCRIPT'
#!/bin/sh
# Task CLI - Global entry point for task-decomposer skill
# Supports: macOS, Linux, Windows (Git Bash/WSL)

set -e

SKILL_NAME="task-decomposer"

if [ -z "${HOME:-}" ]; then
    HOME="${USERPROFILE:-$(cd ~ && pwd)}"
fi

find_skill_dir() {
    for dir in \
        "${SKILL_DIR:-}" \
        "${HOME}/.qoder/skills/${SKILL_NAME}" \
        "${HOME}/.trae-cn/skills/${SKILL_NAME}" \
        "${HOME}/.trae/skills/${SKILL_NAME}" \
        "${HOME}/.claude/skills/${SKILL_NAME}" \
        "${HOME}/.cursor/skills/${SKILL_NAME}" \
        "${HOME}/.skills/${SKILL_NAME}"
    do
        if [ -n "$dir" ] && [ -d "$dir" ]; then
            echo "$dir"
            return 0
        fi
    done
    return 1
}

main() {
    SKILL_DIR=$(find_skill_dir)
    if [ -z "$SKILL_DIR" ]; then
        echo "Error: task-decomposer skill not found"
        echo ""
        echo "Searched locations:"
        echo "  - \$SKILL_DIR (if set)"
        echo "  - ~/.qoder/skills/task-decomposer"
        echo "  - ~/.trae-cn/skills/task-decomposer"
        echo "  - ~/.trae/skills/task-decomposer"
        echo "  - ~/.claude/skills/task-decomposer"
        echo "  - ~/.cursor/skills/task-decomposer"
        echo "  - ~/.skills/task-decomposer"
        echo ""
        echo "To install, run: ./scripts/install.sh install"
        exit 1
    fi

    HARNESS="${SKILL_DIR}/bin/harness.sh"
    if [ ! -f "$HARNESS" ]; then
        echo "Error: harness.sh not found at $HARNESS"
        exit 1
    fi

    COMMON_SH="${SKILL_DIR}/lib/common.sh"
    if [ ! -f "$COMMON_SH" ]; then
        echo "Error: common.sh not found at $COMMON_SH"
        exit 1
    fi

    export SKILL_DIR
    . "$COMMON_SH"

    PROJECT_ROOT=$(get_project_root)
    export PROJECT_ROOT

    exec "$HARNESS" "$@"
}

main "$@"
TASK_SCRIPT
    
    chmod +x "${bin_install_dir}/task"
    
    echo "✓ Command installed to: ${bin_install_dir}/task"
    echo ""
    
    case ":$PATH:" in
        *":${bin_install_dir}:"*)
            ;;
        *)
            echo "⚠ Directory ${bin_install_dir} is not in PATH"
            echo ""
            case "$os" in
                windows)
                    echo "Add this to your PATH (Windows):"
                    echo "  1. Open System Properties > Environment Variables"
                    echo "  2. Add to PATH: ${bin_install_dir}"
                    echo ""
                    echo "Or in Git Bash, add to ~/.bashrc:"
                    echo "  export PATH=\"${bin_install_dir}:\$PATH\""
                    ;;
                *)
                    echo "Add this to your ~/.zshrc or ~/.bashrc:"
                    echo "  export PATH=\"${bin_install_dir}:\$PATH\""
                    echo ""
                    echo "Then run: source ~/.zshrc"
                    ;;
            esac
            ;;
    esac
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Installation Complete!"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "Quick start:"
    echo "  task help        # Show available commands"
    echo "  task list        # List all tasks"
    echo "  task progress    # Show progress"
    echo ""
}

uninstall_skill() {
    skill_install_dir="$1"
    bin_install_dir="$2"
    
    echo "Uninstalling task-decomposer..."
    echo ""
    
    if [ -d "${skill_install_dir}/${SKILL_NAME}" ]; then
        rm -rf "${skill_install_dir}/${SKILL_NAME}"
        echo "✓ Removed: ${skill_install_dir}/${SKILL_NAME}"
    fi
    
    if [ -f "${bin_install_dir}/task" ]; then
        rm -f "${bin_install_dir}/task"
        echo "✓ Removed: ${bin_install_dir}/task"
    fi
    
    echo ""
    echo "Uninstallation complete."
}

main() {
    action="${1:-install}"
    tool="${2:-auto}"
    
    if [ "$tool" = "auto" ]; then
        tool=$(detect_tool)
        echo "Detected tool: $tool"
    fi
    
    skill_install_dir=$(get_skill_dir "$tool")
    bin_install_dir=$(get_bin_dir)
    
    case "$action" in
        install)
            install_skill "$skill_install_dir" "$bin_install_dir"
            ;;
        uninstall)
            uninstall_skill "$skill_install_dir" "$bin_install_dir"
            ;;
        dir)
            echo "Platform: $(detect_os)"
            echo "Skill directory: ${skill_install_dir}/${SKILL_NAME}"
            echo "Binary directory: ${bin_install_dir}"
            ;;
        help|--help|-h)
            echo "Task Decomposer Skill Installer"
            echo ""
            echo "Usage: $0 <command> [tool]"
            echo ""
            echo "Commands:"
            echo "  install [tool]   Install skill + task command (default: auto-detect)"
            echo "  uninstall [tool] Remove everything"
            echo "  dir [tool]       Show installation directories"
            echo "  help             Show this help"
            echo ""
            echo "Tools:"
            echo "  auto        Auto-detect (default)"
            echo "  qoder       Qoder IDE (~/.qoder/skills)"
            echo "  trae        Trae IDE (~/.trae-cn/skills or ~/.trae/skills)"
            echo "  claude-code Claude Code (~/.claude/skills)"
            echo "  cursor      Cursor (~/.cursor/skills)"
            echo "  generic     Generic (~/.skills)"
            echo ""
            echo "Platforms:"
            echo "  macOS, Linux, Windows (Git Bash/WSL)"
            echo ""
            echo "Examples:"
            echo "  $0 install              # Auto-detect and install"
            echo "  $0 install trae         # Install for Trae"
            echo "  $0 uninstall            # Uninstall"
            ;;
        *)
            echo "Unknown command: $action"
            echo "Run '$0 help' for usage"
            exit 1
            ;;
    esac
}

main "$@"
