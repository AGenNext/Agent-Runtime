import type { FabricEvent, FabricRunState } from "./types.js";

export interface FabricReplayResult {
  runId: string;
  eventTypes: string[];
  executed: boolean;
  contained: boolean;
  approvalPending: boolean;
  reconciled: boolean;
  evidenceCount: number;
}

export function replayRun(state: FabricRunState): FabricReplayResult {
  const eventTypes = state.events.map((event) => event.type);

  return {
    runId: state.runId,
    eventTypes,
    executed: eventTypes.includes("fabric.tool.executed"),
    contained: eventTypes.includes("fabric.tool.denied") || state.status === "contained",
    approvalPending: eventTypes.includes("fabric.approval.required") || state.status === "approval_pending",
    reconciled: eventTypes.includes("fabric.reconciliation.completed") || state.status === "reconciled",
    evidenceCount: state.evidence.length,
  };
}

export function assertEventOrder(events: FabricEvent[], expected: string[]): void {
  const actual = events.map((event) => event.type);
  if (actual.join(" -> ") !== expected.join(" -> ")) {
    throw new Error(`Invalid event order. Expected ${expected.join(" -> ")}, got ${actual.join(" -> ")}`);
  }
}
