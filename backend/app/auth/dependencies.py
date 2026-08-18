"""
app/auth/dependencies.py
------------------------
Reusable FastAPI auth dependency.
Validates a Bearer JWT and returns the current user id (UUID string).
"""

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
from app.auth.mongo_db import users_collection
from bson import ObjectId

from app.core.config import settings

_bearer = HTTPBearer(auto_error=False)


def get_current_user_id(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> str:
    """
    Extract and validate the JWT from the Authorization header.
    Returns the subject (user UUID) on success.

    Raises HTTP 401 if token is missing or invalid.
    """
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        payload = jwt.decode(
            credentials.credentials,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )
        user_id: str | None = payload.get("sub")
        if user_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token payload",
            )
        return user_id
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )


# ---------------------------------------------------------
# STUDENT AUTHORIZATION
# ---------------------------------------------------------

async def get_current_student(
    user_id: str = Depends(get_current_user_id)
):
    user = await users_collection.find_one({
        "_id": ObjectId(user_id)
    })

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )

    if user.get("role") != "student":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Student access required"
        )

    return user


# ---------------------------------------------------------
# MENTOR AUTHORIZATION
# ---------------------------------------------------------

async def get_current_mentor(
    user_id: str = Depends(get_current_user_id)
):
    user = await users_collection.find_one({
        "_id": ObjectId(user_id)
    })

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )

    if user.get("role") != "mentor":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Mentor access required"
        )
    return user


# ---------------------------------------------------------
# JWT PAYLOAD EXTRACTION (lightweight, no DB lookup)
# ---------------------------------------------------------

def get_current_user_payload(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> dict:
    """
    Decode the JWT and return the full payload dict.
    Useful when you need the user's role without a DB round-trip.
    Payload is expected to contain at minimum: sub, role.
    """
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )
    try:
        payload = jwt.decode(
            credentials.credentials,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )
        if payload.get("sub") is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token payload",
            )
        return payload
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )


# ---------------------------------------------------------
# EDUCATOR (TEACHER / MENTOR) AUTHORIZATION — no DB lookup
# ---------------------------------------------------------

def get_current_educator(
    payload: dict = Depends(get_current_user_payload),
) -> dict:
    """
    Require the caller to have role 'teacher' or 'mentor'.
    Returns the full JWT payload on success.
    """
    role = payload.get("role", "")
    if role not in ("teacher", "mentor"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Teacher or Mentor access required.",
        )
    return payload