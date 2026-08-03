---
paths: ["**/*gog*", "**/gogcli-safety-hook.py"]
---

# gog CLI Gotchas

## `sheets update --help` triggers the safety hook — don't probe syntax that way

The `gogcli-safety-hook.py` PreToolUse hook (wired in `~/.claude/settings.json`, script lives at `claude-config/scripts/gogcli-safety-hook.py`) blocks `gog sheets update|append|write` unless the spreadsheet ID is in `ALLOWED_SHEET_IDS`. Its regex grabs whatever token immediately follows `update`/`append`/`write` as the "sheet ID" — so `gog sheets update --help` gets `--help` treated as the sheet ID, fails the allowlist check, and denies. This looks like a real block but isn't — it's a false positive from checking syntax mid-command.

**To check `sheets update` flags safely, use `gog sheets --help` (no subcommand) instead** — it lists available commands without tripping the regex.

## `sheets update` value flag is `--values-json`, not `--values`

```bash
gog -a <account> sheets update <spreadsheetId> "SheetName!A1:B1" --values-json '[["val1","val2"]]'
```

`--values` doesn't exist; passing it errors with "unknown flag --values, did you mean --values-json". The value is a JSON array of rows, each row an array of cell values — a single-row update to a range still needs `[[...]]`, not `[...]`.

## Already-allowlisted sheets write successfully — no extra step needed

`ALLOWED_SHEET_IDS` in the safety hook already includes the Datadog Illuminated tracker sheet (`13dtP9_WXPtiikYj2bxrzV2uon2sxSUlb2JaxSPiCOXE`, tab set: Guest Pipeline / Episodes / Shorts) and the Thunder staging sheet (`1eatUotHm4YOin1_rsqRSb71wY4S-lh5SsGInJVznBts`). Writes to these succeed directly — no need to ask permission or add the ID again. If a write to one of these is denied, suspect the `--help` false-positive above before assuming the allowlist needs updating.

To add a new sheet to the allowlist: edit `ALLOWED_SHEET_IDS` in `claude-config/scripts/gogcli-safety-hook.py` (the copy actually wired up via `~/.claude/settings.json` — other copies under `~/.claude/scripts/` or other repos are not live and edits there have no effect).

## `docs find-replace` is unreliable for multi-paragraph structural inserts — prefer manual copy-paste

Using `gog docs find-replace` to insert a new multi-paragraph section (e.g., a heading plus several paragraphs of body text) into an existing Google Doc produced three distinct failure modes across repeated attempts on the same document:

1. **Heading-style bleed** — the inserted body text inherited the heading style of the anchor text it replaced, instead of falling back to normal text.
2. **Content duplication** — a retry after the first failure duplicated the section rather than cleanly replacing it.
3. **Unwanted bold formatting** — inline runs within the inserted text came out bold that shouldn't have been (only visible by eye — `gog docs structure` reports paragraph type and text but not inline run formatting, so this can't be caught programmatically).

None of these produced an error — each command reported success while leaving the doc in a visibly broken state, discoverable only by opening the doc and looking, or asking the user to look.

**Fix that worked**: abandon `find-replace` for this kind of edit. Use Google Docs Version History to restore to a known-good state, then have the user manually copy-paste a plain-text block (prepared in advance) and apply formatting themselves. `gog docs structure --json` is safe to use read-only afterward to verify paragraph-level structure (no duplication, correct text) — but it cannot verify inline formatting; that requires the user to look at the rendered doc.

**When this matters**: any task inserting a new section with mixed heading/body/bullet structure into an existing doc. Simple single-string find-replace (no structural changes) has not shown this failure pattern.
