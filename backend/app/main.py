"""
app/main.py
-----------
FastAPI application entry-point for Smart-Prep backend.
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from datetime import datetime, timedelta
from jose import jwt

from app.core.config import settings
from app.attendance.router import router as attendance_router
from app.auth.router import router as auth_router

app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description=(
        "Smart-Prep backend API. "
        "Includes Attendance Management System with timetable, calendar, "
        "attendance counting and threshold settings."
    ),
    docs_url="/docs",
    redoc_url="/redoc",
)

# ── CORS ─────────────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],          # tighten in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(attendance_router, prefix="/api/v1")

# ── Health check ──────────────────────────────────────────────────────────────
@app.get("/health", tags=["Health"])
def health_check():
    return {"status": "ok", "version": settings.APP_VERSION}

# ── Dev Token ─────────────────────────────────────────────────────────────────
@app.post("/test-token", tags=["Auth"])
def generate_test_token(user_id: str = "test-teacher-uuid"):
    """
    Generate a test JWT token to use in Swagger UI.
    Copy the `access_token` from the response and paste it into the Authorize dialog.
    """
    expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode = {"sub": user_id, "exp": expire}
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return {"access_token": encoded_jwt, "token_type": "bearer"}

app.include_router(auth_router)

@app.get("/")
async def root():
    return {"message": "Smart-Prep API is running"}