from surrealdb import Surreal

from .config import settings


class RuntimeDB:
    def __init__(self) -> None:
        self.client = Surreal(settings.surrealdb_url)

    async def connect(self) -> None:
        await self.client.connect()
        await self.client.signin({
            "user": settings.surrealdb_user,
            "pass": settings.surrealdb_pass
        })
        await self.client.use(
            settings.surrealdb_namespace,
            settings.surrealdb_database
        )

    async def create_identity(self, payload: dict) -> object:
        return await self.client.query(
            "RETURN fn::runtime::auth::identity::create($payload);",
            {"payload": payload}
        )

    async def get_identity_by_email(self, email: str) -> object:
        return await self.client.query(
            "SELECT * FROM auth_identity WHERE email = $email LIMIT 1;",
            {"email": email}
        )

    async def get_identity_by_id(self, identity_id: str) -> object:
        return await self.client.query(
            "SELECT * FROM ONLY type::record('auth_identity', $identity_id);",
            {"identity_id": identity_id}
        )

    async def touch_identity_login(self, identity_id: str) -> object:
        return await self.client.query(
            "UPDATE ONLY type::record('auth_identity', $identity_id) SET last_login_at = time::now(), updated_at = time::now();",
            {"identity_id": identity_id}
        )

    async def freeze_identity(self, identity_id: str, reason: str | None) -> object:
        return await self.client.query(
            "RETURN fn::runtime::auth::identity::freeze($identity_id, $reason);",
            {"identity_id": identity_id, "reason": reason}
        )

    async def create_session(self, payload: dict) -> object:
        return await self.client.query(
            "RETURN fn::runtime::auth::session::create($payload);",
            {"payload": payload}
        )

    async def get_session_by_id(self, session_id: str) -> object:
        return await self.client.query(
            "SELECT * FROM ONLY type::record('auth_session', $session_id);",
            {"session_id": session_id}
        )

    async def get_session_by_refresh_hash(self, refresh_token_hash: str) -> object:
        return await self.client.query(
            "SELECT * FROM auth_session WHERE refresh_token_hash = $refresh_token_hash LIMIT 1;",
            {"refresh_token_hash": refresh_token_hash}
        )

    async def revoke_session(self, session_id: str, reason: str | None) -> object:
        return await self.client.query(
            "RETURN fn::runtime::auth::session::revoke($session_id, $reason);",
            {"session_id": session_id, "reason": reason}
        )

    async def create_magic_link(self, payload: dict) -> object:
        return await self.client.query(
            "RETURN fn::runtime::auth::magic_link::create($payload);",
            {"payload": payload}
        )

    async def get_validation_reports(self, target_ref: str) -> object:
        return await self.client.query(
            "SELECT * FROM auth_validation_report WHERE target_ref = $target_ref ORDER BY checked_at DESC;",
            {"target_ref": target_ref}
        )


runtime_db = RuntimeDB()
