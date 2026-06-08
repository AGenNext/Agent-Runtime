export type TrustStatus = "trusted" | "probation" | "contained";

export interface TrustState {
  subjectId: string;
  score: number;
  threshold: number;
  status: TrustStatus;
  reasons: string[];
}

export interface TrustInput {
  subjectId: string;
  score: number;
  threshold?: number;
  evidence?: string[];
}

export function evaluateTrust(input: TrustInput): TrustState {
  const threshold = input.threshold ?? 0.7;
  const reasons = [...(input.evidence ?? [])];

  if (input.score < 0 || input.score > 1) {
    throw new Error("Trust score must be between 0 and 1.");
  }

  if (input.score < threshold) {
    return {
      subjectId: input.subjectId,
      score: input.score,
      threshold,
      status: "contained",
      reasons: reasons.length > 0 ? reasons : ["trust score below threshold"],
    };
  }

  if (input.score < Math.min(1, threshold + 0.15)) {
    return {
      subjectId: input.subjectId,
      score: input.score,
      threshold,
      status: "probation",
      reasons: reasons.length > 0 ? reasons : ["trust score near threshold"],
    };
  }

  return {
    subjectId: input.subjectId,
    score: input.score,
    threshold,
    status: "trusted",
    reasons: reasons.length > 0 ? reasons : ["trust score meets threshold"],
  };
}

export function mustContainTrust(state: TrustState): boolean {
  return state.status === "contained";
}
