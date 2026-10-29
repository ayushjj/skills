# skills

Skills we built while running a real business with Claude Code. I'm not an engineer, so most of these
exist because something went wrong once and we wanted to make sure it couldn't happen again. Each one is
a folder with a `SKILL.md` that your coding agent loads when the task fits. They follow the open
[Agent Skills](https://agentskills.io/specification) format, so they install into Claude Code, Codex,
Cursor and other agents that read it.

## Install

```bash
npx skills add ayushjj/skills
```

The installer asks which skills and which agents. Other forms:

```bash
npx skills add ayushjj/skills --skill harden        # one skill
npx skills add ayushjj/skills -g -a claude-code     # all skills, globally, Claude Code only
npx skills add ayushjj/skills --list                # just list what's here
```

Claude Code users can also install all of them as a plugin:

```text
/plugin install ayushjj-skills --marketplace ayushjj/skills
```

## Skills

| Skill | What it does |
|---|---|
| [premise-check](skills/premise-check/SKILL.md) | Before planning something new, tests whether the problem is real and worth solving, and says so plainly if it isn't. |
| [creating-specifications](skills/creating-specifications/SKILL.md) | Writes a design, a decisions log and an implementation tracker before you build a non-trivial feature. |
| [harden](skills/harden/SKILL.md) | Proves a specific check, test or guard can actually fail, by breaking what it watches and confirming it goes red. |
| [executing-batch-operations](skills/executing-batch-operations/SKILL.md) | Runs bulk data changes as dry run, sample, rollback file, confirmed run, then audit queries. |
| [prompt-engineering](skills/prompt-engineering/SKILL.md) | Fixes an LLM prompt's structure first, then tunes it against at least 10 measured test cases. |
| [autonomous-batch](skills/autonomous-batch/SKILL.md) | Runs a queue of similar, independent tasks one subagent at a time, each ending in its own pull request. Claude Code only. |
| [plain](skills/plain/SKILL.md) | Explains a term, a piece of code or a pasted post in plain words without losing accuracy; a deeper mode helps a concept stick. |
| [brief](skills/brief/SKILL.md) | Teaches one theme a day from your own saved bookmarks, old and new, in plain words with one thing to try today. |

Some skills include an `evals/` folder with test prompts and graders. Run them with
`claude plugin eval skills/<name>` if you use Claude Code.

## Build your own

Some of my skills only make sense wired into my own folders, notes and git setup, so installing them
would break on yours. For those I share the shape and the lessons instead, as a write-up you hand to
your own agent so it builds a version for your setup. They live in [`build-your-own/`](build-your-own/),
which the installer skips.

- [Session wrap and catch-up](build-your-own/session-wrap-and-catchup.md): end each session with a
  short handover note and one commit, and start the next by reading only that, so the agent picks up
  where it stopped.

## Skills I use from others

These are great and I use them all the time. Install them from their authors so you get the current version.

**Matt Pocock** — [mattpocock/skills](https://github.com/mattpocock/skills)

```bash
npx skills add mattpocock/skills --skill grill-me
```

- `grill-me`: interviews you about every open decision in a plan before work starts.
- `tdd`: test-driven development, one failing test at a time.
- `diagnosing-bugs`: a diagnosis loop that starts from the error and a repro, not a guess.
- `codebase-design`: shared vocabulary for designing deep modules and choosing where seams go.
- `domain-modeling`: builds and sharpens a project's domain language and decision records.
- `research`: investigates a question against primary sources and writes the findings to a file.
- `wizard`: generates an interactive script that walks a person through steps only they can do.
- `writing-for-agents`: how to write skills and agent instruction files that agents actually follow.
- `resolving-merge-conflicts`: works through a merge or rebase conflict hunk by hunk. Archived upstream,
  but the [reference page](https://github.com/mattpocock/skills/blob/main/docs/engineering/resolving-merge-conflicts.md) is still up.

**Every** — [compound-engineering](https://github.com/EveryInc/compound-engineering-plugin): a plugin of
planning, review and shipping workflows for Claude Code, Codex, Cursor and more.

```text
/plugin marketplace add EveryInc/compound-engineering-plugin
/plugin install compound-engineering
```

**Lauren Tan** — [pstack](https://github.com/cursor/plugins/tree/main/pstack): a large set of skills and
engineering principles; its `correct` skill (turning repeated agent mistakes into checks) shaped how I work; my adaptation is not included here.

## License

[MIT](LICENSE)
