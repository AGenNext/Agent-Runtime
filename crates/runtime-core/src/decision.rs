//! Pure governance decision logic.
//!
//! These functions take a snapshot of policy plus active containment state and
//! return a decision. They perform no I/O and never mutate, so they are fully
//! unit-testable offline. The [`crate::engine`] reads the snapshot from a
//! [`crate::store::RuntimeStore`], calls these, then records the result.

use crate::model::{
    AccessDecision, AccessRequest, FreezeType, KillSwitch, KillSwitchScope, ResourceType,
    RuntimeFreeze, RuntimePolicy,
};

/// The result of evaluating an access request, with a reason suitable for the
/// `runtime_access_decision.reason` field and the audit trail.
#[derive(Debug, Clone, PartialEq)]
pub struct AccessOutcome {
    pub decision: AccessDecision,
    pub reason: String,
}

impl AccessOutcome {
    fn deny(reason: impl Into<String>) -> Self {
        AccessOutcome {
            decision: AccessDecision::Deny,
            reason: reason.into(),
        }
    }
}

/// Maps a kill-switch scope onto the resource class it gates, if any.
fn scope_gates_resource(scope: KillSwitchScope, resource: ResourceType) -> bool {
    matches!(
        (scope, resource),
        (KillSwitchScope::Tool, ResourceType::Tool)
            | (KillSwitchScope::Secret, ResourceType::Secret)
            | (KillSwitchScope::Model, ResourceType::Model)
            | (KillSwitchScope::Network, ResourceType::Network)
    )
}

/// Maps a freeze type onto the resource class it blocks, if any.
fn freeze_blocks_resource(freeze: FreezeType, resource: ResourceType) -> bool {
    if freeze == FreezeType::Full {
        return true;
    }
    matches!(
        (freeze, resource),
        (FreezeType::Tools, ResourceType::Tool)
            | (FreezeType::Secrets, ResourceType::Secret)
            | (FreezeType::Model, ResourceType::Model)
            | (FreezeType::Network, ResourceType::Network)
    )
}

/// Decides whether a run may use a resource.
///
/// Precedence, deny-wins: active kill switches, then active freezes, then
/// policy capability flags, then a human-approval gate, otherwise allow.
/// `kill_switches` and `freezes` are expected to already be the active set.
pub fn evaluate_access(
    policy: &RuntimePolicy,
    kill_switches: &[KillSwitch],
    freezes: &[RuntimeFreeze],
    request: &AccessRequest,
) -> AccessOutcome {
    // 1. Kill switches. Global trumps everything; scoped switches gate their
    //    resource class or their explicit target run.
    for switch in kill_switches.iter().filter(|s| s.active) {
        match switch.scope {
            KillSwitchScope::Global => {
                return AccessOutcome::deny("global kill switch active");
            }
            KillSwitchScope::Run => {
                if switch.target_ref.as_deref() == Some(request.run_id.as_str()) {
                    return AccessOutcome::deny("run kill switch active");
                }
            }
            KillSwitchScope::Agent => {
                if switch.target_ref.as_deref() == Some(request.agent_identity.as_str()) {
                    return AccessOutcome::deny("agent kill switch active");
                }
            }
            other => {
                if scope_gates_resource(other, request.resource_type) {
                    return AccessOutcome::deny(format!("{} kill switch active", other));
                }
            }
        }
    }

    // 2. Freezes on this agent.
    for freeze in freezes
        .iter()
        .filter(|f| f.active && f.agent_identity == request.agent_identity)
    {
        if freeze_blocks_resource(freeze.freeze_type, request.resource_type) {
            return AccessOutcome::deny(format!("agent {} freeze active", freeze.freeze_type));
        }
    }

    // 3. Policy capability flags.
    match request.resource_type {
        ResourceType::Secret if !policy.allow_secret_access => {
            return AccessOutcome::deny("policy denies secret access");
        }
        ResourceType::Model if !policy.allow_model_access => {
            return AccessOutcome::deny("policy denies model access");
        }
        ResourceType::ExternalAction if !policy.allow_external_actions => {
            return AccessOutcome::deny("policy denies external actions");
        }
        _ => {}
    }

    // 4. Human approval gate.
    if policy.human_approval_required {
        return AccessOutcome {
            decision: AccessDecision::RequireApproval,
            reason: "policy requires human approval".to_string(),
        };
    }

    AccessOutcome {
        decision: AccessDecision::Allow,
        reason: "allowed by policy".to_string(),
    }
}

