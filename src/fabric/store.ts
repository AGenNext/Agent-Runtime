import type { FabricEvent, FabricRunState, PolicyDecision } from "./types.js";

export interface FabricRunStore {
  saveRun(state: FabricRunState): Promise<void>;
  getRun(runId: string): Promise<FabricRunState | undefined>;
  listRuns(): Promise<FabricRunState[]>;
  appendEvent(runId: string, event: FabricEvent): Promise<void>;
  appendDecision(runId: string, decision: PolicyDecision): Promise<void>;
}

export class InMemoryFabricRunStore implements FabricRunStore {
  private readonly runs = new Map<string, FabricRunState>();

  async saveRun(state: FabricRunState): Promise<void> {
    this.runs.set(state.runId, structuredClone(state));
  }

  async getRun(runId: string): Promise<FabricRunState | undefined> {
    const state = this.runs.get(runId);
    return state ? structuredClone(state) : undefined;
  }

  async listRuns(): Promise<FabricRunState[]> {
    return Array.from(this.runs.values()).map((state) => structuredClone(state));
  }

  async appendEvent(runId: string, event: FabricEvent): Promise<void> {
    const state = this.runs.get(runId);
    if (!state) throw new Error(`Cannot append event. Unknown run: ${runId}`);
    state.events.push(structuredClone(event));
    state.evidence.push(structuredClone(event));
  }

  async appendDecision(runId: string, decision: PolicyDecision): Promise<void> {
    const state = this.runs.get(runId);
    if (!state) throw new Error(`Cannot append decision. Unknown run: ${runId}`);
    state.policyDecisions.push(structuredClone(decision));
  }
}
