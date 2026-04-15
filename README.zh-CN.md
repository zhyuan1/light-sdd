# light-sdd

轻量、可编排、可插拔的 Spec-Driven Development 工作流，为 Claude Code 设计。

SDD 是一个薄编排层。它不实现核心能力 -- 而是将工作委派给 OpenSpec、Superpowers、ECC 或你选择的任何框架中经过验证的 skill。

## SDD 做什么

- **编排** -- 定义流程：brainstorm、propose、spec、plan、code、review、verify、ship
- **校验** -- 每一步之后，对照 schema 检查产物质量
- **引导** -- 根据已有产物，告诉你下一步该做什么
- **委派** -- 核心工作交给 OpenSpec、Superpowers 或你偏好的 skill

## 架构

```
Schema (schema.yaml)         -- 内容约束：每个产物应该包含什么
    |
Templates (templates/)       -- 接口契约：每个产物的标准格式模板
    |
Actions (skills/)            -- 流程编排：前置检查 -> 委派 -> 后置检查
```

每个 Action skill 遵循三段式结构：

1. **Pre-check**（SDD 自有）：校验前置依赖、定位 change 目录
2. **Core Execution**（委派）：调用配置的底层 skill
3. **Post-check**（SDD 自有）：review 循环、格式校验、下一步引导

## 安装

```bash
# 用户级（所有项目通用）
./install.sh

# 使用中文模板
./install.sh --lang zh-CN

# 项目级（仅当前项目）
./install.sh --project

# 自定义目标目录
./install.sh --target .claude-internal

# 组合选项
./install.sh --target .claude-internal --lang zh-CN

# 验证安装完整性
./install.sh --check

# 更新到最新版本
./install.sh --update

# 卸载
./install.sh --uninstall
```

### 前置依赖

SDD 默认委派给以下框架：

| 框架 | 用于 | 安装方式 |
|------|------|---------|
| [OpenSpec](https://github.com/fission-ai/openspec) | propose, ff, verify, ship | `npm i -g @fission-ai/openspec` |
| [Superpowers](https://github.com/obra/superpowers) | brainstorm, plan, code, review-code, verify, ship | 将 skills 复制到 `~/.claude/skills/` |

如果某个框架未安装，每个 SDD action 都列出了可替代的 skill（通常是 ECC 的对应 skill）。

## 工作流

### 完整流程（大功能）

```
sdd-brainstorm -> sdd-propose -> sdd-ff -> sdd-review-spec
                                               |
                                 sdd-plan -> sdd-code (循环)
                                               |
                           sdd-review-code -> sdd-verify -> sdd-ship
```

### 最小流程（小修复）

```
sdd-propose -> sdd-ff -> sdd-code -> sdd-ship
```

### 渐进采用

从核心闭环开始，按需添加质量门禁：

| 级别 | Actions | 获得什么 |
|------|---------|---------|
| 基础 | propose, ff, code, ship | Spec 驱动开发 |
| 审查 | + review-spec, review-code | 质量门禁 |
| 完整 | + brainstorm, plan, verify | 完整工程纪律 |

随时使用 `sdd-status` 查看当前进度。

## 10 个 Action

| Action | 用途 | 委派给 |
|--------|------|-------|
| `/sdd-brainstorm` | 发散探索，确定方向前的头脑风暴 | Superpowers `brainstorming` |
| `/sdd-propose` | 创建变更提案 | OpenSpec `continue-change` |
| `/sdd-ff` | 批量生成缺失的产物 | OpenSpec `ff-change` |
| `/sdd-plan` | 为当前任务批次创建详细执行计划 | Superpowers `writing-plans` |
| `/sdd-code` | 以 TDD 纪律实现任务 | Superpowers `test-driven-development` + `executing-plans` + `systematic-debugging` |
| `/sdd-review-spec` | 审查 spec 的完整性和一致性 | SDD subagent（无外部委派） |
| `/sdd-review-code` | 双阶段代码审查 | Phase 1: SDD spec 合规审查，Phase 2: Superpowers `requesting-code-review` |
| `/sdd-verify` | 验证实现是否满足所有 spec | OpenSpec `verify-change` + Superpowers `verification-before-completion` |
| `/sdd-ship` | 同步 spec、归档变更、完成分支 | OpenSpec `sync-specs` + `archive-change` + Superpowers `finishing-a-development-branch` |
| `/sdd-status` | 扫描产物、报告进度 | SDD 自有逻辑（无委派） |

## Artifact 依赖链

```
brainstorm.md -> proposal.md -> specs/ -> design.md -> tasks.md -> plan.md
   (可选)          (必需)       (必需)     (可选)       (必需)      (可选)
```

所有产物存放在 `.sdd/changes/<change-name>/` 下。进度通过文件存在性推断 -- 不额外追踪状态。

## Change 目录结构

```
.sdd/changes/<change-name>/
  brainstorm.md          # 可选
  proposal.md            # 必需
  specs/
    <capability>/spec.md # 必需，每个能力一个
  design.md              # 可选
  tasks.md               # 必需
  plan.md                # 可选
  reviews/               # 由 review/verify action 生成
    spec-review-*.md
    code-review-*.md
    verification-*.md
```

## Override 机制

### Skill 替换

每个 Action 的 SKILL.md 包含 Override 部分，列出可替代的 skill。要切换默认委派目标，编辑 skill 文件中的委派目标即可。例如：

**默认**（已安装 Superpowers）：
```
Core Execution: invoke brainstorming
```

**Override**（改用 ECC）：
```
Core Execution: invoke think
```

### 转场抑制

部分 Superpowers skill 内置了自动转场逻辑，会在完成后自动调用下一个 skill。SDD 通过显式 Override 抑制这些行为，确保编排节奏由 SDD 控制：

| SDD Action | 被抑制的转场 | 说明 |
|------------|------------|------|
| `sdd-brainstorm` | brainstorming -> writing-plans | brainstorming 完成后会自动启动 writing-plans，SDD 拦截并引导到 `/sdd-propose` |
| `sdd-plan` | writing-plans -> executing-plans | writing-plans 完成后会提示选择执行方式，SDD 拦截并引导到 `/sdd-code` |
| `sdd-code` | executing-plans -> git-worktrees (前) / finishing-branch (后) | executing-plans 前后都有自动转场，SDD 拦截，workspace 和分支收尾由 `/sdd-ship` 负责 |

## Schema

`schema.yaml` 定义了全部 7 种产物类型的内容约束和来源标注（provenance）规范。它只规定每个产物必须包含哪些 section，不涉及流程或执行逻辑。Templates 是 Schema 层和 Action 层之间的接口契约。

## 来源标注（Provenance）

每个生成的产物都携带 YAML frontmatter，记录其来源：

```yaml
---
generated_by: brainstorming        # 实际执行的底层 skill
sdd_action: sdd-brainstorm         # 编排层的 SDD action
timestamp: "2026-04-15T10:00:00Z"  # 生成时间
---
```

用途：排查产物质量问题时快速定位生成源、审计 Override 替换记录、团队交接时理解产物历史。

## 模板语言

模板提供两种语言版本：

| 语言 | 目录 | 安装方式 |
|------|------|---------|
| 英文（默认） | `templates/` | `./install.sh` |
| 中文 | `templates/zh-CN/` | `./install.sh --lang zh-CN` |

两种语言保持相同的 section 结构和 provenance frontmatter，schema 校验对两者均有效。

## License

MIT
