---
name: living-context
description: Records what a coding session learns on a Jira work item as Living Context Entries, scoped so later work inherits them, and reads the team's Entries before changing code. Use when a prompt or branch names a Jira work item key such as SHOP-142, when a Living Context pack or hook line is in context, or before calling get_context, record_context or search_context.
---

# Living Context

Living Context keeps what the team learns on Jira work items as Entries: decisions, gotchas, workarounds, assumptions and open questions. Each Entry is recorded on one Work item and reaches later ones through its Scope tags: components, parent, labels and code paths. A Context pack brings a Work item's Entries into your context. Your part is Capture: record what a teammate will need as the work goes, and read what the team already knows before you change code.

The plugin's hooks fetch and remind: they put the pack in context when a prompt names a Work item, name the repository, ask you to search a directory on your first edit in it, and ask once at the end when nothing was recorded. Hooks never record; recording is yours.

## Starting work

### Missing pack

A prompt naming a Work item usually brings its pack, and for each key in the prompt or the branch a line such as "Living Context: repository is caskcode/fernhill-shop-demo (git remote origin). If no Living Context pack for SHOP-142 is in your context, call get_context SHOP-142." When the prompt names a Jira work item and no pack for it is in context, call `get_context` with its key yourself. A line "Living Context couldn't fetch the pack for SHOP-142: …" is a failed call: handle it as When a Living Context tool fails says.

### When a Living Context tool fails

Tell the engineer what the tool said, in its own words, and carry on with the work.

If the message is about signing in, or the Living Context tools are missing, ask the engineer to run /mcp and choose plugin:living-context:living-context to sign in.

If every Living Context tool fails with MCP_TOOL_CONFIGURATION_INVALID_INPUT, the most likely cause is that Living Context is connected to Confluence on this site and you don't have Confluence access. Tell the engineer to ask a site admin for Confluence access, or to disconnect Confluence from the app.

## While working

### Reading by path

When you start work in a file or directory, call `search_context` with `repository` and `path`: the file, or the directory ending in /. The edit nudge, "Living Context: call search_context { repository: …, path: … } before changing files here.", prompts this on your first edit in a directory.

### Worth an Entry

Before recording, ask: "Would a teammate starting a later Work item in this area want this, and couldn't they learn it in a minute from the code, the diff, or Jira?" Record only what passes. Expect a few Entries a session, often none.

### Never recorded

These never pass, whatever else they say:

- secrets, tokens or personal data;
- facts about this machine or session ("I seeded the local test database");
- progress reports, or restatements of the diff or the Work item;
- guesses stated as facts: record a guess as an assumption;
- anything already in the pack: cite its Entry id instead.

### When

Record as the work goes: when a decision is made, a gotcha bites, or a workaround goes in. One Entry per `record_context` call, on the Work item you are working on.

### Scope

Name the Scope tags explicitly; every Entry needs at least one:

- `components`: the components of the area the Entry is about;
- `parent`: only when the Entry holds for the whole epic;
- `labels`: only when the team uses that label deliberately for an area;
- `paths`: as narrow as the knowledge, the file or directory it is really about, with its `repository`;
- `only_this_work_item`: true when nothing else applies, and then alone.

For `repository`, use the one the Living Context hook line named; when no hook line named one, give no paths and skip reading by path.

### Changes

When an Entry looks wrong or out of date, or an open question is answered, record a new Entry with the old one's id in `references`, and tell the engineer. The new Entry is the change: never edit an Entry.

## Ending the turn

### No Work item

When something passes Worth an Entry but no Work item is known, record nothing and keep working rather than stopping to ask. End the turn with: "Worth recording in Living Context: <gist>. Tell me the Work item key and I'll record it."

### Closing line

End the turn with one line per Entry recorded, "Recorded E-7KQ2M9XP (decision): <gist>", and one per Entry refused as a duplicate, "Already recorded as E-7KQ2M9XP (gotcha): <gist>".
