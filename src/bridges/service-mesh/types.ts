export type ServiceMeshProvider = "istio" | "linkerd" | "cilium" | "other";

export type ServiceMeshMode = "sidecar" | "ambient" | "sidecarless";

export type ServiceMeshDecision = "allow" | "deny" | "observe";

export interface ServiceMeshRoutePolicy {
  id: string;
  provider: ServiceMeshProvider;
  mode: ServiceMeshMode;
  sourceService: string;
  destinationService: string;
  namespace: string;
  mtlsRequired: boolean;
  telemetryRequired: boolean;
  allowedMethods?: string[];
}

export interface ServiceMeshRequest {
  id: string;
  sourceService: string;
  destinationService: string;
  namespace: string;
  method?: string;
  mtlsEnabled: boolean;
  telemetryEnabled: boolean;
}

export interface ServiceMeshBridgeResult {
  requestId: string;
  decision: ServiceMeshDecision;
  reasons: string[];
  evidence: Record<string, unknown>;
}
