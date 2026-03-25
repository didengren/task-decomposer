# Task Decomposer 配置参考

本文档详细说明 Task Decomposer Skill 的配置选项。

---

## 配置文件位置

配置文件有两个层级：

| 文件 | 位置 | 优先级 |
|------|------|--------|
| 项目配置 | `<project_root>/.skill.yaml` | 高 |
| Skill 默认配置 | `<skill_dir>/skill.yaml` | 低 |

配置值按优先级读取：**项目配置 > Skill 默认配置 > 硬编码默认值**

说明：
- 标量配置按优先级覆盖
- 列表配置按整段覆盖，不做逐项合并
- 项目根目录发现优先依赖内置标记和 Skill 默认标记

---

## 完整配置示例

```yaml
# .skill.yaml - 项目级配置

# ========================================
# 项目发现设置
# ========================================
project:
  # 用于识别项目根目录的标记文件
  markers:
    - .skill.yaml
    - pyproject.toml
    - package.json
    - Cargo.toml
    - go.mod
    - .git
    - docs/tasks

# ========================================
# 路径配置（相对于项目根目录）
# ========================================
paths:
  # 任务文件目录
  tasks_dir: docs/tasks
  
  # 规划文档目录
  plans_dir: docs/plans
  
  # 任务模板文件
  task_template: docs/tasks/_template.yaml.example
  
  # 状态存储目录（相对于 skill 目录）
  state_dir: state

# ========================================
# 文档路径
# ========================================
documents:
  # 技术规格文档
  spec: docs/plans/spec.md
  
  # 任务清单文档
  tasks: docs/plans/tasks.md
  
  # 每个任务默认必读文档
  default_docs_to_read:
    - docs/plans/spec.md
    - docs/plans/tasks.md

# ========================================
# 任务 ID 格式
# ========================================
task_id:
  # 正则表达式模式
  pattern: "^PHASE-[0-9]+-[0-9]+-[0-9]+$"
  
  # 示例
  example: "PHASE-1-2-3"
  
  # 说明
  description: "PHASE-{phase}-{subphase}-{sequence}"

# ========================================
# 状态值
# ========================================
status:
  # 有效状态值
  valid_values:
    - pending
    - in_progress
    - completed
    - blocked
  
  # 默认状态
  default: pending

# ========================================
# 验证设置
# ========================================
validation:
  # 任务文件必填字段
  required_fields:
    - id
    - type
    - title
    - priority
    - phase
    - status
  
  # 有效任务类型
  valid_types:
    - feat
    - fix
    - refactor
    - test
    - docs
  
  # 有效优先级
  valid_priorities:
    - high
    - medium
    - low
```

---

## 不同项目类型配置

### Python 项目（默认）

```yaml
paths:
  tasks_dir: docs/tasks
  plans_dir: docs/plans

documents:
  spec: docs/plans/spec.md
  tasks: docs/plans/tasks.md
```

### Node.js 项目

```yaml
paths:
  tasks_dir: .tasks
  plans_dir: .plans

documents:
  spec: .plans/spec.md
  tasks: .plans/tasks.md

project:
  markers:
    - package.json
    - .tasks
```

### Monorepo 项目

```yaml
paths:
  tasks_dir: packages/shared/docs/tasks
  plans_dir: packages/shared/docs/plans

documents:
  spec: packages/shared/docs/plans/spec.md
  tasks: packages/shared/docs/plans/tasks.md
```

### Go 项目

```yaml
paths:
  tasks_dir: docs/tasks
  plans_dir: docs/plans

project:
  markers:
    - go.mod
    - docs/tasks
```

---

## 配置项详解

### paths.tasks_dir

任务 YAML 文件存放目录。

- **类型**: 字符串
- **默认值**: `docs/tasks`
- **示例**: `docs/tasks`, `.tasks`, `packages/shared/docs/tasks`

### paths.plans_dir

规划文档存放目录。

- **类型**: 字符串
- **默认值**: `docs/plans`
- **示例**: `docs/plans`, `.plans`

### paths.task_template

任务模板文件路径，用于创建新任务时的模板。

- **类型**: 字符串
- **默认值**: `docs/tasks/_template.yaml.example`
- **说明**: `scripts/task-creator.sh template` 会读取该路径

### paths.state_dir

任务状态根目录，相对于 skill 目录。实际状态文件会按项目隔离存放在该目录下的子目录中。

- **类型**: 字符串
- **默认值**: `state`

### documents.default_docs_to_read

每个任务默认需要阅读的文档列表。

- **类型**: 字符串数组
- **默认值**: `["docs/plans/spec.md", "docs/plans/tasks.md"]`
- **说明**: `scripts/task-creator.sh create` 会将该列表写入新任务的 `docs_to_read`

### task_id.pattern

任务 ID 的正则表达式模式。

- **类型**: 字符串（正则表达式）
- **默认值**: `^PHASE-[0-9]+-[0-9]+-[0-9]+$`
- **注意**: 当前 CLI 的任务文件发现与示例流程仍基于 `PHASE-*-*-*` 文件命名，修改该模式前应同时调整任务文件命名与相关脚本

### project.markers

用于识别项目根目录的标记文件或目录。

- **类型**: 字符串数组
- **默认值**: `[".skill.yaml", "pyproject.toml", "package.json", "Cargo.toml", "go.mod", ".git", "docs/tasks"]`
- **说明**: 项目根目录发现阶段会先使用内置默认值和 Skill 默认配置；项目级 `.skill.yaml` 中的 `project.markers` 更适合做已发现项目后的配置记录，而不是替代初始根目录发现

---

## 查看当前配置

使用 `config` 命令查看当前生效的配置：

```bash
./bin/harness.sh config
```

输出示例：

```
Task Decomposer Configuration
==============================

Project Root: /path/to/project
Skill Dir:    /path/to/skill

Paths:
  Tasks Dir:    /path/to/project/docs/tasks
  Plans Dir:    /path/to/project/docs/plans
  Task Template: /path/to/project/docs/tasks/_template.yaml.example
  State Dir:    /path/to/skill/state
  Project State: /path/to/skill/state/project-123456789

Documents:
  Spec:  /path/to/project/docs/plans/spec.md
  Tasks: /path/to/project/docs/plans/tasks.md

Config Files:
  Project Config: /path/to/project/.skill.yaml (active)
  Skill Config:   /path/to/skill/skill.yaml (active)
```
