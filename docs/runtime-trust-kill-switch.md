# Runtime Trust Kill Switch

## Purpose

This document defines trust-based containment behavior enforced by Agent Runtime.

## Core Rule

```text
If trust score falls below the organization-defined critical threshold,
freeze the agent immediately.
```

## Enforcement Actions

When triggered, Agent Runtime must:

1. Freeze agent identity.
2. Revoke tool access.
3. Revoke secret access.
4. Lock active runs.
5. Prevent new assignments.
6. Stop A2A handoffs.
7. Mark agent as `unverified` / `trust_failed`.
8. Emit containment events.
9. Preserve evidence.
10. Require human approval to reactivate.

## Final Rule

Trust threshold breaches are runtime containment events.
