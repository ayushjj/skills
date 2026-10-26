---
name: plain
description: >
  Decode a technical term, concept, code, or pasted external thing into plain language —
  without losing accuracy. Use when the user wants something explained simply / non-technically,
  or points at jargon and says "what does this mean." Triggers on '/plain', 'explain simply',
  'in plain words', 'non-technical', 'what does X mean', 'decode this', 'ELI5', 'too technical',
  'simpler', 'I don't understand X'. A deeper opt-in INTERNALIZE MODE (for durable retention, not
  one-shot decode) triggers on '/plain internalize', '/plain deep', 'help me internalize',
  'make this stick', 'I want to really understand / own this concept', 'go deep on X'.
license: MIT
---

# /plain — De-jargon, don't dumb down

The person you're explaining to is smart but not a specialist in this topic. The goal is to strip the jargon while **keeping the rigor**: simple *but* precise. Most people who ask for a plain explanation read it and then decide something, so the explanation should end pointed at a decision or a next step.

In practice the biggest source of confusion is usually **the project's own vocabulary** (named rules, decision IDs, phase names, internal labels), not generic tech. Treat those terms with extra care.

## Setting: the reader's world (asked once)

Analogies land best when they come from the reader's own field. Before the first analogy:

1. Look in the agent's instruction file (for example `CLAUDE.md` or `AGENTS.md`) for a line like `Plain-language analogies: my world is <field>`.
2. If it is there, borrow analogies from that field.
3. If it is not, ask once: "What field do you work in? I'll draw analogies from it." Use the answer, and offer to add the line above to their instruction file so you don't ask again. If they decline or don't answer, use everyday life (cooking, shopping, travel, a household budget).

## The job

**Mode gate (check first):** if invoked as `/plain internalize <x>` / `/plain deep <x>`, or with an "own this concept" phrase (make this stick, go deep on, I want to really understand) → run **INTERNALIZE MODE** (bottom of this file) instead of the default. The mode keyword is only a keyword when followed by the thing to learn (`/plain deep` alone, or `/plain deep learning` meaning the topic, is a normal decode). Everything below is the **default fast-decode** — the common case.

Take whatever they pointed at and return its plain-language meaning. Resolve in this order:

1. **Is it a project-dialect term?** (a named rule, a decision ID like `ADR-012`, a phase name, an internal label, a script/artifact name). If so, **read the source first** — the relevant spec, decisions file, agent instruction file, or the code — and define it in one line grounded in what you read. Do NOT explain a project term from inference; cite where it's defined.
2. **Is it generic tech / a tool / external content** (a post, a library, an architecture term)? Explain it directly in everyday words.

## Output shape (default)

- **Short. Bulleted. Non-technical. Ends with a recommendation or clear next step.** Cap it at a few lines unless they ask to expand.
- **One new idea per bullet.** Working memory holds about four things; don't stack three unexplained terms in one sentence.
- **Lead with the plain meaning, then (only if useful) the technical name** in parentheses — never the reverse.
- **Preserve precision.** Strip the jargon, keep the accuracy. If making it simple drops a nuance that matters to their decision, flag that one spot in a line — don't silently lose it.
- **Say it literally.** Don't swap a plain phrase for a decorative figure of speech ("this saves time", not "this buys you breathing room"). Decoration makes the reader translate twice and brings in meanings you didn't intend. The test: if a literal phrase exists, use it. An analogy that explains an idea the reader has no word for is teaching and stays; a figure of speech standing in for a phrase they already know goes.

## The Feynman test (self-check before sending)

If your explanation still needs jargon to hold together, it failed — rewrite it. Jargon hides the gap, it doesn't fill it.

## Pick the vehicle that produces understanding — proactively

The job is comprehension. People rarely *ask* for an analogy or a diagram, because the format isn't theirs to choose — it's yours. Choose, every time, the vehicle that makes the concept land fastest, and use it without being asked. A sentence plus a small diagram is remembered better than either alone.

Match the vehicle to the **shape of the concept**:

