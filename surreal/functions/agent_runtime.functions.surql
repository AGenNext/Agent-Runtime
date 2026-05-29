-- AGenNext Agent Runtime
-- Executable SurrealQL governance functions.
-- Runtime governs execution. Frameworks execute elsewhere.
--
-- These functions are the only sanctioned mutation path for runtime
-- governance state. The Rust runtime engine invokes them; it never issues
-- raw governance writes. Each state transition emits its audit row in the
-- same call so the audit trail cannot drift from the state it records.
--
-- See docs/runtime-rust-surrealql-boundary.md.

-- Run lifecycle ------------------------------------------------------------

DEFINE FUNCTION OVERWRITE fn::runtime::governance::run::create($run: object) -> object {
    LET $record = type::record("runtime_run", <string>$run.id);

    LET $created = UPSERT ONLY $record CONTENT {
        agent_identity: type::record("agent_identity", <string>$run.agent_identity),
        registry_entry: $run.registry_entry ?? NONE,
        run_owner: $run.run_owner ?? "runtime",
        status: "created",
        priority: $run.priority ?? "normal",
        reason: $run.reason ?? NONE,
        context_ref: $run.context_ref ?? NONE,
        policy_ref: IF type::is_none($run.policy_ref) {
            NONE
        } ELSE {
            type::record("runtime_policy", <string>$run.policy_ref)
        },
        created_at: time::now(),
        updated_at: time::now()
    };

    CREATE runtime_audit_event CONTENT {
        run: $record,
        agent_identity: type::record("agent_identity", <string>$run.agent_identity),
        event_type: "runtime_run_created",
        actor: "runtime",
        message: "Runtime run created",
        data: { priority: $run.priority ?? "normal" },
        created_at: time::now()
    };

    RETURN $created;
};

DEFINE FUNCTION OVERWRITE fn::runtime::governance::run::start($run_id: string) -> object {
    LET $record = type::record("runtime_run", $run_id);

    LET $updated = UPDATE ONLY $record SET
        status = "running",
        started_at = time::now(),
        updated_at = time::now();

    CREATE runtime_audit_event CONTENT {
        run: $record,
        event_type: "runtime_run_started",
        actor: "runtime",
        message: "Runtime run started",
        created_at: time::now()
    };

    RETURN $updated;
};

DEFINE FUNCTION OVERWRITE fn::runtime::governance::run::block($run_id: string, $blocker: object) -> object {
    LET $record = type::record("runtime_run", $run_id);

    UPDATE ONLY $record SET
        status = "blocked",
        updated_at = time::now();

    LET $created = CREATE ONLY runtime_blocker CONTENT {
        run: $record,
        blocker_type: $blocker.blocker_type,
        reason: $blocker.reason,
        severity: $blocker.severity ?? "medium",
        status: "open",
        created_at: time::now()
    };

    CREATE runtime_audit_event CONTENT {
        run: $record,
        event_type: "runtime_run_blocked",
        actor: "runtime",
        message: $blocker.reason,
        data: {
            blocker_type: $blocker.blocker_type,
            severity: $blocker.severity ?? "medium"
        },
        created_at: time::now()
    };

    RETURN $created;
};

DEFINE FUNCTION OVERWRITE fn::runtime::governance::run::complete($run_id: string) -> object {
    LET $record = type::record("runtime_run", $run_id);

    LET $updated = UPDATE ONLY $record SET
        status = "completed",
        completed_at = time::now(),
        updated_at = time::now();

    CREATE runtime_audit_event CONTENT {
        run: $record,
        event_type: "runtime_run_completed",
        actor: "runtime",
        message: "Runtime run completed",
        created_at: time::now()
    };

    RETURN $updated;
};

DEFINE FUNCTION OVERWRITE fn::runtime::governance::run::fail($run_id: string, $reason: option<string>) -> object {
    LET $record = type::record("runtime_run", $run_id);

    LET $updated = UPDATE ONLY $record SET
        status = "failed",
        reason = $reason ?? reason,
        completed_at = time::now(),
        updated_at = time::now();

    CREATE runtime_audit_event CONTENT {
        run: $record,
        event_type: "runtime_run_failed",
        actor: "runtime",
        message: $reason ?? "Runtime run failed",
        created_at: time::now()
    };

    RETURN $updated;
};

DEFINE FUNCTION OVERWRITE fn::runtime::governance::run::kill($run_id: string, $reason: option<string>) -> object {
    LET $record = type::record("runtime_run", $run_id);

    LET $updated = UPDATE ONLY $record SET
        status = "killed",
        reason = $reason ?? reason,
        completed_at = time::now(),
        updated_at = time::now();

    CREATE runtime_audit_event CONTENT {
        run: $record,
        event_type: "runtime_run_killed",
        actor: "runtime",
        message: $reason ?? "Runtime run killed",
        created_at: time::now()
    };

    RETURN $updated;
};

