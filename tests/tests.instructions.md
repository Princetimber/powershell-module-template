---
applyTo: "tests/**,**/*.Tests.ps1"
---

## Pester Testing Standards (tests/)

- Use Pester v5+ syntax and patterns.
- Mock all external dependencies (Graph, REST, filesystem, registry, AD, services).
- Include:
  - Success paths
  - Failure paths
  - Auth failure
  - Empty result handling
  - Throttling/retry logic (where applicable)

- Integration tests must be tagged and opt-in.
- Tests must run cleanly via `Invoke-Pester` and Sampler pipelines.
