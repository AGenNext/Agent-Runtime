import assert from "node:assert/strict";
import test from "node:test";
import {
  InMemoryFabricRunStore,
  assertEventOrder,
  replayRun,
  runFabric,
  type FabricContract,
  type FabricIdentity,
  type ToolRequest,
} from "../src/index.js";

const agent: FabricIdentity = {
  id: "agent:ops:store",
  type: "agent",
  namespace: "tenant:demo",
  owner: "AGenNext",
  version: "1.0.0",
};

const request: ToolRequest = {
  id: "tool-request:store",
  toolId: "tool:k8s:restart-workload",
  action: "restart",
  resourceId: "workload:store-api",
};

const contract: FabricContract = {
  id: "contract:runtime:store",
  subjectId: agent.id,
  action: request.action,
  resourceId: request.resourceId,
  allowedTools: [request.toolId],
};

test("in-memory store persists and retrieves a reconciled run", async () => {
  const store = new InMemoryFabricRunStore();
  const result = runFabric({ runId: "run:store:allow", agent, contract, toolRequest: request, now: new Date("2026-01-01T00:00:00.000Z") });

  await store.saveRun(result.state);
  const restored = await store.getRun("run:store:allow");

  assert.ok(restored);
  assert.equal(restored.status, "reconciled");
  assert.equal(restored.events.length, 4);
  assert.equal(restored.evidence.length, 4);
});

test("replay reconstructs execution and reconciliation evidence", () => {
  const result = runFabric({ runId: "run:replay:allow", agent, contract, toolRequest: request, now: new Date("2026-01-01T00:00:00.000Z") });
  const replay = replayRun(result.state);

  assert.equal(replay.runId, "run:replay:allow");
  assert.equal(replay.executed, true);
  assert.equal(replay.reconciled, true);
  assert.equal(replay.contained, false);
  assert.equal(replay.approvalPending, false);
  assert.equal(replay.evidenceCount, 4);
});

test("event order assertion rejects invalid runtime evidence order", () => {
  const result = runFabric({ runId: "run:order:allow", agent, contract, toolRequest: request, now: new Date("2026-01-01T00:00:00.000Z") });

  assertEventOrder(result.state.events, [
    "fabric.tool.requested",
    "fabric.policy.evaluated",
    "fabric.tool.executed",
    "fabric.reconciliation.completed",
  ]);

  assert.throws(
    () =>
      assertEventOrder(result.state.events, [
        "fabric.reconciliation.completed",
        "fabric.tool.requested",
      ]),
    /Invalid event order/,
  );
});
