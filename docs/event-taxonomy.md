# Fabric Runtime Event Taxonomy

Fabric runtime events are CloudEvents-compatible evidence records emitted by Agent Runtime.

## Core Rule

```text
If it happened, emit an event.
If it changed state, update the runtime state.
If it affected control, record policy evidence.
If it executed, reconcile.
```

## Event Types

| Event Type | Meaning | Required Outcome |
|---|---|---|
| `fabric.tool.requested` | An agent requested a tool operation | Policy evaluation must follow |
| `fabric.policy.evaluated` | Runtime evaluated the platform-held contract and policy boundary | Decision must be recorded |
| `fabric.tool.denied` | Tool operation was denied | Run must be contained |
| `fabric.approval.required` | Contract requires approval before execution | Run must pause as approval pending |
| `fabric.tool.executed` | Approved tool operation executed | Verification must follow |
| `fabric.reconciliation.completed` | Runtime verified execution result and reconciled state | Run may become stable/reconciled |

## Required Event Shape

Every event must follow the CloudEvents-compatible runtime envelope:

```json
{
  "specversion": "1.0",
  "id": "string",
  "type": "fabric.tool.requested",
  "source": "agennext.agent-runtime",
  "subject": "run:id",
  "time": "2026-01-01T00:00:00.000Z",
  "datacontenttype": "application/json",
  "data": {}
}
```

## Runtime Flow

```text
fabric.tool.requested
  -> fabric.policy.evaluated
  -> fabric.tool.denied
```

or

```text
fabric.tool.requested
  -> fabric.policy.evaluated
  -> fabric.approval.required
```

or

```text
fabric.tool.requested
  -> fabric.policy.evaluated
  -> fabric.tool.executed
  -> fabric.reconciliation.completed
```

## Final Rule

```text
No runtime transition without event evidence.
```
