# Multipass Definition

Multipass is the local Ubuntu island substrate for Fabric Runtime development and validation.

## Canonical Definition

```text
Multipass = Local Ubuntu Island Substrate
```

Multipass creates lightweight Ubuntu virtual machines on a developer machine. In Fabric Protocol, each Multipass VM is treated as an island node: bounded, identifiable, observable, and reconcilable.

## What Multipass Is

```text
Local VM substrate
Ubuntu island factory
Developer fabric lab
Pre-cloud validation target
Stable-state test environment
```

## What Multipass Is Not

```text
Not the control plane
Not the platform contract holder
Not the production fabric by itself
Not the reconciliation engine
Not the digital twin store
```

## Fabric Mapping

```text
Multipass Instance
  -> Ubuntu VM
  -> Island Node
  -> Digital Twin
  -> Local Reconciliation Loop
  -> Stable State Evidence
```

## Why Multipass Exists in the Stack

Multipass gives Agent Runtime a safe local place to prove:

```text
island creation
runtime installation
deployment
observation
reconciliation
evidence emission
stable-state validation
```

before moving to VPS, Kubernetes, cloud, edge, or on-prem environments.

## Boundary Rule

```text
Multipass provides the island.
Fabric Runtime governs the operation.
Panel exposes control.
Platform holds the contract.
```

## Minimal Topology

```text
agent-control   = control island
agent-worker-1  = worker island
agent-worker-2  = worker island
```

## Commands

```bash
multipass launch --name agent-control --cpus 2 --memory 4G --disk 20G
multipass launch --name agent-worker-1 --cpus 2 --memory 4G --disk 20G
multipass launch --name agent-worker-2 --cpus 2 --memory 4G --disk 20G

multipass list
multipass shell agent-control
```

## Stable-State Loop

```text
Declare VM
  -> Launch Multipass Instance
  -> Observe Instance
  -> Register Island
  -> Install Runtime
  -> Emit Evidence
  -> Reconcile State
  -> Prove Local Stable State
```

## Final Rule

```text
Local stable state first.
Global stable state second.
```
