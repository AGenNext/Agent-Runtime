# GraphRAG memory strategy

AGenNext Agent-Runtime should use SurrealDB as the default GraphRAG and agent-memory backend.

## Decision

Use SurrealDB for:

- graph memory
- vector memory
- structured state
- runtime events
- workflow state
- action queues
- audit logs
- agent memory
- retrieved context

Use LangGraph for current workflow orchestration.

Use LangChain integrations where they help with retrievers, vector stores, and model/tool wiring.

## Why SurrealDB

SurrealDB can represent infrastructure, agents, users, memories, actions, and workflow state as connected records.

This allows AGenNext to combine:

- graph relationships
- semantic retrieval
- runtime state
- event-driven orchestration
- auditability
- agent memory

without introducing a separate vector database in the first version.

## Relationship

```txt
LangGraph
  Current workflow execution engine

LangChain
  Tooling, retrievers, SurrealDB vector integration

SurrealDB
  Durable memory, graph, state, events, action queues, audit, GraphRAG backend

AgentGraph
  AGenNext graph contract and future-native execution model
```

## Runtime flow

```txt
Blueprint emits AgentGraph-compatible plan
  ↓
Agent-Runtime adapts plan to LangGraph
  ↓
LangGraph executes nodes
  ↓
Nodes read/write SurrealDB
  ↓
SurrealDB stores graph + vector + state + audit
  ↓
Retrieved context flows back into graph execution
```

## k8smicro implication

The `k8smicro` runtime profile should use SurrealDB for:

- infrastructure graph
- server inventory
- cluster inventory
- action queue
- runtime worker state
- deployment memory
- incident history
- semantic retrieval over infra events

## Boundary rule

Do not make LangGraph the source of truth.

LangGraph is the execution framework.

SurrealDB is the durable state, graph, and memory layer.

## Future migration

When AgentGraph-native execution is ready, Agent-Runtime should be able to replace LangGraph execution while keeping:

- SurrealDB state
- AgentGraph contracts
- k8smicro runtime profile
- AgentKube operations
- cloud-provider blueprints

unchanged.
