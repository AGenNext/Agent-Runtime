# Framework adapter contract

Agent-Runtime must remain framework-neutral.

Framework-specific execution code lives in `AGenNext/Agent-Frameworks`.

## Decision

Agent-Runtime invokes framework adapters through a stable adapter contract.

Agent-Runtime must not import LangGraph, CrewAI, AutoGen, or other framework packages directly.

## Runtime responsibility

Agent-Runtime owns:

- runtime lifecycle
- runtime profiles such as `k8smicro`
- action dispatch
- state persistence coordination
- identity/approval checks
- adapter selection
- execution policy

Agent-Runtime does not own:

- LangGraph implementation
- framework-specific graph compilation
- framework-specific runtime packages

## Adapter input contract

```json
{
  "plan": {
    "id": "bootstrap_kimsufi_microcloud",
    "runtime_profile": "k8smicro",
    "nodes": [
      {
        "id": "verify_identity",
        "action": "identity.verify",
        "input": {}
      }
    ],
    "edges": [
      {
        "from": "verify_identity",
        "to": "harden_node"
      }
    ]
  },
  "execution_context": {
    "actor_did": "did:web:example.com:user:chinmay",
    "tenant_id": "default",
    "environment": "dev"
  }
}
```

## Adapter output contract

```json
{
  "run_id": "workflow_run:bootstrap_kimsufi_microcloud",
  "status": "completed",
  "completed": ["verify_identity", "harden_node"],
  "results": {},
  "errors": {}
}
```

## Framework selection

```txt
AgentGraph-compatible plan
  ↓
Agent-Runtime selects framework adapter
  ↓
Agent-Frameworks executes through selected adapter
  ↓
Agent-Runtime persists results to SurrealDB
```

## Initial adapter

The first adapter is:

```txt
AGenNext/Agent-Frameworks/frameworks/langgraph
```

## Rule

Only Agent-Frameworks imports framework packages.

Agent-Runtime consumes adapter contracts only.
