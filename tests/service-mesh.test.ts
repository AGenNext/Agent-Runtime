import assert from "node:assert/strict";
import test from "node:test";
import { evaluateServiceMeshRequest, type ServiceMeshRequest, type ServiceMeshRoutePolicy } from "../src/index.js";

const policy: ServiceMeshRoutePolicy = {
  id: "mesh-policy:istio:demo",
  provider: "istio",
  mode: "ambient",
  sourceService: "frontend",
  destinationService: "api",
  namespace: "demo",
  mtlsRequired: true,
  telemetryRequired: true,
  allowedMethods: ["GET", "POST"],
};

const request: ServiceMeshRequest = {
  id: "mesh-request:allow",
  sourceService: "frontend",
  destinationService: "api",
  namespace: "demo",
  method: "GET",
  mtlsEnabled: true,
  telemetryEnabled: true,
};

test("service mesh bridge allows request that satisfies policy", () => {
  const result = evaluateServiceMeshRequest(policy, request);

  assert.equal(result.decision, "allow");
  assert.deepEqual(result.reasons, ["request satisfies service mesh route policy"]);
  assert.equal(result.evidence.provider, "istio");
  assert.equal(result.evidence.mode, "ambient");
});

test("service mesh bridge denies when mTLS is required but missing", () => {
  const result = evaluateServiceMeshRequest(policy, { ...request, id: "mesh-request:no-mtls", mtlsEnabled: false });

  assert.equal(result.decision, "deny");
  assert.ok(result.reasons.includes("mTLS required but not enabled"));
});

test("service mesh bridge denies when telemetry is required but missing", () => {
  const result = evaluateServiceMeshRequest(policy, { ...request, id: "mesh-request:no-telemetry", telemetryEnabled: false });

  assert.equal(result.decision, "deny");
  assert.ok(result.reasons.includes("telemetry required but not enabled"));
});

test("service mesh bridge denies namespace and method mismatch", () => {
  const result = evaluateServiceMeshRequest(policy, { ...request, id: "mesh-request:mismatch", namespace: "prod", method: "DELETE" });

  assert.equal(result.decision, "deny");
  assert.ok(result.reasons.includes("namespace mismatch"));
  assert.ok(result.reasons.includes("method not allowed"));
});

test("service mesh bridge observes when method is absent", () => {
  const { method: _method, ...withoutMethod } = request;
  const result = evaluateServiceMeshRequest(policy, { ...withoutMethod, id: "mesh-request:observe" });

  assert.equal(result.decision, "observe");
  assert.deepEqual(result.reasons, ["method not provided; route allowed for observation only"]);
});
