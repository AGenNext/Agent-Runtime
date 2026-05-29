//! The governing actor.
//!
//! [`GovernanceEngine`] composes a [`RuntimeStore`] with the pure
//! [`crate::decision`] logic. It reads the live containment snapshot, decides,
//! records the decision, and — for trust breaches — drives containment. It
//! never mutates governance state except through the store (and thus through
//! the `fn::runtime::governance::*` functions).

use crate::decision::{self, AccessOutcome};
use crate::model::{AccessDecision, AccessRequest, FreezeType, RuntimePolicy};
use crate::store::{AccessDecisionRecord, NewFreeze, NewRun, RecordId, RuntimeError, RuntimeStore};

/// Result of a trust-threshold enforcement pass.
#[derive(Debug, Clone, PartialEq)]
pub enum ContainmentOutcome {
    /// Trust is within policy; nothing was changed.
    NoAction,
    /// Trust breached the threshold: the agent was frozen and the run contained.
    Contained {
        /// Record id of the freeze that was created.
        freeze: RecordId,
    },
}

/// Runtime governance engine over a [`RuntimeStore`].
pub struct GovernanceEngine<S> {
    store: S,
}

impl<S: RuntimeStore> GovernanceEngine<S> {
    pub fn new(store: S) -> Self {
        GovernanceEngine { store }
    }

    /// Borrow the underlying store (e.g. for reads or test assertions).
    pub fn store(&self) -> &S {
        &self.store
    }

    // --- run lifecycle pass-throughs ---

    pub async fn create_run(&self, run: NewRun) -> Result<RecordId, RuntimeError> {
        self.store.create_run(run).await
    }

    pub async fn start_run(&self, run_id: &str) -> Result<(), RuntimeError> {
        self.store.start_run(run_id).await
    }

    pub async fn complete_run(&self, run_id: &str) -> Result<(), RuntimeError> {
        self.store.complete_run(run_id).await
    }

    pub async fn fail_run(&self, run_id: &str, reason: Option<&str>) -> Result<(), RuntimeError> {
        self.store.fail_run(run_id, reason).await
    }

    pub async fn kill_run(&self, run_id: &str, reason: Option<&str>) -> Result<(), RuntimeError> {
        self.store.kill_run(run_id, reason).await
    }

    /// Evaluates an access request against live containment state and policy,
    /// records the decision, and returns the outcome.
    ///
    /// The decision is recorded for every request — allow, deny, or
    /// require_approval — so the access trail is complete.
    pub async fn evaluate_access(
        &self,
        policy: &RuntimePolicy,
        request: &AccessRequest,
    ) -> Result<AccessOutcome, RuntimeError> {
        let kill_switches = self.store.active_kill_switches().await?;
        let freezes = self
            .store
            .active_freezes_for_agent(&request.agent_identity)
            .await?;

        let outcome = decision::evaluate_access(policy, &kill_switches, &freezes, request);

        self.store
            .record_access_decision(AccessDecisionRecord {
                run_id: request.run_id.clone(),
                resource_type: request.resource_type,
                resource_ref: request.resource_ref.clone(),
                action: request.action.clone(),
                decision: outcome.decision,
                reason: Some(outcome.reason.clone()),
                policy: None,
            })
            .await?;

        Ok(outcome)
    }

    /// Enforces the trust kill switch (see `docs/runtime-trust-kill-switch.md`).
    ///
    /// If `trust_score` is below the policy threshold the agent is fully frozen
    /// and the run is contained, both through the store. Otherwise no state
    /// changes. Returns what action, if any, was taken.
    pub async fn enforce_trust(
        &self,
        policy: &RuntimePolicy,
        agent_identity: &str,
        run_id: &str,
        trust_score: f64,
    ) -> Result<ContainmentOutcome, RuntimeError> {
        if !decision::requires_containment(trust_score, policy) {
            return Ok(ContainmentOutcome::NoAction);
        }

        let reason = format!(
            "trust score {trust_score} below threshold {}",
            policy.trust_threshold
        );

        let freeze = self
            .store
            .freeze_agent(NewFreeze {
                agent_identity: agent_identity.to_string(),
                freeze_type: FreezeType::Full,
                reason: reason.clone(),
                created_by: "runtime".to_string(),
            })
            .await?;

        self.store.contain_run(run_id, &reason).await?;

        Ok(ContainmentOutcome::Contained { freeze })
    }

