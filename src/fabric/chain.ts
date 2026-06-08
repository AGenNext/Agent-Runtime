import { runFabric } from "./runtime.js";
import type { FabricRuntimeInput, FabricRuntimeResult } from "./types.js";

export interface FabricChainStep extends FabricRuntimeInput {
  stepId: string;
}

export interface FabricChainResult {
  chainId: string;
  results: FabricRuntimeResult[];
  completed: boolean;
  stoppedAt?: string;
}

export function runFabricChain(chainId: string, steps: FabricChainStep[]): FabricChainResult {
  const results: FabricRuntimeResult[] = [];

  for (const step of steps) {
    const result = runFabric(step);
    results.push(result);

    if (!result.allowed) {
      return {
        chainId,
        results,
        completed: false,
        stoppedAt: step.stepId,
      };
    }
  }

  return {
    chainId,
    results,
    completed: true,
  };
}

export function runFabricLoop(
  chainId: string,
  makeStep: (iteration: number) => FabricChainStep,
  maxIterations: number,
): FabricChainResult {
  const steps: FabricChainStep[] = [];

  for (let iteration = 0; iteration < maxIterations; iteration += 1) {
    steps.push(makeStep(iteration));
  }

  return runFabricChain(chainId, steps);
}
