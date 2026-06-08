//! An in-memory [`RuntimeStore`] for offline tests and local experimentation.
//!
//! It models the governance state transitions faithfully enough to exercise the
//! [`crate::engine::GovernanceEngine`] without a SurrealDB instance. It is not
//! durable and not concurrent-safe beyond a process `Mutex`.

use std::collections::HashMap;
use std::sync::Mutex;

use crate::model::{KillSwitch, KillSwitchScope, RunStatus, RuntimeFreeze, RuntimePolicy};
use crate::store::{AccessDecisionRecord, NewFreeze, NewRun, RecordId, RuntimeError, RuntimeStore};

#[derive(Default)]
struct State {
    runs: HashMap<String, RunStatus>,
    kill_switches: Vec<KillSwitch>,
    freezes: Vec<RuntimeFreeze>,
    access_log: Vec<AccessDecisionRecord>,
    policies: HashMap<String, RuntimePolicy>,
    freeze_seq: u64,
}

/// In-memory governance store.
#[derive(Default)]
pub struct MemoryStore {
    state: Mutex<State>,
}

impl MemoryStore {
    pub fn new() -> Self {
        Self::default()
    }

    fn lock(&self) -> std::sync::MutexGuard<'_, State> {
        self.state.lock().expect("MemoryStore mutex poisoned")
    }

    /// Seeds an active kill switch.
    pub fn with_kill_switch(self, id: &str, scope: KillSwitchScope, target: Option<&str>) -> Self {
        self.lock().kill_switches.push(KillSwitch {
            id: id.to_string(),
            scope,
            target_ref: target.map(|t| t.to_string()),
            active: true,
        });
        self
    }

    /// Seeds a policy retrievable via [`RuntimeStore::get_policy`].
    pub fn with_policy(self, id: &str, policy: RuntimePolicy) -> Self {
        self.lock().policies.insert(id.to_string(), policy);
        self
    }

    /// Current status of a run, for assertions.
    pub fn run_status(&self, run_id: &str) -> Option<RunStatus> {
        self.lock().runs.get(run_id).copied()
    }

    /// Number of recorded access decisions, for assertions.
    pub fn access_log_len(&self) -> usize {
        self.lock().access_log.len()
    }

    /// Count of currently active freezes, for assertions.
    pub fn active_freeze_count(&self) -> usize {
        self.lock().freezes.iter().filter(|f| f.active).count()
    }
}

impl RuntimeStore for MemoryStore {
    async fn create_run(&self, run: NewRun) -> Result<RecordId, RuntimeError> {
        self.lock().runs.insert(run.id.clone(), RunStatus::Created);
        Ok(format!("runtime_run:{}", run.id))
    }

    async fn start_run(&self, run_id: &str) -> Result<(), RuntimeError> {
        self.transition(run_id, RunStatus::Running)
    }

    async fn complete_run(&self, run_id: &str) -> Result<(), RuntimeError> {
        self.transition(run_id, RunStatus::Completed)
    }

    async fn fail_run(&self, run_id: &str, _reason: Option<&str>) -> Result<(), RuntimeError> {
        self.transition(run_id, RunStatus::Failed)
    }

    async fn kill_run(&self, run_id: &str, _reason: Option<&str>) -> Result<(), RuntimeError> {
        self.transition(run_id, RunStatus::Killed)
    }

    async fn contain_run(&self, run_id: &str, _reason: &str) -> Result<(), RuntimeError> {
        self.transition(run_id, RunStatus::Contained)
    }

    async fn record_access_decision(
        &self,
        decision: AccessDecisionRecord,
    ) -> Result<(), RuntimeError> {
        self.lock().access_log.push(decision);
        Ok(())
    }

    async fn active_kill_switches(&self) -> Result<Vec<KillSwitch>, RuntimeError> {
        Ok(self
            .lock()
            .kill_switches
            .iter()
            .filter(|s| s.active)
            .cloned()
            .collect())
    }

    async fn active_freezes_for_agent(
        &self,
        agent_identity: &str,
    ) -> Result<Vec<RuntimeFreeze>, RuntimeError> {
        Ok(self
            .lock()
            .freezes
            .iter()
            .filter(|f| f.active && f.agent_identity == agent_identity)
            .cloned()
            .collect())
    }

    async fn freeze_agent(&self, freeze: NewFreeze) -> Result<RecordId, RuntimeError> {
        let mut state = self.lock();
        state.freeze_seq += 1;
        let id = format!("freeze_{}", state.freeze_seq);
        state.freezes.push(RuntimeFreeze {
            id: id.clone(),
            agent_identity: freeze.agent_identity,
            freeze_type: freeze.freeze_type,
            active: true,
        });
        Ok(format!("runtime_freeze:{id}"))
    }

    async fn release_freeze(
        &self,
        freeze_id: &str,
        _released_by: &str,
    ) -> Result<(), RuntimeError> {
        let mut state = self.lock();
        match state.freezes.iter_mut().find(|f| f.id == freeze_id) {
            Some(freeze) => {
                freeze.active = false;
                Ok(())
            }
            None => Err(RuntimeError::NotFound(format!(
                "runtime_freeze:{freeze_id}"
            ))),
        }
    }

    async fn activate_kill_switch(
        &self,
        switch_id: &str,
        _activated_by: &str,
        _reason: Option<&str>,
    ) -> Result<(), RuntimeError> {
        self.set_switch(switch_id, true)
    }

    async fn deactivate_kill_switch(
        &self,
        switch_id: &str,
        _deactivated_by: &str,
    ) -> Result<(), RuntimeError> {
        self.set_switch(switch_id, false)
    }

    async fn get_policy(&self, policy_id: &str) -> Result<Option<RuntimePolicy>, RuntimeError> {
        Ok(self.lock().policies.get(policy_id).cloned())
    }
}

impl MemoryStore {
    fn transition(&self, run_id: &str, status: RunStatus) -> Result<(), RuntimeError> {
        let mut state = self.lock();
        match state.runs.get_mut(run_id) {
            Some(slot) => {
                *slot = status;
                Ok(())
            }
            None => Err(RuntimeError::NotFound(format!("runtime_run:{run_id}"))),
        }
    }

    fn set_switch(&self, switch_id: &str, active: bool) -> Result<(), RuntimeError> {
        let mut state = self.lock();
        match state.kill_switches.iter_mut().find(|s| s.id == switch_id) {
            Some(switch) => {
                switch.active = active;
                Ok(())
            }
            None => Err(RuntimeError::NotFound(format!(
                "runtime_kill_switch:{switch_id}"
            ))),
        }
    }
}
