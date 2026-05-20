# Agent-Handoff integration

Agent-Runtime must enforce A2A handoffs through Agent-Handoff.

## Decision

Agent-Handoff provides the A2A contract, SurrealDB schema, validation rules, and handoff store.

Agent-Runtime is responsible for invoking Agent-Handoff before delivering execution authority to a target agent.

## Runtime responsibilities

Agent-Runtime must:

- receive handoff requests from source agents
- validate handoff completeness using Agent-Handoff validators
- validate required skills and tools before delivery
- validate permissions and approvals before delivery
- persist handoff state through Agent-Handoff SurrealDB store
- block incomplete or invalid handoffs
- deliver only accepted handoffs to target agents
- emit trace events for handoff lifecycle changes

## Required handoff sections

Every A2A handoff must include:

```txt
task
context
environment
knowledge
capabilities
permissions
```

## Enforcement flow

```txt
source agent requests handoff
  ↓
Agent-Runtime calls Agent-Handoff validator
  ↓
Agent-Runtime checks skills/tools availability
  ↓
Agent-Runtime checks permissions/approvals
  ↓
Agent-Runtime persists handoff in SurrealDB
  ↓
Agent-Runtime marks handoff accepted or rejected
  ↓
ONLY accepted handoffs are delivered to target agents
```

## Boundary

| Component | Responsibility |
|---|---|
| Agent-Handoff | A2A model, validators, SurrealDB handoff store |
| Agent-Runtime | Enforcement authority and delivery control |
| Agent-Skills | Skill catalog used for capability validation |
| Agent-Tools | Tool catalog used for capability validation |
| Agent-Identity | Agent/user identity verification |
| Agent-IGA | Access governance for handoff authority |
| Agent-Traces | Handoff lifecycle events |

## Rule

Agents cannot self-certify handoff completeness.

Runtime must reject invalid handoffs before another agent sees them.
