# Jiebang

Jiebang is a lightweight cross-agent handoff skill for continuing the same software project across Claude Code (`cc`), Codex (`cx`), and Antigravity (`ag`) without relying on private chat memory.

It persists the current task, decisions, handoff summaries, and optional autosave snapshots inside the project so the next agent can quickly pick up where the previous one stopped.

## Why This Exists

Modern agentic development often moves between tools. Claude Code may be strong for one workflow, Codex for another, and Antigravity for a third. The problem is that each tool has its own private conversation context.

Jiebang solves this by externalizing the transferable state into project files:

- Stable project configuration stays in the project’s native docs, such as `AGENTS.md`, `CLAUDE.md`, or `README.md`.
- Dynamic handoff state lives in `.jiebang/runtime/`.
- The skill reads only the small handoff files by default, and reads larger project docs only when needed.
- The packaged skill under `skills/jiebang/` is the only canonical scaffold source; target-project `.jiebang/` files are generated locally by `bootstrap`.

## Features

- `接棒cc`, `接棒cx`, `接棒ag`: import a source agent’s persisted handoff state.
- `交棒`: export the current agent’s state without needing a suffix.
- `自动交棒`: use local autosave snapshots to reduce context loss from disconnects or crashes.
- Optional `AGENTS.md` hook: append a bounded, removable hook block only when explicitly requested.
- Local-first persistence: no network service is required for handoff files.
- Token-aware reading: manifest and runtime files first, larger project docs only on demand.
- Safe project integration: existing `CLAUDE.md`, `AGENTS.md`, and other instruction files are never rewritten.

## Install

Install or copy this skill into your Codex skills directory:

```bash
mkdir -p ~/.codex/skills
cp -R skills/jiebang ~/.codex/skills/jiebang
```

Restart Codex after installing a new skill so the skill metadata is loaded.

For other agent environments, keep the same `skills/jiebang` folder structure and ensure the agent can read `SKILL.md` plus the bundled `assets/`, `references/`, and `scripts/` directories.

## Quick Start

From the project you want to hand off between agents:

```bash
~/.codex/skills/jiebang/scripts/jiebang.sh bootstrap
```

Then fill in the durable project context:

```bash
$EDITOR .jiebang/runtime/project.md
$EDITOR .jiebang/runtime/current-task.md
```

When leaving the current agent, say:

```text
交棒
```

When entering another agent, say:

```text
接棒cc
```

Use `cc`, `cx`, or `ag` depending on which agent produced the handoff you want to import.

## Command Reference

All commands are run from the target project root:

```bash
~/.codex/skills/jiebang/scripts/jiebang.sh bootstrap
~/.codex/skills/jiebang/scripts/jiebang.sh bootstrap --update-agents
~/.codex/skills/jiebang/scripts/jiebang.sh remove-agents-hook
~/.codex/skills/jiebang/scripts/jiebang.sh validate
~/.codex/skills/jiebang/scripts/jiebang.sh brief cc
~/.codex/skills/jiebang/scripts/jiebang.sh autosave cc
~/.codex/skills/jiebang/scripts/jiebang.sh watch cc 180
~/.codex/skills/jiebang/scripts/jiebang.sh daemon-start cc 180
~/.codex/skills/jiebang/scripts/jiebang.sh daemon-status
~/.codex/skills/jiebang/scripts/jiebang.sh daemon-stop
```

| Command | Purpose |
|---|---|
| `bootstrap` | Create generated `.jiebang/` scaffold and runtime files from the packaged skill assets. |
| `bootstrap --update-agents` | Also append a bounded Jiebang hook to `AGENTS.md`. |
| `remove-agents-hook` | Remove only the bounded Jiebang hook block from `AGENTS.md`. |
| `validate` | Confirm the required manifest and runtime files exist. |
| `brief <agent>` | Print a compact import pack for `cc`, `cx`, or `ag`. |
| `autosave <agent>` | Write one local auto snapshot for the selected agent. |
| `watch <agent> [seconds]` | Run foreground periodic autosave. |
| `daemon-start <agent> [seconds]` | Start background periodic autosave. |
| `daemon-status` | Show background autosave status. |
| `daemon-stop` | Stop background autosave. |

## File Layout

`bootstrap` creates this structure in the target project:

```text
.jiebang/
  manifest.yml
  templates/
    current-task.md
    decision-log.md
    handoff.md
    project.md
    session.md
  runtime/
    project.md
    current-task.md
    decision-log.md
    handoffs/
      cc.md
      cx.md
      ag.md
    sessions/
      cc.md
      cx.md
      ag.md
```

The important runtime files are:

| File | Role |
|---|---|
| `.jiebang/manifest.yml` | Entry point for the handoff system. |
| `.jiebang/runtime/project.md` | Durable project goal, scope, and constraints. |
| `.jiebang/runtime/current-task.md` | Current active task and success criteria. |
| `.jiebang/runtime/decision-log.md` | Durable decisions and deferred decisions. |
| `.jiebang/runtime/handoffs/{cc,cx,ag}.md` | Manual handoff packet for each agent. |
| `.jiebang/runtime/handoffs/{cc,cx,ag}.auto.md` | Automatic snapshot fallback for each agent. |
| `.jiebang/runtime/sessions/{cc,cx,ag}.md` | More detailed fallback timeline for each agent. |

## Handoff Flow

### Manual Export

`交棒` means “the current agent writes its own state.” It does not need a suffix because the writer is already known.

The handoff should include:

- Current goal
- Completed work
- Work in progress
- Changed files
- Risks or missing verification
- The next concrete action

### Manual Import

`接棒cc`, `接棒cx`, and `接棒ag` mean “read the handoff from this source agent.”

The default read order is:

1. `.jiebang/manifest.yml`
2. `.jiebang/runtime/project.md`
3. `.jiebang/runtime/current-task.md`
4. `.jiebang/runtime/decision-log.md`
5. `.jiebang/runtime/handoffs/<source>.md` as the authoritative manual handoff
6. `.jiebang/runtime/handoffs/<source>.auto.md` only if the manual handoff is missing or clearly stale
7. `.jiebang/runtime/sessions/<source>.md` only as low-level evidence
8. `AGENTS.md`, `CLAUDE.md`, or `README.md` only if project-level rules are needed

## Token Strategy

Jiebang separates stable context from dynamic handoff state:

- Stable project docs are larger but low-change.
- Runtime handoff files are small and task-specific.
- Session logs are fallback context and should not be read by default.

This keeps most handoffs cheap: agents read the manifest, current task, decision log, and the authoritative handoff packet before deciding whether larger docs are needed.

## Safety Model

Jiebang is intentionally conservative:

- It cannot read another agent’s private conversation history.
- It only transfers context that was explicitly persisted into `.jiebang/`.
- It does not rewrite existing `CLAUDE.md`, `AGENTS.md`, or other instruction files.
- `bootstrap --update-agents` appends only this bounded block:

```markdown
<!-- JIEBANG_HOOK_BEGIN -->
...
<!-- JIEBANG_HOOK_END -->
```

- `remove-agents-hook` removes only that bounded block.
- Runtime autosave is local and does not require network access.

## Autosave

Manual `交棒` should produce the highest-quality summary and remains authoritative. Autosave is a safety net.

Run one snapshot:

```bash
~/.codex/skills/jiebang/scripts/jiebang.sh autosave cc
```

Run periodic autosave in the foreground:

```bash
~/.codex/skills/jiebang/scripts/jiebang.sh watch cc 180
```

Run periodic autosave in the background:

```bash
~/.codex/skills/jiebang/scripts/jiebang.sh daemon-start cc 180
~/.codex/skills/jiebang/scripts/jiebang.sh daemon-status
~/.codex/skills/jiebang/scripts/jiebang.sh daemon-stop
```

Autosave writes a machine-generated `.auto.md` snapshot and appends a timeline entry to the selected agent’s session log. It should never overwrite a manual handoff.

## Development

Validate a bootstrapped target project:

```bash
skills/jiebang/scripts/jiebang.sh validate
```

Run the integration suite for the packaged skill:

```bash
bash tests/test_jiebang.sh
```

## Limitations

- Handoff quality depends on agents writing useful summaries.
- Autosave snapshots are intentionally conservative and may omit reasoning.
- Automatic snapshots live in `.auto.md` files and are only used when the manual handoff is missing or stale.
- Private chat memory from Claude Code, Codex, or Antigravity is not accessible unless an agent writes it into `.jiebang/`.
- The current implementation is file-based and local-first; team synchronization should be handled separately through git or another collaboration layer.

## License

MIT. See [LICENSE](LICENSE).