/// Whether a trust score breaches the policy threshold and must trigger
/// containment. Mirrors `docs/runtime-trust-kill-switch.md`: a score *below*
/// the critical threshold freezes the agent.
pub fn requires_containment(trust_score: f64, policy: &RuntimePolicy) -> bool {
    trust_score < policy.trust_threshold
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::KillSwitchScope;

    fn request(resource_type: ResourceType, resource_ref: &str) -> AccessRequest {
        AccessRequest {
            run_id: "run_1".to_string(),
            agent_identity: "agent_1".to_string(),
            resource_type,
            resource_ref: resource_ref.to_string(),
            action: "invoke".to_string(),
        }
    }

    fn switch(scope: KillSwitchScope, target: Option<&str>) -> KillSwitch {
        KillSwitch {
            id: "ks".to_string(),
            scope,
            target_ref: target.map(|t| t.to_string()),
            active: true,
        }
    }

    fn freeze(agent: &str, freeze_type: FreezeType) -> RuntimeFreeze {
        RuntimeFreeze {
            id: "fz".to_string(),
            agent_identity: agent.to_string(),
            freeze_type,
            active: true,
        }
    }

    #[test]
    fn allows_model_under_default_policy() {
        let outcome = evaluate_access(
            &RuntimePolicy::default(),
            &[],
            &[],
            &request(ResourceType::Model, "model:gpt-5"),
        );
        assert_eq!(outcome.decision, AccessDecision::Allow);
    }

    #[test]
    fn default_policy_denies_secrets_and_external_actions() {
        let policy = RuntimePolicy::default();
        assert_eq!(
            evaluate_access(
                &policy,
                &[],
                &[],
                &request(ResourceType::Secret, "secret:db")
            )
            .decision,
            AccessDecision::Deny
        );
        assert_eq!(
            evaluate_access(
                &policy,
                &[],
                &[],
                &request(ResourceType::ExternalAction, "http:post")
            )
            .decision,
            AccessDecision::Deny
        );
    }

    #[test]
    fn global_kill_switch_denies_everything() {
        let outcome = evaluate_access(
            &RuntimePolicy::default(),
            &[switch(KillSwitchScope::Global, None)],
            &[],
            &request(ResourceType::Model, "model:gpt-5"),
        );
        assert_eq!(outcome.decision, AccessDecision::Deny);
        assert_eq!(outcome.reason, "global kill switch active");
    }

    #[test]
    fn scoped_kill_switch_only_gates_its_resource() {
        let switches = [switch(KillSwitchScope::Tool, None)];
        let policy = RuntimePolicy::default();
        assert_eq!(
            evaluate_access(
                &policy,
                &switches,
                &[],
                &request(ResourceType::Tool, "tool:shell")
            )
            .decision,
            AccessDecision::Deny
        );
        // A model call is unaffected by a tool-scoped switch.
        assert_eq!(
            evaluate_access(
                &policy,
                &switches,
                &[],
                &request(ResourceType::Model, "model:gpt-5")
            )
            .decision,
            AccessDecision::Allow
        );
    }

    #[test]
    fn run_kill_switch_matches_only_its_target() {
        let policy = RuntimePolicy::default();
        let other = [switch(KillSwitchScope::Run, Some("run_other"))];
        assert_eq!(
            evaluate_access(&policy, &other, &[], &request(ResourceType::Model, "m")).decision,
            AccessDecision::Allow
        );
        let mine = [switch(KillSwitchScope::Run, Some("run_1"))];
        assert_eq!(
            evaluate_access(&policy, &mine, &[], &request(ResourceType::Model, "m")).decision,
            AccessDecision::Deny
        );
    }

    #[test]
    fn full_freeze_denies_any_resource() {
        let outcome = evaluate_access(
            &RuntimePolicy::default(),
            &[],
            &[freeze("agent_1", FreezeType::Full)],
            &request(ResourceType::Model, "model:gpt-5"),
        );
        assert_eq!(outcome.decision, AccessDecision::Deny);
    }

    #[test]
    fn freeze_on_other_agent_is_ignored() {
        let outcome = evaluate_access(
            &RuntimePolicy::default(),
            &[],
            &[freeze("agent_2", FreezeType::Full)],
            &request(ResourceType::Model, "model:gpt-5"),
        );
        assert_eq!(outcome.decision, AccessDecision::Allow);
    }

    #[test]
    fn human_approval_policy_requires_approval() {
        let mut policy = RuntimePolicy::default();
        policy.human_approval_required = true;
        let outcome = evaluate_access(&policy, &[], &[], &request(ResourceType::Model, "m"));
        assert_eq!(outcome.decision, AccessDecision::RequireApproval);
    }

    #[test]
    fn trust_below_threshold_triggers_containment() {
        let policy = RuntimePolicy::default();
        assert!(requires_containment(0.5, &policy));
        assert!(!requires_containment(0.7, &policy));
        assert!(!requires_containment(0.95, &policy));
    }
}