DEFINE FUNCTION OVERWRITE fn::runtime::governance::run::contain($run_id: string, $reason: option<string>) -> object {
    LET $record = type::record("runtime_run", $run_id);

    LET $updated = UPDATE ONLY $record SET
        status = "contained",
        reason = $reason ?? reason,
        updated_at = time::now();

    CREATE runtime_audit_event CONTENT {
        run: $record,
        event_type: "runtime_run_contained",
        actor: "runtime",
        message: $reason ?? "Runtime run contained",
        created_at: time::now()
    };

    RETURN $updated;
};

-- Blocker lifecycle --------------------------------------------------------

DEFINE FUNCTION OVERWRITE fn::runtime::governance::blocker::resolve($blocker_id: string) -> object {
    LET $record = type::record("runtime_blocker", $blocker_id);

    LET $updated = UPDATE ONLY $record SET
        status = "resolved",
        resolved_at = time::now();

    CREATE runtime_audit_event CONTENT {
        run: $updated.run,
        event_type: "runtime_blocker_resolved",
        actor: "runtime",
        message: "Runtime blocker resolved",
        created_at: time::now()
    };

    RETURN $updated;
};

-- Access gating ------------------------------------------------------------

DEFINE FUNCTION OVERWRITE fn::runtime::governance::access::decide($decision: object) -> object {
    LET $run = type::record("runtime_run", <string>$decision.run_id);

    LET $recorded = CREATE ONLY runtime_access_decision CONTENT {
        run: $run,
        resource_type: $decision.resource_type,
        resource_ref: $decision.resource_ref,
        action: $decision.action,
        decision: $decision.decision,
        reason: $decision.reason ?? NONE,
        policy: IF type::is_none($decision.policy) {
            NONE
        } ELSE {
            type::record("runtime_policy", <string>$decision.policy)
        },
        decided_at: time::now()
    };

    CREATE runtime_audit_event CONTENT {
        run: $run,
        event_type: "runtime_access_decision",
        actor: "runtime",
        message: "Runtime access decision recorded",
        data: {
            resource_type: $decision.resource_type,
            resource_ref: $decision.resource_ref,
            action: $decision.action,
            decision: $decision.decision
        },
        created_at: time::now()
    };

    RETURN $recorded;
};

DEFINE FUNCTION OVERWRITE fn::runtime::governance::gate::record($gate: object) -> object {
    LET $run = type::record("runtime_run", <string>$gate.run_id);

    LET $recorded = CREATE ONLY runtime_gate CONTENT {
        run: $run,
        gate_type: $gate.gate_type,
        resource: $gate.resource,
        decision: $gate.decision,
        reason: $gate.reason ?? NONE,
        policy: IF type::is_none($gate.policy) {
            NONE
        } ELSE {
            type::record("runtime_policy", <string>$gate.policy)
        },
        decided_by: $gate.decided_by ?? "runtime",
        decided_at: time::now()
    };

    CREATE runtime_audit_event CONTENT {
        run: $run,
        event_type: "runtime_gate_decision",
        actor: "runtime",
        message: "Runtime gate decision recorded",
        data: {
            gate_type: $gate.gate_type,
            resource: $gate.resource,
            decision: $gate.decision
        },
        created_at: time::now()
    };

    RETURN $recorded;
};

-- Kill switches ------------------------------------------------------------

DEFINE FUNCTION OVERWRITE fn::runtime::governance::kill_switch::activate($switch_id: string, $activated_by: string, $reason: option<string>) -> object {
    LET $record = type::record("runtime_kill_switch", $switch_id);

    LET $updated = UPDATE ONLY $record SET
        active = true,
        activated_by = $activated_by,
        reason = $reason ?? reason,
        activated_at = time::now();

    CREATE runtime_audit_event CONTENT {
        event_type: "runtime_kill_switch_activated",
        actor: $activated_by,
        message: $reason ?? "Kill switch activated",
        data: {
            scope: $updated.scope,
            target_ref: $updated.target_ref
        },
        created_at: time::now()
    };

    RETURN $updated;
};

DEFINE FUNCTION OVERWRITE fn::runtime::governance::kill_switch::deactivate($switch_id: string, $deactivated_by: string) -> object {
    LET $record = type::record("runtime_kill_switch", $switch_id);

    LET $updated = UPDATE ONLY $record SET
        active = false,
        deactivated_at = time::now();

    CREATE runtime_audit_event CONTENT {
        event_type: "runtime_kill_switch_deactivated",
        actor: $deactivated_by,
        message: "Kill switch deactivated",
        data: {
            scope: $updated.scope,
            target_ref: $updated.target_ref
        },
        created_at: time::now()
    };

    RETURN $updated;
};

