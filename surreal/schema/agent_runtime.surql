-- AGenNext Agent Runtime
-- Executable SurrealQL governance schema.
-- Runtime governs execution. Frameworks execute elsewhere.

DEFINE TABLE runtime_policy SCHEMAFULL PERMISSIONS NONE;
DEFINE FIELD name ON TABLE runtime_policy TYPE string ASSERT string::len($value) > 0;
DEFINE FIELD description ON TABLE runtime_policy TYPE option<string>;
DEFINE FIELD trust_threshold ON TABLE runtime_policy TYPE float DEFAULT 0.7 ASSERT $value >= 0 AND $value <= 1;
DEFINE FIELD max_runtime_seconds ON TABLE runtime_policy TYPE int DEFAULT 3600 ASSERT $value > 0;
DEFINE FIELD max_tool_calls ON TABLE runtime_policy TYPE int DEFAULT 100 ASSERT $value >= 0;
DEFINE FIELD allow_external_actions ON TABLE runtime_policy TYPE bool DEFAULT false;
DEFINE FIELD allow_secret_access ON TABLE runtime_policy TYPE bool DEFAULT false;
DEFINE FIELD allow_model_access ON TABLE runtime_policy TYPE bool DEFAULT true;
DEFINE FIELD human_approval_required ON TABLE runtime_policy TYPE bool DEFAULT false;
DEFINE FIELD status ON TABLE runtime_policy TYPE string DEFAULT "active" ASSERT $value IN ["active", "inactive", "deprecated"];
DEFINE FIELD created_at ON TABLE runtime_policy TYPE datetime DEFAULT time::now();
DEFINE FIELD updated_at ON TABLE runtime_policy TYPE datetime DEFAULT time::now();
DEFINE INDEX runtime_policy_name_idx ON TABLE runtime_policy COLUMNS name UNIQUE;
DEFINE INDEX runtime_policy_status_idx ON TABLE runtime_policy COLUMNS status;

DEFINE TABLE runtime_run SCHEMAFULL PERMISSIONS NONE;
DEFINE FIELD agent_identity ON TABLE runtime_run TYPE record<agent_identity>;
DEFINE FIELD registry_entry ON TABLE runtime_run TYPE option<string>;
DEFINE FIELD run_owner ON TABLE runtime_run TYPE string;
DEFINE FIELD status ON TABLE runtime_run TYPE string DEFAULT "created" ASSERT $value IN ["created", "scheduled", "running", "blocked", "paused", "completed", "failed", "cancelled", "killed", "contained"];
DEFINE FIELD priority ON TABLE runtime_run TYPE string DEFAULT "normal" ASSERT $value IN ["low", "normal", "high", "critical"];
DEFINE FIELD reason ON TABLE runtime_run TYPE option<string>;
DEFINE FIELD context_ref ON TABLE runtime_run TYPE option<string>;
DEFINE FIELD policy_ref ON TABLE runtime_run TYPE option<record<runtime_policy>>;
DEFINE FIELD created_at ON TABLE runtime_run TYPE datetime DEFAULT time::now();
DEFINE FIELD started_at ON TABLE runtime_run TYPE option<datetime>;
DEFINE FIELD completed_at ON TABLE runtime_run TYPE option<datetime>;
DEFINE FIELD updated_at ON TABLE runtime_run TYPE datetime DEFAULT time::now();
DEFINE INDEX runtime_run_agent_idx ON TABLE runtime_run COLUMNS agent_identity;
DEFINE INDEX runtime_run_status_idx ON TABLE runtime_run COLUMNS status;
DEFINE INDEX runtime_run_owner_idx ON TABLE runtime_run COLUMNS run_owner;

DEFINE TABLE runtime_gate SCHEMAFULL PERMISSIONS NONE;
DEFINE FIELD run ON TABLE runtime_gate TYPE record<runtime_run>;
DEFINE FIELD gate_type ON TABLE runtime_gate TYPE string ASSERT $value IN ["tool", "secret", "model", "network", "external_action", "human_approval"];
DEFINE FIELD resource ON TABLE runtime_gate TYPE string;
DEFINE FIELD decision ON TABLE runtime_gate TYPE string ASSERT $value IN ["allow", "deny", "require_approval"];
DEFINE FIELD reason ON TABLE runtime_gate TYPE option<string>;
DEFINE FIELD policy ON TABLE runtime_gate TYPE option<record<runtime_policy>>;
DEFINE FIELD decided_by ON TABLE runtime_gate TYPE string DEFAULT "runtime";
DEFINE FIELD decided_at ON TABLE runtime_gate TYPE datetime DEFAULT time::now();
DEFINE INDEX runtime_gate_run_idx ON TABLE runtime_gate COLUMNS run;
DEFINE INDEX runtime_gate_decision_idx ON TABLE runtime_gate COLUMNS decision;

