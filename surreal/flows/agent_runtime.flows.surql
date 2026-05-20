-- Agent-Runtime governance flows.
-- These functions govern runtime state only. They do not execute framework workflows.

DEFINE FUNCTION fn::runtime::create_runtime_run(
  $agent_identity: record<agent_identity>,
  $registry_entry: string,
  $run_owner: record<identity_ref>,
  $reason: option<string>,
  $context_ref: option<string>,
  $policy_ref: option<record<runtime_policy>>,
  $priority: int
) {
  LET $created = CREATE ONLY runtime_run CONTENT {
    agent_identity: $agent_identity,
    registry_entry: $registry_entry,
    run_owner: $run_owner,
    status: 'created',
    priority: $priority,
    reason: $reason,
    context_ref: $context_ref,
    policy_ref: $policy_ref,
    created_at: time::now(),
    started_at: NONE,
    completed_at: NONE,
    updated_at: time::now()
  };

  CREATE runtime_audit_event CONTENT {
    run: $created.id,
    agent_identity: $agent_identity,
    event_type: 'runtime_run.created',
    actor: 'runtime',
    message: 'Runtime run created.',
    data: { registry_entry: $registry_entry, policy_ref: $policy_ref },
    created_at: time::now()
  };

  RETURN $created;
};

DEFINE FUNCTION fn::runtime::start_runtime_run($run: record<runtime_run>, $actor: string) {
  LET $updated = UPDATE ONLY $run SET
    status = 'running',
    started_at = time::now(),
    updated_at = time::now()
  RETURN AFTER;

  CREATE runtime_audit_event CONTENT {
    run: $run,
    agent_identity: $updated.agent_identity,
    event_type: 'runtime_run.started',
    actor: $actor,
    message: 'Runtime run started.',
    data: {},
    created_at: time::now()
  };

  RETURN $updated;
};

DEFINE FUNCTION fn::runtime::block_runtime_run(
  $run: record<runtime_run>,
  $blocker_type: string,
  $reason: string,
  $severity: string,
  $actor: string
) {
  LET $blocker = CREATE ONLY runtime_blocker CONTENT {
    run: $run,
    blocker_type: $blocker_type,
    reason: $reason,
    severity: $severity,
    status: 'open',
    created_at: time::now(),
    resolved_at: NONE
  };

  LET $updated = UPDATE ONLY $run SET
    status = 'blocked',
    updated_at = time::now()
  RETURN AFTER;

  CREATE runtime_audit_event CONTENT {
    run: $run,
    agent_identity: $updated.agent_identity,
    event_type: 'runtime_run.blocked',
    actor: $actor,
    message: $reason,
    data: { blocker: $blocker.id, blocker_type: $blocker_type, severity: $severity },
    created_at: time::now()
  };

  RETURN { run: $updated, blocker: $blocker };
};

DEFINE FUNCTION fn::runtime::complete_runtime_run($run: record<runtime_run>, $actor: string, $message: string) {
  LET $updated = UPDATE ONLY $run SET
    status = 'completed',
    completed_at = time::now(),
    updated_at = time::now()
  RETURN AFTER;

  CREATE runtime_audit_event CONTENT {
    run: $run,
    agent_identity: $updated.agent_identity,
    event_type: 'runtime_run.completed',
    actor: $actor,
    message: $message,
    data: {},
    created_at: time::now()
  };

  RETURN $updated;
};

DEFINE FUNCTION fn::runtime::fail_runtime_run($run: record<runtime_run>, $actor: string, $reason: string) {
  LET $updated = UPDATE ONLY $run SET
    status = 'failed',
    completed_at = time::now(),
    updated_at = time::now()
  RETURN AFTER;

  CREATE runtime_audit_event CONTENT {
    run: $run,
    agent_identity: $updated.agent_identity,
    event_type: 'runtime_run.failed',
    actor: $actor,
    message: $reason,
    data: {},
    created_at: time::now()
  };

  RETURN $updated;
};

DEFINE FUNCTION fn::runtime::kill_runtime_run($run: record<runtime_run>, $actor: string, $reason: string) {
  LET $updated = UPDATE ONLY $run SET
    status = 'killed',
    completed_at = time::now(),
    updated_at = time::now()
  RETURN AFTER;

  CREATE runtime_audit_event CONTENT {
    run: $run,
    agent_identity: $updated.agent_identity,
    event_type: 'runtime_run.killed',
    actor: $actor,
    message: $reason,
    data: {},
    created_at: time::now()
  };

  RETURN $updated;
};

DEFINE FUNCTION fn::runtime::contain_runtime_run($run: record<runtime_run>, $actor: string, $reason: string) {
  LET $updated = UPDATE ONLY $run SET
    status = 'contained',
    updated_at = time::now()
  RETURN AFTER;

  CREATE runtime_audit_event CONTENT {
    run: $run,
    agent_identity: $updated.agent_identity,
    event_type: 'runtime_run.contained',
    actor: $actor,
    message: $reason,
    data: {},
    created_at: time::now()
  };

  RETURN $updated;
};

