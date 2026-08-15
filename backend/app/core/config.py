"""
app/core/config.py
------------------
Application settings loaded from environment variables (or .env file).
"""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # ── Application ──────────────────────────────────────────────
    APP_NAME: str = "Smart-Prep API"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False

    # ── Database (Supabase / PostgreSQL) ──────────────────────────
    DATABASE_URL: str = "postgresql://postgres:password@localhost:5432/smartprep"

    # ── JWT Auth ──────────────────────────────────────────────────
    SECRET_KEY: str = "change-me-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24  # 1 day

    # ── Attendance Defaults ───────────────────────────────────────
    DEFAULT_ATTENDANCE_THRESHOLD: float = 75.0   # percentage


settings = Settings()