DEFINE TABLE runtime_kill_switch SCHEMAFULL PERMISSIONS NONE;
DEFINE FIELD name ON TABLE runtime_kill_switch TYPE string;
DEFINE FIELD scope ON TABLE runtime_kill_switch TYPE string ASSERT $value IN ["global", "agent", "run", "tool", "model", "secret", "network"];
DEFINE FIELD target_ref ON TABLE runtime_kill_switch TYPE option<string>;
DEFINE FIELD active ON TABLE runtime_kill_switch TYPE bool DEFAULT false;
DEFINE FIELD reason ON TABLE runtime_kill_switch TYPE option<string>;
DEFINE FIELD activated_by ON TABLE runtime_kill_switch TYPE option<string>;
DEFINE FIELD activated_at ON TABLE runtime_kill_switch TYPE option<datetime>;
DEFINE FIELD deactivated_at ON TABLE runtime_kill_switch TYPE option<datetime>;
DEFINE INDEX runtime_kill_switch_active_idx ON TABLE runtime_kill_switch COLUMNS active;
DEFINE INDEX runtime_kill_switch_scope_idx ON TABLE runtime_kill_switch COLUMNS scope, target_ref;

DEFINE TABLE runtime_freeze SCHEMAFULL PERMISSIONS NONE;
DEFINE FIELD agent_identity ON TABLE runtime_freeze TYPE record<agent_identity>;
DEFINE FIELD freeze_type ON TABLE runtime_freeze TYPE string ASSERT $value IN ["identity", "tools", "secrets", "model", "network", "full"];
DEFINE FIELD reason ON TABLE runtime_freeze TYPE string;
DEFINE FIELD active ON TABLE runtime_freeze TYPE bool DEFAULT true;
DEFINE FIELD created_by ON TABLE runtime_freeze TYPE string;
DEFINE FIELD created_at ON TABLE runtime_freeze TYPE datetime DEFAULT time::now();
DEFINE FIELD released_by ON TABLE runtime_freeze TYPE option<string>;
DEFINE FIELD released_at ON TABLE runtime_freeze TYPE option<datetime>;
DEFINE INDEX runtime_freeze_agent_idx ON TABLE runtime_freeze COLUMNS agent_identity;
DEFINE INDEX runtime_freeze_active_idx ON TABLE runtime_freeze COLUMNS active;

DEFINE TABLE runtime_blocker SCHEMAFULL PERMISSIONS NONE;
DEFINE FIELD run ON TABLE runtime_blocker TYPE record<runtime_run>;
DEFINE FIELD blocker_type ON TABLE runtime_blocker TYPE string;
DEFINE FIELD reason ON TABLE runtime_blocker TYPE string;
DEFINE FIELD severity ON TABLE runtime_blocker TYPE string ASSERT $value IN ["low", "medium", "high", "critical"];
DEFINE FIELD status ON TABLE runtime_blocker TYPE string DEFAULT "open" ASSERT $value IN ["open", "resolved", "ignored"];
DEFINE FIELD created_at ON TABLE runtime_blocker TYPE datetime DEFAULT time::now();
DEFINE FIELD resolved_at ON TABLE runtime_blocker TYPE option<datetime>;
DEFINE INDEX runtime_blocker_run_idx ON TABLE runtime_blocker COLUMNS run;
DEFINE INDEX runtime_blocker_status_idx ON TABLE runtime_blocker COLUMNS status;

