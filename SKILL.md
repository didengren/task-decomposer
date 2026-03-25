---
name: "task-decomposer"
description: "将项目规划文档拆解为可执行任务，管理任务依赖和状态，驱动 AI 完成开发工作流，支持任务自动闭环执行。当用户提到任务、阶段、依赖、项目规划、开发工作流、进度跟踪，或想要拆分计划、创建任务、管理工作流、自动执行任务时使用此技能——即使他们没有明确要求'任务管理'或'task-decomposer'。"
---

# Task Decomposer Skill

将项目规划文档拆解为可执行任务，管理任务依赖和状态，驱动 AI 完成开发工作流，支持任务自动闭环执行。

---

## 安装

```bash
npm install -g @bicorne/task-decomposer
```

如果你是在本地开发此仓库，也可以继续使用：

```bash
cd /path/to/task-decomposer
./scripts/install.sh install
```

详细的安装位置、PATH 配置、卸载、打包、npm 发布和回归验证流程请查看 `INSTALL.md`。

---

## 快速开始

安装后，在目标项目目录下准备以下内容：

- `docs/plans/spec.md`
- `docs/plans/tasks.md`
- `docs/tasks/PHASE-*.yaml` 任务文件

如果还没有任务文件，先让 AI 根据规划文档生成到 `docs/tasks/`。想快速体验可直接复制 `references/example-project/`。

```bash
# 初始化状态
task init

# 查看当前配置
task config

# 查看帮助
task help

# 查看可执行任务
task ready

# 查看任务详情
task show PHASE-1-1-1

# 开始任务
task start PHASE-1-1-1

# 完成任务
task complete PHASE-1-1-1

# 查看进度
task progress
```

### 命令速查表

| 命令 | 说明 |
|------|------|
| `list [phase]` | 列出所有任务或指定阶段任务 |
| `show <task_id>` | 显示任务详情 |
| `status <task_id> [status]` | 获取或设置任务状态 |
| `start [--force] <task_id>` | 开始任务（检查依赖） |
| `complete <task_id>` | 完成任务 |
| `progress` | 显示进度摘要 |
| `ready` | 列出可执行任务 |
| `blocked` | 列出阻塞任务 |
| `tree [task_id]` | 显示依赖树 |
| `validate` | 验证所有任务文件 |
| `test <task_id>` | 运行任务验证命令 |
| `config` | 显示当前配置 |

---

## 文档分工

- `README.md`：面向使用者的快速上手与示例
- `INSTALL.md`：安装、打包、卸载、回归验证
- `references/config.md`：路径与配置项参考

---

## 核心能力

### 1. 自动任务拆分

AI 可以直接读取 `docs/plans/` 目录中的规划文档，自动生成任务文件到 `docs/tasks/` 目录。

**工作流程：**

```
┌─────────────────────────────────────────────────────────────┐
│                   自动任务拆分流程                           │
├─────────────────────────────────────────────────────────────┤
│  1. READ ─────→ 读取规划文档                                 │
│       │           docs/plans/spec.md                        │
│       │           docs/plans/tasks.md                       │
│       ▼                                                     │
│  2. PARSE ────→ 解析任务结构                                 │
│       │           识别 Phase、Subphase、Task                 │
│       │           提取任务标题、描述、依赖                    │
│       ▼                                                     │
│  3. GENERATE ─→ 生成任务文件                                 │
│       │           按模板格式生成 YAML 文件                   │
│       │           写入 docs/tasks/ 目录                      │
│       ▼                                                     │
│  4. VALIDATE ─→ 验证任务文件                                 │
│                   检查必填字段、枚举值与依赖关系              │
└─────────────────────────────────────────────────────────────┘
```

**触发条件：**

当用户说以下内容时，AI 应自动执行任务拆分：
- "拆分任务" / "生成任务文件"
- "初始化任务" / "创建任务"
- "根据规划文档生成任务"
- "同步任务列表"

### 2. 任务文件模板

任务文件使用以下 YAML 格式：

