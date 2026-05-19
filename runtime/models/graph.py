from typing import Any
from pydantic import BaseModel, Field


class GraphNode(BaseModel):
    id: str
    action: str
    input: dict[str, Any] = Field(default_factory=dict)


class GraphEdge(BaseModel):
    from_node: str
    to_node: str


class AgentGraphPlan(BaseModel):
    id: str
    runtime_profile: str = "k8smicro"
    nodes: list[GraphNode]
    edges: list[GraphEdge]
