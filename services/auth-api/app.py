from datetime import datetime, timedelta, UTC
from uuid import uuid4

from fastapi import FastAPI, HTTPException, Header
from pydantic import BaseModel, EmailStr
from jose import jwt
from passlib.context import CryptContext

app = FastAPI(title="Agent-Auth Runtime API")

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
JWT_SECRET = "CHANGE_ME"
JWT_ALGORITHM = "HS256"
JWT_EXPIRES_MINUTES = 60


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


def create_access_token(subject: str) -> str:
    expires = datetime.now(UTC) + timedelta(minutes=JWT_EXPIRES_MINUTES)
    payload = {
        "sub": subject,
        "exp": expires
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


@app.get("/health")
async def health() -> dict:
    return {
        "ok": True,
        "service": "agent-auth-runtime"
    }


@app.post("/auth/signup")
async def signup(payload: SignupRequest) -> dict:
    identity_id = f"identity:{uuid4()}"
    session_id = f"session:{uuid4()}"

    password_hash = None
    if payload.password:
        password_hash = pwd_context.hash(payload.password)

    # TODO:
    # call fn::runtime::auth::identity::create
    # call fn::runtime::auth::session::create

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
    # TODO:
    # lookup identity in SurrealDB
    # verify password hash
    # create auth_session

    identity_id = f"identity:{uuid4()}"
    session_id = f"session:{uuid4()}"

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

    # TODO:
    # revoke auth_session in SurrealDB

    return {
        "ok": True
    }


@app.get("/auth/session")
async def get_session(authorization: str | None = Header(default=None)) -> dict:
    if not authorization:
        raise HTTPException(status_code=401, detail="missing authorization")

    # TODO:
    # validate JWT
    # lookup auth_session

    return {
        "status": "active"
    }


@app.post("/auth/magic-link")
async def create_magic_link(payload: MagicLinkRequest) -> dict:
    magic_link_id = f"magic_link:{uuid4()}"

    # TODO:
    # create auth_magic_link
    # send email externally later

    return {
        "id": magic_link_id,
        "status": "pending"
    }


@app.post("/auth/users/{identity_id}/freeze")
async def freeze_user(identity_id: str, payload: FreezeRequest) -> dict:
    # TODO:
    # call fn::runtime::auth::identity::freeze

    return {
        "ok": True,
        "identity_id": identity_id,
        "reason": payload.reason
    }


@app.get("/auth/reports/{target_ref}")
async def get_reports(target_ref: str) -> dict:
    # TODO:
    # query auth_validation_report

    return {
        "reports": [],
        "target_ref": target_ref
    }
