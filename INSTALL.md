# Task Decomposer Skill 安装与分发指南

本文档面向安装者与维护者，聚焦三件事：
- 如何安装与卸载
- 如何打包与分发
- 遇到问题时如何排查

---

## 安装

### 最短路径

```bash
npm install -g @bicorne/task-decomposer
task help
```

### 从 npm 安装

```bash
npm install -g @bicorne/task-decomposer
```

这里发布到 npm 的并不只是一个独立 CLI，而是完整的 skill 包；全局安装后会同时得到 skill 内容和 `task` 命令入口。

### 从 GitHub 安装

```bash
npm install -g github:didengren/task-decomposer
```

或者：

```bash
npm install -g git+https://github.com/didengren/task-decomposer.git
```

### 自动安装 skill（推荐给本地开发者）

```bash
cd /path/to/task-decomposer
./scripts/install.sh install
```

脚本会自动检测你的 AI 工具并安装到正确位置。

### 指定工具安装

```bash
# 安装到 Qoder
./scripts/install.sh install qoder

# 安装到 Claude Code
./scripts/install.sh install claude-code

# 安装到 Trae
./scripts/install.sh install trae

# 安装到 Cursor
./scripts/install.sh install cursor

# 安装到通用位置
./scripts/install.sh install generic
```

---

### 安装位置

| 工具 | 安装目录 |
|------|----------|
| Qoder | `~/.qoder/skills/task-decomposer/` |
| Claude Code | `~/.claude/skills/task-decomposer/` |
| Trae | `~/.trae-cn/skills/task-decomposer/` 或 `~/.trae/skills/task-decomposer/` |
| Cursor | `~/.cursor/skills/task-decomposer/` |
| 通用 | `~/.skills/task-decomposer/` |

全局命令通常安装到：
- `~/.local/bin/task`
- 或 `/usr/local/bin/task`

npm 全局安装时，包目录通常位于：
- `$(npm root -g)/@bicorne/task-decomposer`

---

### 手动安装

如果不想使用安装脚本，可以手动复制：

```bash
cd /path/to/task-decomposer

INSTALL_DIR="$HOME/.claude/skills"

mkdir -p "$INSTALL_DIR"
cp -r . "$INSTALL_DIR/task-decomposer"

chmod +x "$INSTALL_DIR/task-decomposer/bin/"*.sh
chmod +x "$INSTALL_DIR/task-decomposer/scripts/"*.sh
```

手动复制只会安装 skill 目录；如果还需要全局 `task` 命令，仍建议执行安装脚本。

---

### 卸载

#### 使用脚本卸载

```bash
./scripts/install.sh uninstall
```

#### 手动卸载

```bash
rm -rf ~/.qoder/skills/task-decomposer
# 或
rm -rf ~/.claude/skills/task-decomposer
# 或
rm -rf ~/.trae-cn/skills/task-decomposer
# 或
rm -rf ~/.trae/skills/task-decomposer
# 或
rm -rf ~/.cursor/skills/task-decomposer
# 或
rm -rf ~/.skills/task-decomposer
```

---

### 安装后检查

```bash
task help
./scripts/install.sh dir
```

如果你还想确认项目接入正常，可以进入目标项目后执行：

```bash
cd /path/to/your-project
task config
task init
```

---

### 项目接入配置

安装后，在项目根目录创建 `.skill.yaml` 自定义配置：

```bash
cd /path/to/your-project

cat > .skill.yaml << 'EOF'
paths:
  tasks_dir: docs/tasks
  plans_dir: docs/plans

documents:
  spec: docs/plans/spec.md
  tasks: docs/plans/tasks.md
EOF
```

更完整的使用流程见 [README.md](./README.md)。

---

## 分发

### 发布到 npm

当前 npm 包名为 `@bicorne/task-decomposer`。

发布前先执行：

```bash
cd /path/to/task-decomposer
npm run release:check
```

推荐发布流程：

```bash
cd /path/to/task-decomposer
npm run release:check
npm version patch
git push origin main --follow-tags
```

本地直接发布：

```bash
npm publish --access public
```

如果使用 GitHub Actions 自动发布：

```bash
npm version patch
git push origin main --follow-tags
```

如果改为手动打 tag，需要保证 tag 与 `package.json` 版本完全一致，例如 `v1.0.1` 对应 `"version": "1.0.1"`。

需要在 GitHub 仓库中配置 `NPM_TOKEN`。工作流会在发布后执行一次新的 npm 全局安装，并运行 `task help` 作为 smoke test。

---

### 创建安装包

```bash
cd /path/to/task-decomposer

./scripts/package.sh tar
./scripts/package.sh zip
./scripts/package.sh all
```

默认会在 skill 上级目录生成：
- `task-decomposer.skill.tar.gz`
- `task-decomposer.skill.zip`

如果需要指定输出目录：

```bash
./scripts/package.sh tar /tmp/task-decomposer-packages
```

### 从安装包部署

```bash
mkdir -p ~/.claude/skills
tar -xzvf task-decomposer.skill.tar.gz -C ~/.claude/skills/

# 或
unzip task-decomposer.skill.zip -d ~/.claude/skills/
```

部署后建议立即检查：

```bash
task help
```

---

### 回归验证

在修改脚本后，可以运行：

```bash
cd /path/to/task-decomposer
npm run verify
```

该脚本会同时验证仓库直接安装、打包产物解压安装与 npm 安装流程，并覆盖安装后的 `task` 命令、项目根目录识别、自定义任务目录解析、内置示例任务集、多词验证命令执行，以及工作流在校验失败时不会误完成任务。

---

### 安装后的目录结构

安装后的目录结构（默认不包含 `references/`）：

```
task-decomposer/
├── SKILL.md              # Skill 主文档
├── README.md             # 快速开始指南
├── INSTALL.md            # 本文件
├── skill.yaml            # 默认配置
├── lib/
│   └── common.sh         # 公共函数库
├── bin/
│   ├── harness.sh        # 任务管理 CLI
│   ├── task-parser.sh    # YAML 解析器
│   └── dep-graph.sh      # 依赖图分析
├── scripts/
│   ├── workflow.sh       # 工作流脚本
│   ├── task-creator.sh   # 任务创建脚本
│   ├── install.sh        # 安装脚本
│   ├── package.sh        # 打包脚本
│   └── verify.sh         # 回归验证脚本
└── state/                # 状态存储
```

---

## 排障

### 安装后命令找不到

先确认全局命令目录是否已加入 PATH：

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

如果是手动复制安装，再补充执行权限：

```bash
chmod +x ~/.claude/skills/task-decomposer/bin/*.sh
chmod +x ~/.claude/skills/task-decomposer/scripts/*.sh
```

### 如何更新

重新运行安装脚本即可：

```bash
./scripts/install.sh install
```

### 如何查看安装位置

```bash
./scripts/install.sh dir
```

### 多个工具可以共用吗

可以。为每个工具分别安装：

```bash
./scripts/install.sh install qoder
./scripts/install.sh install claude-code
./scripts/install.sh install trae
./scripts/install.sh install cursor
```

---

## 相关文档

- [README.md](./README.md) - 使用者操作手册
- [SKILL.md](./SKILL.md) - Skill 主文档
- [references/config.md](./references/config.md) - 配置参考
