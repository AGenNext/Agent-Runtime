# Runtime-enforced A2A handoff

A2A handoff validation must be enforced by Agent-Runtime.

Agents must not self-certify handoff completeness.

## Decision

Before a target agent receives execution control, Agent-Runtime must validate:

- task completeness
- context completeness
- environment completeness
- knowledge completeness
- required skills
- required tools
- permissions/approval state
- runtime profile compatibility

using Agent-Handoff contracts.

## Runtime flow

```txt
source agent requests handoff
  ↓
Agent-Runtime persists handoff in SurrealDB
  ↓
Agent-Runtime validates handoff completeness
  ↓
Agent-Runtime validates required skills/tools
  ↓
Agent-Runtime validates permissions and approvals
  ↓
ONLY THEN target agent receives execution authority
```

## Rule

Invalid handoffs must never be delivered to agents.

The runtime is the enforcement authority.
