"""
app/main.py
-----------
FastAPI application entry-point for Smart-Prep backend.
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.auth.router import router as auth_router


from app.core.config import settings
from app.attendance.router import router as attendance_router

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

app.include_router(auth_router)

@app.get("/")
async def root():
    return {"message": "Smart-Prep API is running"}