    /// Convenience: evaluate access and return whether the action may proceed.
    pub async fn is_allowed(
        &self,
        policy: &RuntimePolicy,
        request: &AccessRequest,
    ) -> Result<bool, RuntimeError> {
        Ok(self.evaluate_access(policy, request).await?.decision == AccessDecision::Allow)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::memory::MemoryStore;
    use crate::model::{KillSwitchScope, Priority, ResourceType, RunStatus};

    /// Minimal executor: the store's futures complete without ever pending,
    /// so a single poll loop drives them without an async runtime dependency.
    fn block_on<F: core::future::Future>(future: F) -> F::Output {
        use core::task::{Context, Poll, RawWaker, RawWakerVTable, Waker};

        fn noop(_: *const ()) {}
        fn clone(_: *const ()) -> RawWaker {
            RawWaker::new(core::ptr::null(), &VTABLE)
        }
        static VTABLE: RawWakerVTable = RawWakerVTable::new(clone, noop, noop, noop);

        let waker = unsafe { Waker::from_raw(RawWaker::new(core::ptr::null(), &VTABLE)) };
        let mut cx = Context::from_waker(&waker);
        let mut future = core::pin::pin!(future);
        loop {
            if let Poll::Ready(value) = future.as_mut().poll(&mut cx) {
                return value;
            }
        }
    }

    fn new_run(id: &str, agent: &str) -> NewRun {
        NewRun {
            id: id.to_string(),
            agent_identity: agent.to_string(),
            run_owner: "runtime".to_string(),
            priority: Priority::Normal,
            reason: None,
            context_ref: None,
            registry_entry: None,
            policy_ref: None,
        }
    }

    fn access(
        run_id: &str,
        agent: &str,
        resource_type: ResourceType,
        resource_ref: &str,
    ) -> AccessRequest {
        AccessRequest {
            run_id: run_id.to_string(),
            agent_identity: agent.to_string(),
            resource_type,
            resource_ref: resource_ref.to_string(),
            action: "invoke".to_string(),
        }
    }

    #[test]
    fn run_lifecycle_transitions() {
        block_on(async {
            let engine = GovernanceEngine::new(MemoryStore::new());
            engine.create_run(new_run("r1", "agent_1")).await.unwrap();
            assert_eq!(engine.store().run_status("r1"), Some(RunStatus::Created));
            engine.start_run("r1").await.unwrap();
            assert_eq!(engine.store().run_status("r1"), Some(RunStatus::Running));
            engine.complete_run("r1").await.unwrap();
            assert_eq!(engine.store().run_status("r1"), Some(RunStatus::Completed));
        });
    }

    #[test]
    fn starting_unknown_run_is_not_found() {
        block_on(async {
            let engine = GovernanceEngine::new(MemoryStore::new());
            let err = engine.start_run("ghost").await.unwrap_err();
            assert_eq!(err, RuntimeError::NotFound("runtime_run:ghost".to_string()));
        });
    }

    #[test]
    fn evaluate_access_allows_and_records() {
        block_on(async {
            let engine = GovernanceEngine::new(MemoryStore::new());
            engine.create_run(new_run("r1", "agent_1")).await.unwrap();
            let policy = RuntimePolicy::default();

            let outcome = engine
                .evaluate_access(
                    &policy,
                    &access("r1", "agent_1", ResourceType::Model, "model:gpt-5"),
                )
                .await
                .unwrap();

            assert_eq!(outcome.decision, AccessDecision::Allow);
            assert_eq!(engine.store().access_log_len(), 1);
        });
    }

    #[test]
    fn evaluate_access_denies_under_active_kill_switch_and_still_records() {
        block_on(async {
            let store = MemoryStore::new().with_kill_switch("ks1", KillSwitchScope::Global, None);
            let engine = GovernanceEngine::new(store);
            engine.create_run(new_run("r1", "agent_1")).await.unwrap();

            let allowed = engine
                .is_allowed(
                    &RuntimePolicy::default(),
                    &access("r1", "agent_1", ResourceType::Model, "m"),
                )
                .await
                .unwrap();

            assert!(!allowed);
            // Denied decisions are still part of the access trail.
            assert_eq!(engine.store().access_log_len(), 1);
        });
    }

    #[test]
    fn enforce_trust_contains_on_breach() {
        block_on(async {
            let engine = GovernanceEngine::new(MemoryStore::new());
            engine.create_run(new_run("r1", "agent_1")).await.unwrap();
            engine.start_run("r1").await.unwrap();

            let outcome = engine
                .enforce_trust(&RuntimePolicy::default(), "agent_1", "r1", 0.4)
                .await
                .unwrap();

            assert!(matches!(outcome, ContainmentOutcome::Contained { .. }));
            assert_eq!(engine.store().run_status("r1"), Some(RunStatus::Contained));
            assert_eq!(engine.store().active_freeze_count(), 1);

            // After a full freeze, further access is denied.
            let allowed = engine
                .is_allowed(
                    &RuntimePolicy::default(),
                    &access("r1", "agent_1", ResourceType::Model, "m"),
                )
                .await
                .unwrap();
            assert!(!allowed);
        });
    }

    #[test]
    fn enforce_trust_noop_when_within_threshold() {
        block_on(async {
            let engine = GovernanceEngine::new(MemoryStore::new());
            engine.create_run(new_run("r1", "agent_1")).await.unwrap();
            engine.start_run("r1").await.unwrap();

            let outcome = engine
                .enforce_trust(&RuntimePolicy::default(), "agent_1", "r1", 0.9)
                .await
                .unwrap();

            assert_eq!(outcome, ContainmentOutcome::NoAction);
            assert_eq!(engine.store().run_status("r1"), Some(RunStatus::Running));
            assert_eq!(engine.store().active_freeze_count(), 0);
        });
    }
}
