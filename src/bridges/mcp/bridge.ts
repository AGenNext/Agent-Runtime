import type { MCPBridgeResult, MCPToolPolicy, MCPToolRequest } from "./types.js";

export function evaluateMCPToolRequest(policy: MCPToolPolicy, request: MCPToolRequest): MCPBridgeResult {
  const reasons: string[] = [];

  if (policy.serverId !== request.serverId) {
    reasons.push("server mismatch");
  }

  if (policy.toolName !== request.toolName) {
    reasons.push("tool mismatch");
  }

  if (policy.tenantId !== request.tenantId) {
    reasons.push("tenant mismatch");
  }

  if (!policy.allowedActions.includes(request.action)) {
    reasons.push("action not allowed");
  }

  if (policy.readOnly && request.mutatesState) {
    reasons.push("read-only policy cannot mutate state");
  }

  if (reasons.length > 0) {
    return {
      requestId: request.id,
      decision: "deny",
      reasons,
      evidence: {
        policyId: policy.id,
        serverId: policy.serverId,
        toolName: policy.toolName,
        tenantId: policy.tenantId,
      },
    };
  }

  if (policy.requiresApproval) {
    return {
      requestId: request.id,
      decision: "observe",
      reasons: ["approval required before MCP tool execution"],
      evidence: {
        policyId: policy.id,
        serverId: policy.serverId,
        toolName: policy.toolName,
        tenantId: policy.tenantId,
      },
    };
  }

  return {
    requestId: request.id,
    decision: "allow",
    reasons: ["request satisfies MCP tool policy"],
    evidence: {
      policyId: policy.id,
      serverId: policy.serverId,
      toolName: policy.toolName,
      tenantId: policy.tenantId,
    },
  };
}
