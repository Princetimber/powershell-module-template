---
applyTo: "build.ps1,build.yaml,.github/workflows/**"
---

## Build & CI Standards

- Maintain compatibility with Sampler + Invoke-Build.
- Never bypass lint or test stages.
- Ensure ScriptAnalyzer and Pester run in CI.
- Pin module/action versions where practical.
- Do not expose secrets in logs.
- Keep GitVersion.yml consistent with release strategy.
