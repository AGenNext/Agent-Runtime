//! Names of the `fn::runtime::governance::*` SurrealQL functions that the
//! runtime is allowed to call.
//!
//! These are the single sanctioned mutation path (see
//! `docs/runtime-rust-surrealql-boundary.md`). The SurrealDB binding builds
//! `RETURN <name>($arg);` statements from these constants; keeping them here
//! means the Rust contract and the `.surql` definitions move together, and the
//! test below fails if they drift apart.

pub const RUN_CREATE: &str = "fn::runtime::governance::run::create";
pub const RUN_START: &str = "fn::runtime::governance::run::start";
pub const RUN_BLOCK: &str = "fn::runtime::governance::run::block";
pub const RUN_COMPLETE: &str = "fn::runtime::governance::run::complete";
pub const RUN_FAIL: &str = "fn::runtime::governance::run::fail";
pub const RUN_KILL: &str = "fn::runtime::governance::run::kill";
pub const RUN_CONTAIN: &str = "fn::runtime::governance::run::contain";

pub const BLOCKER_RESOLVE: &str = "fn::runtime::governance::blocker::resolve";

pub const ACCESS_DECIDE: &str = "fn::runtime::governance::access::decide";
pub const GATE_RECORD: &str = "fn::runtime::governance::gate::record";

pub const KILL_SWITCH_ACTIVATE: &str = "fn::runtime::governance::kill_switch::activate";
pub const KILL_SWITCH_DEACTIVATE: &str = "fn::runtime::governance::kill_switch::deactivate";

pub const FREEZE_CREATE: &str = "fn::runtime::governance::freeze::create";
pub const FREEZE_RELEASE: &str = "fn::runtime::governance::freeze::release";

pub const RECOVERY_REQUEST: &str = "fn::runtime::governance::recovery::request";
pub const RECOVERY_APPROVE: &str = "fn::runtime::governance::recovery::approve";
pub const RECOVERY_REJECT: &str = "fn::runtime::governance::recovery::reject";
pub const RECOVERY_COMPLETE: &str = "fn::runtime::governance::recovery::complete";

pub const AUDIT: &str = "fn::runtime::governance::audit";

/// Every governance function this crate knows how to call.
pub const ALL: &[&str] = &[
    RUN_CREATE,
    RUN_START,
    RUN_BLOCK,
    RUN_COMPLETE,
    RUN_FAIL,
    RUN_KILL,
    RUN_CONTAIN,
    BLOCKER_RESOLVE,
    ACCESS_DECIDE,
    GATE_RECORD,
    KILL_SWITCH_ACTIVATE,
    KILL_SWITCH_DEACTIVATE,
    FREEZE_CREATE,
    FREEZE_RELEASE,
    RECOVERY_REQUEST,
    RECOVERY_APPROVE,
    RECOVERY_REJECT,
    RECOVERY_COMPLETE,
    AUDIT,
];

#[cfg(test)]
mod tests {
    use super::*;

    /// The governance `.surql` definitions, pinned at compile time.
    const SURQL: &str = include_str!("../../../surreal/functions/agent_runtime.functions.surql");

    #[test]
    fn every_call_name_is_defined_in_surql() {
        for name in ALL {
            let definition = format!("DEFINE FUNCTION OVERWRITE {}(", name);
            assert!(
                SURQL.contains(&definition),
                "{name} is not defined in agent_runtime.functions.surql"
            );
        }
    }

    #[test]
    fn surql_defines_no_unlisted_governance_functions() {
        let defined = SURQL
            .match_indices("DEFINE FUNCTION OVERWRITE fn::runtime::governance::")
            .count();
        assert_eq!(
            defined,
            ALL.len(),
            "the surql file defines {defined} governance functions but calls::ALL lists {}",
            ALL.len()
        );
    }
}
