# Runtime: Rust vs SurrealQL boundary

AGenNext Agent-Runtime governance lives in two layers: SurrealQL inside SurrealDB, and the Rust runtime engine. This document defines which responsibilities belong to each.

## Decision

SurrealQL is the source of truth and invariant enforcer.

The Rust runtime is the governing actor that decides and propagates effects to the live execution plane.

It is not a choice of Rust *or* SurrealQL. It is a split of responsibility across both.

## Core principle

```text
SurrealQL  → owns authoritative state, invariants, atomic transitions, and audit.
Rust       → owns decisions, enforcement effects, scheduling, and external I/O.
```

This mirrors the repository principle:

```text
Frameworks execute.
Agent-Runtime governs.
```

Here, SurrealDB persists and guards governance state. Rust enforces it against running agents.

## What each layer is good at

| Dimension | SurrealQL (functions + schema) | Rust runtime |
|---|---|---|
| Atomic state transitions | Strong — runs inside the DB, no read/write race | Weak — multi-step mutations risk partial writes |
| Schema invariants | Strong — `ASSERT`, enum membership, unique indexes | Must duplicate and re-validate |
| Audit durability | Strong — audit row written in the same call as the transition | Crash between action and log leaves an audit gap |
| Source-of-truth state | Authoritative | Must never be authoritative |
| External I/O (frameworks, tools, HTTP) | Not its job | The runtime's purpose |
| Containment effects (kill process, revoke live token, stop in-flight handoff) | Can only record intent | Only Rust can act on the execution plane |
| Scheduling, timeouts, concurrency | Weak | Strong |
| Policy composition with external signals (trust score, blast radius) | Limited | Natural |
| Testability | Needs a live DB | Pure decision logic unit-tests offline |

## Failure modes of each extreme

### All logic in SurrealQL

- Can record a freeze, but cannot kill the running agent process or revoke a live credential.
- Logic locked into the DB dialect.
- Hard to unit-test.
- No real enforcement of containment.

### All logic in Rust

- Time-of-check/time-of-use races on state transitions.
- Weaker atomicity.
- Audit gaps on crash.
- Re-implements invariants that `ASSERT` already guarantees.

## Boundary

### SurrealQL owns (authoritative, atomic)

- Schema and `ASSERT` invariants.
- State-machine transition functions: `create`, `start`, `block`, `complete`, `fail`, `kill`, `contain`.
- `freeze` and `kill_switch` records.
- `access_decision` and `audit_event` writes, with each transition emitting its audit row in the same call.
- The "resolve governance state for run" read.

### Rust owns (the governing actor)

- Evaluating access before each tool, secret, and model call, reading live kill switches, freezes, and policy.
- Trust-threshold enforcement: invoking the containment function and propagating real effects — terminate execution, revoke live access, halt A2A handoffs. This is the behavior `runtime-trust-kill-switch.md` describes but nothing currently executes.
- Scheduling loop, timeouts, and blocker detection.
- Calling SurrealQL functions as the only way to mutate governance state. Rust never issues raw governance writes.

## Interaction rule

```text
Rust runtime
  ↓ calls fn::runtime::governance::* (parameterized, atomic)
SurrealQL functions
  ↓ enforce ASSERT + write transition + audit row in one call
SurrealDB
  ↓ authoritative governance state
Rust runtime
  → reads resolved state, then acts on the live execution plane
```

Rust treats SurrealQL governance functions as the only mutation path. SurrealDB treats Rust as the only caller permitted to drive transitions.

## Closed gap

The original `surreal/flows/agent_runtime.flows.surql` was raw `CREATE`/`UPDATE` scripts rather than callable `DEFINE FUNCTION` definitions, and it used `runtime_run:$run`, which is not valid parameterized record-ID syntax. The auth layer already showed the correct pattern with `type::record("auth_session", $id)` and `fn::runtime::auth::*`.

Those flows are now `fn::runtime::governance::*` functions in `surreal/functions/agent_runtime.functions.surql`, using `type::record(...)`, with each transition emitting its audit row in the same call. Rust invokes these as the only mutation path.

## Implementation order

1. Convert `surreal/flows` into `fn::runtime::governance::*` functions using `type::record(...)`, each emitting its audit row in the same call. **(done — `surreal/functions/agent_runtime.functions.surql`)**
2. Scaffold the Rust runtime crate: domain model, pure decision logic, a store trait with an in-memory mock for offline tests, and a SurrealDB binding that invokes the governance functions. **(done — `crates/runtime-core`; SurrealDB binding deferred behind the `surreal` feature, with the call contract pinned in `calls.rs`)**
3. Wire trust-threshold containment and access gating in Rust on top of those functions. **(done in core — `decision.rs` + `engine.rs`; remaining: the live SurrealDB binding and propagating effects to running processes)**

## Rule

Do not put authoritative governance state or invariant enforcement in Rust.

Do not put external I/O, process control, or live containment effects in SurrealQL.
