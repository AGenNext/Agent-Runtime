import type { FabricEvent, FabricRunState, PolicyDecision } from "../../fabric/types.js";
import type { FabricRunStore } from "../../fabric/store.js";

export interface SurrealQueryClient {
  query<T = unknown>(sql: string, vars?: Record<string, unknown>): Promise<T>;
}

export class SurrealDBFabricRunStore implements FabricRunStore {
  constructor(private readonly client: SurrealQueryClient) {}

  async saveRun(state: FabricRunState): Promise<void> {
    await this.client.query(
      `UPSERT fabric_run:⟨$runId⟩ CONTENT {
        runId: $runId,
        agent: $agent,
        status: $status,
        declared: $declared,
        observed: $observed,
        drift: $drift,
        events: $events,
        policyDecisions: $policyDecisions,
        evidence: $evidence,
        updatedAt: time::now()
      }`,
      { ...state },
    );
  }

  async getRun(runId: string): Promise<FabricRunState | undefined> {
    const result = await this.client.query<FabricRunState[]>(
      "SELECT * FROM fabric_run WHERE runId = $runId LIMIT 1",
      { runId },
    );
    return result[0];
  }

  async listRuns(): Promise<FabricRunState[]> {
    return this.client.query<FabricRunState[]>("SELECT * FROM fabric_run ORDER BY updatedAt DESC");
  }

  async appendEvent(runId: string, event: FabricEvent): Promise<void> {
    await this.client.query(
      `CREATE fabric_event CONTENT {
        runId: $runId,
        event: $event,
        eventType: $eventType,
        subject: $subject,
        emittedAt: <datetime>$emittedAt
      }`,
      { runId, event, eventType: event.type, subject: event.subject, emittedAt: event.time },
    );

    const state = await this.getRun(runId);
    if (!state) throw new Error(`Cannot append event. Unknown run: ${runId}`);
    state.events.push(event);
    state.evidence.push(event);
    await this.saveRun(state);
  }

  async appendDecision(runId: string, decision: PolicyDecision): Promise<void> {
    await this.client.query(
      `CREATE fabric_policy_decision CONTENT {
        runId: $runId,
        decision: $decision,
        result: $result,
        subjectId: $subjectId,
        action: $action,
        resourceId: $resourceId,
        decidedAt: <datetime>$decidedAt
      }`,
      {
        runId,
        decision,
        result: decision.result,
        subjectId: decision.subjectId,
        action: decision.action,
        resourceId: decision.resourceId,
        decidedAt: decision.timestamp,
      },
    );

    const state = await this.getRun(runId);
    if (!state) throw new Error(`Cannot append decision. Unknown run: ${runId}`);
    state.policyDecisions.push(decision);
    await this.saveRun(state);
  }
}
