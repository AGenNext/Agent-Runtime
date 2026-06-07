import assert from "node:assert/strict";
import test from "node:test";
import { runFabric, type FabricContract, type FabricIdentity, type ToolRequest } from "../src/index.js";

const agent: FabricIdentity = {
  id: "agent:ops:001",
  type: "agent",
  namespace: "tenant:demo",
  owner: "AGenNext",
  version: "1.0.0",
};

const request: ToolRequest = {
  id: "tool-request:001",
  toolId: "tool:k8s:restart-workload",
  action: "restart",
  resourceId: "workload:demo-api",
  input: { namespace: "demo", workload: "demo-api" },
};

const contract: FabricContract = {
  id: "contract:runtime:001",
  subjectId: agent.id,
  action: request.action,
  resourceId: request.resourceId,
  allowedTools: [request.toolId],
};

test("valid contract allows tool execution and reconciles stable state", () => {
  const result = runFabric({ runId: "run:allow", agent, contract, toolRequest: request, now: new Date("2026-01-01T00:00:00.000Z") });

  assert.equal(result.allowed, true);
  assert.equal(result.decision.result, "allow");
  assert.equal(result.state.status, "reconciled");
  assert.deepEqual(result.state.drift, []);
  assert.equal(result.state.observed.executed, true);
  assert.equal(result.state.observed.reconciled, true);
  assert.deepEqual(result.state.events.map((event) => event.type), [
    "fabric.tool.requested",
    "fabric.policy.evaluated",
    "fabric.tool.executed",
    "fabric.reconciliation.completed",
  ]);
});

test("missing contract denies action and contains the run", () => {
  const result = runFabric({ runId: "run:deny", agent, toolRequest: request, now: new Date("2026-01-01T00:00:00.000Z") });

  assert.equal(result.allowed, false);
  assert.equal(result.decision.result, "deny");
  assert.equal(result.state.status, "contained");
  assert.equal(result.state.observed.executed, false);
  assert.equal(result.state.observed.contained, true);
  assert.ok(result.state.drift.includes("requested action was denied and contained"));
  assert.deepEqual(result.state.events.map((event) => event.type), [
    "fabric.tool.requested",
    "fabric.policy.evaluated",
    "fabric.tool.denied",
  ]);
});

test("approval-required contract pauses execution without tool run", () => {
  const approvalContract: FabricContract = { ...contract, id: "contract:runtime:approval", requiresApproval: true };
  const result = runFabric({ runId: "run:approval", agent, contract: approvalContract, toolRequest: request, now: new Date("2026-01-01T00:00:00.000Z") });

  assert.equal(result.allowed, false);
  assert.equal(result.decision.result, "require_approval");
  assert.equal(result.state.status, "approval_pending");
  assert.equal(result.state.observed.executed, false);
  assert.equal(result.state.observed.approvalRequired, true);
  assert.ok(result.state.drift.includes("execution pending approval"));
  assert.deepEqual(result.state.events.map((event) => event.type), [
    "fabric.tool.requested",
    "fabric.policy.evaluated",
    "fabric.approval.required",
  ]);
});
