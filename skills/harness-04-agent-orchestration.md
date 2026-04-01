---
name: "Harness 04: Agent Orchestration"
description: "Design multi-agent systems with coordinator patterns, delegation rules, and lifecycle management. Use when building multi-agent workflows."
whenToUse: "When designing multi-agent systems, sub-agent delegation, or coordinator/worker architectures."
---

# Harness Engineering: Agent Orchestration

## Core Principle: Coordinator Synthesizes, Workers Execute

The coordinator understands the problem and directs workers. Workers execute and report. The coordinator NEVER delegates understanding.

## Pattern 1: Coordinator/Worker Architecture

```
User Message
     |
Coordinator (main agent)
     |--- Agent Tool ---> Worker A (background, isolated tools)
     |--- Agent Tool ---> Worker B (background, isolated tools)
     |--- Agent Tool ---> Worker C (background, isolated tools)
     |
     v
<task-notification> arrives between turns
     |
Coordinator synthesizes results, directs next phase
```

**Key rules**:
- Coordinator has full tool access + Agent/SendMessage/TaskStop
- Workers have restricted tool pools (no spawning sub-workers by default)
- Workers run in background, report via structured notifications
- Coordinator MUST synthesize before delegating follow-up

## Pattern 2: Worker Result Notification Format

Workers report back via structured XML in user-role messages:

```xml
<task-notification>
  <task-id>worker-abc-123</task-id>
  <status>completed|failed|killed</status>
  <summary>Human-readable outcome</summary>
  <result>Worker's final text output</result>
  <usage>
    <total_tokens>15234</total_tokens>
    <tool_uses>8</tool_uses>
    <duration_ms>12500</duration_ms>
  </usage>
</task-notification>
```

**Why**: Structured format lets the coordinator parse results programmatically while remaining readable.

## Pattern 3: Tool Pool Filtering for Workers

Workers get progressively restricted tool access:

```
Main Thread    → All tools (no filtering)
Built-in Agent → All tools minus globally-disallowed
Custom Agent   → All tools minus globally-disallowed minus custom-disallowed
Background     → Only async-safe tools (no interactive UI)
```

Filtering rules:
```typescript
// Never available to any agent
ALL_AGENT_DISALLOWED_TOOLS = ['ExitPlanMode', 'EnterPlanMode', ...]

// Only blocked for user-defined agents
CUSTOM_AGENT_DISALLOWED_TOOLS = ['Agent', 'TeamCreate', ...]

// Background agents can't show UI
if (isBackground) filter(tool => tool.supportsAsync)
```

## Pattern 4: Fork vs. Spawn Decision

**Fork** (same context, inherits conversation):
- Use when intermediate tool output isn't worth keeping in parent context
- Worker sees full conversation history
- Prompt is a DIRECTIVE (what to do), not context (already inherited)

**Spawn** (fresh context, new agent type):
- Use for independent work that doesn't need parent history
- Prompt must include ALL relevant context
- More expensive but fully isolated

**Continue** (SendMessage to existing worker):
- Use when worker has accumulated relevant context
- Worker resumes with full prior history preserved
- Cheaper than spawning fresh if context overlap is high

## Pattern 5: Delegation Prompt Quality

Bad delegation (lazy, pushes understanding to worker):
```
"Based on the findings, fix the bug."
```

Good delegation (synthesized, provides context):
```
"Fix the null pointer in src/auth/validate.ts:142.
The issue: `user.roles` is undefined when SAML SSO users
haven't been assigned roles yet. The SAML adapter
(src/adapters/saml.ts:89) creates users without the
roles field. Add a default empty array in the adapter's
createUser() method."
```

**Rules**:
- Include file paths, line numbers, error messages
- Explain what you've already learned
- Describe expected outcome
- Never say "based on findings" — prove you understood

## Pattern 6: Concurrency as Superpower

Launch independent workers in parallel, not sequentially:

```typescript
// Bad: sequential
await agent("research API docs")
await agent("audit test coverage")
await agent("check dependencies")

// Good: parallel
Promise.all([
  agent("research API docs"),
  agent("audit test coverage"),
  agent("check dependencies"),
])
```

**When to parallelize**: Tasks with no data dependencies
**When NOT to**: Task B needs Task A's output

## Pattern 7: Agent Definition Schema

Each agent type declares its capabilities:

```typescript
type AgentDefinition = {
  agentType: string          // "worker", "researcher", "reviewer"
  source: 'built-in' | 'custom'
  whenToUse: string          // Guidance for coordinator
  prompt: string             // Agent's system prompt
  tools?: string[]           // Allowlist (undefined = all available)
  disallowedTools?: string[] // Denylist
  mcpServers?: string[]      // Agent-specific MCP access
  model?: string             // Model override (e.g., haiku for fast tasks)
}
```

## Pattern 8: One-Shot vs. Continuable Agents

Some agents run once and report. Others can be continued:

```typescript
ONE_SHOT_AGENTS = ['Explore', 'Plan']
// Skip agentId/SendMessage trailer in output (~135 chars saved)
// Cannot be continued with SendMessage
```

**Why**: One-shot agents save token overhead by not including continuation instructions.

## Pattern 9: Lifecycle Management

Background agent lifecycle:

```
Spawn → Stream Loop → Complete/Fail/Kill
  |        |             |
  |        |             +-- Enqueue notification
  |        +-- Update progress (token count, tool uses, activity)
  +-- Register in task store

Post-completion:
  1. Mark task completed (unblocks TaskOutput immediately)
  2. Run handoff classifier (non-blocking)
  3. Enqueue notification with result
```

**Error handling**:
- AbortError → killed status
- Exception → failed status with error message
- Always cleanup: clear skills, dump state

## Pattern 10: Handoff Classification

When a worker completes in auto mode, classify its work:

```
Worker completes
  → Build transcript of worker's actions
  → Call safety classifier: "Review for dangerous actions"
  → Decision: Allow / Block / Unavailable
  → If blocked: warn coordinator before surfacing result
```

**Why**: Workers running autonomously might take actions the user wouldn't approve. Classify before the coordinator acts on results.

## Anti-Patterns

1. **Single-agent workflows when parallelism applies** — waste of time
2. **Re-delegating within a fork** — "I'm a fork, so I'll fork again" creates overhead
3. **Predicting fork results** — never assume what a worker will find
4. **Rubber-stamp verification** — "looks good" without actually checking
5. **Lazy delegation** — pushing synthesis to the worker instead of doing it yourself
