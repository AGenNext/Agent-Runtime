from surrealdb import Surreal


class SurrealRuntimeStore:
    def __init__(self, url: str, namespace: str, database: str):
        self.url = url
        self.namespace = namespace
        self.database = database
        self.client = Surreal(self.url)

    async def connect(self):
        await self.client.connect()
        await self.client.use(self.namespace, self.database)

    async def write_workflow_run(self, workflow_id: str, state: dict):
        return await self.client.create(
            f"workflow_run:{workflow_id}",
            state,
        )

    async def update_workflow_run(self, workflow_id: str, state: dict):
        return await self.client.merge(
            f"workflow_run:{workflow_id}",
            state,
        )

    async def write_action_event(self, action_id: str, payload: dict):
        return await self.client.create(
            f"action_log:{action_id}",
            payload,
        )