DEFINE FUNCTION fn::runtime::evaluate_tool_access(
  $run: record<runtime_run>,
  $resource_ref: string,
  $action: string
) {
  LET $run_state = SELECT * FROM ONLY $run;
  LET $policy = SELECT * FROM ONLY $run_state.policy_ref;
  LET $global_kills = SELECT id FROM runtime_kill_switch WHERE active = true AND scope = 'global';
  LET $tool_kills = SELECT id FROM runtime_kill_switch WHERE active = true AND scope = 'tool' AND target_ref = $resource_ref;
  LET $agent_freezes = SELECT id FROM runtime_freeze WHERE active = true AND agent_identity = $run_state.agent_identity AND freeze_type IN ['tools', 'full'];
  LET $decision = IF array::len($global_kills) > 0 OR array::len($tool_kills) > 0 OR array::len($agent_freezes) > 0 THEN
    'deny'
  ELSE IF $policy.human_approval_required OR !$policy.allow_external_actions THEN
    'require_approval'
  ELSE
    'allow'
  END;

  RETURN CREATE ONLY runtime_access_decision CONTENT {
    run: $run,
    resource_type: 'tool',
    resource_ref: $resource_ref,
    action: $action,
    decision: $decision,
    reason: 'Tool access evaluated by Agent-Runtime governance.',
    policy: $run_state.policy_ref,
    decided_at: time::now()
  };
};

DEFINE FUNCTION fn::runtime::evaluate_secret_access(
  $run: record<runtime_run>,
  $resource_ref: string,
  $action: string
) {
  LET $run_state = SELECT * FROM ONLY $run;
  LET $policy = SELECT * FROM ONLY $run_state.policy_ref;
  LET $global_kills = SELECT id FROM runtime_kill_switch WHERE active = true AND scope = 'global';
  LET $secret_kills = SELECT id FROM runtime_kill_switch WHERE active = true AND scope = 'secret' AND target_ref = $resource_ref;
  LET $agent_freezes = SELECT id FROM runtime_freeze WHERE active = true AND agent_identity = $run_state.agent_identity AND freeze_type IN ['secrets', 'full'];
  LET $decision = IF array::len($global_kills) > 0 OR array::len($secret_kills) > 0 OR array::len($agent_freezes) > 0 THEN
    'deny'
  ELSE IF $policy.allow_secret_access THEN
    'allow'
  ELSE
    'require_approval'
  END;

  RETURN CREATE ONLY runtime_access_decision CONTENT {
    run: $run,
    resource_type: 'secret',
    resource_ref: $resource_ref,
    action: $action,
    decision: $decision,
    reason: 'Secret access evaluated by Agent-Runtime governance.',
    policy: $run_state.policy_ref,
    decided_at: time::now()
  };
};

DEFINE FUNCTION fn::runtime::activate_kill_switch(
  $kill_switch: record<runtime_kill_switch>,
  $actor: string,
  $reason: string
) {
  RETURN UPDATE ONLY $kill_switch SET
    active = true,
    reason = $reason,
    activated_by = $actor,
    activated_at = time::now(),
    deactivated_at = NONE
  RETURN AFTER;
};

DEFINE FUNCTION fn::runtime::deactivate_kill_switch($kill_switch: record<runtime_kill_switch>, $actor: string) {
  RETURN UPDATE ONLY $kill_switch SET
    active = false,
    reason = NONE,
    activated_by = $actor,
    deactivated_at = time::now()
  RETURN AFTER;
};

DEFINE FUNCTION fn::runtime::freeze_agent(
  $agent_identity: record<agent_identity>,
  $freeze_type: string,
  $reason: string,
  $actor: string
) {
  RETURN CREATE ONLY runtime_freeze CONTENT {
    agent_identity: $agent_identity,
    freeze_type: $freeze_type,
    reason: $reason,
    active: true,
    created_by: $actor,
    created_at: time::now(),
    released_by: NONE,
    released_at: NONE
  };
};

DEFINE FUNCTION fn::runtime::release_agent_freeze($freeze: record<runtime_freeze>, $actor: string) {
  RETURN UPDATE ONLY $freeze SET
    active = false,
    released_by = $actor,
    released_at = time::now()
  RETURN AFTER;
};

DEFINE FUNCTION fn::runtime::request_recovery(
  $run: record<runtime_run>,
  $recovery_type: string,
  $reason: string,
  $requested_by: string
) {
  RETURN CREATE ONLY runtime_recovery CONTENT {
    run: $run,
    recovery_type: $recovery_type,
    reason: $reason,
    status: 'requested',
    requested_by: $requested_by,
    requested_at: time::now(),
    completed_at: NONE
  };
};

DEFINE FUNCTION fn::runtime::approve_recovery($recovery: record<runtime_recovery>, $actor: string) {
  LET $updated = UPDATE ONLY $recovery SET status = 'approved' RETURN AFTER;
  CREATE runtime_audit_event CONTENT {
    run: $updated.run,
    agent_identity: NONE,
    event_type: 'runtime_recovery.approved',
    actor: $actor,
    message: 'Runtime recovery approved.',
    data: { recovery: $recovery },
    created_at: time::now()
  };
  RETURN $updated;
};

DEFINE FUNCTION fn::runtime::complete_recovery($recovery: record<runtime_recovery>, $actor: string, $message: string) {
  LET $updated = UPDATE ONLY $recovery SET
    status = 'completed',
    completed_at = time::now()
  RETURN AFTER;

  CREATE runtime_audit_event CONTENT {
    run: $updated.run,
    agent_identity: NONE,
    event_type: 'runtime_recovery.completed',
    actor: $actor,
    message: $message,
    data: { recovery: $recovery },
    created_at: time::now()
  };

  RETURN $updated;
};
