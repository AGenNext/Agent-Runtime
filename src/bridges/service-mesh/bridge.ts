import type {
  ServiceMeshBridgeResult,
  ServiceMeshRequest,
  ServiceMeshRoutePolicy,
} from "./types.js";

export function evaluateServiceMeshRequest(
  policy: ServiceMeshRoutePolicy,
  request: ServiceMeshRequest,
): ServiceMeshBridgeResult {
  const reasons: string[] = [];

  if (policy.namespace !== request.namespace) {
    reasons.push("namespace mismatch");
  }

  if (policy.sourceService !== request.sourceService) {
    reasons.push("source service mismatch");
  }

  if (policy.destinationService !== request.destinationService) {
    reasons.push("destination service mismatch");
  }

  if (policy.mtlsRequired && !request.mtlsEnabled) {
    reasons.push("mTLS required but not enabled");
  }

  if (policy.telemetryRequired && !request.telemetryEnabled) {
    reasons.push("telemetry required but not enabled");
  }

  if (policy.allowedMethods && request.method && !policy.allowedMethods.includes(request.method)) {
    reasons.push("method not allowed");
  }

  if (reasons.length > 0) {
    return {
      requestId: request.id,
      decision: "deny",
      reasons,
      evidence: {
        provider: policy.provider,
        mode: policy.mode,
        policyId: policy.id,
      },
    };
  }

  if (!request.method) {
    return {
      requestId: request.id,
      decision: "observe",
      reasons: ["method not provided; route allowed for observation only"],
      evidence: {
        provider: policy.provider,
        mode: policy.mode,
        policyId: policy.id,
      },
    };
  }

  return {
    requestId: request.id,
    decision: "allow",
    reasons: ["request satisfies service mesh route policy"],
    evidence: {
      provider: policy.provider,
      mode: policy.mode,
      policyId: policy.id,
    },
  };
}
