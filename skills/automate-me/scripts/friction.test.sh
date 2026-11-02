#!/usr/bin/env bash
# Positive + negative controls for friction.js: fixtures with KNOWN counts, so the detector
# has to prove it can fire (and stay quiet) before a run's numbers are trusted.
set -u
here="$(dirname "$0")"; tmp="$(mktemp -d)" || exit 1; [ -n "$tmp" ] || exit 1; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "ok   $1"; else fail=$((fail+1)); echo "FAIL $1 (want $3, got $2)"; fi; }
u() { printf '{"type":"user","entrypoint":"%s","timestamp":"%s","message":{"role":"user","content":"%s"}}\n' "$1" "$2" "$3"; }
a() { printf '{"type":"assistant","entrypoint":"cli","timestamp":"%s","message":{"role":"assistant","content":[{"type":"text","text":"%s"}]}}\n' "$1" "$2"; }
tr_() { printf '{"type":"user","entrypoint":"cli","timestamp":"%s","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"x","is_error":true,"content":"%s"}]}}\n' "$1" "${2:-PreToolUse:Bash hook error: blocked}"; }
trA() { printf '{"type":"user","entrypoint":"cli","timestamp":"%s","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"x","is_error":true,"content":[{"type":"text","text":"%s"}]}]}}\n' "$1" "$2"; }
run() { FRICTION_ROOT="$1" node "$here/friction.js" --since 2026-09-01 --top 5 2>"$tmp/err"; }
val() { printf '%s\n' "$1" | awk -v k="$2" '$1==k{print $2}'; }
T=2026-09-10T10:00:00Z

# p1: owner session — one of each owner signal, one repeat, one admission, one tool block.
mkdir -p "$tmp/p1"
{ u cli $T "please build the report"; a $T "Done, here it is."
  u cli $T "hmm, no use the other one"; a $T "You're right, fixing it."
  u cli $T "help me understand where we are"; a $T "Here is where we are."
  u cli $T "status?"; a $T "Mostly done."
  u cli $T "please also check the totals"; tr_ $T; a $T "You're right, after a tool reply"
  u cli $T "you decide which one"; a $T "Picked A."
  u cli $T "the vendor names look lowercase"; a $T "Good catch, fixing the case."
  u cli $T "rebuild the vendor summary table with totals"; a $T "Rebuilt."
  u cli $T "rebuild the vendor summary table with totals please"; a $T "Rebuilt again."
  u cli $T "[Request interrupted by user]"
} > "$tmp/p1/s1.jsonl"
# p2: automated sdk job that SAYS explain — must be skipped entirely.
mkdir -p "$tmp/p2"
{ u sdk-py $T "explain this change"; u sdk-py $T "explain again"; } > "$tmp/p2/s2.jsonl"
# p3: one-message session — below --min-turns, skipped.
mkdir -p "$tmp/p3"; u cli $T "explain x" > "$tmp/p3/s3.jsonl"

out="$(FRICTION_ROOT="$tmp" node "$here/friction.js" --since 2026-09-01 --top 5 --json "$tmp/good.json" 2>"$tmp/p1.err")"; code=$?
row() { val "$out" "$1"; }
check "exit 0 on good data" "$code" 0
check "one owner session counted" "$(printf '%s\n' "$out" | head -1 | sed -E 's/^sessions ([0-9]+).*/\1/')" 1
check "automated job skipped" "$(printf '%s\n' "$out" | head -1 | grep -c 'skipped 1 automated, 1 shorter')" 1
check "owner turns exclude interrupt marker" "$(printf '%s\n' "$out" | head -1 | sed -E 's/.*owner turns ([0-9]+).*/\1/')" 9
check "correction after a lead-in (hmm, no ...)" "$(row correction)" 1
check "explain" "$(row explain)" 1
check "status" "$(row status)" 1
check "handback" "$(row handback)" 1
check "repeat_request: near-identical consecutive asks" "$(row repeat_request)" 1
check "caught_miss: 1 real; not after tool work, not on an already-flagged line" "$(row caught_miss)" 1
check "hook block counted (exactly 1)" "$(printf '%s\n' "$out" | grep -c 'hook/permission blocks 1$')" 1
check "under 20 owner turns: control-not-run warning" "$(grep -c 'CONTROL NOT RUN (<20 owner turns)' "$tmp/p1.err")" 1
check "--json written on a passing run" "$([ -s "$tmp/good.json" ] && echo yes)" yes

