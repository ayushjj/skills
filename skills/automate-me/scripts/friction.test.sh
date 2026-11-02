#!/usr/bin/env bash
# Positive + negative controls for friction.js: fixtures with KNOWN counts, so the detector
# has to prove it can fire (and stay quiet) before a run's numbers are trusted.
set -u
here="$(dirname "$0")"; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "ok   $1"; else fail=$((fail+1)); echo "FAIL $1 (want $3, got $2)"; fi; }
u() { printf '{"type":"user","entrypoint":"%s","timestamp":"%s","message":{"role":"user","content":"%s"}}\n' "$1" "$2" "$3"; }
a() { printf '{"type":"assistant","entrypoint":"cli","timestamp":"%s","message":{"role":"assistant","content":[{"type":"text","text":"%s"}]}}\n' "$1" "$2"; }
tr_() { printf '{"type":"user","entrypoint":"cli","timestamp":"%s","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"x","is_error":true,"content":"PreToolUse:Bash hook error: blocked"}]}}\n' "$1"; }
T=2026-09-10T10:00:00Z

# p1: owner session — one of each owner signal, one admission, one tool block.
mkdir -p "$tmp/p1"
{ u cli $T "please build the report"; a $T "Done, here it is."
  u cli $T "hmm, that is not what i asked"; a $T "You're right, fixing it."
  u cli $T "help me understand where we are"; a $T "Here is where we are."
  u cli $T "status?"; tr_ $T; a $T "You're right, after a tool reply"
  u cli $T "you decide which one"; a $T "Picked A."
  u cli $T "the vendor names look lowercase"; a $T "Good catch, fixing the case."
  u cli $T "[Request interrupted by user]"
} > "$tmp/p1/s1.jsonl"
# p2: automated sdk job that SAYS explain — must be skipped entirely.
mkdir -p "$tmp/p2"
{ u sdk-py $T "explain this change"; u sdk-py $T "explain again"; } > "$tmp/p2/s2.jsonl"
# p3: one-message session — below --min-turns, skipped.
mkdir -p "$tmp/p3"; u cli $T "explain x" > "$tmp/p3/s3.jsonl"

out="$(FRICTION_ROOT="$tmp" node "$here/friction.js" --since 2026-09-01 --top 5)"; code=$?
row() { printf '%s\n' "$out" | awk -v k="$1" '$1==k{print $2}'; }
check "exit 0 on good data" "$code" 0
check "one owner session counted" "$(printf '%s\n' "$out" | head -1 | sed -E 's/^sessions ([0-9]+).*/\1/')" 1
check "automated job skipped" "$(printf '%s\n' "$out" | head -1 | grep -c 'skipped 1 automated, 1 shorter')" 1
check "owner turns exclude interrupt marker" "$(printf '%s\n' "$out" | head -1 | sed -E 's/.*owner turns ([0-9]+)/\1/')" 6
check "correction after a lead-in" "$(row correction)" 1
check "explain" "$(row explain)" 1
check "status" "$(row status)" 1
check "handback" "$(row handback)" 1
check "caught_miss: 1 real; not after tool work, not on an already-flagged line" "$(row caught_miss)" 1
check "hook block counted" "$(printf '%s\n' "$out" | grep -c 'hook/permission blocks 1')" 1

# window: same fixture, window after the events -> no sessions -> CONTROL FAILED (exit 2)
FRICTION_ROOT="$tmp" node "$here/friction.js" --since 2026-09-20 >/dev/null 2>&1; check "empty window exits 2" "$?" 2
# bad flag -> usage error, never a silent unbounded run
FRICTION_ROOT="$tmp" node "$here/friction.js" --until --top 1 >/dev/null 2>&1; check "bad flag exits 64" "$?" 64
# blind detector: 20+ owner turns, none matching any signal -> exit 2
mkdir -p "$tmp/blind/p"; words=(alpha bravo charlie delta echo foxtrot golf hotel india juliet kilo lima mike november oscar papa quebec romeo sierra tango uniform victor)
for w in "${words[@]}"; do u cli $T "draft $w"; done > "$tmp/blind/p/b.jsonl"
FRICTION_ROOT="$tmp/blind" node "$here/friction.js" --since 2026-09-01 >/dev/null 2>&1; check "20 turns, zero owner signals exits 2" "$?" 2

# precision (automate-me 2026-10-24): answers to Claude's own question and phrases inside a paste are not friction.
mkdir -p "$tmp/prec/p"
{ u cli $T "no, it's ok"; u cli $T "no but let us keep it"; u cli $T "no, we don't need that"
  u cli $T "that is not what we used last time"; u cli $T "how do you decide which one"
  u cli $T "once you decide, tell me"; u cli $T "<pasted_content>you decide the format</pasted_content> fyi"
  u cli $T "no, that is wrong"; u cli $T "your call"; } > "$tmp/prec/p/q.jsonl"
pout="$(FRICTION_ROOT="$tmp/prec" node "$here/friction.js" --since 2026-09-01 --top 1)"
prow() { printf '%s\n' "$pout" | awk -v k="$1" '$1==k{print $2}'; }
check "precision: only the real correction counts" "$(prow correction)" 1
check "precision: only the real handback counts" "$(prow handback)" 1

echo "RESULT: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
