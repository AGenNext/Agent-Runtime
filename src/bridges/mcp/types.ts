export type MCPBridgeDecision = "allow" | "deny" | "observe";

export interface MCPToolPolicy {
  id: string;
  serverId: string;
  toolName: string;
  tenantId: string;
  allowedActions: string[];
  requiresApproval?: boolean;
  readOnly?: boolean;
}

export interface MCPToolRequest {
  id: string;
  serverId: string;
  toolName: string;
  tenantId: string;
  action: string;
  input?: Record<string, unknown>;
  mutatesState?: boolean;
}

export interface MCPBridgeResult {
  requestId: string;
  decision: MCPBridgeDecision;
  reasons: string[];
  evidence: Record<string, unknown>;
}
