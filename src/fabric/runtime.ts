import type {
  FabricContract,
  FabricEvent,
  FabricRuntimeInput,
  FabricRuntimeResult,
  PolicyDecision,
  ToolRequest,
} from "./types.js";

function iso(now?: Date): string {
  return (now ?? new Date()).toISOString();
}

function event<T extends Record<string, unknown>>(
  type: string,
  source: string,
  subject: string,
  data: T,
  now?: Date,
): FabricEvent<T> {
  return {
    specversion: "1.0",
    id: `${type}:${subject}:${iso(now)}`,
    type,
    source,
    subject,
    time: iso(now),
    datacontenttype: "application/json",
    data,
  };
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

export function runFabric(input: FabricRuntimeInput): FabricRuntimeResult {
  const decision = evaluatePolicy(input);
  const base = {
    runId: input.runId,
    agent: input.agent,
    declared: {
      action: input.toolRequest.action,
      resourceId: input.toolRequest.resourceId,
      toolId: input.toolRequest.toolId,
    },
    observed: {},
    drift: [] as string[],
    events: [] as FabricEvent[],
    policyDecisions: [decision],
    evidence: [] as FabricEvent[],
  };

  const requested = event(
    "fabric.tool.requested",
    "agennext.agent-runtime",
    input.runId,
    { agentId: input.agent.id, request: input.toolRequest },
    input.now,
  );

  const policyEvaluated = event(
    "fabric.policy.evaluated",
    "agennext.agent-runtime",
    input.runId,
    { decision },
    input.now,
  );

  if (decision.result === "deny") {
    const denied = event(
      "fabric.tool.denied",
      "agennext.agent-runtime",
      input.runId,
      { reason: decision.reason },
      input.now,
    );
    return {
      allowed: false,
      decision,
      state: {
        ...base,
        status: "contained",
        observed: { contained: true, executed: false },
        drift: ["requested action was denied and contained"],
        events: [requested, policyEvaluated, denied],
        evidence: [requested, policyEvaluated, denied],
      },
    };
  }

  if (decision.result === "require_approval") {
    const approval = event(
      "fabric.approval.required",
      "agennext.agent-runtime",
      input.runId,
      { reason: decision.reason },
      input.now,
    );
    return {
      allowed: false,
      decision,
      state: {
        ...base,
        status: "approval_pending",
        observed: { approvalRequired: true, executed: false },
        drift: ["execution pending approval"],
        events: [requested, policyEvaluated, approval],
        evidence: [requested, policyEvaluated, approval],
      },
    };
  }

  const executed = event(
    "fabric.tool.executed",
    "agennext.agent-runtime",
    input.runId,
    { toolId: input.toolRequest.toolId, action: input.toolRequest.action },
    input.now,
  );
  const reconciled = event(
    "fabric.reconciliation.completed",
    "agennext.agent-runtime",
    input.runId,
    { status: "reconciled" },
    input.now,
  );

  return {
    allowed: true,
    decision,
    state: {
      ...base,
      status: "reconciled",
      observed: { executed: true, reconciled: true },
      drift: [],
      events: [requested, policyEvaluated, executed, reconciled],
      evidence: [requested, policyEvaluated, executed, reconciled],
    },
  };
}