| Concept shape | Best vehicle |
|---|---|
| A named project term / definition | One-line plain definition (read its source first) |
| An abstract or unfamiliar idea | **Analogy** — borrowed from the reader's world (see Setting), and name the one place it breaks |
| A process with steps | A short ASCII flow (`A → B → C`) or numbered list |
| A comparison / tradeoff | A 2-column table, ≤5 rows |
| Relationships / hierarchy | A small ASCII tree or diagram |
| A single fact | Just say it — no scaffolding |

Often the best answer combines two: a one-line plain meaning **plus** a 4-line diagram. A diagram that replaces a paragraph is *shorter*. Brevity is about cutting noise, not cutting the thing that makes it click.

When you reach for a visual or analogy they didn't ask for, just use it — don't ask permission first. If it doesn't land, they'll tell you, and you adjust.

## Progressive disclosure

Give the **minimum sufficient** explanation first. Offer depth ("want the layer underneath?") only if they signal they want it. Don't front-load every caveat.

## Don't

- Don't hand them a technical artifact (a diff, an option list) to rubber-stamp. Decode it AND recommend — a recommendation they can evaluate beats a decision they can't.
- Don't pad. Precise and to the point beats thorough-but-verbose, always.
- Don't invent a definition for a project-internal term — read its source first.
- **(internalize mode)** Don't let the deep mode leak into the default — only the explicit triggers above activate it; every other ask gets the fast decode.
- **(internalize mode)** Don't write recall questions they can answer yes/no or by recognition — they must force retrieval or application. And when they answer, correct what's wrong; don't flatter.
- **(internalize mode)** Don't fabricate a connection or a note title — read the note, or say "this is new territory." A forced connection is worse than an honest gap.

---

## Internalize mode (only when explicitly triggered)

The default decodes a concept so the reader can *act now*. Internalize mode is for the few concepts they want to *own* long-term — it trades brevity for retention. It may run longer than the default, but stay **a few short labeled beats, not a wall of text**. It is multi-turn: it ends by handing them the work, then waits.

The three mechanics are among the most robust findings on how memory forms: connect-to-what-you-know (elaborative encoding), one-world analogy (analogical transfer), and retrieve-before-you're-told (the testing effect). Run them in order.

**Beat 0 — Ground it first (same rigor as default).** If it's a project term, read its source before explaining — depth is not licence to infer a definition. Going deep makes grounding *more* important, not less.

**Beat 1 — Master-analogy.** Build ONE coherent analogy drawn from the reader's world (see Setting) that the *whole* concept maps into — not three scattered mini-analogies. Map the concept's main moving parts onto that single world, then **name the 1-2 places the analogy breaks**. The breakpoint is where the real understanding lives — an analogy you can't break, you don't yet understand. (Example of "one analogy": explaining caching, queues and retries all through a single restaurant kitchen — the pass, the ticket rail, the re-fire — instead of a new comparison for each.)

**Beat 2 — Latticework.** Bolt the new concept to what they already know — a fact tied to three things you know is retained; a fact floating alone is forgotten.
- If the user names a notes or knowledge index in their instruction file, scan it and surface **2-4 genuine** connections, using the real note titles: *extends* `[note]`, *in tension with* `[note]`, *same shape as* `[note]`. Read the note before claiming the link.
- Otherwise, link to concepts already discussed in this conversation or in the current project.
- If nothing genuinely connects, say so — "no strong link to what you already hold; this is new territory" — and do NOT manufacture one.

**Beat 3 — Active recall (pose, then STOP).** End the message with 2-3 questions and **do not answer them** — the effortful attempt is the mechanism, not the explanation. Questions must demand retrieval or application, never yes/no: *explain it back in your own words · apply it to a concrete case from your world · name where it breaks.* Then stop and wait. When they answer next turn, give **honest correction** — mark what's right, fix what's off — not praise.

**Beat 4 — Spaced follow-up (offer, don't impose).** Once the recall exchange resolves, offer one line: if your agent can set reminders, a short recall check a few days out — spacing is the strongest retention lever there is. Never auto-schedule; let them choose each time.
