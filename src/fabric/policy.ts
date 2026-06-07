import type { FabricContract, FabricRuntimeInput, PolicyDecision, ToolRequest } from "./types.js";

function iso(now?: Date): string {
  return (now ?? new Date()).toISOString();
}

function isToolAllowed(contract: FabricContract | undefined, request: ToolRequest): boolean {
  if (!contract) return false;
  return (
    contract.action === request.action &&
    contract.resourceId === request.resourceId &&
    contract.allowedTools.includes(request.toolId)
  );
}

export function evaluatePolicy(input: FabricRuntimeInput): PolicyDecision {
  const now = iso(input.now);
  const contract = input.contract;
  const request = input.toolRequest;

  if (!contract) {
    return {
      id: `policy:${input.runId}:deny:no-contract`,
      subjectId: input.agent.id,
      action: request.action,
      resourceId: request.resourceId,
      result: "deny",
      reason: "No platform-held contract was provided for this run.",
      timestamp: now,
    };
  }

  if (contract.subjectId !== input.agent.id) {
    return {
      id: `policy:${input.runId}:deny:subject-mismatch`,
      subjectId: input.agent.id,
      action: request.action,
      resourceId: request.resourceId,
      result: "deny",
      reason: "Contract subject does not match agent identity.",
      timestamp: now,
    };
  }

  if (!isToolAllowed(contract, request)) {
    return {
      id: `policy:${input.runId}:deny:tool-or-action-not-allowed`,
      subjectId: input.agent.id,
      action: request.action,
      resourceId: request.resourceId,
      result: "deny",
      reason: "Tool, action, or resource is not allowed by the contract.",
      timestamp: now,
    };
  }

  if (contract.requiresApproval) {
    return {
      id: `policy:${input.runId}:approval-required`,
      subjectId: input.agent.id,
      action: request.action,
      resourceId: request.resourceId,
      result: "require_approval",
      reason: "Contract requires human approval before execution.",
      timestamp: now,
    };
  }

  return {
    id: `policy:${input.runId}:allow`,
    subjectId: input.agent.id,
    action: request.action,
    resourceId: request.resourceId,
    result: "allow",
    reason: "Contract allows this tool action on this resource.",
    timestamp: now,
  };
}