DEFINE TABLE runtime_schedule SCHEMAFULL PERMISSIONS NONE;
DEFINE FIELD run ON TABLE runtime_schedule TYPE record<runtime_run>;
DEFINE FIELD scheduled_for ON TABLE runtime_schedule TYPE datetime;
DEFINE FIELD schedule_type ON TABLE runtime_schedule TYPE string DEFAULT "once" ASSERT $value IN ["once", "recurring", "manual"];
DEFINE FIELD status ON TABLE runtime_schedule TYPE string DEFAULT "pending" ASSERT $value IN ["pending", "scheduled", "running", "completed", "cancelled", "failed"];
DEFINE FIELD created_at ON TABLE runtime_schedule TYPE datetime DEFAULT time::now();
DEFINE FIELD updated_at ON TABLE runtime_schedule TYPE datetime DEFAULT time::now();
DEFINE INDEX runtime_schedule_status_idx ON TABLE runtime_schedule COLUMNS status;
DEFINE INDEX runtime_schedule_run_idx ON TABLE runtime_schedule COLUMNS run;

DEFINE TABLE runtime_recovery SCHEMAFULL PERMISSIONS NONE;
DEFINE FIELD run ON TABLE runtime_recovery TYPE record<runtime_run>;
DEFINE FIELD recovery_type ON TABLE runtime_recovery TYPE string ASSERT $value IN ["retry", "resume", "rollback", "reactivate", "manual_review"];
DEFINE FIELD reason ON TABLE runtime_recovery TYPE string;
DEFINE FIELD status ON TABLE runtime_recovery TYPE string DEFAULT "requested" ASSERT $value IN ["requested", "approved", "running", "completed", "failed", "rejected"];
DEFINE FIELD requested_by ON TABLE runtime_recovery TYPE string;
DEFINE FIELD requested_at ON TABLE runtime_recovery TYPE datetime DEFAULT time::now();
DEFINE FIELD completed_at ON TABLE runtime_recovery TYPE option<datetime>;
DEFINE INDEX runtime_recovery_run_idx ON TABLE runtime_recovery COLUMNS run;
DEFINE INDEX runtime_recovery_status_idx ON TABLE runtime_recovery COLUMNS status;

DEFINE TABLE runtime_access_decision SCHEMAFULL PERMISSIONS NONE;
DEFINE FIELD run ON TABLE runtime_access_decision TYPE record<runtime_run>;
DEFINE FIELD resource_type ON TABLE runtime_access_decision TYPE string ASSERT $value IN ["tool", "secret", "model", "network", "filesystem", "external_action"];
DEFINE FIELD resource_ref ON TABLE runtime_access_decision TYPE string;
DEFINE FIELD action ON TABLE runtime_access_decision TYPE string;
DEFINE FIELD decision ON TABLE runtime_access_decision TYPE string ASSERT $value IN ["allow", "deny", "require_approval"];
DEFINE FIELD reason ON TABLE runtime_access_decision TYPE option<string>;
DEFINE FIELD policy ON TABLE runtime_access_decision TYPE option<record<runtime_policy>>;
DEFINE FIELD decided_at ON TABLE runtime_access_decision TYPE datetime DEFAULT time::now();
DEFINE INDEX runtime_access_decision_run_idx ON TABLE runtime_access_decision COLUMNS run;
DEFINE INDEX runtime_access_decision_resource_idx ON TABLE runtime_access_decision COLUMNS resource_type, resource_ref;

DEFINE TABLE runtime_audit_event SCHEMAFULL PERMISSIONS NONE;
DEFINE FIELD run ON TABLE runtime_audit_event TYPE option<record<runtime_run>>;
DEFINE FIELD agent_identity ON TABLE runtime_audit_event TYPE option<record<agent_identity>>;
DEFINE FIELD event_type ON TABLE runtime_audit_event TYPE string;
DEFINE FIELD actor ON TABLE runtime_audit_event TYPE string DEFAULT "runtime";
DEFINE FIELD message ON TABLE runtime_audit_event TYPE string;
DEFINE FIELD data ON TABLE runtime_audit_event TYPE object DEFAULT {};
DEFINE FIELD created_at ON TABLE runtime_audit_event TYPE datetime DEFAULT time::now();
DEFINE INDEX runtime_audit_event_run_idx ON TABLE runtime_audit_event COLUMNS run;
DEFINE INDEX runtime_audit_event_agent_idx ON TABLE runtime_audit_event COLUMNS agent_identity;
DEFINE INDEX runtime_audit_event_type_idx ON TABLE runtime_audit_event COLUMNS event_type;
