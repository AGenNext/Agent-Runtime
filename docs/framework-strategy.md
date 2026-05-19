# Framework strategy

AGenNext Agent-Runtime will use LangGraph as the execution framework until the native AgentGraph runtime is ready.

## Decision

Use LangGraph now.

Keep AgentGraph as the AGenNext graph contract and future-native execution model.

## Why

LangGraph already provides a practical graph execution framework for agent workflows. This lets Agent-Runtime ship working graph-based orchestration without waiting for a fully custom AgentGraph runtime engine.

## Boundary

| Component | Role |
|---|---|
| LangGraph | Current execution framework |
| AgentGraph | AGenNext graph contract and future-native runtime model |
| Agent-Runtime | Runtime engine that invokes LangGraph today and AgentGraph-native later |
| k8smicro | Agent-Runtime profile for Kubernetes micro-clouds |
| AgentKube | Kubernetes operations layer |
| SurrealDB | Runtime state, memory, events, audit, graph persistence |

## Current flow

```txt
Blueprint
  ↓
AgentGraph-compatible graph contract
  ↓
Agent-Runtime graph adapter
  ↓
LangGraph execution
  ↓
Runtime workers/adapters
  ↓
SurrealDB state and audit
```

## Future flow

```txt
Blueprint
  ↓
AgentGraph contract
  ↓
AgentGraph native runtime
  ↓
Runtime workers/adapters
  ↓
SurrealDB state and audit
```

## Implementation rule

Do not couple business/domain agents directly to LangGraph.

Domain agents should emit AgentGraph-compatible plans. Agent-Runtime owns the adapter that translates those plans to LangGraph execution.

This allows the runtime to later replace LangGraph with AgentGraph-native execution without rewriting blueprints or cloud-provider agents.

## k8smicro implication

`profiles/k8smicro` should use LangGraph through Agent-Runtime's graph adapter.

It should not call LangGraph directly from domain-specific cloud agents.
