//! Domain model mirroring the governance schema in
//! `surreal/schema/agent_runtime.surql`.
//!
//! String enums round-trip through the same literals the schema's `ASSERT`s
//! accept, so a value that parses here is one SurrealDB will store.

/// Declares a string-backed enum with `as_str`, `parse`, and `Display`,
/// keeping the Rust variants and their SurrealQL literals in one place.
macro_rules! str_enum {
    ($(#[$meta:meta])* $name:ident { $($variant:ident => $lit:literal),+ $(,)? }) => {
        $(#[$meta])*
        #[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
        pub enum $name {
            $($variant),+
        }

        impl $name {
            /// The SurrealQL string literal for this variant.
            pub fn as_str(&self) -> &'static str {
                match self {
                    $( $name::$variant => $lit ),+
                }
            }

            /// Parses a SurrealQL literal, returning `None` for unknown values.
            pub fn parse(value: &str) -> Option<Self> {
                match value {
                    $( $lit => Some($name::$variant), )+
                    _ => None,
                }
            }
        }

        impl core::fmt::Display for $name {
            fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
                f.write_str(self.as_str())
            }
        }
    };
}

str_enum! {
    /// Lifecycle state of a `runtime_run`.
    RunStatus {
        Created => "created",
        Scheduled => "scheduled",
        Running => "running",
        Blocked => "blocked",
        Paused => "paused",
        Completed => "completed",
        Failed => "failed",
        Cancelled => "cancelled",
        Killed => "killed",
        Contained => "contained",
    }
}

str_enum! {
    /// Scheduling priority of a run.
    Priority {
        Low => "low",
        Normal => "normal",
        High => "high",
        Critical => "critical",
    }
}

str_enum! {
    /// Kind of gate a `runtime_gate` records.
    GateType {
        Tool => "tool",
        Secret => "secret",
        Model => "model",
        Network => "network",
        ExternalAction => "external_action",
        HumanApproval => "human_approval",
    }
}

str_enum! {
    /// Class of resource an access decision concerns.
    ResourceType {
        Tool => "tool",
        Secret => "secret",
        Model => "model",
        Network => "network",
        Filesystem => "filesystem",
        ExternalAction => "external_action",
    }
}

str_enum! {
    /// Outcome of an access evaluation.
    AccessDecision {
        Allow => "allow",
        Deny => "deny",
        RequireApproval => "require_approval",
    }
}

str_enum! {
    /// Scope of a freeze applied to an agent identity.
    FreezeType {
        Identity => "identity",
        Tools => "tools",
        Secrets => "secrets",
        Model => "model",
        Network => "network",
        Full => "full",
    }
}

str_enum! {
    /// Scope a kill switch applies to.
    KillSwitchScope {
        Global => "global",
        Agent => "agent",
        Run => "run",
        Tool => "tool",
        Model => "model",
        Secret => "secret",
        Network => "network",
    }
}

str_enum! {
    /// Kind of recovery requested for a run.
    RecoveryType {
        Retry => "retry",
        Resume => "resume",
        Rollback => "rollback",
        Reactivate => "reactivate",
        ManualReview => "manual_review",
    }
}

/// Governance policy applied to a run (`runtime_policy`).
#[derive(Debug, Clone, PartialEq)]
pub struct RuntimePolicy {
    pub name: String,
    pub trust_threshold: f64,
    pub max_runtime_seconds: u64,
    pub max_tool_calls: u64,
    pub allow_external_actions: bool,
    pub allow_secret_access: bool,
    pub allow_model_access: bool,
    pub human_approval_required: bool,
}

impl Default for RuntimePolicy {
    /// Mirrors `runtime_policy` schema defaults.
    fn default() -> Self {
        RuntimePolicy {
            name: "Default Runtime Policy".to_string(),
            trust_threshold: 0.7,
            max_runtime_seconds: 3600,
            max_tool_calls: 100,
            allow_external_actions: false,
            allow_secret_access: false,
            allow_model_access: true,
            human_approval_required: false,
        }
    }
}

/// An active kill switch read from `runtime_kill_switch`.
#[derive(Debug, Clone, PartialEq)]
pub struct KillSwitch {
    pub id: String,
    pub scope: KillSwitchScope,
    /// Target record id for `agent`/`run`/resource scopes; `None` for global.
    pub target_ref: Option<String>,
    pub active: bool,
}

/// An active freeze read from `runtime_freeze`.
#[derive(Debug, Clone, PartialEq)]
pub struct RuntimeFreeze {
    pub id: String,
    pub agent_identity: String,
    pub freeze_type: FreezeType,
    pub active: bool,
}

/// A request to use a governed resource, evaluated before the action runs.
#[derive(Debug, Clone, PartialEq)]
pub struct AccessRequest {
    pub run_id: String,
    pub agent_identity: String,
    pub resource_type: ResourceType,
    pub resource_ref: String,
    pub action: String,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trips_known_literals() {
        for status in [
            RunStatus::Created,
            RunStatus::Running,
            RunStatus::Contained,
            RunStatus::Killed,
        ] {
            assert_eq!(RunStatus::parse(status.as_str()), Some(status));
        }
        assert_eq!(
            AccessDecision::parse("require_approval"),
            Some(AccessDecision::RequireApproval)
        );
        assert_eq!(FreezeType::parse("full"), Some(FreezeType::Full));
        assert_eq!(
            KillSwitchScope::parse("global"),
            Some(KillSwitchScope::Global)
        );
        assert_eq!(
            RecoveryType::parse("manual_review"),
            Some(RecoveryType::ManualReview)
        );
    }

    #[test]
    fn rejects_unknown_literals() {
        assert_eq!(RunStatus::parse("exploded"), None);
        assert_eq!(ResourceType::parse(""), None);
    }

    #[test]
    fn default_policy_matches_schema_defaults() {
        let policy = RuntimePolicy::default();
        assert_eq!(policy.trust_threshold, 0.7);
        assert!(!policy.allow_secret_access);
        assert!(policy.allow_model_access);
        assert!(!policy.human_approval_required);
    }
}
