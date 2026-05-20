# Runtime enforcement for pre-handoff evaluation

Agent-Runtime must enforce pre-handoff evaluation before a target agent accepts responsibility.

## Decision

A2A handoff delivery requires:

1. handoff completeness validation
2. capability validation
3. permission validation
4. pre-handoff evaluation approval

The target agent must not receive execution authority unless all gates pass.

## Runtime flow

```txt
source agent requests handoff
  ↓
Agent-Runtime validates handoff structure
  ↓
Agent-Runtime validates required skills/tools
  ↓
Agent-Runtime validates permissions
  ↓
Agent-Runtime requests Agent-Eval pre-handoff scoring
  ↓
if score >= threshold:
    deliver handoff
else:
    reject and return repair request
```

## Rule

The runtime owns enforcement.

Accepting agents must not bypass evaluation gates.
