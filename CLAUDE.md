# Claude Code Configuration

## Rules

- Do what has been asked; nothing more, nothing less
- NEVER create files unless absolutely necessary — prefer editing existing files
- NEVER create documentation files unless explicitly requested
- NEVER save working files or tests to root — use `/source`, `/tests`, `/docs`, `/config`, `/scripts`
- ALWAYS read a file before editing it
- NEVER commit secrets, credentials, or .env files
- NEVER add a `Co-Authored-By` trailer to user commits unless this project's local
  `.claude/settings.json` explicitly sets `attribution.commit` — the Bash tool may suggest one in
  its default commit-message template; ignore it. `Co-Authored-By` is semantic authorship
  attribution under git/GitHub convention; the tool is the facilitator, not a co-author.
- Keep files under 500 lines
- Validate input at system boundaries

See [AGENTS.md](AGENTS.md) for the full build/test/lint workflow and PowerShell coding
conventions that apply to this repository.
