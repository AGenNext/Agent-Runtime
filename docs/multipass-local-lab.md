# Multipass Local Lab

Multipass is the local Ubuntu island lab for Agent Runtime.

It creates lightweight Ubuntu fabric islands on a developer machine so the runtime can be tested before moving to VPS, cloud, edge, or on-prem targets.

## Role

```text
Multipass = Local Island Lab
```

It is not the product core.
It is a local substrate for testing stable-state control loops.

## Topology

```text
agent-control   = control island
agent-worker-1  = worker island
agent-worker-2  = worker island
```

## Create Islands

```bash
multipass launch --name agent-control --cpus 2 --memory 4G --disk 20G
multipass launch --name agent-worker-1 --cpus 2 --memory 4G --disk 20G
multipass launch --name agent-worker-2 --cpus 2 --memory 4G --disk 20G
```

## Inspect

```bash
multipass list
multipass info agent-control
multipass shell agent-control
```

## Fabric Mapping

Each Multipass VM is an island:

```text
Multipass VM
  -> Ubuntu
  -> Island
  -> Digital Twin
  -> Local Reconciliation
```

## Stable-State Loop

```text
Declare VM
  -> Launch VM
  -> Observe VM
  -> Register Island
  -> Deploy Runtime
  -> Emit Evidence
  -> Reconcile State
```

## Rule

```text
Local stable state first.
Global stable state second.
```
