-- Query: Get runtime run by ID
SELECT * FROM runtime_run:$run;

-- Query: Get active runs for agent
SELECT * FROM runtime_run
WHERE agent_identity = agent_identity:$agent_identity
  AND status IN ["created", "scheduled", "running", "blocked", "paused"];

-- Query: Get blocked runs
SELECT * FROM runtime_run
WHERE status = "blocked";

-- Query: Get active kill switches
SELECT * FROM runtime_kill_switch
WHERE active = true;

-- Query: Get active freezes for agent
SELECT * FROM runtime_freeze
WHERE agent_identity = agent_identity:$agent_identity
  AND active = true;

-- Query: Get audit trail for run
SELECT * FROM runtime_audit_event
WHERE run = runtime_run:$run
ORDER BY created_at ASC;

-- Query: Get access decisions for run
SELECT * FROM runtime_access_decision
WHERE run = runtime_run:$run
ORDER BY decided_at DESC;

-- Query: Resolve runtime governance state for run
SELECT
  *,
  (SELECT * FROM runtime_access_decision WHERE run = runtime_run:$run) AS access_decisions,
  (SELECT * FROM runtime_blocker WHERE run = runtime_run:$run) AS blockers,
  (SELECT * FROM runtime_recovery WHERE run = runtime_run:$run) AS recoveries,
  (SELECT * FROM runtime_audit_event WHERE run = runtime_run:$run ORDER BY created_at ASC) AS audit_events
FROM runtime_run:$run;