-- Agent freeze -------------------------------------------------------------

DEFINE FUNCTION OVERWRITE fn::runtime::governance::freeze::create($freeze: object) -> object {
    LET $agent = type::record("agent_identity", <string>$freeze.agent_identity);

    LET $created = CREATE ONLY runtime_freeze CONTENT {
        agent_identity: $agent,
        freeze_type: $freeze.freeze_type,
        reason: $freeze.reason,
        active: true,
        created_by: $freeze.created_by ?? "runtime",
        created_at: time::now()
    };

    CREATE runtime_audit_event CONTENT {
        agent_identity: $agent,
        event_type: "runtime_agent_frozen",
        actor: $freeze.created_by ?? "runtime",
        message: $freeze.reason,
        data: { freeze_type: $freeze.freeze_type },
        created_at: time::now()
    };

    RETURN $created;
};

DEFINE FUNCTION OVERWRITE fn::runtime::governance::freeze::release($freeze_id: string, $released_by: string) -> object {
    LET $record = type::record("runtime_freeze", $freeze_id);

    LET $updated = UPDATE ONLY $record SET
        active = false,
        released_by = $released_by,
        released_at = time::now();

    CREATE runtime_audit_event CONTENT {
        agent_identity: $updated.agent_identity,
        event_type: "runtime_agent_freeze_released",
        actor: $released_by,
        message: "Agent freeze released",
        data: { freeze_type: $updated.freeze_type },
        created_at: time::now()
    };

    RETURN $updated;
};

-- Recovery -----------------------------------------------------------------

DEFINE FUNCTION OVERWRITE fn::runtime::governance::recovery::request($recovery: object) -> object {
    LET $run = type::record("runtime_run", <string>$recovery.run_id);

    LET $created = CREATE ONLY runtime_recovery CONTENT {
        run: $run,
        recovery_type: $recovery.recovery_type,
        reason: $recovery.reason,
        status: "requested",
        requested_by: $recovery.requested_by ?? "runtime",
        requested_at: time::now()
    };

    CREATE runtime_audit_event CONTENT {
        run: $run,
        event_type: "runtime_recovery_requested",
        actor: $recovery.requested_by ?? "runtime",
        message: $recovery.reason,
        data: { recovery_type: $recovery.recovery_type },
        created_at: time::now()
    };

    RETURN $created;
};

DEFINE FUNCTION OVERWRITE fn::runtime::governance::recovery::approve($recovery_id: string, $approved_by: string) -> object {
    LET $record = type::record("runtime_recovery", $recovery_id);

    LET $updated = UPDATE ONLY $record SET status = "approved";

    CREATE runtime_audit_event CONTENT {
        run: $updated.run,
        event_type: "runtime_recovery_approved",
        actor: $approved_by,
        message: "Runtime recovery approved",
        created_at: time::now()
    };

    RETURN $updated;
};

DEFINE FUNCTION OVERWRITE fn::runtime::governance::recovery::reject($recovery_id: string, $rejected_by: string, $reason: option<string>) -> object {
    LET $record = type::record("runtime_recovery", $recovery_id);

    LET $updated = UPDATE ONLY $record SET status = "rejected";

    CREATE runtime_audit_event CONTENT {
        run: $updated.run,
        event_type: "runtime_recovery_rejected",
        actor: $rejected_by,
        message: $reason ?? "Runtime recovery rejected",
        created_at: time::now()
    };

    RETURN $updated;
};

DEFINE FUNCTION OVERWRITE fn::runtime::governance::recovery::complete($recovery_id: string) -> object {
    LET $record = type::record("runtime_recovery", $recovery_id);

    LET $updated = UPDATE ONLY $record SET
        status = "completed",
        completed_at = time::now();

    CREATE runtime_audit_event CONTENT {
        run: $updated.run,
        event_type: "runtime_recovery_completed",
        actor: "runtime",
        message: "Runtime recovery completed",
        created_at: time::now()
    };

    RETURN $updated;
};

-- Audit --------------------------------------------------------------------

DEFINE FUNCTION OVERWRITE fn::runtime::governance::audit($event: object) -> object {
    RETURN CREATE ONLY runtime_audit_event CONTENT {
        run: IF type::is_none($event.run_id) {
            NONE
        } ELSE {
            type::record("runtime_run", <string>$event.run_id)
        },
        agent_identity: IF type::is_none($event.agent_identity) {
            NONE
        } ELSE {
            type::record("agent_identity", <string>$event.agent_identity)
        },
        event_type: $event.event_type,
        actor: $event.actor ?? "runtime",
        message: $event.message,
        data: $event.data ?? {},
        created_at: time::now()
    };
};
