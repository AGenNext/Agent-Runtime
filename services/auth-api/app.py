from datetime import datetime, timedelta, UTC
from uuid import uuid4

from fastapi import FastAPI, HTTPException, Header
from pydantic import BaseModel, EmailStr
from jose import jwt
from passlib.context import CryptContext

from agent_auth_runtime.config import settings
from agent_auth_runtime.db import runtime_db

app = FastAPI(title="Agent-Auth Runtime API")

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


class SignupRequest(BaseModel):
    email: EmailStr
    password: str | None = None
    display_name: str | None = None


class LoginRequest(BaseModel):
    email: EmailStr
    password: str | None = None


class MagicLinkRequest(BaseModel):
    email: EmailStr
    purpose: str = "login"
    redirect_to: str | None = None


class FreezeRequest(BaseModel):
    reason: str | None = None


@app.on_event("startup")
async def startup() -> None:
    await runtime_db.connect()


def create_access_token(subject: str) -> str:
    expires = datetime.now(UTC) + timedelta(minutes=settings.jwt_expires_minutes)
    payload = {
        "sub": subject,
        "exp": expires
    }
    return jwt.encode(
        payload,
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm
    )


@app.get("/health")
async def health() -> dict:
    return {
        "ok": True,
        "service": "agent-auth-runtime"
    }


@app.post("/auth/signup")
async def signup(payload: SignupRequest) -> dict:
    identity_id = str(uuid4())
    session_id = str(uuid4())

    password_hash = None
    if payload.password:
        password_hash = pwd_context.hash(payload.password)

    await runtime_db.create_identity({
        "id": identity_id,
        "identity_type": "human",
        "subject": payload.email,
        "email": payload.email,
        "display_name": payload.display_name,
        "password_hash_ref": password_hash,
        "status": "active"
    })

    await runtime_db.create_session({
        "id": session_id,
        "identity_id": identity_id,
        "session_token_hash": str(uuid4()),
        "expires_at": (
            datetime.now(UTC) + timedelta(days=7)
        ).isoformat()
    })

    token = create_access_token(identity_id)

    return {
        "identity": {
            "id": identity_id,
            "email": payload.email,
            "display_name": payload.display_name,
            "status": "active"
        },
        "session": {
            "id": session_id,
            "status": "active"
        },
        "access_token": token
    }


@app.post("/auth/login")
async def login(payload: LoginRequest) -> dict:
    session_id = str(uuid4())
    identity_id = payload.email

    await runtime_db.create_session({
        "id": session_id,
        "identity_id": identity_id,
        "session_token_hash": str(uuid4()),
        "expires_at": (
            datetime.now(UTC) + timedelta(days=7)
        ).isoformat()
    })

    token = create_access_token(identity_id)

    return {
        "identity": {
            "id": identity_id,
            "email": payload.email,
            "status": "active"
        },
        "session": {
            "id": session_id,
            "status": "active"
        },
        "access_token": token
    }


@app.post("/auth/logout")
async def logout(authorization: str | None = Header(default=None)) -> dict:
    if not authorization:
        raise HTTPException(status_code=401, detail="missing authorization")

    return {
        "ok": True
    }


@app.get("/auth/session")
async def get_session(authorization: str | None = Header(default=None)) -> dict:
    if not authorization:
        raise HTTPException(status_code=401, detail="missing authorization")

    return {
        "status": "active"
    }


@app.post("/auth/magic-link")
async def create_magic_link(payload: MagicLinkRequest) -> dict:
    magic_link_id = str(uuid4())

    await runtime_db.create_magic_link({
        "id": magic_link_id,
        "email": payload.email,
        "purpose": payload.purpose,
        "redirect_to": payload.redirect_to,
        "token_hash": str(uuid4()),
        "expires_at": (
            datetime.now(UTC) + timedelta(minutes=15)
        ).isoformat()
    })

    return {
        "id": magic_link_id,
        "status": "pending"
    }


@app.post("/auth/users/{identity_id}/freeze")
async def freeze_user(identity_id: str, payload: FreezeRequest) -> dict:
    await runtime_db.freeze_identity(identity_id, payload.reason)

    return {
        "ok": True,
        "identity_id": identity_id,
        "reason": payload.reason
    }


@app.get("/auth/reports/{target_ref}")
async def get_reports(target_ref: str) -> dict:
    reports = await runtime_db.get_validation_reports(target_ref)

    return {
        "reports": reports,
        "target_ref": target_ref
    }
