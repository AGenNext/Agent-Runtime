export type PolicyDecisionResult = "allow" | "deny" | "require_approval" | "escalate";

export type ReconciliationStatus =
  | "declared"
  | "observing"
  | "policy_pending"
  | "approval_pending"
  | "executing"
  | "verifying"
  | "reconciled"
  | "denied"
  | "contained"
  | "failed";

export interface FabricIdentity {
  id: string;
  type: "agent" | "tool" | "run" | "contract" | "policy" | "tenant" | "profile";
  namespace: string;
  owner: string;
  version: string;
}

export interface FabricContract {
  id: string;
  subjectId: string;
  action: string;
  resourceId: string;
  allowedTools: string[];
  requiresApproval?: boolean;
}

export interface PolicyDecision {
  id: string;
  subjectId: string;
  action: string;
  resourceId: string;
  result: PolicyDecisionResult;
  reason: string;
  timestamp: string;
}

export interface ToolRequest {
  id: string;
  toolId: string;
  action: string;
  resourceId: string;
  input?: Record<string, unknown>;
}

export interface FabricEvent<T = Record<string, unknown>> {
  specversion: "1.0";
  id: string;
  type: string;
  source: string;
  subject: string;
  time: string;
  datacontenttype: "application/json";
  data: T;
}

export interface FabricRunState {
  runId: string;
  agent: FabricIdentity;
  status: ReconciliationStatus;
  declared: Record<string, unknown>;
  observed: Record<string, unknown>;
  drift: string[];
  events: FabricEvent[];
  policyDecisions: PolicyDecision[];
  evidence: FabricEvent[];
}

export interface FabricRuntimeInput {
  runId: string;
  agent: FabricIdentity;
  contract?: FabricContract;
  toolRequest: ToolRequest;
  now?: Date;
}

export interface FabricRuntimeResult {
  state: FabricRunState;
  decision: PolicyDecision;
  allowed: boolean;
}
