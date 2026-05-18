# Agent Runtime

Agent Runtime is the AGenNext-owned runtime control plane for agent execution governance.

It is not LangGraph.
It may use LangGraph, LangChain, or other frameworks through adapters, but the runtime authority belongs here.

## Responsibility

Agent Runtime owns:

- agent lifecycle state
- agent identity state
- trust threshold enforcement
- access freeze and containment
- run ownership
- scheduling governance
- blocker and timeout governance
- A2A runtime policy enforcement
- tool access gating
- secret access gating
- model access gating
- runtime kill switches
- runtime recovery and reactivation policy

## Boundary

```text
Agent-Runtime
  → owns execution governance and containment

Agent-Frameworks
  → owns framework adapters such as LangGraph

LangGraph
  → executes graph workflows when selected
```

## Core Principle

```text
Frameworks execute.
Agent-Runtime governs.
```

## Final Rule

Do not put AGenNext governance, trust kill switches, identity freeze, or access containment inside LangGraph-specific runtime adapters.
