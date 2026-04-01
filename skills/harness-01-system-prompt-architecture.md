---
name: "Harness 01: System Prompt Architecture"
description: "Design modular, cacheable, layered system prompts for AI agents. Use when building or reviewing agent system prompts."
whenToUse: "When designing system prompts, building agent harnesses, or reviewing prompt structure for AI-powered tools."
---

# Harness Engineering: System Prompt Architecture

## Core Principle: Modular Assembly, Not Monoliths

System prompts should be **assembled from independent sections**, not written as one giant string. Each section has clear responsibility, caching scope, and update frequency.

## Pattern 1: Static/Dynamic Boundary

Split the prompt into two zones separated by a boundary marker:

```
[STATIC ZONE — cacheable across all users/sessions]
- Agent identity & role
- Core behavioral rules
- Tool descriptions & usage guidance
- Language/style preferences

__DYNAMIC_BOUNDARY__

[DYNAMIC ZONE — per-session, per-user]
- User context (CLAUDE.md, preferences)
- System context (git status, environment)
- Memory/recall content
- MCP server instructions
```

**Why**: Everything before the boundary can reuse cached prompt tokens across users (global scope). Everything after is session-specific. This dramatically reduces latency and cost.

## Pattern 2: Section Registration

Each section should be a named, independently cacheable unit:

```typescript
// Cached once per conversation — safe to reuse
systemPromptSection('tool_guidance', () =>
  getToolGuidanceSection(enabledTools)
)

// Recomputes every turn — explicitly marked dangerous with reason
DANGEROUS_uncachedSection('mcp_instructions', () =>
  getMcpInstructions(connectedServers),
  'MCP servers connect/disconnect mid-session'
)
```

**Rules**:
- Default: cached per conversation (compute once, reuse)
- Uncached sections REQUIRE an explicit reason string
- Sections return `string | null` (null = omitted entirely)

## Pattern 3: Parallel Computation

Independent sections should compute in parallel:

```typescript
const [skills, outputStyle, envInfo] = await Promise.all([
  getSkillCommands(cwd),
  getOutputStyleConfig(),
  computeEnvInfo(model, directories),
])
```

## Pattern 4: Layered Context Injection

Context comes from multiple sources with clear priority:

| Layer | Source | Scope | Example |
|-------|--------|-------|---------|
| Managed | Admin policies | Global | `/etc/claude-code/CLAUDE.md` |
| User | User preferences | Per-user | `~/.claude/CLAUDE.md` |
| Project | Repo instructions | Per-repo | `./CLAUDE.md`, `.claude/rules/*.md` |
| Local | Private overrides | Per-machine | `./CLAUDE.local.md` |
| Session | Runtime state | Per-session | Git status, memory recall |

**Higher layers override lower ones. Closer-to-CWD files get higher attention (loaded last).**

## Pattern 5: Feature-Flag Prompt Tiers

Entire prompt complexity levels can change based on feature flags:

```
PROACTIVE mode → lean autonomous prompt (no permission explanations)
SIMPLE mode    → minimal prompt (just CWD + date)
DEFAULT mode   → full interactive prompt with all sections
COORDINATOR    → multi-agent orchestration prompt
```

**Don't conditionally add fragments; swap entire prompt strategies.**

## Pattern 6: Environment Information Block

Always inject structured environment info:

```
# Environment
- Working directory: /path/to/project (git: true)
- Platform: darwin | linux | win32
- Shell: zsh | bash
- Model: claude-opus-4-6 (context: 1M)
- Date: 2026-04-01
- Knowledge cutoff: May 2025
```

This grounds the agent in reality and prevents hallucinated capabilities.

## Anti-Patterns

1. **Monolithic prompt string** — impossible to cache, test, or maintain
2. **Inline tool descriptions** — fragments cache when tools change; use attachments
3. **Recomputing static content per turn** — wastes tokens and busts cache
4. **Mixing identity with instructions** — identity is stable, instructions evolve
5. **No boundary marker** — forces entire prompt into per-session scope
