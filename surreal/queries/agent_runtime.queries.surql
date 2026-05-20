-- Reusable Agent-Runtime governance queries.
-- Bind variables such as $run and $agent_identity before running these blocks.

-- get run by id
SELECT * FROM ONLY $run;

-- get active runs for agent
SELECT * FROM runtime_run
WHERE agent_identity = $agent_identity
AND status IN ['created', 'scheduled', 'running', 'blocked', 'paused', 'contained']
ORDER BY priority DESC, updated_at DESC;

-- get blocked runs
SELECT * FROM runtime_run
WHERE status = 'blocked'
ORDER BY updated_at DESC;

-- get active kill switches
SELECT * FROM runtime_kill_switch
WHERE active = true
ORDER BY activated_at DESC;

-- get active freezes for agent
SELECT * FROM runtime_freeze
WHERE agent_identity = $agent_identity
AND active = true
ORDER BY created_at DESC;

-- get audit trail for run
SELECT * FROM runtime_audit_event
WHERE run = $run
ORDER BY created_at ASC;

-- get access decisions for run
SELECT * FROM runtime_access_decision
WHERE run = $run
ORDER BY decided_at DESC;

-- resolve runtime governance state for run
SELECT
  *,
  (
    SELECT * FROM runtime_blocker
    WHERE run = $parent.id AND status = 'open'
    ORDER BY created_at DESC
  ) AS open_blockers,
  (
    SELECT * FROM runtime_gate
    WHERE run = $parent.id
    ORDER BY decided_at DESC
  ) AS gates,
  (
    SELECT * FROM runtime_access_decision
    WHERE run = $parent.id
    ORDER BY decided_at DESC
  ) AS access_decisions,
  (
    SELECT * FROM runtime_freeze
    WHERE agent_identity = $parent.agent_identity AND active = true
    ORDER BY created_at DESC
  ) AS active_freezes,
  (
    SELECT * FROM runtime_kill_switch
    WHERE active = true
    ORDER BY activated_at DESC
  ) AS active_kill_switches,
  (
    SELECT * FROM runtime_recovery
    WHERE run = $parent.id
    ORDER BY requested_at DESC
  ) AS recovery_requests,
  (
    SELECT * FROM runtime_audit_event
    WHERE run = $parent.id
    ORDER BY created_at ASC
  ) AS audit_trail
FROM ONLY $run;
