from abc import ABC, abstractmethod

from runtime.models.run import AdapterInput, AdapterOutput


class FrameworkAdapter(ABC):
    @abstractmethod
    async def execute(self, adapter_input: AdapterInput) -> AdapterOutput:
        ...
