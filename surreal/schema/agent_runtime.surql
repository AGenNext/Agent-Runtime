-- AGenNext Agent-Runtime governance schema.
-- Runtime state is data. Execution frameworks run elsewhere through adapters.

DEFINE TABLE runtime_run SCHEMAFULL;
DEFINE FIELD agent_identity ON TABLE runtime_run TYPE record<agent_identity>;
DEFINE FIELD registry_entry ON TABLE runtime_run TYPE string;
DEFINE FIELD run_owner ON TABLE runtime_run TYPE record<identity_ref>;
DEFINE FIELD status ON TABLE runtime_run TYPE string ASSERT $value IN [
  'created',
  'scheduled',
  'running',
  'blocked',
  'paused',
  'completed',
  'failed',
  'cancelled',
  'killed',
  'contained'
];
DEFINE FIELD priority ON TABLE runtime_run TYPE int ASSERT $value >= 0 AND $value <= 100;
DEFINE FIELD reason ON TABLE runtime_run TYPE option<string>;
DEFINE FIELD context_ref ON TABLE runtime_run TYPE option<string>;
DEFINE FIELD policy_ref ON TABLE runtime_run TYPE option<record<runtime_policy>>;
DEFINE FIELD created_at ON TABLE runtime_run TYPE datetime;
DEFINE FIELD started_at ON TABLE runtime_run TYPE option<datetime>;
DEFINE FIELD completed_at ON TABLE runtime_run TYPE option<datetime>;
DEFINE FIELD updated_at ON TABLE runtime_run TYPE datetime;
DEFINE INDEX idx_runtime_run_status ON TABLE runtime_run FIELDS status;
DEFINE INDEX idx_runtime_run_agent_identity ON TABLE runtime_run FIELDS agent_identity;
DEFINE INDEX idx_runtime_run_agent_status ON TABLE runtime_run FIELDS agent_identity, status;

DEFINE TABLE runtime_policy SCHEMAFULL;
DEFINE FIELD name ON TABLE runtime_policy TYPE string;
DEFINE FIELD description ON TABLE runtime_policy TYPE string;
DEFINE FIELD trust_threshold ON TABLE runtime_policy TYPE number ASSERT $value >= 0 AND $value <= 1;
DEFINE FIELD max_runtime_seconds ON TABLE runtime_policy TYPE int ASSERT $value > 0;
DEFINE FIELD max_tool_calls ON TABLE runtime_policy TYPE int ASSERT $value >= 0;
DEFINE FIELD allow_external_actions ON TABLE runtime_policy TYPE bool;
DEFINE FIELD allow_secret_access ON TABLE runtime_policy TYPE bool;
DEFINE FIELD allow_model_access ON TABLE runtime_policy TYPE bool;
DEFINE FIELD human_approval_required ON TABLE runtime_policy TYPE bool;
DEFINE FIELD status ON TABLE runtime_policy TYPE string ASSERT $value IN ['active', 'inactive', 'deprecated'];
DEFINE FIELD created_at ON TABLE runtime_policy TYPE datetime;
DEFINE FIELD updated_at ON TABLE runtime_policy TYPE datetime;
DEFINE INDEX idx_runtime_policy_status ON TABLE runtime_policy FIELDS status;
DEFINE INDEX idx_runtime_policy_name ON TABLE runtime_policy FIELDS name;

DEFINE TABLE runtime_gate SCHEMAFULL;
DEFINE FIELD run ON TABLE runtime_gate TYPE record<runtime_run>;
DEFINE FIELD gate_type ON TABLE runtime_gate TYPE string;
DEFINE FIELD resource ON TABLE runtime_gate TYPE string;
DEFINE FIELD decision ON TABLE runtime_gate TYPE string ASSERT $value IN ['allow', 'deny', 'require_approval'];
DEFINE FIELD reason ON TABLE runtime_gate TYPE string;
DEFINE FIELD policy ON TABLE runtime_gate TYPE option<record<runtime_policy>>;
DEFINE FIELD decided_by ON TABLE runtime_gate TYPE string;
DEFINE FIELD decided_at ON TABLE runtime_gate TYPE datetime;
DEFINE INDEX idx_runtime_gate_run ON TABLE runtime_gate FIELDS run;
DEFINE INDEX idx_runtime_gate_decision ON TABLE runtime_gate FIELDS decision;

