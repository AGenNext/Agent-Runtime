-- AGenNext Agent Runtime
-- Workflow execution state and action event log.
-- Populated by the LangGraph adapter via SurrealRuntimeStore.

DEFINE TABLE workflow_run SCHEMAFULL PERMISSIONS NONE;
DEFINE FIELD plan_id ON TABLE workflow_run TYPE string ASSERT string::len($value) > 0;
DEFINE FIELD runtime_profile ON TABLE workflow_run TYPE string DEFAULT "k8smicro";
DEFINE FIELD actor_did ON TABLE workflow_run TYPE string;
DEFINE FIELD tenant_id ON TABLE workflow_run TYPE string DEFAULT "default";
DEFINE FIELD environment ON TABLE workflow_run TYPE string DEFAULT "dev";
DEFINE FIELD status ON TABLE workflow_run TYPE string DEFAULT "running" ASSERT $value IN ["running", "completed", "failed"];
DEFINE FIELD node_count ON TABLE workflow_run TYPE int DEFAULT 0;
DEFINE FIELD completed_nodes ON TABLE workflow_run TYPE option<array>;
DEFINE FIELD started_at ON TABLE workflow_run TYPE option<string>;
DEFINE FIELD completed_at ON TABLE workflow_run TYPE option<string>;
DEFINE INDEX workflow_run_plan_idx ON TABLE workflow_run COLUMNS plan_id;
DEFINE INDEX workflow_run_status_idx ON TABLE workflow_run COLUMNS status;
DEFINE INDEX workflow_run_actor_idx ON TABLE workflow_run COLUMNS actor_did;

DEFINE TABLE action_log SCHEMAFULL PERMISSIONS NONE;
DEFINE FIELD run_id ON TABLE action_log TYPE string ASSERT string::len($value) > 0;
DEFINE FIELD node_id ON TABLE action_log TYPE option<string>;
DEFINE FIELD action ON TABLE action_log TYPE option<string>;
DEFINE FIELD event_type ON TABLE action_log TYPE string ASSERT $value IN ["node_running", "node_completed", "node_failed", "run_failed"];
DEFINE FIELD error ON TABLE action_log TYPE option<string>;
DEFINE FIELD timestamp ON TABLE action_log TYPE string;
DEFINE INDEX action_log_run_idx ON TABLE action_log COLUMNS run_id;
DEFINE INDEX action_log_event_idx ON TABLE action_log COLUMNS event_type;
DEFINE INDEX action_log_node_idx ON TABLE action_log COLUMNS run_id, node_id;
