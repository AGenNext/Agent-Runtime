-- Runtime Flow: create_runtime_run
CREATE runtime_run CONTENT {
  agent_identity: $agent_identity,
  registry_entry: $registry_entry,
  run_owner: $run_owner,
  status: "created",
  priority: $priority,
  reason: $reason,
  context_ref: $context_ref,
  policy_ref: $policy_ref,
  created_at: time::now(),
  updated_at: time::now()
};

-- Runtime Flow: start_runtime_run
UPDATE runtime_run:$run SET
  status = "running",
  started_at = time::now(),
  updated_at = time::now();

-- Runtime Flow: block_runtime_run
UPDATE runtime_run:$run SET
  status = "blocked",
  updated_at = time::now();

CREATE runtime_blocker CONTENT {
  run: runtime_run:$run,
  blocker_type: $blocker_type,
  reason: $reason,
  severity: $severity,
  status: "open",
  created_at: time::now()
};

-- Runtime Flow: complete_runtime_run
UPDATE runtime_run:$run SET
  status = "completed",
  completed_at = time::now(),
  updated_at = time::now();

-- Runtime Flow: fail_runtime_run
UPDATE runtime_run:$run SET
  status = "failed",
  completed_at = time::now(),
  updated_at = time::now();

-- Runtime Flow: kill_runtime_run
UPDATE runtime_run:$run SET
  status = "killed",
  completed_at = time::now(),
  updated_at = time::now();

-- Runtime Flow: contain_runtime_run
UPDATE runtime_run:$run SET
  status = "contained",
  updated_at = time::now();

-- Runtime Flow: evaluate_tool_access
CREATE runtime_access_decision CONTENT {
  run: runtime_run:$run,
  resource_type: "tool",
  resource_ref: $resource_ref,
  action: $action,
  decision: $decision,
  reason: $reason,
  policy: $policy,
  decided_at: time::now()
};

-- Runtime Flow: evaluate_secret_access
CREATE runtime_access_decision CONTENT {
  run: runtime_run:$run,
  resource_type: "secret",
  resource_ref: $resource_ref,
  action: $action,
  decision: $decision,
  reason: $reason,
  policy: $policy,
  decided_at: time::now()
};

-- Runtime Flow: activate_kill_switch
UPDATE runtime_kill_switch:$kill_switch SET
  active = true,
  activated_by = $activated_by,
  activated_at = time::now();

-- Runtime Flow: deactivate_kill_switch
UPDATE runtime_kill_switch:$kill_switch SET
  active = false,
  deactivated_at = time::now();

-- Runtime Flow: freeze_agent
CREATE runtime_freeze CONTENT {
  agent_identity: $agent_identity,
  freeze_type: $freeze_type,
  reason: $reason,
  active: true,
  created_by: $created_by,
  created_at: time::now()
};

-- Runtime Flow: release_agent_freeze
UPDATE runtime_freeze:$freeze SET
  active = false,
  released_by = $released_by,
  released_at = time::now();

-- Runtime Flow: request_recovery
CREATE runtime_recovery CONTENT {
  run: runtime_run:$run,
  recovery_type: $recovery_type,
  reason: $reason,
  status: "requested",
  requested_by: $requested_by,
  requested_at: time::now()
};

-- Runtime Flow: approve_recovery
UPDATE runtime_recovery:$recovery SET
  status = "approved";

-- Runtime Flow: complete_recovery
UPDATE runtime_recovery:$recovery SET
  status = "completed",
  completed_at = time::now();
