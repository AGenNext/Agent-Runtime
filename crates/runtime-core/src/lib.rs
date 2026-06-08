//! AGenNext Agent-Runtime governance engine core.
//!
//! This crate is the Rust side of the runtime/SurrealQL boundary documented in
//! `docs/runtime-rust-surrealql-boundary.md`:
//!
//! - **SurrealQL** is the source of truth and invariant enforcer. State only
//!   changes through the `fn::runtime::governance::*` functions.
//! - **Rust** is the governing actor. It decides, gates access, and drives
//!   containment, calling SurrealQL functions as the only mutation path.
//!
//! The core is deliberately dependency-free and split so that the decisions
//! ([`decision`]) are pure and unit-testable offline, while I/O lives behind
//! the [`store::RuntimeStore`] trait. An in-memory [`memory::MemoryStore`]
//! backs tests; the SurrealDB binding (feature `surreal`) honors the call
//! contract pinned in [`calls`].
#![allow(async_fn_in_trait)]

pub mod calls;
pub mod decision;
pub mod engine;
pub mod memory;
pub mod model;
pub mod store;

pub use decision::{evaluate_access, requires_containment, AccessOutcome};
pub use engine::{ContainmentOutcome, GovernanceEngine};
pub use model::{
    AccessDecision, AccessRequest, FreezeType, GateType, KillSwitch, KillSwitchScope, Priority,
    RecoveryType, ResourceType, RunStatus, RuntimeFreeze, RuntimePolicy,
};
pub use store::{AccessDecisionRecord, NewFreeze, NewRun, RecordId, RuntimeError, RuntimeStore};
