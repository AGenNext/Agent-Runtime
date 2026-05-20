from pydantic import Field
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    surrealdb_url: str = Field(default="ws://localhost:8000/rpc", alias="SURREALDB_URL")
    surrealdb_namespace: str = Field(default="agennext", alias="SURREALDB_NAMESPACE")
    surrealdb_database: str = Field(default="runtime", alias="SURREALDB_DATABASE")
    surrealdb_user: str = Field(default="root", alias="SURREALDB_USER")
    surrealdb_pass: str = Field(default="root", alias="SURREALDB_PASS")

    jwt_secret: str = Field(default="CHANGE_ME", alias="AGENT_AUTH_JWT_SECRET")
    jwt_algorithm: str = Field(default="HS256", alias="AGENT_AUTH_JWT_ALGORITHM")
    jwt_expires_minutes: int = Field(default=60, alias="AGENT_AUTH_JWT_EXPIRES_MINUTES")


settings = Settings()
