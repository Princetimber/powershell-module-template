---
applyTo: ".github/workflows/**"
---

## CI/CD workflow standards

- Keep workflows minimal and deterministic.
- Pin action versions and tool versions where practical.
- Ensure lint + tests run in CI:
  - `Invoke-ScriptAnalyzer -Recurse`
  - `Invoke-Pester`

- Never echo secrets. Use masked secrets and OIDC where supported.
- Prefer least-privilege permissions in workflow `permissions:` blocks.
