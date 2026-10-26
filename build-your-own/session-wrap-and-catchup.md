# Build your own: session wrap + catch-up

*A pair of habits that lets your coding agent pick up tomorrow exactly where it stopped today.*

This is not an installable skill. My versions are wired into my own folders, my own notes files and my
own git setup, so they would break on yours. What carries over is the shape and the lessons. Read this,
then hand it to your agent with the prompt at the bottom. It will build a version that fits your setup.

---

## What it does

Every new agent session starts with a blank memory. Two skills fix that:

- **Wrap**, at the end of a session: the agent writes down what changed, what was decided and what
  comes next, in a few fixed places, and saves it all in one commit.
- **Catch-up**, at the start of the next session: the agent reads only those places plus the latest
  commits, gives you a five-line summary, and recommends the next move.

Think of a shift handover in a factory or a hospital. The outgoing shift writes the log the incoming
shift reads. The value is not in the writing. It is in the next shift starting work in two minutes
instead of twenty, without repeating yesterday's mistakes.

## Why bother

- Without it, every session opens with "where were we?" Ten minutes of re-reading, and the agent still
  guesses wrong about what is finished.
- Decisions that leave no code behind disappear: "we tried tool X and dropped it", "we ruled out
  approach Y". Without a written log the next session proposes X again.
- Most agents auto-load one notes file into every session (`CLAUDE.md`, `AGENTS.md` or similar). That
  file is paid for on every run, so it has to stay short. Something has to keep it short, and the wrap
  is the moment to do it.

---

## The shape: four places, each with one job

| Place | What it holds | Size rule |
|---|---|---|
| **1. The always-loaded notes file** | A short "Current state" block: the phase you are in, the next action, and the last three sessions as one line each, with a link to that session's notes | Hard cap (I use about 2,500 characters and 30 lines). Enforced by a script. |
| **2. A session log** | One entry per session, newest first: a short label, date, status (done / paused / blocked), the exact next action, rough duration, files changed | The label is capped; the next action is not, because catch-up reads it word for word. |
| **3. The feature plan file** (when you are building something across several sessions) | The real task list, and one "latest session" block at the top. Older blocks are squashed to one line each. | That top block is capped. |
| **4. Learnings notes** | The full story of a session, written only when something non-obvious happened. Always includes a Decisions section. | No cap. This is where long text goes. |

Plus **one commit per wrap**, so a single search through the git history finds each session.

The rule that ties these together: **headline and pointer, never the same story in three places.** The
notes file says "shipped X, see the plan". The plan says "X done, see learnings". Only the learnings
file tells the story.

---

## The wrap, step by step (plain terms)

1. **Put up a "don't compact me" sign.** This applies only if your agent squashes long conversations
   automatically. A wrap takes several steps, and having it cut off halfway is the worst outcome.
2. **Update the feature plan,** if there is one: tick off tasks and write the latest-session block.
   Record each real decision in the project's decision log, not buried in the plan.
3. **Write a learnings note,** only if something non-obvious happened. It must have a Decisions section,
   even if that section says "None this session."
4. **Ask once:** "Did a repeatable mistake or a new rule come out of this session?" If yes, add it to your
   rules file. Usually the answer is no; skip it quietly.
5. **Update the "Current state" block** in the always-loaded notes file.
6. **Add the session-log entry** at the top of the log.
7. **Run the size checker.** If anything is over its cap, move the extra text down to the learnings note.
   Do not squeeze it.
8. **Make one commit** of exactly the files this session touched. **Push only if it is safe** (see lesson 10).
9. **Take the sign down.**

## The catch-up, step by step

1. **Refresh what the server knows** (`git fetch`). It is harmless: it never touches your files.
2. **Read, all at once:**
   - the last ~8 commits;
   - any uncommitted changes;
   - the top session-log entry for this project;
   - the active feature plan;
   - the one learnings note the notes file links to.
3. **Check for staleness.** Are there commits newer than the notes file's date? Has the server moved ahead
   of you? Say so.
4. **Check status words against reality.** If the notes say "PR #12 awaiting review", look the PR up. It
   may have been merged elsewhere. Fix the note before trusting it.
5. **Present a fixed-shape summary:** last session, current state, next action (word for word), branch,
   things to watch.
6. **Recommend one next move.** Do not offer a menu. Wait for the user.
7. **Settle the branch only after the user says what they want to do** (see lesson 12).

---

## Lessons learned (each one cost me at least one bad session)

1. **Write everything first, commit once, at the end.** My first version committed first and wrote notes
   after, so every wrap left its own notes out of the commit.

2. **Size rules written as text get ignored. Enforce them with a script that fails the commit.** I asked
   for "a 3–8 word label" for weeks. The labels grew to several thousand characters anyway. A checker that
   blocks the commit fixed it within a day.

3. **Never make a gate wait for "N clean runs" before it starts enforcing.** One of my checkers printed
   FAIL and still let everything through for over two months. It was waiting for three clean runs, and the backlog
   it existed to prevent kept those runs from ever being clean. Switch to enforcing on a date and pay the
   one-time cleanup.

4. **When something is over its cap, move text down a tier. Do not trim in circles.** Overflow almost
   always means a story was written into a summary slot. Move the story to the learnings note and leave a
   pointer.