DEFINE TABLE runtime_kill_switch SCHEMAFULL;
DEFINE FIELD name ON TABLE runtime_kill_switch TYPE string;
DEFINE FIELD scope ON TABLE runtime_kill_switch TYPE string ASSERT $value IN ['global', 'agent', 'run', 'tool', 'model', 'secret', 'network'];
DEFINE FIELD target_ref ON TABLE runtime_kill_switch TYPE option<string>;
DEFINE FIELD active ON TABLE runtime_kill_switch TYPE bool;
DEFINE FIELD reason ON TABLE runtime_kill_switch TYPE option<string>;
DEFINE FIELD activated_by ON TABLE runtime_kill_switch TYPE option<string>;
DEFINE FIELD activated_at ON TABLE runtime_kill_switch TYPE option<datetime>;
DEFINE FIELD deactivated_at ON TABLE runtime_kill_switch TYPE option<datetime>;
DEFINE INDEX idx_runtime_kill_switch_active ON TABLE runtime_kill_switch FIELDS active;
DEFINE INDEX idx_runtime_kill_switch_scope_active ON TABLE runtime_kill_switch FIELDS scope, active;
DEFINE INDEX idx_runtime_kill_switch_target_active ON TABLE runtime_kill_switch FIELDS target_ref, active;

DEFINE TABLE runtime_freeze SCHEMAFULL;
DEFINE FIELD agent_identity ON TABLE runtime_freeze TYPE record<agent_identity>;
DEFINE FIELD freeze_type ON TABLE runtime_freeze TYPE string ASSERT $value IN ['identity', 'tools', 'secrets', 'model', 'network', 'full'];
DEFINE FIELD reason ON TABLE runtime_freeze TYPE string;
DEFINE FIELD active ON TABLE runtime_freeze TYPE bool;
DEFINE FIELD created_by ON TABLE runtime_freeze TYPE string;
DEFINE FIELD created_at ON TABLE runtime_freeze TYPE datetime;
DEFINE FIELD released_by ON TABLE runtime_freeze TYPE option<string>;
DEFINE FIELD released_at ON TABLE runtime_freeze TYPE option<datetime>;
DEFINE INDEX idx_runtime_freeze_agent_identity ON TABLE runtime_freeze FIELDS agent_identity;
DEFINE INDEX idx_runtime_freeze_active ON TABLE runtime_freeze FIELDS active;
DEFINE INDEX idx_runtime_freeze_agent_active ON TABLE runtime_freeze FIELDS agent_identity, active;

DEFINE TABLE runtime_blocker SCHEMAFULL;
DEFINE FIELD run ON TABLE runtime_blocker TYPE record<runtime_run>;
DEFINE FIELD blocker_type ON TABLE runtime_blocker TYPE string;
DEFINE FIELD reason ON TABLE runtime_blocker TYPE string;
DEFINE FIELD severity ON TABLE runtime_blocker TYPE string ASSERT $value IN ['low', 'medium', 'high', 'critical'];
DEFINE FIELD status ON TABLE runtime_blocker TYPE string ASSERT $value IN ['open', 'resolved', 'ignored'];
DEFINE FIELD created_at ON TABLE runtime_blocker TYPE datetime;
DEFINE FIELD resolved_at ON TABLE runtime_blocker TYPE option<datetime>;
DEFINE INDEX idx_runtime_blocker_run ON TABLE runtime_blocker FIELDS run;
DEFINE INDEX idx_runtime_blocker_status ON TABLE runtime_blocker FIELDS status;
DEFINE INDEX idx_runtime_blocker_severity ON TABLE runtime_blocker FIELDS severity;

