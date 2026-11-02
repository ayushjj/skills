---
name: automate-me
description: >
  Reads your recent Claude Code session conversations, finds where work went worse than it
  should (you corrected the agent, asked for a plainer explanation, asked for status, handed a
  decision back, repeated yourself), works out why, and drafts ready-to-approve fixes to your
  skills or instruction files, or a new skill when a procedure repeats. Run weekly. Claude Code
  only. Triggers on '/automate-me', 'what do I keep repeating', 'where am I a bottleneck',
  'mine my sessions', 'what should be a skill', 'where am I losing time'.
license: MIT
---

# /automate-me — find where you keep losing time, and fix it

**Job:** once a week, look back over how you actually worked with the agent, find the moments
that went worse than they should have, work out why, and hand you a short list of fixes you can
approve with a yes. Nothing changes without your yes.

**Why read conversations, not just prompts.** An earlier version only counted what the user typed
and stopped at a report. Five runs produced two settings tweaks and zero skill changes. A count can
tell you that "explain this" requests are rising; only reading the conversation around each one
tells you which reply was unclear and what to change.

**Scope.** A session wrap captures what one session learned. This skill looks across many
sessions for friction that *repeats*, and proposes the fix.

## Step 0: Load state

Read `~/.claude/automate-me-state.yaml`.
- If present → take `last_run` and `surfaced` (problems found in earlier runs).
- If missing → first run: look back 30 days, `surfaced: []`.

Say: "automate-me: last run {last_run} ({N} days ago). Reading sessions since then."

## Step 1: Find the friction moments (in code, not by the model)

```bash
bash "<this skill's folder>/scripts/friction.test.sh"     # must pass first
node "<this skill's folder>/scripts/friction.js" --since {last_run} --top 12 --json "$TMPDIR/friction.json"
```

`friction.js` reads the session transcripts in `~/.claude/projects/` and flags five kinds of moment
in your own messages: **correction** ("no, that's not what I asked"), **explain** ("help me
understand", "simpler"), **status** ("where are we"), **handback** ("you decide", "why are you
asking"), and **repeat_request** (you said nearly the same thing twice in a row). It also flags
**caught_miss**, when the agent's next reply opens with "you're right", and it counts tool errors
and blocked actions. It prints counts and file/line pointers only, never transcript text. It skips
automated runs and one-message sessions.

**Exit 2 = CONTROL FAILED = the step did not run.** Never read it as "no friction". The test script
proves the counter can fire and can stay quiet on known examples before any number is trusted.

## Step 2: Read the moments and judge (one subagent)

Hand `friction.json` to one subagent on your strongest model. It reads a window around each moment
(the 2–3 agent replies before it, your message, what happened after), across at least 30 moments in
at least 8 sessions, and returns:

- **How often the counter was right** (real friction / moments checked). If a signal is right less
  than about 60% of the time, tune its pattern in `friction.js` and add a test case.
- **Root causes, grouped,** with counts and paraphrased examples. No verbatim text from you or the
  agent, no client names, no credentials, tokens or URLs with keys (agent replies can repeat a
  secret you pasted, so paraphrase those too).
- **Where each fix belongs.** Read the target first: your `CLAUDE.md`, a project `CLAUDE.md`, an
  output style, a skill's `SKILL.md`, or a NEW skill when the same multi-step procedure shows up in
  3 or more sessions.
- **Make it impossible before you write it down.** Written instructions are the last resort,
  because nothing fails when an agent skips them. For each cause, try in order:
  1. remove the cause (one owner, one supported way, delete the wrong example people copy);
  2. a hook, script, type or lint check that fails and names the fix;
  3. a test;
  4. only then text in a skill, style or `CLAUDE.md`, and only for judgment calls.

  Every text fix says why 1–3 can't do the job. Every check fix is shown failing on a real past
  instance (see the `harden` skill). If a cause matches a text fix applied in an earlier run, move
  one level up the list.
- **Test every text fix before drafting it.** Take 3 real moments of the failure. Run one fresh
  agent per moment on the OLD text and one on the NEW text. One blind judge scores a single yes/no
  question, with its rule and edge cases written down before it reads any reply. The test counts
  only if OLD fails in at least 2 of 3. Draft the fix only if NEW passes at least 2 more than OLD.
- **Up to 5 drafted fixes:** exact old → new text, each with a before → after from your side.

## Step 3: Check against earlier runs

Compare the causes with `surfaced`. A cause that matches a fix you already applied means that fix
didn't work. Say so plainly; it is the most useful thing a run can find.

## Step 4: Present the fixes

Save the report to `~/.claude/automate-me-reports/{YYYY-MM-DD}-report.md`: counts, causes, drafts.
No transcript text, and not the top-sessions table (folder names can carry client names). Before
saving, search the draft for `password|token|secret|api[_-]?key|key=` and any client names you keep
private; a hit blocks the save until it is rewritten.

Show each fix as: what goes wrong today → what changes after → the exact edit. Apply only the ones
you approve.

## Step 5: Update state

```yaml
# automate-me state — maintained by the skill.
last_run: "{today}"
surfaced:           # keep the last 30
  - intent: "explain → plainer replies"
    first_seen: "{date}"
    runs_seen: 3
    status: open    # open | acted | dismissed
```

## Checks
- Before you approve anything, the run wrote only to `automate-me-reports/` and the state file.
- No raw prompt text in the report: counts, paraphrases and pointers only.
- Running it twice on the same day finds the same top sessions (the counting step is code).
- A fix you applied is re-measured next run: the cause it targeted should shrink.

## Guardrails
- Resolve paths through `$HOME`; don't hard-code your home folder, project or business names.
- Rank problems by how many sessions they show up in, not raw count. One busy session is not a habit.
- Drafts are proposals; nothing goes into a skill, style or `CLAUDE.md` without your yes.

Credit: the "make it impossible before you write it down" order comes from the `correct` skill in
Lauren Tan's [pstack](https://github.com/cursor/plugins/tree/main/pstack).
