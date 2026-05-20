from agent_eval.standard_evaluator import StandardEvaluator
from agent_handoff.capability_validator import CapabilityValidator
from agent_handoff.validator import HandoffValidator


class RuntimeHandoffGate:
    def __init__(
        self,
        standard: dict,
        available_skills: list[str],
        available_tools: list[str],
    ):
        self.evaluator = StandardEvaluator(standard)
        self.capability_validator = CapabilityValidator(
            available_skills=available_skills,
            available_tools=available_tools,
        )

    def validate_handoff(self, handoff, work_payload: dict):
        HandoffValidator.validate_complete(handoff)

        self.capability_validator.validate(handoff)

        evaluation = self.evaluator.evaluate(work_payload)

        if not evaluation.passed:
            raise ValueError(
                f"Pre-handoff evaluation failed: {evaluation.rejection_reasons}"
            )

        return evaluation