# window: same fixture, window after the events -> no sessions -> CONTROL FAILED (exit 2)
FRICTION_ROOT="$tmp" node "$here/friction.js" --since 2026-09-20 >/dev/null 2>&1; check "empty window exits 2" "$?" 2
FRICTION_ROOT="$tmp" node "$here/friction.js" --since=2026-09-20 >/dev/null 2>&1; check "--since=VALUE form is read (empty window exits 2)" "$?" 2
# bad flag -> usage error, never a silent unbounded run
FRICTION_ROOT="$tmp" node "$here/friction.js" --until --top 1 >/dev/null 2>&1; check "bad flag exits 64" "$?" 64
FRICTION_ROOT="$tmp" node "$here/friction.js" --sinse 2026-09-20 >/dev/null 2>&1; check "unknown flag (--sinse) exits 64" "$?" 64
# blind detector: 20+ owner turns, none matching any signal -> exit 2
mkdir -p "$tmp/blind/p"; words=(alpha bravo charlie delta echo foxtrot golf hotel india juliet kilo lima mike november oscar papa quebec romeo sierra tango uniform victor)
for w in "${words[@]}"; do u cli $T "draft $w"; done > "$tmp/blind/p/b.jsonl"
run "$tmp/blind" >/dev/null; check "20 turns, zero owner signals exits 2" "$?" 2
check "blind: stderr names the blind-detector control" "$(grep -c 'owner turns but no owner signals' "$tmp/err")" 1
# blind with boilerplate wrappers: repeat_request fires on near-identical wrapper text, but it must not
# count toward the control (only correction/explain/status/handback do).
mkdir -p "$tmp/wrap/p"; i=0
for w in "${words[@]}"; do i=$((i+1)); u cli $T "<user_input>draft item$i alpha bravo</user_input>"; done > "$tmp/wrap/p/w.jsonl"
run "$tmp/wrap" >/dev/null; check "wrapped boilerplate, no real signal exits 2" "$?" 2
check "wrapped: stderr names the blind-detector control" "$(grep -c 'owner turns but no owner signals' "$tmp/err")" 1
mkdir -p "$tmp/rep/p"
for w in "${words[@]}"; do u cli $T "draft item alpha bravo charlie $w"; done > "$tmp/rep/p/r.jsonl"
echo stale > "$tmp/stale.json"
FRICTION_ROOT="$tmp/rep" node "$here/friction.js" --since 2026-09-01 --json "$tmp/stale.json" >/dev/null 2>"$tmp/err"; check "repeats only (no real signal) exits 2" "$?" 2
check "repeats only: stderr names the blind-detector control" "$(grep -c 'owner turns but no owner signals' "$tmp/err")" 1
check "failed control: stale --json deleted, not rewritten" "$([ -e "$tmp/stale.json" ] && echo exists || echo gone)" gone

# claude-desktop is the owner working (only sdk-* entrypoints are automated)
mkdir -p "$tmp/desk/p"
{ u claude-desktop $T "build the thing"; a $T "Built."; u claude-desktop $T "no, use the other file"; } > "$tmp/desk/p/d.jsonl"
dout="$(run "$tmp/desk")"
check "claude-desktop session counted" "$(printf '%s\n' "$dout" | head -1 | sed -E 's/^sessions ([0-9]+).*/\1/')" 1
check "claude-desktop correction counted" "$(val "$dout" correction)" 1
# IDE / system wrapper tags are stripped before the regexes
mkdir -p "$tmp/ide/p"
{ u cli $T "build it"; a $T "Built."
  u cli $T "<ide_opened_file>The user opened the file /x/y.ts in the IDE.</ide_opened_file> no, use the other file"; } > "$tmp/ide/p/i.jsonl"
