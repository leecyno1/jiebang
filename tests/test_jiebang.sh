#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/skills/jiebang/scripts/jiebang.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file() {
  [ -f "$1" ] || fail "expected file: $1"
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  grep -q "$pattern" "$file" || fail "expected '$pattern' in $file"
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  if grep -q "$pattern" "$file"; then
    fail "did not expect '$pattern' in $file"
  fi
}

make_project() {
  local project
  project="$(mktemp -d)"
  echo "$project"
}

test_bootstrap_and_validate() {
  local project
  project="$(make_project)"
  (
    cd "$project"
    "$SCRIPT" bootstrap >/dev/null
    "$SCRIPT" validate >/dev/null
    assert_file ".jiebang/manifest.yml"
    assert_file ".jiebang/runtime/handoffs/cc.md"
    assert_file ".jiebang/runtime/sessions/cc.md"
  )
  rm -rf "$project"
}

test_agents_hook_is_bounded_and_removable() {
  local project
  project="$(make_project)"
  (
    cd "$project"
    cat > AGENTS.md <<'EOF'
# AGENTS.md

Original config line
EOF
    "$SCRIPT" bootstrap --update-agents >/dev/null
    assert_contains "AGENTS.md" "Original config line"
    assert_contains "AGENTS.md" "JIEBANG_HOOK_BEGIN"
    "$SCRIPT" remove-agents-hook >/dev/null
    assert_contains "AGENTS.md" "Original config line"
    assert_not_contains "AGENTS.md" "JIEBANG_HOOK_BEGIN"
  )
  rm -rf "$project"
}

test_autosave_writes_auto_handoff_and_preserves_manual() {
  local project
  project="$(make_project)"
  (
    cd "$project"
    "$SCRIPT" bootstrap >/dev/null
    cat > .jiebang/runtime/handoffs/cc.md <<'EOF'
---
agent: cc
status: active
updated_at: 2026-04-19 09:00
task: manual
mode: manual
---

# Handoff

## Goal

Manual summary stays authoritative.
EOF
    "$SCRIPT" autosave cc >/dev/null
    assert_contains ".jiebang/runtime/handoffs/cc.md" "Manual summary stays authoritative."
    assert_file ".jiebang/runtime/handoffs/cc.auto.md"
    assert_contains ".jiebang/runtime/handoffs/cc.auto.md" "mode: auto"
  )
  rm -rf "$project"
}

test_brief_prefers_manual_then_auto() {
  local project
  project="$(make_project)"
  (
    cd "$project"
    "$SCRIPT" bootstrap >/dev/null
    cat > .jiebang/runtime/handoffs/cc.md <<'EOF'
---
agent: cc
status: active
updated_at: 2026-04-19 10:00
task: manual
mode: manual
---

# Handoff

## Goal

Manual goal.
EOF
    cat > .jiebang/runtime/handoffs/cc.auto.md <<'EOF'
---
agent: cc
status: active
updated_at: 2026-04-19 10:10
task: auto
mode: auto
---

# Handoff

## Goal

Auto goal.
EOF

    "$SCRIPT" brief cc > brief.txt
    assert_contains "brief.txt" "authoritative_source: manual"
    assert_contains "brief.txt" "Manual goal."

    rm .jiebang/runtime/handoffs/cc.md
    "$SCRIPT" brief cc > brief-auto.txt
    assert_contains "brief-auto.txt" "authoritative_source: auto"
    assert_contains "brief-auto.txt" "Auto goal."
  )
  rm -rf "$project"
}

test_brief_uses_newer_auto_when_manual_is_stale() {
  local project
  project="$(make_project)"
  (
    cd "$project"
    "$SCRIPT" bootstrap >/dev/null
    cat > .jiebang/runtime/handoffs/cc.md <<'EOF'
---
agent: cc
status: active
updated_at: 2026-04-18 08:00
task: manual
mode: manual
---

# Handoff

## Goal

Stale manual goal.
EOF
    cat > .jiebang/runtime/handoffs/cc.auto.md <<'EOF'
---
agent: cc
status: active
updated_at: 2026-04-19 10:30
task: auto
mode: auto
---

# Handoff

## Goal

Fresh auto goal.
EOF
    "$SCRIPT" brief cc > brief-stale.txt
    assert_contains "brief-stale.txt" "authoritative_source: auto"
    assert_contains "brief-stale.txt" "Fresh auto goal."
  )
  rm -rf "$project"
}

test_daemon_writes_auto_handoff() {
  local project
  project="$(make_project)"
  (
    cd "$project"
    "$SCRIPT" bootstrap >/dev/null
    "$SCRIPT" daemon-start cc 1 >/dev/null
    sleep 2
    "$SCRIPT" daemon-status >/dev/null
    "$SCRIPT" daemon-stop >/dev/null
    assert_file ".jiebang/runtime/handoffs/cc.auto.md"
    assert_contains ".jiebang/runtime/sessions/cc.md" "auto handoff snapshot refreshed"
  )
  rm -rf "$project"
}

main() {
  test_bootstrap_and_validate
  test_agents_hook_is_bounded_and_removable
  test_autosave_writes_auto_handoff_and_preserves_manual
  test_brief_prefers_manual_then_auto
  test_brief_uses_newer_auto_when_manual_is_stale
  test_daemon_writes_auto_handoff
  echo "PASS: all jiebang tests"
}

main "$@"
