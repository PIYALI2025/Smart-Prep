"""
tests/test_attendance.py
------------------------
Unit + integration tests for the Attendance Management System.

Unit tests (no DB):
  - Attendance percentage calculation
  - Classes-needed calculation
  - Subject aggregation logic
  - Day-of-week helpers

Integration tests (FastAPI TestClient + SQLite in-memory):
  - Period CRUD
  - Weekly routine CRUD
  - Holiday / Extra off-day CRUD
  - Attendance marking, updating, clearing
  - Calendar endpoint
  - Stats endpoint
  - Threshold CRUD + compliance check
"""

from __future__ import annotations

import uuid
from datetime import date, time

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# ── App imports ───────────────────────────────────────────────────────────────
from app.main import app
from app.core.database import Base, get_db
from app.auth.dependencies import get_current_user_id
from app.attendance.utils import (
    attendance_percentage,
    classes_needed_for_threshold,
    is_weekly_holiday,
    is_extra_off_day,
    aggregate_by_subject,
)


# ══════════════════════════════════════════════════════════════════════════════
# Test database setup (SQLite in-memory)
# ══════════════════════════════════════════════════════════════════════════════

SQLALCHEMY_TEST_URL = "sqlite:///:memory:"

test_engine = create_engine(
    SQLALCHEMY_TEST_URL,
    connect_args={"check_same_thread": False},
)
TestingSessionLocal = sessionmaker(
    autocommit=False, autoflush=False, bind=test_engine
)


def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


def override_get_current_user_id():
    return "test-user-uuid-1234"


# Apply overrides
app.dependency_overrides[get_db] = override_get_db
app.dependency_overrides[get_current_user_id] = override_get_current_user_id


@pytest.fixture(scope="session", autouse=True)
def create_tables():
    Base.metadata.create_all(bind=test_engine)
    yield
    Base.metadata.drop_all(bind=test_engine)


@pytest.fixture(scope="module")
def client():
    with TestClient(app) as c:
        yield c


CLASS_ID = "TEST-CLASS-10A"
STUDENT_ID = "student-uuid-5678"


# ══════════════════════════════════════════════════════════════════════════════
# Unit Tests — utils.py
# ══════════════════════════════════════════════════════════════════════════════

class TestAttendancePercentage:
    def test_normal(self):
        assert attendance_percentage(75, 25) == 75.0

    def test_all_present(self):
        assert attendance_percentage(10, 0) == 100.0

    def test_all_absent(self):
        assert attendance_percentage(0, 10) == 0.0

    def test_no_classes(self):
        assert attendance_percentage(0, 0) == 0.0

    def test_rounding(self):
        # 2/3 ≈ 66.67
        assert attendance_percentage(2, 1) == 66.67


class TestClassesNeeded:
    def test_already_above(self):
        assert classes_needed_for_threshold(80, 20, 75.0) == 0

    def test_exactly_at(self):
        assert classes_needed_for_threshold(75, 25, 75.0) == 0

    def test_below(self):
        # 60% present → need extra classes to reach 75%
        needed = classes_needed_for_threshold(6, 4, 75.0)
        assert needed > 0
        # Verify: (6 + needed) / (10 + needed) >= 0.75
        assert (6 + needed) / (10 + needed) >= 0.75

    def test_zero_classes(self):
        needed = classes_needed_for_threshold(0, 0, 75.0)
        assert needed > 0  # needs classes to have 75 %


class TestDayHelpers:
    def test_weekly_holiday(self):
        # 2026-08-16 is a Sunday
        sunday = date(2026, 8, 16)
        assert is_weekly_holiday(sunday, ["sunday"]) is True
        assert is_weekly_holiday(sunday, ["saturday"]) is False

    def test_extra_off_day(self):
        d = date(2026, 8, 15)  # Independence Day
        assert is_extra_off_day(d, [date(2026, 8, 15)]) is True
        assert is_extra_off_day(d, [date(2026, 8, 16)]) is False


class TestAggregateBySubject:
    def test_basic(self):
        records = [
            {"subject_name": "Maths", "mark": "present"},
            {"subject_name": "Maths", "mark": "present"},
            {"subject_name": "Maths", "mark": "absent"},
            {"subject_name": "Science", "mark": "absent"},
        ]
        stats, total_p, total_a, total_o = aggregate_by_subject(records, {}, 75.0)
        assert total_p == 2
        assert total_a == 2
        maths  = next(s for s in stats if s["subject_name"] == "Maths")
        science = next(s for s in stats if s["subject_name"] == "Science")
        assert maths["attendance_pct"]   == pytest.approx(66.67)
        assert science["attendance_pct"] == 0.0

    def test_off_day_excluded(self):
        records = [{"subject_name": "English", "mark": "off_day"}] * 5
        _, p, a, o = aggregate_by_subject(records, {}, 75.0)
        assert p == 0 and a == 0 and o == 5


# ══════════════════════════════════════════════════════════════════════════════
# Integration Tests — API endpoints
# ══════════════════════════════════════════════════════════════════════════════

class TestPeriodsCRUD:
    period_id: str = ""

    def test_create_period(self, client):
        r = client.post("/api/v1/attendance/periods", json={
            "class_id":   CLASS_ID,
            "name":       "Period 1",
            "start_time": "09:00:00",
            "end_time":   "09:45:00",
            "order":      1,
        })
        assert r.status_code == 201
        data = r.json()
        assert data["name"] == "Period 1"
        TestPeriodsCRUD.period_id = data["id"]

    def test_list_periods(self, client):
        r = client.get("/api/v1/attendance/periods", params={"class_id": CLASS_ID})
        assert r.status_code == 200
        assert len(r.json()) >= 1

    def test_update_period(self, client):
        r = client.put(
            f"/api/v1/attendance/periods/{self.period_id}",
            json={"name": "Period 1 Updated"},
        )
        assert r.status_code == 200
        assert r.json()["name"] == "Period 1 Updated"

    def test_duplicate_period_conflict(self, client):
        # Restore name to test uniqueness
        client.put(
            f"/api/v1/attendance/periods/{self.period_id}",
            json={"name": "Period 1"},
        )
        r = client.post("/api/v1/attendance/periods", json={
            "class_id":   CLASS_ID,
            "name":       "Period 1",
            "start_time": "09:00:00",
            "end_time":   "09:45:00",
        })
        assert r.status_code == 409


