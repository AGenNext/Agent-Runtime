export type K8sGPTBridgeDecision = "allow" | "deny" | "observe";

export type K8sGPTAnalyzer =
  | "pod"
  | "service"
  | "deployment"
  | "statefulset"
  | "ingress"
  | "pvc"
  | "job"
  | "cronjob"
  | "networkpolicy"
  | "node"
  | "security";

export interface K8sGPTBridgePolicy {
  id: string;
  clusterId: string;
  tenantId: string;
  namespace: string;
  allowedAnalyzers: K8sGPTAnalyzer[];
  readOnly: boolean;
  requiresApproval?: boolean;
}

export interface K8sGPTAnalyzeRequest {
  id: string;
  clusterId: string;
  tenantId: string;
  namespace: string;
  analyzer: K8sGPTAnalyzer;
  explain?: boolean;
  mutatesState?: boolean;
}

export interface K8sGPTBridgeResult {
  requestId: string;
  decision: K8sGPTBridgeDecision;
  reasons: string[];
  evidence: Record<string, unknown>;
}
