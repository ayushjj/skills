#!/usr/bin/env node
// Friction extractor for /automate-me. Reads session transcripts (not just typed prompts) and
// finds the moments where work went less well than it should: you corrected the agent,
// asked for a plainer explanation, asked for status, handed a decision back, repeated a request,
// or Claude's next reply admitted a miss ("you're right"). Also counts tool errors and hook /
// permission blocks. Prints COUNTS + pointers (file, line) only — never transcript text.
//
// Usage: node friction.js --since YYYY-MM-DD [--until YYYY-MM-DD] [--top N] [--min-turns N] [--json out.json]
// FRICTION_ROOT overrides the transcripts dir (tests only). Exit 2 = CONTROL FAILED; exit 64 = bad usage.
'use strict';
const fs = require('fs'), path = require('path'), os = require('os');

function usage(msg) { console.error(`usage error: ${msg}\n${fs.readFileSync(__filename, 'utf8').split('\n')[7]}`); process.exit(64); }
function flag(name, fallback) {
  const i = process.argv.indexOf(name);
  if (i < 0) return fallback;
  const v = process.argv[i + 1];
  if (v === undefined || v.startsWith('--')) usage(`${name} needs a value`);
  return v;
}
function dateFlag(name, fallback) {
  const v = Date.parse(flag(name, fallback));
  if (!Number.isFinite(v)) usage(`${name} is not a date`);
  return v;
}
function intFlag(name, fallback) {
  const v = Number(flag(name, fallback));
  if (!Number.isInteger(v) || v < 0) usage(`${name} must be a whole number`);
  return v;
}
const since = dateFlag('--since', '1970-01-01');
const until = dateFlag('--until', '2999-01-01');
const top = intFlag('--top', '15');
// Sessions with a single owner message are almost all automated one-shot runs (headless `claude -p`),
// not you working. Counting them dilutes every rate (in one real run, 230 of 282 "sessions").
const minTurns = intFlag('--min-turns', '2');
const root = process.env.FRICTION_ROOT || path.join(os.homedir(), '.claude', 'projects');

