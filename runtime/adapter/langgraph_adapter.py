from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Annotated, Any

from typing_extensions import TypedDict

from langgraph.graph import END, START, StateGraph

from runtime.adapter.base import FrameworkAdapter
from runtime.models.graph import AgentGraphPlan
from runtime.models.run import AdapterInput, AdapterOutput
from runtime.state.surreal import SurrealRuntimeStore


def _merge(existing: dict, update: dict) -> dict:
    return {**existing, **update}


class WorkflowState(TypedDict):
    node_states: Annotated[dict[str, dict], _merge]
    results: Annotated[dict[str, Any], _merge]
    errors: Annotated[dict[str, str], _merge]


class LangGraphAdapter(FrameworkAdapter):
    def __init__(self, store: SurrealRuntimeStore) -> None:
        self._store = store

    async def execute(self, adapter_input: AdapterInput) -> AdapterOutput:
        plan = adapter_input.plan
        ctx = adapter_input.execution_context
        run_id = f"{plan.id}_{uuid.uuid4().hex[:8]}"

        await self._store.connect()
        await self._store.write_workflow_run(run_id, {
            "plan_id": plan.id,
            "runtime_profile": plan.runtime_profile,
            "actor_did": ctx.actor_did,
            "tenant_id": ctx.tenant_id,
            "environment": ctx.environment,
            "status": "running",
            "node_count": len(plan.nodes),
            "started_at": _now(),
        })

        graph = self._build_graph(plan, run_id)
        initial_state: WorkflowState = {
            "node_states": {n.id: {"status": "pending"} for n in plan.nodes},
            "results": {},
            "errors": {},
        }

        try:
            final_state = await graph.ainvoke(initial_state)
        except Exception as exc:
            await self._store.write_action_event(f"{run_id}_run_error", {
                "run_id": run_id,
                "event_type": "run_failed",
                "error": str(exc),
                "timestamp": _now(),
            })
            await self._store.update_workflow_run(run_id, {
                "status": "failed",
                "completed_at": _now(),
            })
            return AdapterOutput(run_id=run_id, status="failed", errors={"_run": str(exc)})

        completed = [
            nid
            for nid, ns in final_state["node_states"].items()
            if ns.get("status") == "completed"
        ]
        has_failures = any(
            ns.get("status") == "failed"
            for ns in final_state["node_states"].values()
        )
        status = "failed" if has_failures else "completed"

        await self._store.update_workflow_run(run_id, {
            "status": status,
            "completed_at": _now(),
            "completed_nodes": completed,
        })

        return AdapterOutput(
            run_id=run_id,
            status=status,
            completed=completed,
            results=final_state["results"],
            errors=final_state["errors"],
        )

    def _build_graph(self, plan: AgentGraphPlan, run_id: str) -> StateGraph:
        builder = StateGraph(WorkflowState)

        for node in plan.nodes:
            builder.add_node(
                node.id,
                self._make_node_fn(node.id, node.action, node.input, run_id),
            )

        targets = {e.to_node for e in plan.edges}
        for node in plan.nodes:
            if node.id not in targets:
                builder.add_edge(START, node.id)

        for edge in plan.edges:
            builder.add_edge(edge.from_node, edge.to_node)

        sources = {e.from_node for e in plan.edges}
        for node in plan.nodes:
            if node.id not in sources:
                builder.add_edge(node.id, END)

        return builder.compile()

    def _make_node_fn(self, node_id: str, action: str, node_input: dict, run_id: str):
        store = self._store

        async def _node(state: WorkflowState) -> dict:
            started_at = _now()
            await store.write_action_event(f"{run_id}_{node_id}_start", {
                "run_id": run_id,
                "node_id": node_id,
                "action": action,
                "event_type": "node_running",
                "timestamp": started_at,
            })

            try:
                result = await _dispatch_action(action, node_input)
                completed_at = _now()
                await store.write_action_event(f"{run_id}_{node_id}_done", {
                    "run_id": run_id,
                    "node_id": node_id,
                    "action": action,
                    "event_type": "node_completed",
                    "timestamp": completed_at,
                })
                return {
                    "node_states": {
                        node_id: {
                            "status": "completed",
                            "started_at": started_at,
                            "completed_at": completed_at,
                        }
                    },
                    "results": {node_id: result},
                }
            except Exception as exc:
                failed_at = _now()
                await store.write_action_event(f"{run_id}_{node_id}_fail", {
                    "run_id": run_id,
                    "node_id": node_id,
                    "action": action,
                    "event_type": "node_failed",
                    "error": str(exc),
                    "timestamp": failed_at,
                })
                return {
                    "node_states": {
                        node_id: {
                            "status": "failed",
                            "started_at": started_at,
                            "failed_at": failed_at,
                            "error": str(exc),
                        }
                    },
                    "errors": {node_id: str(exc)},
                }

        return _node


async def _dispatch_action(action: str, node_input: dict) -> dict:
    # Dispatches to a registered action handler. Extend by registering handlers
    # keyed on action name (e.g. "identity.verify" → handler callable).
    return {"action": action, "input": node_input, "status": "executed"}


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()
