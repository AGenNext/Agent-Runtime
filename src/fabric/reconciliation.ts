export type ReconciliationOutcome = "in_sync" | "drift_detected" | "reconciled" | "failed";

export interface ReconciliationInput {
  declared: Record<string, unknown>;
  observed: Record<string, unknown>;
  requiredKeys?: string[];
}

export interface ReconciliationResult {
  outcome: ReconciliationOutcome;
  drift: string[];
  stable: boolean;
}

export function detectDrift(input: ReconciliationInput): string[] {
  const keys = input.requiredKeys ?? Array.from(new Set([...Object.keys(input.declared), ...Object.keys(input.observed)]));
  const drift: string[] = [];

  for (const key of keys) {
    const declaredValue = input.declared[key];
    const observedValue = input.observed[key];
    if (JSON.stringify(declaredValue) !== JSON.stringify(observedValue)) {
      drift.push(key);
    }
  }

  return drift;
}

export function reconcile(input: ReconciliationInput): ReconciliationResult {
  const drift = detectDrift(input);

  if (drift.length === 0) {
    return {
      outcome: "in_sync",
      drift,
      stable: true,
    };
  }

  return {
    outcome: "drift_detected",
    drift,
    stable: false,
  };
}

export function proveStableState(input: ReconciliationInput): ReconciliationResult {
  const result = reconcile(input);
  if (result.stable) return { ...result, outcome: "reconciled" };
  return result;
}
