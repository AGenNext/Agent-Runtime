from datetime import datetime, timedelta, UTC
from uuid import uuid4

from fastapi import FastAPI, HTTPException, Header
from pydantic import BaseModel, EmailStr
from jose import JWTError, jwt
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


def create_access_token(subject: str, session_id: str | None = None) -> str:
    expires = datetime.now(UTC) + timedelta(minutes=settings.jwt_expires_minutes)
    payload = {
        "sub": subject,
        "exp": expires,
    }
    if session_id:
        payload["sid"] = session_id
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def decode_bearer_token(authorization: str | None) -> dict:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="missing bearer token")

    token = authorization.split(" ", 1)[1]
    try:
        return jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    except JWTError as exc:
        raise HTTPException(status_code=401, detail="invalid token") from exc


def first_result(result: object) -> object | None:
    if isinstance(result, list) and result:
        first = result[0]
        if isinstance(first, dict) and "result" in first:
            value = first["result"]
            if isinstance(value, list):
                return value[0] if value else None
            return value
        return first
    return None


@app.get("/health")
async def health() -> dict:
    return {"ok": True, "service": "agent-auth-runtime"}


@app.post("/auth/signup")
async def signup(payload: SignupRequest) -> dict:
    existing = first_result(await runtime_db.get_identity_by_email(payload.email))
    if existing:
        raise HTTPException(status_code=409, detail="identity already exists")

    identity_id = str(uuid4())
    session_id = str(uuid4())

    password_hash = pwd_context.hash(payload.password) if payload.password else None

    await runtime_db.create_identity({
        "id": identity_id,
        "identity_type": "human",
        "subject": payload.email,
        "email": payload.email,
        "display_name": payload.display_name,
        "password_hash_ref": password_hash,
        "status": "active",
    })

    await runtime_db.create_session({
        "id": session_id,
        "identity_id": identity_id,
        "session_token_hash": str(uuid4()),
        "jwt_id": session_id,
        "expires_at": (datetime.now(UTC) + timedelta(days=7)).isoformat(),
    })

    token = create_access_token(identity_id, session_id)

    return {
        "identity": {
            "id": identity_id,
            "email": payload.email,
            "display_name": payload.display_name,
            "status": "active",
        },
        "session": {"id": session_id, "status": "active"},
        "access_token": token,
    }


@app.post("/auth/login")
async def login(payload: LoginRequest) -> dict:
    identity = first_result(await runtime_db.get_identity_by_email(payload.email))
    if not isinstance(identity, dict):
        raise HTTPException(status_code=401, detail="invalid credentials")

    if identity.get("status") != "active":
        raise HTTPException(status_code=403, detail="identity is not active")

    stored_hash = identity.get("password_hash_ref")
    if stored_hash and payload.password:
        if not pwd_context.verify(payload.password, stored_hash):
            raise HTTPException(status_code=401, detail="invalid credentials")
    elif stored_hash:
        raise HTTPException(status_code=401, detail="password required")

    identity_id = str(identity.get("id", "")).split(":")[-1]
    session_id = str(uuid4())

    await runtime_db.create_session({
        "id": session_id,
        "identity_id": identity_id,
        "session_token_hash": str(uuid4()),
        "jwt_id": session_id,
        "expires_at": (datetime.now(UTC) + timedelta(days=7)).isoformat(),
    })
    await runtime_db.touch_identity_login(identity_id)

    token = create_access_token(identity_id, session_id)

    return {
        "identity": {
            "id": identity_id,
            "email": identity.get("email"),
            "display_name": identity.get("display_name"),
            "status": identity.get("status"),
        },
        "session": {"id": session_id, "status": "active"},
        "access_token": token,
    }


@app.post("/auth/logout")
async def logout(authorization: str | None = Header(default=None)) -> dict:
    claims = decode_bearer_token(authorization)
    session_id = claims.get("sid")
    if session_id:
        await runtime_db.revoke_session(session_id, "logout")
    return {"ok": True}


@app.get("/auth/session")
async def get_session(authorization: str | None = Header(default=None)) -> dict:
    claims = decode_bearer_token(authorization)
    identity_id = claims.get("sub")
    session_id = claims.get("sid")

    identity = first_result(await runtime_db.get_identity_by_id(identity_id)) if identity_id else None
    session = first_result(await runtime_db.get_session_by_id(session_id)) if session_id else None

    if not identity or not session:
        raise HTTPException(status_code=401, detail="session not found")

    if isinstance(session, dict) and session.get("status") != "active":
        raise HTTPException(status_code=401, detail="session not active")

    return {"identity": identity, "session": session}


@app.post("/auth/magic-link")
async def create_magic_link(payload: MagicLinkRequest) -> dict:
    magic_link_id = str(uuid4())

    await runtime_db.create_magic_link({
        "id": magic_link_id,
        "email": payload.email,
        "purpose": payload.purpose,
        "redirect_to": payload.redirect_to,
        "token_hash": str(uuid4()),
        "expires_at": (datetime.now(UTC) + timedelta(minutes=15)).isoformat(),
    })

    return {"id": magic_link_id, "status": "pending"}


@app.post("/auth/users/{identity_id}/freeze")
async def freeze_user(identity_id: str, payload: FreezeRequest) -> dict:
    await runtime_db.freeze_identity(identity_id, payload.reason)
    return {"ok": True, "identity_id": identity_id, "reason": payload.reason}


@app.get("/auth/reports/{target_ref}")
async def get_reports(target_ref: str) -> dict:
    reports = await runtime_db.get_validation_reports(target_ref)
    return {"reports": reports, "target_ref": target_ref}