check "IDE-wrapped correction counted" "$(val "$(run "$tmp/ide")" correction)" 1
# URLs, curly apostrophes, array-form tool results
mkdir -p "$tmp/misc/p"
{ u cli $T "https://x.com/someone/status/1234567890"; a $T "Read it."
  u cli $T "that’s not the right file"; a $T "Switching."
  u cli $T "check the export folder"; a $T "You’re right, it was empty."
  trA $T "PreToolUse:Write hook error: blocked"; a $T "Blocked." ; } > "$tmp/misc/p/m.jsonl"
mout="$(run "$tmp/misc")"
check "URL-only message is not a status ask" "$(val "$mout" status)" 0
check "curly apostrophe correction (that’s not)" "$(val "$mout" correction)" 1
check "curly apostrophe admission (You’re right)" "$(val "$mout" caught_miss)" 1
check "array-form tool_result hook error counted as a block" "$(printf '%s\n' "$mout" | grep -c 'hook/permission blocks 1$')" 1
# a plain tool error is a tool error, not a hook/permission block
mkdir -p "$tmp/err1/p"
{ u cli $T "read the config"; tr_ $T "Error: ENOENT no such file"; a $T "Missing."; u cli $T "make it then"; } > "$tmp/err1/p/e.jsonl"
eout="$(run "$tmp/err1")"
check "non-hook is_error: 0 blocks" "$(printf '%s\n' "$eout" | grep -c 'hook/permission blocks 0$')" 1
check "non-hook is_error: 1 tool error" "$(printf '%s\n' "$eout" | sed -nE 's/^tool errors ([0-9]+).*/\1/p')" 1
# unusable timestamps: skipped and reported, never a crash
mkdir -p "$tmp/badts/p"
{ u cli garbage "first turn here"; u cli garbage "second turn here"; } > "$tmp/badts/p/bad.jsonl"
{ u cli $T "first turn here"; u cli $T "second turn here"; } > "$tmp/badts/p/good.jsonl"
bout="$(run "$tmp/badts")"; bcode=$?
check "bad timestamp: exit 0, no crash" "$bcode" 0
check "bad timestamp: reported as skipped unreadable" "$(printf '%s\n' "$bout" | head -1 | grep -c 'skipped 1 unreadable')" 1
# CLAUDE_CONFIG_DIR moves the transcripts dir
mkdir -p "$tmp/cfg/projects/p"; { u cli $T "first turn here"; u cli $T "second turn here"; } > "$tmp/cfg/projects/p/c.jsonl"
cout="$(FRICTION_ROOT= CLAUDE_CONFIG_DIR="$tmp/cfg" node "$here/friction.js" --since 2026-09-10 --until 2026-09-11 2>/dev/null)"
check "CLAUDE_CONFIG_DIR/projects is read" "$(printf '%s\n' "$cout" | head -1 | sed -E 's/^sessions ([0-9]+).*owner turns ([0-9]+).*/\1:\2/')" 1:2

# precision (automate-me 2026-10-24): answers to Claude's own question and phrases inside a paste are not friction.
mkdir -p "$tmp/prec/p"
{ u cli $T "no, it's ok"; u cli $T "no but let us keep it"; u cli $T "no, we don't need that"
  u cli $T "that is not what we used last time"; u cli $T "how do you decide which one"
  u cli $T "once you decide, tell me"; u cli $T "<pasted_content>you decide the format</pasted_content> fyi"
  u cli $T "no, that is wrong"; u cli $T "your call"; } > "$tmp/prec/p/q.jsonl"
pout="$(FRICTION_ROOT="$tmp/prec" node "$here/friction.js" --since 2026-09-01 --top 1 2>/dev/null)"
check "precision: only the real correction counts" "$(val "$pout" correction)" 1
check "precision: only the real handback counts" "$(val "$pout" handback)" 1

echo "RESULT: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
