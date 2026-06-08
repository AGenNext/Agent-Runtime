import assert from "node:assert/strict";
import test from "node:test";
import { evaluateMCPToolRequest, type MCPToolPolicy, type MCPToolRequest } from "../src/index.js";

const policy: MCPToolPolicy = {
  id: "mcp-policy:demo:file-reader",
  serverId: "mcp:server:tools",
  toolName: "file_reader",
  tenantId: "tenant:demo",
  allowedActions: ["read", "list"],
  readOnly: true,
};

const request: MCPToolRequest = {
  id: "mcp-request:allow",
  serverId: "mcp:server:tools",
  toolName: "file_reader",
  tenantId: "tenant:demo",
  action: "read",
  mutatesState: false,
};

test("MCP bridge allows request that satisfies tool policy", () => {
  const result = evaluateMCPToolRequest(policy, request);

  assert.equal(result.decision, "allow");
  assert.deepEqual(result.reasons, ["request satisfies MCP tool policy"]);
  assert.equal(result.evidence.policyId, policy.id);
});

test("MCP bridge denies server mismatch", () => {
  const result = evaluateMCPToolRequest(policy, { ...request, id: "mcp-request:server-mismatch", serverId: "mcp:server:other" });

  assert.equal(result.decision, "deny");
  assert.ok(result.reasons.includes("server mismatch"));
});

test("MCP bridge denies tenant mismatch", () => {
  const result = evaluateMCPToolRequest(policy, { ...request, id: "mcp-request:tenant-mismatch", tenantId: "tenant:other" });

  assert.equal(result.decision, "deny");
  assert.ok(result.reasons.includes("tenant mismatch"));
});

test("MCP bridge denies unallowed action", () => {
  const result = evaluateMCPToolRequest(policy, { ...request, id: "mcp-request:delete", action: "delete" });

  assert.equal(result.decision, "deny");
  assert.ok(result.reasons.includes("action not allowed"));
});

test("MCP bridge denies mutation under read-only policy", () => {
  const result = evaluateMCPToolRequest(policy, { ...request, id: "mcp-request:mutate", mutatesState: true });

  assert.equal(result.decision, "deny");
  assert.ok(result.reasons.includes("read-only policy cannot mutate state"));
});

test("MCP bridge observes when approval is required", () => {
  const result = evaluateMCPToolRequest({ ...policy, id: "mcp-policy:approval", readOnly: false, requiresApproval: true }, { ...request, id: "mcp-request:approval" });

  assert.equal(result.decision, "observe");
  assert.deepEqual(result.reasons, ["approval required before MCP tool execution"]);
});
