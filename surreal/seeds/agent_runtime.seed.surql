-- AGenNext Agent Runtime Seed Data

CREATE runtime_policy:default_runtime_policy SET
  name = "Default Runtime Policy",
  description = "Default governance policy for standard agent execution",
  trust_threshold = 0.7,
  max_runtime_seconds = 3600,
  max_tool_calls = 100,
  allow_external_actions = false,
  allow_secret_access = false,
  allow_model_access = true,
  human_approval_required = false,
  status = "active";

CREATE runtime_run:research_agent_run_001 SET
  agent_identity = agent_identity:research_agent,
  registry_entry = "registry_entry:research_agent",
  run_owner = "runtime",
  status = "created",
  priority = "normal",
  reason = "Initial runtime execution",
  context_ref = "context:research_session_001",
  policy_ref = runtime_policy:default_runtime_policy;

CREATE runtime_access_decision:research_agent_model_access SET
  run = runtime_run:research_agent_run_001,
  resource_type = "model",
  resource_ref = "model:gpt-5",
  action = "invoke",
  decision = "allow",
  reason = "Allowed by default runtime policy",
  policy = runtime_policy:default_runtime_policy;

CREATE runtime_audit_event:research_agent_run_created SET
  run = runtime_run:research_agent_run_001,
  agent_identity = agent_identity:research_agent,
  event_type = "runtime_run_created",
  actor = "runtime",
  message = "Runtime run created",
  data = {
    run_status: "created",
    policy: "default_runtime_policy"
  };

CREATE runtime_kill_switch:global_emergency_stop SET
  name = "Global Emergency Stop",
  scope = "global",
  active = false,
  reason = "Inactive by default";

CREATE runtime_freeze:research_agent_model_freeze SET
  agent_identity = agent_identity:research_agent,
  freeze_type = "model",
  reason = "Demonstration freeze record",
  active = false,
  created_by = "runtime",
  created_at = time::now(),
  released_by = "runtime",
  released_at = time::now();
