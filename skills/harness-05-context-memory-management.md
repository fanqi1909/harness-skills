---
name: "Harness 05: Context & Memory Management"
description: "Design context assembly, memory systems, and conversation compaction for AI agents. Use when building persistent agent memory or managing context windows."
whenToUse: "When designing memory systems, context injection, conversation compaction, or token budget management for AI agents."
---

# Harness Engineering: Context & Memory Management

## Core Principle: Context Is Scarce, Memory Is Cheap — Bridge Them Carefully

The context window is a fixed budget. Memory is persistent storage. The harness decides what crosses the boundary each turn.

## Pattern 1: Three-Tier Context Assembly

```
System Context (computed once, memoized)
  - Git status, branch, recent commits
  - Platform, shell, model info
  - Cached for conversation lifetime

User Context (computed once, clearable)
  - CLAUDE.md instructions (project + user)
  - Memory index (MEMORY.md)
  - Current date
  - Cleared on /compact or /clear

Turn Context (computed per turn)
  - MCP server instructions
  - Token budget remaining
  - Recent tool results
```

**Memoization rule**: Compute once, reuse until explicitly cleared. Never recompute static context per turn.

## Pattern 2: CLAUDE.md Instruction Discovery

Walk directory tree upward from CWD, loading instructions at each level:

```
Priority (high → low):
1. /etc/claude-code/CLAUDE.md     (admin managed)
2. ~/.claude/CLAUDE.md            (user global)
3. ./CLAUDE.md                    (project root)
4. ./.claude/CLAUDE.md            (project config dir)
5. ./.claude/rules/*.md           (modular project rules)
6. ./CLAUDE.local.md              (private, gitignored)
```

**Processing rules**:
- Files closer to CWD loaded LAST (higher attention from model)
- `@include` directives supported: `@path`, `@./relative`, `@~/home`
- HTML block comments stripped (preserves inline and code-block)
- Max 40,000 characters recommended per file
- Frontmatter `paths` field limits applicability by glob

## Pattern 3: Memory Type Taxonomy

Structure memories by type, each with clear purpose:

| Type | What | When to Save | When to Use |
|------|------|-------------|-------------|
| **user** | Role, preferences, knowledge | Learn about user | Tailor behavior |
| **feedback** | Corrections + confirmations | User corrects/validates approach | Don't repeat mistakes |
| **project** | Goals, deadlines, decisions | Learn project context | Inform suggestions |
| **reference** | External system pointers | Learn about external tools | Navigate external systems |

**What NOT to save**:
- Code patterns, architecture (derivable from reading code)
- Git history (use `git log`)
- Debug solutions (fix is in the code)
- Ephemeral task state (stales quickly)

## Pattern 4: Index + File Memory Architecture

```
MEMORY.md (Index — always loaded)
  - [User Role](user_role.md) — senior backend engineer, Go expert
  - [Testing Feedback](feedback_testing.md) — always use real DB, not mocks
  - [Sprint Goal](project_sprint.md) — auth rewrite due 2026-04-15

Individual files (loaded on demand by relevance)
  ---
  name: Testing Feedback
  description: User requires integration tests with real databases
  type: feedback
  ---
  Always use real databases in integration tests, not mocks.
  **Why:** Prior incident where mock/prod divergence masked a broken migration.
  **How to apply:** Any test file touching DB models must use test database.
```

**Constraints**:
- MEMORY.md: max 200 lines, 25KB (always in context)
- Individual files: loaded by relevance query (max 5 per turn)
- One topic per file, frontmatter required

## Pattern 5: Relevance-Based Memory Recall

Not all memories load every turn. Use a side-query to select:

```
1. Scan all memory file headers (name, description)
2. Side-query to fast model: "Which 5 memories are relevant to this turn?"
3. Load selected files into context
4. Track recently-surfaced memories to avoid repetition
```

**Why**: Loading all memories wastes context. Selective recall keeps context focused.

## Pattern 6: Conversation Compaction

When context approaches the limit, compress:

```
Trigger: context_tokens > (window_size - output_reserve - buffer)

Process:
1. Strip images/documents (not needed for summary)
2. Group messages by API-round (preserve semantic boundaries)
3. Fork subagent to generate conversation summary
4. Replace old messages with summary
5. Re-inject: up to 5 active files, skill instructions, MCP config

Post-compact marker:
  [Earlier conversation summarized — key points preserved]
```

**Safety**:
- Never compact mid-tool-loop (wait for assistant turn end)
- Circuit breaker: stop after 3 consecutive failures
- Fallback: drop 20% of oldest message groups if summary fails

## Pattern 7: Token Budget Compartmentalization

Reserve tokens for different purposes:

```
Total Context Window: 200,000 tokens
  - System prompt:    ~15,000 (static)
  - Tool descriptions: ~8,000 (cached)
  - CLAUDE.md:        ~5,000 (cached)
  - Memory:           ~2,000 (per-turn)
  - Conversation:     ~150,000 (growing)
  - Output reserve:   ~20,000 (must always be available)
  - Compact buffer:   ~13,000 (triggers compaction before hitting limit)
```

## Pattern 8: Cost Tracking

Track token usage across the session:

```typescript
modelUsage = {
  'claude-opus-4-6': {
    inputTokens: 150000,
    outputTokens: 45000,
    cacheReadTokens: 120000,   // Huge savings from prompt caching
    cacheWriteTokens: 15000,   // Higher cost but amortized
  }
}
```

Persist costs on session exit for analytics. Restore on resume (match session ID).

## Pattern 9: Sticky Cache Latches

Some states should "stick on" once activated to preserve cache:

```typescript
// Once AFK mode activates, keep it on (don't bust cache by toggling)
if (isAFK) afkLatch = true
// Latch stays true even if user returns briefly
// Only explicit reset clears it
```

**Why**: Toggling flags between turns breaks prompt cache. Latches prevent flip-flopping.

## Pattern 10: Session Memory (Background Extraction)

For long conversations, extract memories in the background:

```
Trigger: conversation > 60K tokens
  AND (tokens_since_last > 50K)
  AND (tool_calls > 3 OR no_tools_in_last_turn)

Process:
  - Fork background subagent
  - Feed conversation delta (new messages since last extraction)
  - Append extracted facts to session memory file
  - Fire-and-forget (don't block main conversation)
```

**Why**: Long conversations contain important context that may be lost to compaction. Extract before it's compressed away.
