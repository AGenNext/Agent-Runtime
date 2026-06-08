import assert from "node:assert/strict";
import test from "node:test";
import {
  runFabricChain,
  runFabricLoop,
  type FabricChainStep,
  type FabricContract,
  type FabricIdentity,
  type ToolRequest,
} from "../src/index.js";

const agent: FabricIdentity = {
  id: "agent:ops:chain",
  type: "agent",
  namespace: "tenant:demo",
  owner: "AGenNext",
  version: "1.0.0",
};

function makeRequest(index: number): ToolRequest {
  return {
    id: `tool-request:chain:${index}`,
    toolId: "tool:k8s:restart-workload",
    action: "restart",
    resourceId: `workload:chain-api-${index}`,
  };
}

function makeContract(request: ToolRequest): FabricContract {
  return {
    id: `contract:chain:${request.id}`,
    subjectId: agent.id,
    action: request.action,
    resourceId: request.resourceId,
    allowedTools: [request.toolId],
  };
}

function makeStep(index: number): FabricChainStep {
  const request = makeRequest(index);
  return {
    stepId: `step:${index}`,
    runId: `run:chain:${index}`,
    agent,
    contract: makeContract(request),
    toolRequest: request,
    now: new Date("2026-01-01T00:00:00.000Z"),
  };
}

test("fabric chain completes when every step is allowed", () => {
  const result = runFabricChain("chain:allow", [makeStep(1), makeStep(2)]);

  assert.equal(result.completed, true);
  assert.equal(result.stoppedAt, undefined);
  assert.equal(result.results.length, 2);
  assert.ok(result.results.every((run) => run.allowed));
  assert.ok(result.results.every((run) => run.state.status === "reconciled"));
});

test("fabric chain stops at first denied step", () => {
  const deniedStep = makeStep(2);
  delete deniedStep.contract;

  const result = runFabricChain("chain:deny", [makeStep(1), deniedStep, makeStep(3)]);

  assert.equal(result.completed, false);
  assert.equal(result.stoppedAt, "step:2");
  assert.equal(result.results.length, 2);
  assert.equal(result.results[0]?.state.status, "reconciled");
  assert.equal(result.results[1]?.state.status, "contained");
});

test("fabric loop creates bounded repeated governed runs", () => {
  const result = runFabricLoop("loop:bounded", makeStep, 3);

  assert.equal(result.completed, true);
  assert.equal(result.results.length, 3);
  assert.deepEqual(
    result.results.map((run) => run.state.runId),
    ["run:chain:0", "run:chain:1", "run:chain:2"],
  );
});