class TestHolidayCRUD:
    holiday_id: str = ""

    def test_create_holiday(self, client):
        r = client.post("/api/v1/attendance/holidays", json={
            "class_id":    CLASS_ID,
            "day_of_week": "sunday",
            "description": "Weekly off",
        })
        assert r.status_code == 201
        TestHolidayCRUD.holiday_id = r.json()["id"]

    def test_list_holidays(self, client):
        r = client.get("/api/v1/attendance/holidays", params={"class_id": CLASS_ID})
        assert r.status_code == 200
        assert any(h["day_of_week"] == "sunday" for h in r.json())

    def test_delete_holiday(self, client):
        r = client.delete(f"/api/v1/attendance/holidays/{self.holiday_id}")
        assert r.status_code == 204


class TestExtraOffDayCRUD:
    off_day_id: str = ""

    def test_create_extra_off_day(self, client):
        r = client.post("/api/v1/attendance/extra-off-days", json={
            "class_id": CLASS_ID,
            "off_date": "2026-08-15",
            "reason":   "Independence Day",
        })
        assert r.status_code == 201
        TestExtraOffDayCRUD.off_day_id = r.json()["id"]

    def test_list_extra_off_days(self, client):
        r = client.get("/api/v1/attendance/extra-off-days",
                       params={"class_id": CLASS_ID})
        assert r.status_code == 200
        assert len(r.json()) >= 1

    def test_delete_extra_off_day(self, client):
        r = client.delete(
            f"/api/v1/attendance/extra-off-days/{self.off_day_id}"
        )
        assert r.status_code == 204


class TestAttendanceMarking:
    record_id: str = ""

    def test_mark_present(self, client):
        period_id = TestPeriodsCRUD.period_id
        r = client.post("/api/v1/attendance/mark", json={
            "class_id":   CLASS_ID,
            "student_id": STUDENT_ID,
            "period_id":  period_id,
            "date":       "2026-08-10",
            "mark":       "present",
        })
        assert r.status_code == 201
        TestAttendanceMarking.record_id = r.json()["id"]

    def test_mark_duplicate_conflicts(self, client):
        period_id = TestPeriodsCRUD.period_id
        r = client.post("/api/v1/attendance/mark", json={
            "class_id":   CLASS_ID,
            "student_id": STUDENT_ID,
            "period_id":  period_id,
            "date":       "2026-08-10",
            "mark":       "absent",
        })
        assert r.status_code == 409

    def test_update_mark(self, client):
        r = client.put(
            f"/api/v1/attendance/mark/{self.record_id}",
            json={"mark": "absent"},
        )
        assert r.status_code == 200
        assert r.json()["mark"] == "absent"

    def test_get_calendar(self, client):
        r = client.get(
            f"/api/v1/attendance/calendar/{STUDENT_ID}",
            params={"class_id": CLASS_ID},
        )
        assert r.status_code == 200
        assert len(r.json()) >= 1

    def test_delete_mark(self, client):
        r = client.delete(f"/api/v1/attendance/mark/{self.record_id}")
        assert r.status_code == 204


class TestThresholdCRUD:
    threshold_id: str = ""

    def test_create_global_threshold(self, client):
        r = client.post("/api/v1/attendance/threshold", json={
            "class_id":  CLASS_ID,
            "scope":     "global",
            "threshold": 75.0,
        })
        assert r.status_code == 201
        TestThresholdCRUD.threshold_id = r.json()["id"]

    def test_create_subject_threshold(self, client):
        r = client.post("/api/v1/attendance/threshold", json={
            "class_id":     CLASS_ID,
            "scope":        "subject",
            "subject_name": "Maths",
            "threshold":    80.0,
        })
        assert r.status_code == 201

    def test_list_thresholds(self, client):
        r = client.get("/api/v1/attendance/threshold",
                       params={"class_id": CLASS_ID})
        assert r.status_code == 200
        assert len(r.json()) >= 2

    def test_update_threshold(self, client):
        r = client.put(
            f"/api/v1/attendance/threshold/{self.threshold_id}",
            json={"threshold": 80.0},
        )
        assert r.status_code == 200
        assert r.json()["threshold"] == 80.0

    def test_check_threshold(self, client):
        r = client.get(
            f"/api/v1/attendance/threshold/check/{STUDENT_ID}",
            params={"class_id": CLASS_ID},
        )
        assert r.status_code == 200
        data = r.json()
        assert "overall_pct" in data
        assert "subjects" in data
        assert "global_threshold" in data


class TestStatsEndpoints:
    def test_overall_stats(self, client):
        r = client.get(
            f"/api/v1/attendance/stats/{STUDENT_ID}",
            params={"class_id": CLASS_ID},
        )
        assert r.status_code == 200
        data = r.json()
        assert data["student_id"] == STUDENT_ID
        assert "overall_attendance_pct" in data
        assert "subjects" in data

    def test_subject_stats(self, client):
        r = client.get(
            f"/api/v1/attendance/stats/{STUDENT_ID}/subject/Maths",
            params={"class_id": CLASS_ID},
        )
        assert r.status_code == 200
        assert r.json()["subject_name"] == "Maths"
