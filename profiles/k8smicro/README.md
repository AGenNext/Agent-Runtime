# k8smicro runtime profile

`k8smicro` is the lightweight Kubernetes micro-cloud profile of AGenNext Agent-Runtime.

It is not a separate runtime repository. It is a runtime profile/module inside `AGenNext/Agent-Runtime`.

## Purpose

`k8smicro` turns a bare metal or low-cost VPS node into a governed, agent-managed Kubernetes micro-cloud.

## Layer model

```txt
Provider / Bare Metal
  OVH, Kimsufi, VPS, edge node

Operating System
  Debian, Ubuntu

Kubernetes substrate
  k3s by default

Agent-Runtime profile
  k8smicro

Graph execution model
  AgentGraph

Kubernetes operations
  AgentKube

State / memory / event control plane
  SurrealDB

Identity / trust
  walt.id through Agent-Identity
```

## Responsibility

k8smicro owns:

- node bootstrap profile
- k3s installation strategy
- runtime worker profile
- SurrealDB action subscription loop
- adapter registry
- SSH execution bridge
- Kubernetes execution bridge through AgentKube
- AgentGraph execution bridge
- policy hooks
- install scripts for micro-cloud nodes

k8smicro does not own:

- cloud-provider-specific planning
- OVH/Kimsufi product modeling
- AgentGraph schema authority
- AgentKube operator implementation
- identity issuance

## Relationship

```txt
cloud-architect-agents
  ↓ uses
Agent-Runtime / profiles / k8smicro
  ↓ uses
AgentGraph + AgentKube + Agent-Identity + SurrealDB
```

## Default target

```txt
OVH/Kimsufi Eco bare metal
  ↓
Debian or Ubuntu
  ↓
k3s
  ↓
Agent-Runtime: k8smicro profile
  ↓
SurrealDB-backed agent actions
```
