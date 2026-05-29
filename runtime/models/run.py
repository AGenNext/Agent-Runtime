from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field

from runtime.models.graph import AgentGraphPlan

NodeLifecycleState = Literal["pending", "running", "completed", "failed", "skipped"]


class ExecutionContext(BaseModel):
    actor_did: str
    tenant_id: str = "default"
    environment: str = "dev"


class AdapterInput(BaseModel):
    plan: AgentGraphPlan
    execution_context: ExecutionContext


class AdapterOutput(BaseModel):
    run_id: str
    status: str
    completed: list[str] = Field(default_factory=list)
    results: dict[str, Any] = Field(default_factory=dict)
    errors: dict[str, str] = Field(default_factory=dict)
