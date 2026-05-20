-- Seed data for Agent-Runtime governance.

UPSERT runtime_policy:default CONTENT {
  name: 'Default Runtime Governance Policy',
  description: 'Default containment policy for governed agent runs.',
  trust_threshold: 0.70,
  max_runtime_seconds: 3600,
  max_tool_calls: 100,
  allow_external_actions: false,
  allow_secret_access: false,
  allow_model_access: true,
  human_approval_required: true,
  status: 'active',
  created_at: time::now(),
  updated_at: time::now()
};

UPSERT runtime_run:sample_research_run CONTENT {
  agent_identity: agent_identity:research_agent,
  registry_entry: 'registry_entry:research_agent',
  run_owner: identity_ref:runtime_team,
  status: 'created',
  priority: 50,
  reason: 'Sample governed research run.',
  context_ref: 'context:sample_research',
  policy_ref: runtime_policy:default,
  created_at: time::now(),
  started_at: NONE,
  completed_at: NONE,
  updated_at: time::now()
};

CREATE runtime_access_decision CONTENT {
  run: runtime_run:sample_research_run,
  resource_type: 'tool',
  resource_ref: 'tool:web_research',
  action: 'invoke',
  decision: 'require_approval',
  reason: 'Default policy requires human approval for external actions.',
  policy: runtime_policy:default,
  decided_at: time::now()
};

CREATE runtime_audit_event CONTENT {
  run: runtime_run:sample_research_run,
  agent_identity: agent_identity:research_agent,
  event_type: 'runtime_run.created',
  actor: 'seed',
  message: 'Sample runtime run created.',
  data: {
    registry_entry: 'registry_entry:research_agent',
    policy: runtime_policy:default
  },
  created_at: time::now()
};

UPSERT runtime_kill_switch:global CONTENT {
  name: 'Global runtime stop',
  scope: 'global',
  target_ref: NONE,
  active: false,
  reason: NONE,
  activated_by: NONE,
  activated_at: NONE,
  deactivated_at: time::now()
};

CREATE runtime_freeze CONTENT {
  agent_identity: agent_identity:research_agent,
  freeze_type: 'full',
  reason: 'Sample released trust/runtime freeze.',
  active: false,
  created_by: 'seed',
  created_at: time::now(),
  released_by: 'seed',
  released_at: time::now()
};
