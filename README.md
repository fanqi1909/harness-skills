# Harness Engineering Skills

从 Claude Code CLI 源码中提炼的 6 个 harness engineering 技巧，帮助你设计和构建 AI agent 系统。

## 使用方式

将 `skills/` 目录下的 `harness-*.md` 文件放入以下目录之一：
- `~/.claude/skills/` — 全局生效（所有项目）
- `<project>/.claude/skills/` — 仅当前项目生效

然后在 Claude Code 中通过 `/skill-name` 调用，例如：
```
/harness-02-tool-description-engineering
帮我给 search_source 工具重写 description
```

---

## Skills 分类

### 可直接用于指导编码的 Skills（Action-Oriented）

这些 skills 包含具体的模式和代码范式，调用后可以直接让 agent 按照模式编写代码。

| Skill | 文档 | 典型用法 |
|-------|------|---------|
| **02 Tool Description** | [harness-02-tool-description-engineering.md](skills/harness-02-tool-description-engineering.md) | "帮我写这个工具的 description" / "review 这个工具描述" |
| **03 Permission & Safety** | [harness-03-permission-safety-harness.md](skills/harness-03-permission-safety-harness.md) | "给这个工具加权限检查" / "设计 safePath 函数" |
| **06 Prompt Caching** | [harness-06-prompt-caching-strategy.md](skills/harness-06-prompt-caching-strategy.md) | "优化这个 prompt 的缓存命中率" / "拆分静态和动态部分" |

**使用场景**：你已经有具体的代码要写或重构，需要 agent 按照最佳实践来做。

---

### 启发式 / 架构设计 Skills（Heuristic / Design）

这些 skills 更偏向架构决策和设计思路，适合在规划阶段调用，让 agent 帮你出方案。

| Skill | 文档 | 典型用法 |
|-------|------|---------|
| **01 System Prompt Architecture** | [harness-01-system-prompt-architecture.md](skills/harness-01-system-prompt-architecture.md) | "帮我设计这个 agent 的 system prompt 结构" / "review prompt 分层" |
| **04 Agent Orchestration** | [harness-04-agent-orchestration.md](skills/harness-04-agent-orchestration.md) | "设计一个多 agent 工作流" / "coordinator/worker 怎么拆分" |
| **05 Context & Memory** | [harness-05-context-memory-management.md](skills/harness-05-context-memory-management.md) | "设计 agent 的记忆系统" / "对话太长了怎么压缩" |

**使用场景**：你在规划一个新的 agent 系统或重新设计现有架构，需要参考成熟的设计模式。

---

## 各 Skill 速查

### [01 System Prompt Architecture](skills/harness-01-system-prompt-architecture.md)
> 模块化、可缓存、分层的 system prompt 设计

- 静态/动态边界分割
- Section 注册 + 独立缓存
- 分层上下文注入（managed → user → project → local）
- Feature flag 驱动的 prompt 层级切换
- 环境信息结构化注入

### [02 Tool Description Engineering](skills/harness-02-tool-description-engineering.md)
> 工具描述不是文档，而是行为指令

- 负向路由（"不要用 Bash 做 X，用 Y"）
- 跨工具名称常量引用
- When to Use / When NOT to Use 自我门控
- 前置条件声明（"必须先 Read 才能 Edit"）
- 带推理的示例（example + reasoning）
- Fail-closed 默认值

### [03 Permission & Safety Harness](skills/harness-03-permission-safety-harness.md)
> 多层防御，fail-closed 默认

- 分层验证管线（validate → check → security → rules → prompt）
- 权限模式层级（plan < default < acceptEdits < auto < bypass）
- 规则源优先级（deny 永远胜出）
- 危险命令模式匹配（destructive patterns）
- 路径遍历防护（safePath）
- 不可变权限上下文
- 异步分类器 + 用户提示竞态处理

### [04 Agent Orchestration](skills/harness-04-agent-orchestration.md)
> Coordinator 理解问题，Worker 执行任务

- Coordinator/Worker 架构
- XML 格式的任务通知
- 工具池逐层过滤
- Fork vs Spawn vs Continue 决策
- 委派提示质量（不要偷懒委派理解）
- 并发是超能力
- 生命周期管理（spawn → stream → complete/fail/kill）

### [05 Context & Memory Management](skills/harness-05-context-memory-management.md)
> Context 是稀缺的，Memory 是廉价的

- 三层上下文组装（system / user / turn）
- CLAUDE.md 发现 + 目录树向上遍历
- 记忆类型分类（user / feedback / project / reference）
- Index + File 记忆架构
- 基于相关性的按需召回
- 对话压缩（compaction）触发与流程
- Token 预算分区
- 后台 Session Memory 提取

### [06 Prompt Caching Strategy](skills/harness-06-prompt-caching-strategy.md)
> 最好的 token 是不需要重新计算的

- 稳定内容前置
- 边界标记分割缓存作用域
- 动态内容用 attachment 注入（不要内联到 tool schema）
- Section 级缓存控制
- 去重后注入
- Sticky-on latch 防止缓存抖动
- Tool schema 保持稳定

---

## 组合使用建议

| 任务 | 推荐组合 |
|------|---------|
| 从零构建 agent | [01](skills/harness-01-system-prompt-architecture.md) → [02](skills/harness-02-tool-description-engineering.md) → [03](skills/harness-03-permission-safety-harness.md) |
| 设计多 agent 系统 | [04](skills/harness-04-agent-orchestration.md) → [01](skills/harness-01-system-prompt-architecture.md) → [05](skills/harness-05-context-memory-management.md) |
| 优化现有 agent 性能 | [06](skills/harness-06-prompt-caching-strategy.md) → [01](skills/harness-01-system-prompt-architecture.md) → [02](skills/harness-02-tool-description-engineering.md) |
| 加安全防护 | [03](skills/harness-03-permission-safety-harness.md)（核心）+ [02](skills/harness-02-tool-description-engineering.md)（工具描述加安全声明） |
| 设计记忆系统 | [05](skills/harness-05-context-memory-management.md)（核心）+ [06](skills/harness-06-prompt-caching-strategy.md)（缓存策略） |
