# Command Contract

## Receive Commands

| Command | Meaning |
|---------|---------|
| `接棒cc` | Import Claude Code's persisted state into the current agent |
| `接棒cx` | Import Codex's persisted state into the current agent |
| `接棒ag` | Import Antigravity's persisted state into the current agent |

For any `接棒xx` command, the agent should:

1. Read the shared runtime files
2. Read the source agent manual handoff packet first
3. Fall back to the source agent autosave handoff when the manual handoff is missing or stale
4. State what was imported and whether the source was manual or auto
5. State what is still unknown
6. Continue the user's requested task

## Export Commands

| Command | Meaning |
|---------|---------|
| `交棒` | Persist the current agent's own state for the next agent to consume |

For `交棒`, the agent should update its own outbound handoff packet first. The writer is always the current agent, so no suffix is needed.

## Automatic Export

| Command | Meaning |
|---------|---------|
| `自动交棒` | Enable or run local snapshot-based handoff persistence for the active agent |

For `自动交棒`, the system should prefer:

1. local writes
2. periodic snapshots
3. append-only session logging
4. manual `交棒` remaining authoritative over auto snapshots

Example:

- If Claude is about to switch to Codex, Claude updates `.jiebang/runtime/handoffs/cc.md`, then the user goes to Codex and says `接棒cc`.