DEFINE TABLE runtime_schedule SCHEMAFULL;
DEFINE FIELD run ON TABLE runtime_schedule TYPE record<runtime_run>;
DEFINE FIELD scheduled_for ON TABLE runtime_schedule TYPE datetime;
DEFINE FIELD schedule_type ON TABLE runtime_schedule TYPE string;
DEFINE FIELD status ON TABLE runtime_schedule TYPE string ASSERT $value IN ['pending', 'scheduled', 'running', 'completed', 'cancelled', 'failed'];
DEFINE FIELD created_at ON TABLE runtime_schedule TYPE datetime;
DEFINE FIELD updated_at ON TABLE runtime_schedule TYPE datetime;
DEFINE INDEX idx_runtime_schedule_run ON TABLE runtime_schedule FIELDS run;
DEFINE INDEX idx_runtime_schedule_status ON TABLE runtime_schedule FIELDS status;
DEFINE INDEX idx_runtime_schedule_due ON TABLE runtime_schedule FIELDS scheduled_for, status;

DEFINE TABLE runtime_recovery SCHEMAFULL;
DEFINE FIELD run ON TABLE runtime_recovery TYPE record<runtime_run>;
DEFINE FIELD recovery_type ON TABLE runtime_recovery TYPE string;
DEFINE FIELD reason ON TABLE runtime_recovery TYPE string;
DEFINE FIELD status ON TABLE runtime_recovery TYPE string ASSERT $value IN ['requested', 'approved', 'running', 'completed', 'failed', 'rejected'];
DEFINE FIELD requested_by ON TABLE runtime_recovery TYPE string;
DEFINE FIELD requested_at ON TABLE runtime_recovery TYPE datetime;
DEFINE FIELD completed_at ON TABLE runtime_recovery TYPE option<datetime>;
DEFINE INDEX idx_runtime_recovery_run ON TABLE runtime_recovery FIELDS run;
DEFINE INDEX idx_runtime_recovery_status ON TABLE runtime_recovery FIELDS status;

DEFINE TABLE runtime_access_decision SCHEMAFULL;
DEFINE FIELD run ON TABLE runtime_access_decision TYPE record<runtime_run>;
DEFINE FIELD resource_type ON TABLE runtime_access_decision TYPE string;
DEFINE FIELD resource_ref ON TABLE runtime_access_decision TYPE string;
DEFINE FIELD action ON TABLE runtime_access_decision TYPE string;
DEFINE FIELD decision ON TABLE runtime_access_decision TYPE string ASSERT $value IN ['allow', 'deny', 'require_approval'];
DEFINE FIELD reason ON TABLE runtime_access_decision TYPE string;
DEFINE FIELD policy ON TABLE runtime_access_decision TYPE option<record<runtime_policy>>;
DEFINE FIELD decided_at ON TABLE runtime_access_decision TYPE datetime;
DEFINE INDEX idx_runtime_access_decision_run ON TABLE runtime_access_decision FIELDS run;
DEFINE INDEX idx_runtime_access_decision_resource ON TABLE runtime_access_decision FIELDS resource_type, resource_ref;
DEFINE INDEX idx_runtime_access_decision_decision ON TABLE runtime_access_decision FIELDS decision;

DEFINE TABLE runtime_audit_event SCHEMAFULL;
DEFINE FIELD run ON TABLE runtime_audit_event TYPE option<record<runtime_run>>;
DEFINE FIELD agent_identity ON TABLE runtime_audit_event TYPE option<record<agent_identity>>;
DEFINE FIELD event_type ON TABLE runtime_audit_event TYPE string;
DEFINE FIELD actor ON TABLE runtime_audit_event TYPE string;
DEFINE FIELD message ON TABLE runtime_audit_event TYPE string;
DEFINE FIELD data ON TABLE runtime_audit_event TYPE object FLEXIBLE;
DEFINE FIELD created_at ON TABLE runtime_audit_event TYPE datetime;
DEFINE INDEX idx_runtime_audit_event_run ON TABLE runtime_audit_event FIELDS run;
DEFINE INDEX idx_runtime_audit_event_agent_identity ON TABLE runtime_audit_event FIELDS agent_identity;
DEFINE INDEX idx_runtime_audit_event_type ON TABLE runtime_audit_event FIELDS event_type;
DEFINE INDEX idx_runtime_audit_event_created ON TABLE runtime_audit_event FIELDS created_at;
