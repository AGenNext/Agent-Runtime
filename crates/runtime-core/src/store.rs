//! The persistence contract the governance engine drives.
//!
//! Every method corresponds to a `fn::runtime::governance::*` SurrealQL
//! function (see [`crate::calls`]); implementations must route through those
//! functions rather than issuing raw writes. The trait is intentionally small
//! and async so a real SurrealDB binding and the in-memory
//! [`crate::memory::MemoryStore`] can both satisfy it.

use crate::model::{
    AccessDecision, FreezeType, KillSwitch, Priority, ResourceType, RuntimeFreeze, RuntimePolicy,
};

/// A SurrealDB record id, e.g. `runtime_run:abc`.
pub type RecordId = String;

/// Errors surfaced by a [`RuntimeStore`].
#[derive(Debug, Clone, PartialEq)]
pub enum RuntimeError {
    /// A referenced record (run, policy, freeze, …) does not exist.
    NotFound(String),
    /// The backend rejected or failed the operation.
    Backend(String),
}

impl core::fmt::Display for RuntimeError {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        match self {
            RuntimeError::NotFound(what) => write!(f, "not found: {what}"),
            RuntimeError::Backend(msg) => write!(f, "backend error: {msg}"),
        }
    }
}

impl std::error::Error for RuntimeError {}

/// Arguments for `fn::runtime::governance::run::create`.
#[derive(Debug, Clone, PartialEq)]
pub struct NewRun {
    pub id: String,
    pub agent_identity: String,
    pub run_owner: String,
    pub priority: Priority,
    pub reason: Option<String>,
    pub context_ref: Option<String>,
    pub registry_entry: Option<String>,
    pub policy_ref: Option<String>,
}

/// Arguments for `fn::runtime::governance::freeze::create`.
#[derive(Debug, Clone, PartialEq)]
pub struct NewFreeze {
    pub agent_identity: String,
    pub freeze_type: FreezeType,
    pub reason: String,
    pub created_by: String,
}

/// Arguments for `fn::runtime::governance::access::decide`.
#[derive(Debug, Clone, PartialEq)]
pub struct AccessDecisionRecord {
    pub run_id: String,
    pub resource_type: ResourceType,
    pub resource_ref: String,
    pub action: String,
    pub decision: AccessDecision,
    pub reason: Option<String>,
    pub policy: Option<String>,
}

/// The governance state and transitions the runtime needs.
pub trait RuntimeStore {
    // --- run lifecycle ---
    async fn create_run(&self, run: NewRun) -> Result<RecordId, RuntimeError>;
    async fn start_run(&self, run_id: &str) -> Result<(), RuntimeError>;
    async fn complete_run(&self, run_id: &str) -> Result<(), RuntimeError>;
    async fn fail_run(&self, run_id: &str, reason: Option<&str>) -> Result<(), RuntimeError>;
    async fn kill_run(&self, run_id: &str, reason: Option<&str>) -> Result<(), RuntimeError>;
    async fn contain_run(&self, run_id: &str, reason: &str) -> Result<(), RuntimeError>;

    // --- access gating ---
    async fn record_access_decision(
        &self,
        decision: AccessDecisionRecord,
    ) -> Result<(), RuntimeError>;

    // --- containment state reads ---
    async fn active_kill_switches(&self) -> Result<Vec<KillSwitch>, RuntimeError>;
    async fn active_freezes_for_agent(
        &self,
        agent_identity: &str,
    ) -> Result<Vec<RuntimeFreeze>, RuntimeError>;

    // --- containment writes ---
    async fn freeze_agent(&self, freeze: NewFreeze) -> Result<RecordId, RuntimeError>;
    async fn release_freeze(&self, freeze_id: &str, released_by: &str) -> Result<(), RuntimeError>;
    async fn activate_kill_switch(
        &self,
        switch_id: &str,
        activated_by: &str,
        reason: Option<&str>,
    ) -> Result<(), RuntimeError>;
    async fn deactivate_kill_switch(
        &self,
        switch_id: &str,
        deactivated_by: &str,
    ) -> Result<(), RuntimeError>;

    // --- policy ---
    async fn get_policy(&self, policy_id: &str) -> Result<Option<RuntimePolicy>, RuntimeError>;
}