```yaml
id: PHASE-{phase}-{subphase}-{seq}
type: feat|fix|refactor|test|docs
title: 任务标题（简洁明确）
priority: high|medium|low
phase: 1|2|3|4|5|6
dependencies: []

docs_to_read:
  - docs/plans/spec.md
  - docs/plans/tasks.md

spec:
  description: |
    详细描述任务目标、实现范围和完成标准。
  files:
    - src/path/to/file.py
  context:
    - docs/plans/spec.md#章节号

acceptance_criteria:
  - 验收标准1
  - 验收标准2

implementation:
  steps:
    - step: 步骤描述
      details: 详细说明

validation:
  commands:
    - pytest tests/
  manual_checks:
    - 手动验证项

status: pending
```

### 3. 任务 ID 命名规则

```
PHASE-{phase}-{subphase}-{sequence}

示例：
- PHASE-1-1-1  → Phase 1, Subphase 1, Task 1
- PHASE-2-3-4  → Phase 2, Subphase 3, Task 4
- PHASE-6-1-7  → Phase 6, Subphase 1, Task 7
```

---

## AI 执行指南

### 任务拆分执行步骤

当用户请求拆分任务时，AI 应按以下步骤执行：

#### Step 1: 读取规划文档

使用 Read 工具读取以下文件：
- `docs/plans/spec.md` - 技术规格说明书
- `docs/plans/tasks.md` - 任务清单（格式不限，AI 自行理解）

#### Step 2: 理解文档内容

**重要：不对 `tasks.md` 格式作任何假设。**

AI 应该：
1. 理解文档的整体结构（无论使用何种格式）
2. 识别任务层级关系（Phase → Subphase → Task）
3. 提取任务关键信息（标题、描述、依赖、验收标准等）
4. 根据文档内容推断任务 ID 编号规则

**支持的文档格式示例：**

```markdown
## Phase 1: 基础框架搭建
### 1.1 项目初始化
- [ ] **T1.1.1** 创建项目目录结构
```

```markdown
# 任务列表

| ID | 任务 | 阶段 | 依赖 |
|----|------|------|------|
| 1-1-1 | 创建项目目录结构 | Phase 1 | - |
```

```markdown
# Phase 1

## 1.1 项目初始化

1. 创建项目目录结构
   - 创建 src/ 目录
   - 创建 data/ 目录
```

**AI 应该能够理解以上任意格式，并提取任务信息。**

#### Step 3: 生成任务文件

对每个任务，生成对应的 YAML 文件：

1. **确定任务 ID**: `PHASE-{phase}-{subphase}-{seq}`
2. **提取任务信息**:
   - title: 任务标题
   - description: 任务描述（从任务详情提取）
   - dependencies: 依赖关系
   - files: 相关文件
   - acceptance_criteria: 验收标准
   - implementation_steps: 实现步骤
   - validation_commands: 验证命令

3. **写入文件**: `docs/tasks/PHASE-{phase}-{subphase}-{seq}.yaml`

#### Step 4: 验证生成的文件

检查：
- YAML 格式正确
- 依赖关系有效（引用的任务 ID 存在）
- 必填字段完整

---

## 任务状态管理

### 状态值

| 状态 | 说明 |
|------|------|
| `pending` | 待处理 |
| `in_progress` | 进行中 |
| `completed` | 已完成 |
| `blocked` | 被阻塞 |

### 状态更新方式

**方式一：命令行**
```bash
task status PHASE-1-1-1 in_progress
task complete PHASE-1-1-1
```

**方式二：AI 直接修改**

AI 直接修改任务文件中的 `status` 字段：

```yaml
status: in_progress  # 或 completed, pending, blocked
```

---

## 自动闭环工作流

当用户请求执行任务时，AI 会自动完成以下步骤：

```
┌─────────────────────────────────────────────────────────────┐
│                    自动闭环工作流                             │
├─────────────────────────────────────────────────────────────┤
│  1. FIND ─────→ 查找可执行任务                               │
│       │           读取 docs/tasks/*.yaml                    │
│       │           找到 status=pending 且依赖已满足的任务     │
│       ▼                                                     │
│  2. START ────→ 开始任务                                    │
│       │           更新 status=in_progress                   │
│       ▼                                                     │
│  3. READ ─────→ 阅读必读文档                                 │
│       │           docs_to_read 字段指定的文档                │
│       ▼                                                     │
│  4. IMPLEMENT → 执行实现步骤                                 │
│       │           implementation.steps 字段指定的步骤       │
│       ▼                                                     │
│  5. VALIDATE ─→ 运行验证命令                                 │
│       │           validation.commands 字段指定的命令        │
│       ▼                                                     │
│  6. COMPLETE ─→ 标记任务完成                                 │
│                   更新 status=completed                     │
└─────────────────────────────────────────────────────────────┘
```

