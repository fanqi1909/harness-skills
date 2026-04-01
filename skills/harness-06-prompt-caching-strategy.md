---
name: "Harness 06: Prompt Caching Strategy"
description: "Maximize prompt cache hit rates for AI agent systems. Use when optimizing latency and cost for LLM-powered tools."
whenToUse: "When optimizing prompt caching, reducing latency, or managing cost in AI agent systems."
---

# Harness Engineering: Prompt Caching Strategy

## Core Principle: The Best Token Is One You Don't Recompute

Prompt caching lets the LLM provider skip reprocessing unchanged prefix tokens. Every cache hit saves latency AND cost. Design your prompt to maximize the stable prefix.

## Pattern 1: Front-Load Stable Content

```
[STABLE — changes rarely, cacheable across users]
  Agent identity
  Core behavioral rules
  Tool descriptions
  Language preferences

[SEMI-STABLE — changes per session, cacheable within session]
  User instructions (CLAUDE.md)
  Memory index
  Environment info

[VOLATILE — changes per turn, never cached]
  MCP server instructions
  Token budget
  Recent context
  Conversation messages
```

**Rule**: Move content UP in the prompt if it changes less frequently.

## Pattern 2: Boundary Markers

Explicit markers separate cache scopes:

```
[Global scope — cached across ALL users in the org]
...static content...

__SYSTEM_PROMPT_DYNAMIC_BOUNDARY__

[Session scope — cached within this user's session only]
...user-specific content...
```

**Why**: The API caches prefix tokens. Content before the boundary gets the broadest cache sharing.

## Pattern 3: Attachment-Based Dynamic Content

Don't inline volatile content in tool descriptions (busts tool schema cache). Instead, inject as message attachments:

```
❌ Bad: Inline MCP server list in Agent tool description
   → Every MCP connect/disconnect busts Agent tool cache

✅ Good: Static Agent tool description + dynamic attachment message
   → Tool schema stays cached; attachment is per-turn
```

```typescript
// Static tool description (cached)
description: "Launch agents to handle tasks..."

// Dynamic attachment (per-turn, doesn't bust tool cache)
messages.push({
  role: 'user',
  content: [{
    type: 'text',
    text: '<system-reminder>Available agents: worker, researcher...</system-reminder>'
  }]
})
```

## Pattern 4: Section-Level Cache Control

Each prompt section declares its own cache behavior:

```typescript
// Cached per conversation (default, safe)
systemPromptSection('identity', () => getIdentitySection())

// Uncached — recomputes every turn (requires justification)
DANGEROUS_uncachedSection('mcp_instructions',
  () => getMcpInstructions(),
  'MCP servers connect/disconnect mid-session'  // Required reason
)

DANGEROUS_uncachedSection('token_budget',
  () => getTokenBudget(),
  'Budget changes every turn as tokens are consumed'
)
```

**Rule**: Default is cached. Uncached requires explicit reason. This forces developers to justify cache-busting.

## Pattern 5: Deduplication Before Injection

Config values from multiple sources may overlap. Dedup before inlining:

```typescript
function dedup<T>(arr: T[]): T[] {
  return [...new Set(arr)]
}

// Sandbox paths like ~/.cache appear 3x across config layers
// Dedup saves ~150-200 tokens per request
const allowedPaths = dedup([
  ...userPaths,
  ...projectPaths,
  ...policyPaths,
])
```

## Pattern 6: Sticky-On Latches

Prevent cache-busting from state toggling:

```typescript
// Problem: fast mode toggles bust cache every time
// Solution: once activated, latch stays on

let fastModeLatch = false

function shouldUseFastMode() {
  if (settings.fastMode) fastModeLatch = true
  return fastModeLatch  // Never toggles back to false
}
```

**Use for**: AFK detection, fast mode, cache-editing mode, any boolean that toggles frequently.

## Pattern 7: Parallel Computation for Assembly

Compute independent sections in parallel to minimize TTFT:

```typescript
const [skills, style, env, memory] = await Promise.all([
  getSkillCommands(cwd),
  getOutputStyleConfig(),
  computeEnvInfo(model),
  loadMemoryIndex(),
])

return assemblePrompt(skills, style, env, memory)
```

**Why**: Sequential computation of 4 sections with 50ms each = 200ms. Parallel = 50ms.

## Pattern 8: Tool Schema Stability

Keep tool input schemas stable across turns:

```
❌ Bad: Tool schema includes dynamic list of allowed values
   → Schema changes every turn, busts tool cache

✅ Good: Tool schema is static; dynamic values in description or attachment
   → Schema cached; dynamic content in a cheaper location
```

## Pattern 9: Cache Scope Hierarchy

```
Global scope (broadest sharing):
  - Agent identity, behavioral rules
  - Tool schemas (input/output definitions)
  - Static tool descriptions

Organization scope:
  - Shared instructions, policies
  - Common tool configurations

User scope:
  - CLAUDE.md content
  - Memory index
  - User preferences

Session scope:
  - Conversation history
  - Turn-specific context
  - MCP instructions
```

Each scope level can cache independently. Design content to fall into the broadest possible scope.

## Pattern 10: One-Shot Agent Trailer Optimization

For agents that can't be continued, skip the continuation instructions:

```typescript
if (ONE_SHOT_AGENT_TYPES.has(agentType)) {
  // Skip "Use SendMessage with agentId: X to continue..."
  // Saves ~135 chars per agent run
  // At 34M runs/week, this adds up
}
```

**Why**: Small savings per call compound at scale.

## Measuring Cache Effectiveness

Track these metrics:
- `cache_read_tokens / total_input_tokens` = cache hit rate (target: >70%)
- `cache_write_tokens` = cost of cache misses (should decrease over session)
- TTFT (time to first token) = primary user-facing metric
- Cost per turn = input_cost + output_cost - cache_savings

## Anti-Patterns

1. **Dynamic content at prompt start** — pushes stable content out of cache prefix
2. **Inlining volatile lists in tool schemas** — busts tool cache on every change
3. **Recomputing memoizable content** — unnecessary cache invalidation
4. **No boundary marker** — entire prompt in session scope, no global sharing
5. **Boolean flag toggles** — each toggle busts cache; use latches instead
