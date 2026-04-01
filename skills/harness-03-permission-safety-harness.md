---
name: "Harness 03: Permission & Safety Harness"
description: "Build layered permission systems with fail-closed defaults for AI agent tool execution. Use when designing safety controls."
whenToUse: "When designing permission systems, safety checks, or access controls for AI agent tools."
---

# Harness Engineering: Permission & Safety Harness

## Core Principle: Defense in Depth — Multiple Independent Layers

No single check should be the only barrier. Each layer catches what the previous missed.

## Pattern 1: Layered Validation Pipeline

Every tool call passes through multiple stages:

```
Input
  → validateInput()         [Tool-specific: schema, format]
  → checkPermissions()      [Tool + General: mode, rules]
  → Security Checks         [Domain-specific: bash patterns, path traversal]
  → Rule Matching           [Global: allow/deny/ask rules]
  → User Prompt             [Final: human in the loop]
```

Each layer is independent. Removing one should not compromise overall safety.

## Pattern 2: Fail-Closed Defaults

Unknown = denied. Unimplemented = safest assumption:

```typescript
// Tool defaults
isReadOnly: () => false        // Assume writes until proven otherwise
isConcurrencySafe: () => false // Assume NOT safe for parallel
isDestructive: () => false     // Neutral, but permission still required

// Permission defaults
checkPermissions: () => 'passthrough'  // Defer to general system (NOT 'allow')
```

**Critical**: `'passthrough'` means "I don't know, ask the general system." Never default to `'allow'`.

## Pattern 3: Permission Mode Hierarchy

Define discrete modes with clear escalation:

| Mode | Behavior | Use Case |
|------|----------|----------|
| `plan` | Auto-deny interactive tools | Planning phase |
| `default` | Prompt user for each action | Normal interactive |
| `acceptEdits` | Auto-approve file operations | Trusted editing |
| `auto` | ML classifier decides | Advanced automation |
| `bypass` | Skip all checks | Internal/testing only |

**Rules**:
- Modes are ordered by trust level
- Lower modes cannot escalate to higher without explicit user action
- Each mode defines which tools auto-approve vs. prompt

## Pattern 4: Rule Sources with Priority

Permission rules come from multiple sources with clear precedence:

```typescript
type RuleSource =
  | 'policySettings'    // Admin (highest priority, can't be overridden)
  | 'userSettings'      // User's ~/.claude/settings.json
  | 'projectSettings'   // Repo's .claude/settings.json
  | 'localSettings'     // .claude/settings.local.json
  | 'flagSettings'      // CLI flags
  | 'session'           // Runtime changes (lowest priority)
```

**Deny always wins**: If any source denies, the action is denied regardless of allows.

## Pattern 5: Pattern-Based Tool Rules

Rules use glob-like patterns for flexible matching:

```
Bash(git *)        → Allow all git commands
Bash(npm test)     → Allow exactly "npm test"
Edit(src/**)       → Allow editing files under src/
Read(*.env)        → Deny reading .env files
```

Tools implement `preparePermissionMatcher()` to parse these patterns:

```typescript
preparePermissionMatcher: (input) => {
  return (pattern: string) => {
    return minimatch(input.command, pattern)
  }
}
```

## Pattern 6: Dangerous Pattern Detection

Maintain explicit lists of dangerous operations:

```typescript
const DESTRUCTIVE_PATTERNS = [
  /\bgit\s+reset\s+--hard\b/   → "may discard uncommitted changes",
  /\bgit\s+push\b.*--force/    → "may overwrite remote history",
  /rm\s+-[a-zA-Z]*[rR].*f/     → "may recursively force-remove",
  /\b(DROP|TRUNCATE)\s+TABLE/   → "may drop database objects",
  /\bkubectl\s+delete\b/       → "may delete Kubernetes resources",
  /\bterraform\s+destroy\b/    → "may destroy infrastructure",
]
```

Each pattern has a human-readable explanation that's shown to the user.

## Pattern 7: Path Traversal Prevention

All user-supplied paths must be validated against a root:

```typescript
function safePath(relPath: string): string | null {
  const resolved = path.resolve(ROOT, relPath)
  if (!resolved.startsWith(ROOT)) return null  // Traversal blocked
  return resolved
}
```

**Additional protections**:
- Case-insensitive comparison (defeats `.cLauDe/Settings.json`)
- Reject `~username` expansion (only `~` for home)
- Protected directories: `.git`, `.vscode`, `.claude`
- Protected files: `.gitconfig`, `.bashrc`, `.zshrc`, `.mcp.json`

## Pattern 8: Immutable Permission Context

Permission context is deeply immutable to prevent accidental mutations:

```typescript
type ToolPermissionContext = DeepImmutable<{
  mode: PermissionMode
  alwaysAllowRules: ToolPermissionRulesBySource
  alwaysDenyRules: ToolPermissionRulesBySource
  alwaysAskRules: ToolPermissionRulesBySource
}>
```

**Why**: Permission checks should never have side effects. A check that modifies the context could corrupt subsequent checks.

## Pattern 9: Async Classifier + User Prompt Race

When an automated classifier and user prompt compete:

```typescript
function createResolveOnce<T>(resolve) {
  let claimed = false
  return {
    resolve(value: T) {
      if (claimed) return  // Second resolver is no-op
      claimed = true
      resolve(value)
    },
    claim(): boolean {
      if (claimed) return false
      claimed = true
      return true
    }
  }
}
```

**Why**: Both classifier and user can respond. First one wins. Prevents double-resolution bugs.

## Pattern 10: Denial Tracking & Escalation

Track consecutive denials to detect patterns:

```
User denies command → counter++
Counter > threshold → switch from auto-approve to manual prompting
```

**Why**: Repeated denials signal the agent is doing something the user doesn't want. Escalate friction.

## Pattern 11: Dangerous Permission Stripping

In auto mode, strip rules that would grant too-broad access:

```typescript
// These rules are STRIPPED in auto mode:
Bash(*)           → Too broad, allows anything
Bash(python *)    → Code execution
Bash(node *)      → Code execution
Bash(curl *)      → Network access
Bash(ssh *)       → Remote access
```

**Why**: Users may have set broad rules for interactive mode. Auto mode should not inherit them blindly.

## Security Check Taxonomy (23 checks from Claude Code's BashTool)

1. Incomplete commands (dangling pipes, unclosed quotes)
2. Obfuscated flags (hex-encoded, unicode tricks)
3. Shell metacharacters in unexpected positions
4. Dangerous environment variables ($IFS injection)
5. Command substitution in arguments ($(), ``)
6. Process substitution (<(), >())
7. Output redirection in read-only commands
8. Git commit message substitution injection
9. /proc/environ access
10. Control characters and unicode whitespace
11. Brace expansion abuse
12. Comment/quote desync attacks
