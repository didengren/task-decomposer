# Task Decomposer Skill

将项目规划文档拆解为可执行任务，管理任务依赖和状态，驱动 AI 完成开发工作流。

这是一个以 skill 形态交付的能力包，npm 包只是分发载体，`task` 是随 skill 一起安装的命令行入口。

**完全独立**：本 skill 不依赖任何外部工具，可独立运行。

**多项目适配**：通过配置文件支持不同项目结构。

---

## 操作手册

### 适合谁

如果你要做下面几件事，这份 README 就够用：
- 安装 `task` 命令
- 安装一个可被 AI 工具识别和复用的 skill 包
- 在项目里接入任务拆解工作流
- 按任务依赖顺序推进开发
- 打包 skill 给别人分发

### 最短路径

```bash
npm install -g @bicorne/task-decomposer

cd /path/to/your-project
mkdir -p docs/plans docs/tasks
task init
task ready
task show PHASE-1-1-1
```

---

## 1. 安装

### 方式 A：从 npm 安装

```bash
npm install -g @bicorne/task-decomposer
```

### 方式 B：从 GitHub 安装

```bash
npm install -g github:didengren/task-decomposer
```

或者：

```bash
npm install -g git+https://github.com/didengren/task-decomposer.git
```

### 方式 C：直接从仓库安装

```bash
cd /path/to/task-decomposer
./scripts/install.sh install
```

如果要显式指定安装目标工具：

```bash
./scripts/install.sh install qoder
./scripts/install.sh install claude-code
./scripts/install.sh install trae
./scripts/install.sh install cursor
./scripts/install.sh install generic
```

### 方式 D：从打包产物安装

以 Claude Code 为例：

```bash
mkdir -p ~/.claude/skills
tar -xzvf task-decomposer.skill.tar.gz -C ~/.claude/skills/
```

或者：

```bash
mkdir -p ~/.claude/skills
unzip task-decomposer.skill.zip -d ~/.claude/skills/
```

### 安装后检查

```bash
task help
```

如果命令找不到，通常是 `~/.local/bin` 没有加入 PATH。

---

## 2. 准备项目

进入你的业务项目根目录，至少准备以下结构：

```text
your-project/
├── docs/
│   ├── plans/
│   │   ├── spec.md
│   │   └── tasks.md
│   └── tasks/
│       ├── PHASE-1-1-1.yaml
│       └── ...
└── .skill.yaml           # 可选
```

最少需要：
- `docs/plans/spec.md`
- `docs/plans/tasks.md`
- `docs/tasks/PHASE-*.yaml`

如果目录还不存在：

```bash
cd /path/to/your-project
mkdir -p docs/plans docs/tasks
```

如果还没有任务文件，可以先让 AI 根据规划文档生成到 `docs/tasks/`。

### 可选：自定义配置

默认目录是 `docs/plans` 与 `docs/tasks`。如果你的项目结构不同，可在项目根目录创建 `.skill.yaml`：

```yaml
paths:
  tasks_dir: docs/tasks
  plans_dir: docs/plans

documents:
  spec: docs/plans/spec.md
  tasks: docs/plans/tasks.md
```

查看当前配置：

```bash
task config
```

---

## 3. 开始使用

### 第一次进入项目

```bash
cd /path/to/your-project
task init
```

这一步会初始化任务状态存储，并按任务 YAML 中定义的状态建立本地状态。

### 推荐工作流

```bash
task ready
task show PHASE-1-1-1
task start PHASE-1-1-1
task test PHASE-1-1-1
task complete PHASE-1-1-1
task ready
task progress
```

这套流程分别表示：
- 找到当前可执行任务
- 阅读任务详情与验收标准
- 开始任务
- 运行该任务定义的验证命令
- 标记任务完成
- 查看新解锁的任务
- 查看整体推进进度

---

## 4. 常用命令

### 查看类命令

```bash
task list
task list 1
task ready
task blocked
task show PHASE-1-1-1
task tree PHASE-1-1-1
task progress
```

- `task list`：查看全部任务
- `task list 1`：只看某个 phase
- `task ready`：查看当前可开始的任务
- `task blocked`：查看被依赖阻塞的任务
- `task show <任务ID>`：查看任务详情
- `task tree <任务ID>`：查看依赖树
- `task progress`：查看整体进度

### 执行类命令

```bash
task start PHASE-1-1-1
task test PHASE-1-1-1
task complete PHASE-1-1-1
```

- `task start <任务ID>`：开始任务，并检查依赖
- `task test <任务ID>`：执行任务定义里的验证命令
- `task complete <任务ID>`：标记完成，并显示新的 ready 任务

如需跳过依赖检查：

```bash
task start --force PHASE-1-1-1
```

### 校验命令

```bash
task validate
```

用于检查所有任务 YAML 的字段、状态、优先级和类型是否合法。

---

## 5. 打包分发

### 分发 skill 安装包

如果你要把当前 skill 分发给别人，可在仓库根目录运行：

```bash
cd /path/to/task-decomposer
./scripts/package.sh tar
./scripts/package.sh zip
./scripts/package.sh all
```

默认会在上级目录生成：
- `task-decomposer.skill.tar.gz`
- `task-decomposer.skill.zip`

输出到指定目录：

```bash
./scripts/package.sh tar /tmp/task-decomposer-packages
```

### 发布到 npm

当前 npm 包名使用更稳妥的 scoped 形式：`@bicorne/task-decomposer`

发布前先在仓库根目录执行：

```bash
npm run release:check
```

推荐发布流程：

```bash
npm run release:check
npm version patch
git push origin main --follow-tags
```

如果你走本地发布：

```bash
npm publish --access public
```

如果你走 GitHub Actions 自动发布：

```bash
npm version patch
git push origin main --follow-tags
```

如果你手动打 tag，必须保证 git tag 与 `package.json` 中的版本完全一致，例如：

```bash
git tag v1.0.1
```

对应：

```json
{
  "version": "1.0.1"
}
```

需要提前在 GitHub 仓库中配置 `NPM_TOKEN`。工作流会在发布后执行一次全新前缀目录安装，再运行 `task help` 作为 smoke test。

---

## 6. 示例体验

如果你想先体验一遍完整流程，可以直接使用仓库自带示例项目：

```bash
cp -R references/example-project /tmp/task-decomposer-demo
cd /tmp/task-decomposer-demo
task init
task ready
task show PHASE-1-1-1
task test PHASE-1-1-1
task complete PHASE-1-1-1
task ready
```

---

## 7. 维护者验证

如果你修改了脚本，建议在仓库根目录运行：

```bash
npm run verify
```

它会同时验证：
- 直接安装流程
- 打包后再解压安装流程
- npm 安装流程
- `task` 命令是否可用
- 自定义项目目录与示例项目是否工作正常

---

## 相关文档

- [INSTALL.md](./INSTALL.md) - 安装、卸载、打包、回归验证
- [SKILL.md](./SKILL.md) - Skill 行为说明与任务格式
- [references/config.md](./references/config.md) - 完整配置参考
- [references/example-project](./references/example-project) - 最小示例项目
- 项目任务文件: `docs/tasks/*.yaml`
- 项目规划文档: `docs/plans/spec.md`, `docs/plans/tasks.md`
