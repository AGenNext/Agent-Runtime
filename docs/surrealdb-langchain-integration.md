# SurrealDB + LangChain integration

SurrealDB has a native LangChain vector store integration, so AGenNext can use SurrealDB for both runtime state and vector memory.

## Decision

Use SurrealDB as the default memory backend for Agent-Runtime.

Use LangChain's SurrealDB vector store integration for embeddings/vector search where LangGraph workflows need semantic retrieval.

## Relationship

```txt
LangGraph execution
  ↓
LangChain tools / retrievers
  ↓
SurrealDB vector store
  ↓
SurrealDB memory, graph, events, audit, state
```

## Runtime implication

Agent-Runtime should treat SurrealDB as the source of truth for:

- action queue
- workflow runs
- agent memory
- audit logs
- graph state
- vector memory
- retrieved context

## Why this matters

This avoids introducing a separate vector database for the first version of the runtime.

SurrealDB can support:

- structured infra state
- graph relations
- live action events
- semantic memory
- RAG retrieval
- audit persistence

## Boundary

| Capability | Backend |
|---|---|
| Graph/workflow state | SurrealDB |
| Action queue | SurrealDB |
| Runtime events | SurrealDB |
| Audit logs | SurrealDB |
| Vector memory | SurrealDB via LangChain integration |
| Execution framework | LangGraph |
| Graph contract | AgentGraph |

## Rule

Do not introduce a separate vector DB unless there is a measured need.

Default to SurrealDB-native memory first.
