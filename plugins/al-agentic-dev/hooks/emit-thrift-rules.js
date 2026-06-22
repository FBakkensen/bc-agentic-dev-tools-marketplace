#!/usr/bin/env node
// SessionStart re-injection: emit references/thrift-rules.md verbatim so the token-thrift
// rules survive a context compaction (matcher startup|resume|compact in hooks.json).
// Single source of truth — this script never restates the rules, it re-reads the one file.
// Missing node degrades to prompt-resident-only (skills still read thrift-rules.md on
// invocation); the only loss is mid-loop re-assertion across compaction.
const fs = require("fs");
const path = require("path");

const rulesPath = path.join(__dirname, "..", "references", "thrift-rules.md");

try {
  const body = fs.readFileSync(rulesPath, "utf8");
  // Plain stdout on exit 0 is added as SessionStart context. A one-line frame tells the
  // model these are standing rules, not conversation.
  process.stdout.write(
    "Standing token-thrift rules for AL/Business Central work (re-asserted after context loss):\n\n" +
      body
  );
} catch {
  // Never block a session on a missing or unreadable rules file.
  process.exit(0);
}
