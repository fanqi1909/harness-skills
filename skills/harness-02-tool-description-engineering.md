---
name: "Harness 02: Tool Description Engineering"
description: "Write tool descriptions that steer agent behavior. Use when defining tools, APIs, or function schemas for AI agents."
whenToUse: "When writing tool descriptions, designing tool schemas, or debugging agent tool selection/usage issues."
---

# Harness Engineering: Tool Description Engineering

## Core Principle: Tool Descriptions Are Behavioral Directives, Not Documentation

A tool description isn't just "what this tool does" — it's an instruction to the model about **when, how, and when NOT** to use it.

## Pattern 1: Routing via Negative Rules

Tell the model what NOT to use this tool for, and redirect to the correct tool:

```
"Executes a bash command and returns its output.

IMPORTANT: Avoid using this tool to run grep, cat, head, tail, sed, awk,
or echo commands. Instead, use the appropriate dedicated tool:
- File read → Read tool (NOT cat/head/tail)
- File edit → Edit tool (NOT sed/awk)
- File search → Glob tool (NOT find/ls)
- Content search → Grep tool (NOT grep/rg)"
```

**Why**: Models default to Bash for everything. Negative routing forces them toward specialized tools.

## Pattern 2: Cross-Tool Name Constants

Reference other tools by imported constants, never hardcoded strings:

```typescript
import { FILE_READ_TOOL_NAME } from '../FileReadTool/constants.js'
import { GLOB_TOOL_NAME } from '../GlobTool/constants.js'

// In description:
`To read files use ${FILE_READ_TOOL_NAME} instead of cat.`
```

**Why**: Prevents prompt drift when tools are renamed. Single source of truth.

## Pattern 3: Self-Gating with When/When-NOT

Structure descriptions with explicit usage conditions:

```
## When to Use This Tool
- Complex multi-step tasks (3+ steps)
- User explicitly requests task tracking
- After receiving detailed instructions

## When NOT to Use
- Single, straightforward task
- Trivial task completable in <3 steps
- Purely conversational requests
```

**Why**: The model uses these rules to decide if it should invoke the tool at all, reducing unnecessary calls.

## Pattern 4: Precondition Declarations

State what must be true BEFORE the tool can be used:

```
"You MUST use the Read tool at least once in the conversation
BEFORE editing. This tool will error if you attempt an edit
without reading the file."
```

**Why**: Models skip preconditions unless explicitly told. This prevents "edit without reading" errors.

## Pattern 5: Examples with Reasoning

Don't just show examples — explain WHY the model should make that choice:

```
<example>
User: "Add dark mode to app settings"
Agent: Creates 5-task list (component, state, styles, toggle, tests)
</example>

<reasoning>
The agent used the todo list because:
1. Multi-step feature requiring UI + state + styling
2. Inferred test task from best practices
3. Feature crosses multiple files/concerns
</reasoning>
```

**Why**: Examples teach WHAT; reasoning teaches WHEN to generalize.

## Pattern 6: Context-Aware Descriptions

Tool descriptions can be dynamic based on runtime state:

```typescript
async function description(input, options) {
  const base = "Executes a bash command..."

  // Add sandbox info only when sandboxed
  if (options.sandboxEnabled) {
    return base + "\n\n# Sandbox\nThis tool runs in a sandbox..."
  }

  // Add git workflow only when git instructions enabled
  if (options.includeGitInstructions) {
    return base + "\n\n# Git Workflow\n..."
  }

  return base
}
```

**Why**: Avoid bloating descriptions with irrelevant context. Show only what applies.

## Pattern 7: Behavioral Metadata in Schema

Declare behavioral properties alongside the tool, not just in prose:

```typescript
{
  name: "FileEdit",
  isReadOnly: (input) => false,         // Declares: this tool writes
  isDestructive: (input) => false,      // Declares: not destructive
  isConcurrencySafe: (input) => false,  // Declares: don't run in parallel
  interruptBehavior: () => 'block',     // Declares: don't cancel mid-execution

  // For automated safety classification
  toAutoClassifierInput: (input) => ({
    file: input.file_path,
    operation: 'string_replace'
  })
}
```

**Why**: Structured metadata enables automated permission checks without parsing prose.

## Pattern 8: Compliance-Critical Rules in CAPS

Use formatting emphasis for rules that MUST be followed:

```
"CRITICAL REQUIREMENT - You MUST follow this:
  - After answering, you MUST include a 'Sources:' section
  - MANDATORY - never skip including sources

IMPORTANT - Use the correct year in search queries:
  - The current month is ${currentMonthYear}.
  - You MUST use this year, NOT last year."
```

**Why**: Models respond to formatting emphasis. CAPS + MUST/NEVER for hard rules.

## Pattern 9: Token Budget Awareness

Limit tool description size based on context window:

```typescript
const SKILL_BUDGET = 0.01 // 1% of context window
const charBudget = contextWindowTokens * 4 * 0.01

// Bundled skills: full description
// Plugin skills: truncate if over budget
```

**Why**: Tool descriptions compete with conversation for context. Budget them.

## Pattern 10: Fail-Closed Defaults

Tool defaults should be the SAFEST option:

```typescript
const TOOL_DEFAULTS = {
  isReadOnly: () => false,          // Assume writes (safer)
  isConcurrencySafe: () => false,   // Assume NOT safe (safer)
  isDestructive: () => false,       // Neutral default
  checkPermissions: () => 'allow',  // Defer to general system
}
```

**Why**: An unimplemented method should never accidentally grant access.