---

## 使用示例

### 示例 1：自动拆分任务

**Input:**
```
用户: 根据规划文档拆分任务
```

**AI 执行步骤:**
```
1. 读取 docs/plans/spec.md 和 docs/plans/tasks.md
2. 解析 Phase 结构和任务列表
3. 为每个任务生成 YAML 文件
4. 输出生成结果摘要
```

**Output:**
```
AI: 已完成任务拆分，生成以下任务文件：

    Phase 1 (基础框架搭建): 8 个任务
      - PHASE-1-1-1.yaml  创建项目目录结构
      - PHASE-1-1-2.yaml  配置 pyproject.toml
      ...

    总计: 63 个任务文件已生成
```

### 示例 2：执行下一个任务

**Input:**
```
用户: 执行下一个任务
```

**Output:**
```
AI: 正在查找可执行任务...
    找到: PHASE-2-1-1
    
    ═══════════════════════════════════════
      Task: PHASE-2-1-1
    ═══════════════════════════════════════
    
    Title:    实现 storage/vector_store.py
    Type:     feat
    Priority: high
    Phase:    2
    
    Dependencies: [已完成]
    
    ───────────────────────────────────────
    开始执行任务...
```

### 示例 3：查看进度

**命令行:**
```bash
task progress
```

**Output:**
```
Progress Summary
================
Total:       63
Completed:   15
In Progress: 2
Pending:     46
Ready:       5
Blocked:     3

[████░░░░░░░░░░░░░░░░] 25%

可执行任务:
- PHASE-2-1-1 (实现向量存储)
- PHASE-2-2-1 (实现索引层存储)
```

### 示例 4：查看依赖树

**命令行:**
```bash
task tree PHASE-4-2-2
```

**Output:**
```
依赖树:
○ PHASE-4-2-2
  ✓ PHASE-2-1-1
    ✓ PHASE-1-1-1
    ✓ PHASE-1-2-1
  ○ PHASE-3-4-5
    ✓ PHASE-3-1-1
    ✓ PHASE-3-2-1

状态说明: ✓ 已完成, ○ 待处理, ► 进行中
阻塞原因: PHASE-3-4-5 未完成
```

---

## 配置

项目可在根目录创建 `.skill.yaml` 自定义路径：

```yaml
paths:
  tasks_dir: docs/tasks
  plans_dir: docs/plans
  task_template: docs/tasks/_template.yaml.example

documents:
  spec: docs/plans/spec.md
  tasks: docs/plans/tasks.md
```

---

## 最佳实践

1. **按顺序执行** - 优先完成无依赖的任务
2. **定期检查进度** - 使用 `task progress` 查看完成情况
3. **验证完成** - 确保所有验收标准满足后再标记完成
4. **阅读文档** - 执行任务前务必阅读 `docs_to_read` 中的文档
5. **保持同步** - 规划文档更新后重新拆分任务

---

## 文件结构

```
~/.trae-cn/skills/task-decomposer/    # Skill 安装目录
├── SKILL.md              # Skill 主文档
├── skill.yaml            # 默认配置
├── bin/
│   ├── task              # 全局命令入口
│   ├── harness.sh        # 任务管理 CLI
│   └── ...
└── scripts/
    └── install.sh        # 安装脚本

~/.local/bin/task                     # 全局命令（在 PATH 中）

project/                              # 项目目录
├── docs/
│   ├── plans/
│   │   ├── spec.md      # 技术规格说明书
│   │   └── tasks.md     # 任务清单
│   └── tasks/
│       ├── _template.yaml.example
│       ├── PHASE-1-1-1.yaml
│       └── ...
└── .skill.yaml          # 项目配置（可选）
```