5. **Don't pick "the active plan" by taking the first folder in alphabetical order.** Mine did, for months.
   It checked a dormant plan, the dormant plan passed every time, and the live one was never checked. Read
   which plan is active from what your notes file declares. If nothing declares one, print "skipped
   because no active plan is declared." A second bug in the same place: the pattern that found plan paths
   could not match plans kept under `docs/`, so one project skipped every check from day one.

6. **Silence must never mean two things.** "No checks configured" and "all checks passed" both printed
   nothing, so I could not tell them apart. Every check prints a line: OK, FAIL, NOT RUN or CANNOT CHECK.

7. **Add the new log entry above the old one. Don't edit the top entry in place.** The most common wrap bug
   I had: the agent replaced the old top label with the new one, leaving the old entry's date, status and
   next-action fields stuck under the new label. When a field appears twice, the last one wins, so catch-up
   read the *old* next action. Count the entries before and after; the count must go up by one.

8. **Check that the log still parses, every wrap.** A cleanup script that edited the log line by line
   deleted some keys but left their contents behind. The file stopped being valid, and nobody noticed for
   dozens of wraps because every reader also went line by line. Don't run a log-editing script until it has
   tests.

9. **If you run several sessions at once, don't stage "everything" in a shared folder.** `git add -A` swept
   other live sessions' half-finished edits into my commit. Keep a list of the files *this* session edited
   and commit exactly those.

10. **Push automatically only when it is clearly safe:**
    - you are on the main branch;
    - you are ahead of the server and not diverged;
    - the repo is not one where a push means a deploy.

    I once had a wrap push to a repo that deploys on push, and it redeployed a live service. Give such repos
    an opt-out file the wrap checks *first*. A rule written in a notes file loses to a step in the skill, so
    the step must carry the exception itself.

11. **Lock files and "in progress" markers need a liveness check and a long enough timer.** My
    "don't compact" marker expired after 10 minutes, but a wrap takes about 15, so it expired halfway. The
    fix:
    - record which process owns the marker;
    - refresh it at every step;
    - clear it automatically when that process is gone.

12. **Settle the branch after you know the plan for the session, and never switch with unsaved work.** A
    finished branch stays checked out in the folder until something switches it, so every new session
    silently starts there. Catch-up compares the branch's state (merged? deleted on the server? unsaved
    changes?) with what you said you want to do. Then it *proposes* staying or starting a fresh branch from
    the latest server copy, and waits for a yes.

13. **Write memory as dated history.** Write "as of 2026-03-01, X", not "X is current". When it changes,
    add a new dated line and mark the old one superseded. Undated "currently" claims were read as true for
    weeks after they stopped being true.

14. **Catch-up should add to what is already loaded, not repeat it.** Don't re-read the notes file the agent
    already has in context. Follow the one link it contains, read the log's top entry, and stop. A good
    catch-up costs a few thousand tokens, not tens of thousands.

15. **Trigger the wrap by measured context use, not by the agent "remembering".** A small hook reads how
    full the context window is, and nudges the agent at three levels:
    - **soft:** finish the current task, then wrap;
    - **hard:** wrap now;
    - **emergency:** write only the notes file, the log and one commit.

    Before this, the reminder sometimes never came, and a wrap started too late ran out of room halfway.

16. **Test the commands in the shell you actually use.** I hit three portability bugs:
    - zsh and bash expand variables differently;
    - macOS `grep` stops early with `-m 1`, which drops the lines `-A` should show;
    - some tools treat `$1` inside a skill file as a placeholder and blank it out before the shell sees it.

17. **Every checker needs a test that proves it can fail.** Feed it a known-bad input and watch it go red. A
    checker you have only ever seen pass tells you nothing.

---

## Start small

You do not need all of this on day one. A good first version:

- **Wrap:** update a short "Current state" block, add one log entry, make one commit.
- **Catch-up:** read the top log entry and the last 8 commits, give a five-line summary, recommend one
  next step.

Add a checker the second time a rule gets broken, not before.

---

## Give this to your agent

Copy everything in the box into a session with your coding agent, from the folder where you do most of
your work:

```text
I want two skills: "wrap" (end of session) and "catch-up" (start of session), so you can pick up
tomorrow where we stop today. The attached write-up describes the shape and the lessons; build a
version that fits MY setup, not the author's.

Before writing anything:
1. Inspect my setup and tell me what you found: which agent and version this is, which file(s) you
   auto-load every session, whether this folder is a git repo (and what its main branch is called),
   whether pushing here triggers a deploy, whether conversations get auto-compacted, and whether I
   run several sessions at once.
2. Propose the smallest useful version (the "Start small" section) and where each of the four places
   will live in my setup. Ask me at most 5 questions, each with your recommended answer.

When I say go:
- Write both skills in this agent's skill format and folder.
- Keep the always-loaded notes block under a size cap, and write a small script that checks the cap,
  plus one test that shows the script FAILS on an over-cap example.
- New log entries go ON TOP; verify the entry count went up by exactly one.
- Commit only the files this session changed. Never auto-push unless I am on my main branch, ahead
  and not diverged, and the repo has no "no auto-push" marker. Start with auto-push OFF until I turn
  it on.
- Catch-up must not re-read files you already auto-load, must check any "awaiting/open" status words
  against the real source, and must propose (not perform) any branch switch.
- Every check prints OK / FAIL / NOT RUN / CANNOT CHECK, never nothing.
- Then do a dry run: wrap this session for real, start a fresh session, run catch-up, and show me
  the summary it produced.
```