// Owner-message signals, in priority order: one message counts under its FIRST match only.
const OWNER_SIGNALS = [
  ['correction', t => /^(?:\[image #?\d*\]\s*|hmm,?\s*|actually,?\s*|ok,?\s*|wait,?\s*)*(no\b(?![,.]?\s*(worr|problem|need|it'?s ok|its ok|it is ok|but\b|we don'?t need))|nope|wrong|that'?s not|not what (i|you)\b|i said|i meant|i already|you didn'?t|why did you|stop\b)/.test(t)
    || /\b(i already told|that'?s wrong|not what i asked|you missed|you forgot)\b/.test(t)],
  ['explain', t => /\b(explain|help me understand|don'?t understand|didn'?t understand|simpler|plain (words|language)|dumb (it )?down|what does .{1,40} mean)\b/.test(t)],
  ['status', t => t.length < 200 && /\b(status|where are we|what('?s| has been) (done|left)|progress|is it done|update me)\b/.test(t)],
  ['handback', t => /(?<!\b(how|do|when|once|if|until|after) )\b(you decide|your call|why are you asking|just do it|stop asking)\b/.test(t)],
];
const ALL_SIGNALS = [...OWNER_SIGNALS.map(([k]) => k), 'repeat_request', 'caught_miss'];
const ADMISSION = /^(you'?re right|you are right|i got that wrong|good catch|that'?s on me|my mistake|you caught)/;
const BLOCK = /^(PreToolUse:\w+ hook error|Permission for this action was denied|.{0,40}hook (error|blocked))/i;

function ownerText(entry) {
  if (entry.type !== 'user' || entry.isMeta || entry.isCompactSummary || entry.isSidechain) return null;
  const content = entry.message && entry.message.content;
  if (typeof content === 'string') return content;
  if (Array.isArray(content) && !content.some(x => x && x.type === 'tool_result')) {
    return content.filter(x => x && x.type === 'text').map(x => x.text).join(' ') || null;
  }
  return null;
}
const isSystemish = text => /^(<(command-|local-command|bash-|task-notification|system-reminder)|\[SYSTEM|\[Request interrupted)/.test(text);
const wordSet = text => new Set(text.match(/[a-z]{4,}/g) || []);
function overlap(a, b) {
  if (a.size < 4 || b.size < 4) return 0; // too short to call a repeat
  let shared = 0; for (const w of a) if (b.has(w)) shared++;
  return shared / Math.max(a.size, b.size);
}

function readSession(file, project) {
  let raw;
  try { raw = fs.readFileSync(file, 'utf8'); } catch { return null; } // rotated, deleted, or too large
  const session = { file, project, automated: false, turns: 0, toolErrors: 0, blocks: 0, moments: [], counts: {} };
  const flagged = new Set();
  const mark = (line, signal) => {
    if (flagged.has(line)) return; // one owner message counts once
    flagged.add(line); session.counts[signal] = (session.counts[signal] || 0) + 1; session.moments.push({ line, signal });
  };
  let prevWords = null, firstTs = null, lineNo = 0, awaitingReplyTo = null;
  for (const line of raw.split('\n')) {
    lineNo++;
    if (!line) continue;
    let entry; try { entry = JSON.parse(line); } catch { continue; }
    if (entry.entrypoint && entry.entrypoint !== 'cli') session.automated = true; // sdk/headless jobs, not the owner
    const ts = entry.timestamp ? Date.parse(entry.timestamp) : null;
    if (ts !== null && firstTs === null) firstTs = ts;
    if (ts !== null && (ts < since || ts >= until)) continue; // count only what happened inside the window
    const content = entry.message && entry.message.content;
    if (entry.type === 'user' && Array.isArray(content)) {
      for (const block of content) if (block && block.type === 'tool_result') {
        awaitingReplyTo = null; // a reply after tool work answers the tool, not the owner
        if (block.is_error) session.toolErrors++;
        const body = typeof block.content === 'string' ? block.content : JSON.stringify(block.content || '');
        if (BLOCK.test(body.trimStart())) session.blocks++;
      }
    }
    if (entry.type === 'assistant' && !entry.isSidechain && Array.isArray(content) && awaitingReplyTo !== null) {
      const reply = content.filter(x => x && x.type === 'text').map(x => x.text).join(' ').trim().toLowerCase();
      if (reply) { if (ADMISSION.test(reply)) mark(awaitingReplyTo, 'caught_miss'); awaitingReplyTo = null; }
    }
    const text = ownerText(entry);
    if (!text || isSystemish(text.trim())) continue;
    const lower = text.replace(/<pasted_content[\s\S]*?<\/pasted_content>/g, '').toLowerCase().trim();
    session.turns++;
    awaitingReplyTo = lineNo;
    const words = wordSet(lower);
    const match = OWNER_SIGNALS.find(([, test]) => test(lower));
    if (match) mark(lineNo, match[0]);
    else if (prevWords && overlap(words, prevWords) > 0.6) mark(lineNo, 'repeat_request');
    prevWords = words;
  }
  session.firstTs = firstTs;
  return session;
}

let skippedShort = 0, skippedAuto = 0;
const sessions = [];
let dirs = [];
try { dirs = fs.readdirSync(root); } catch { /* handled by control below */ }
for (const dir of dirs) {
  if (/worktrees|scratchpad|-private-tmp/.test(dir)) continue; // agent worktrees, not owner sessions
  const projectDir = path.join(root, dir);
  let files; try { files = fs.readdirSync(projectDir).filter(f => f.endsWith('.jsonl')); } catch { continue; }
  for (const f of files) {
    const file = path.join(projectDir, f);
    let stat; try { stat = fs.statSync(file); } catch { continue; }
    if (stat.mtimeMs < since) continue; // not touched since the window opened (cheap prefilter)
    const session = readSession(file, dir.replace(/^-Users-[^-]+-?/, '') || 'home');
    if (!session || session.firstTs === null) continue;
    if (session.automated) { skippedAuto++; continue; }
    if (session.turns < minTurns) { skippedShort++; continue; }
    session.start = new Date(session.firstTs).toISOString().slice(0, 10);
    session.friction = session.moments.length + 0.2 * session.blocks;
    sessions.push(session);
  }
}

if (sessions.length === 0) { console.error(`CONTROL FAILED: no sessions with >=${minTurns} owner turns read from ${root}`); process.exit(2); }
const totals = {}; let turns = 0;
for (const s of sessions) { turns += s.turns; for (const [k, v] of Object.entries(s.counts)) totals[k] = (totals[k] || 0) + v; }
const sessionsWith = k => sessions.filter(s => s.counts[k]).length;
console.log(`sessions ${sessions.length} (owner, >=${minTurns} turns in window; skipped ${skippedAuto} automated, ${skippedShort} shorter) | owner turns ${turns}`);
console.log('signal\tmoments\tsessions\t% of sessions');
for (const k of ALL_SIGNALS) console.log(`${k}\t${totals[k] || 0}\t${sessionsWith(k)}\t${Math.round(100 * sessionsWith(k) / sessions.length)}%`);
console.log(`tool errors ${sessions.reduce((a, s) => a + s.toolErrors, 0)} | hook/permission blocks ${sessions.reduce((a, s) => a + s.blocks, 0)}`);
const ranked = [...sessions].sort((a, b) => b.friction - a.friction).slice(0, top);
console.log(`\nTOP ${ranked.length} sessions by friction (open these windows):`);
for (const s of ranked) console.log(`${s.start}\t${s.project}\tturns ${s.turns}\t${JSON.stringify(s.counts)}\tblocks ${s.blocks}\t${s.file}\tlines ${s.moments.slice(0, 12).map(m => m.line).join(',')}`);
const out = flag('--json');
if (out) fs.writeFileSync(out, JSON.stringify(ranked.map(({ firstTs, ...rest }) => rest), null, 1));
// Control: 20+ owner turns with zero OWNER-side signals means the detector is blind (format change,
// broken regex). caught_miss is Claude-side, so it cannot mask a blind owner detector.
const ownerSignals = ALL_SIGNALS.filter(k => k !== 'caught_miss').reduce((a, k) => a + (totals[k] || 0), 0);
if (turns >= 20 && ownerSignals === 0) { console.error(`CONTROL FAILED: ${turns} owner turns but no owner signals`); process.exit(2); }
