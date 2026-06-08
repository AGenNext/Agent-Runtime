export type InstallTarget = "local" | "k3s" | "kubernetes";
export type InstallStatus = "planned" | "installed" | "failed";
export type DeployStatus = "planned" | "deployed" | "failed";
export type ReconcileStatus = "in_sync" | "drift_detected" | "reconciled" | "failed";

export interface FabricInstallPlan {
  id: string;
  target: InstallTarget;
  namespace: string;
  components: string[];
}

export interface FabricInstallResult {
  planId: string;
  status: InstallStatus;
  appliedComponents: string[];
  reasons: string[];
}

export interface FabricDeployPlan {
  id: string;
  namespace: string;
  image: string;
  replicas: number;
  env?: Record<string, string>;
}

export interface FabricDeployResult {
  planId: string;
  status: DeployStatus;
  image: string;
  namespace: string;
  reasons: string[];
}

export interface FabricReconcilePlan {
  id: string;
  declared: Record<string, unknown>;
  observed: Record<string, unknown>;
}

export interface FabricReconcileResult {
  planId: string;
  status: ReconcileStatus;
  drift: string[];
  reasons: string[];
}

export function installFabric(plan: FabricInstallPlan): FabricInstallResult {
  if (plan.components.length === 0) {
    return {
      planId: plan.id,
      status: "failed",
      appliedComponents: [],
      reasons: ["no components declared for installation"],
    };
  }

  return {
    planId: plan.id,
    status: "installed",
    appliedComponents: plan.components,
    reasons: ["fabric install plan accepted"],
  };
}

export function deployFabric(plan: FabricDeployPlan): FabricDeployResult {
  if (!plan.image.includes(":")) {
    return {
      planId: plan.id,
      status: "failed",
      image: plan.image,
      namespace: plan.namespace,
      reasons: ["image must use an explicit tag"],
    };
  }

  if (plan.replicas < 1) {
    return {
      planId: plan.id,
      status: "failed",
      image: plan.image,
      namespace: plan.namespace,
      reasons: ["replicas must be at least 1"],
    };
  }

  return {
    planId: plan.id,
    status: "deployed",
    image: plan.image,
    namespace: plan.namespace,
    reasons: ["fabric deploy plan accepted"],
  };
}

export function reconcileFabric(plan: FabricReconcilePlan): FabricReconcileResult {
  const keys = Array.from(new Set([...Object.keys(plan.declared), ...Object.keys(plan.observed)]));
  const drift = keys.filter((key) => JSON.stringify(plan.declared[key]) !== JSON.stringify(plan.observed[key]));

  if (drift.length === 0) {
    return {
      planId: plan.id,
      status: "in_sync",
      drift,
      reasons: ["declared and observed state match"],
    };
  }

  return {
    planId: plan.id,
    status: "drift_detected",
    drift,
    reasons: ["declared and observed state differ"],
  };
}
