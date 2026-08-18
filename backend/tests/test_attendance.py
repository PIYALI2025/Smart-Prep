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
from app.auth.dependencies import (
    get_current_user_id,
    get_current_user_payload,
    get_current_educator,
)
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

from sqlalchemy.pool import StaticPool

SQLALCHEMY_TEST_URL = "sqlite:///:memory:"

test_engine = create_engine(
    SQLALCHEMY_TEST_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
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


def override_get_current_user_payload():
    return {"sub": "test-user-uuid-1234", "role": "teacher"}


def override_get_current_educator():
    return {"sub": "test-user-uuid-1234", "role": "teacher"}


# Apply overrides
app.dependency_overrides[get_db] = override_get_db
app.dependency_overrides[get_current_user_id] = override_get_current_user_id
app.dependency_overrides[get_current_user_payload] = override_get_current_user_payload
app.dependency_overrides[get_current_educator] = override_get_current_educator


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


# ══════════════════════════════════════════════════════════════════════════════
# New Integration Tests — Lecture Plans, Bulk Mark, History, Class Summary, Gaps
# ══════════════════════════════════════════════════════════════════════════════

class TestLecturePlanCRUD:
    plan_id: str = ""

    def test_create_lecture_plan(self, client):
        period_id = TestPeriodsCRUD.period_id
        r = client.post("/api/v1/attendance/lecture-plan", json={
            "class_id":       CLASS_ID,
            "section":        "A",
            "subject_name":   "Mathematics",
            "period_id":      period_id,
            "date":           "2026-08-18",
            "teacher_id":     "teacher-001",
            "topic":          "Quadratic Equations",
            "subtopics":      "Factoring, Quadratic Formula",
            "exam_weightage": 8.5,
        })
        assert r.status_code == 201
        data = r.json()
        assert data["topic"] == "Quadratic Equations"
        assert data["subject_name"] == "Mathematics"
        TestLecturePlanCRUD.plan_id = data["id"]

    def test_list_lecture_plans(self, client):
        r = client.get("/api/v1/attendance/lecture-plan", params={
            "class_id": CLASS_ID,
            "section":  "A",
            "date":     "2026-08-18",
        })
        assert r.status_code == 200
        assert len(r.json()) >= 1

    def test_update_lecture_plan(self, client):
        r = client.put(
            f"/api/v1/attendance/lecture-plan/{self.plan_id}",
            json={"topic": "Quadratic Equations — Advanced"},
        )
        assert r.status_code == 200
        assert "Advanced" in r.json()["topic"]

    def test_duplicate_lecture_plan_conflict(self, client):
        period_id = TestPeriodsCRUD.period_id
        r = client.post("/api/v1/attendance/lecture-plan", json={
            "class_id":     CLASS_ID,
            "section":      "A",
            "subject_name": "Science",
            "period_id":    period_id,
            "date":         "2026-08-18",
            "topic":        "Photosynthesis",
        })
        assert r.status_code == 409


class TestBulkMarkAttendance:
    def test_bulk_mark_rejects_without_is_unplanned(self, client):
        """No lecture plan on 2026-08-19 → should 422 unless is_unplanned."""
        period_id = TestPeriodsCRUD.period_id
        r = client.post("/api/v1/attendance/bulk-mark", json={
            "class_id":   CLASS_ID,
            "section":    "A",
            "date":       "2026-08-19",
            "period_id":  period_id,
            "records": [
                {"student_id": STUDENT_ID, "status": "present"},
            ],
        })
        assert r.status_code == 422

    def test_bulk_mark_unplanned_ok(self, client):
        """Setting is_unplanned=true allows marking without lecture plan."""
        period_id = TestPeriodsCRUD.period_id
        r = client.post("/api/v1/attendance/bulk-mark", json={
            "class_id":     CLASS_ID,
            "section":      "A",
            "date":         "2026-08-19",
            "period_id":    period_id,
            "is_unplanned": True,
            "records": [
                {"student_id": STUDENT_ID, "status": "present"},
            ],
        })
        assert r.status_code == 201
        data = r.json()
        assert data["total_marked"] == 1
        assert data["present_count"] == 1

    def test_bulk_mark_with_lecture_plan_creates_gaps(self, client):
        """Bulk mark on date with lecture plan; absent students get gap records."""
        period_id = TestPeriodsCRUD.period_id
        r = client.post("/api/v1/attendance/bulk-mark", json={
            "class_id":  CLASS_ID,
            "section":   "A",
            "date":      "2026-08-18",
            "period_id": period_id,
            "records": [
                {"student_id": "student-A", "status": "present"},
                {"student_id": "student-B", "status": "absent"},
                {"student_id": "student-C", "status": "late"},
            ],
        })
        assert r.status_code == 201
        data = r.json()
        assert data["total_marked"] == 3
        assert data["present_count"] == 1
        assert data["absent_count"] == 1
        assert data["late_count"] == 1
        assert "student-B" in data["absent_students"]
        assert data["gaps_created"] >= 1
        assert data["lecture_plan_id"] is not None

    def test_bulk_mark_late_is_valid(self, client):
        """Verify 'late' is accepted as a valid mark."""
        period_id = TestPeriodsCRUD.period_id
        r = client.post("/api/v1/attendance/bulk-mark", json={
            "class_id":     CLASS_ID,
            "section":      "A",
            "date":         "2026-08-20",
            "period_id":    period_id,
            "is_unplanned": True,
            "records": [
                {"student_id": STUDENT_ID, "status": "late", "notes": "5 min late"},
            ],
        })
        assert r.status_code == 201
        assert r.json()["late_count"] == 1


class TestStudentHistory:
    def test_history_as_teacher(self, client):
        """Teachers can view any student's history."""
        r = client.get(
            f"/api/v1/attendance/history/{STUDENT_ID}",
            params={"class_id": CLASS_ID},
        )
        assert r.status_code == 200
        data = r.json()
        assert data["student_id"] == STUDENT_ID
        assert isinstance(data["records"], list)

    def test_history_student_self_access(self, client):
        """
        When payload has role=student and sub matches student_id → OK.
        We override the payload dependency temporarily.
        """
        def student_payload():
            return {"sub": STUDENT_ID, "role": "student"}

        app.dependency_overrides[get_current_user_payload] = student_payload
        try:
            r = client.get(
                f"/api/v1/attendance/history/{STUDENT_ID}",
                params={"class_id": CLASS_ID},
            )
            assert r.status_code == 200
        finally:
            # Restore teacher override
            app.dependency_overrides[get_current_user_payload] = override_get_current_user_payload

    def test_history_student_cross_access_denied(self, client):
        """Students cannot access another student's history."""
        def student_payload():
            return {"sub": "other-student-uuid", "role": "student"}

        app.dependency_overrides[get_current_user_payload] = student_payload
        try:
            r = client.get(
                f"/api/v1/attendance/history/{STUDENT_ID}",
                params={"class_id": CLASS_ID},
            )
            assert r.status_code == 403
        finally:
            app.dependency_overrides[get_current_user_payload] = override_get_current_user_payload


class TestClassSummary:
    def test_class_summary(self, client):
        r = client.get("/api/v1/attendance/class-summary", params={
            "class_id": CLASS_ID,
            "section":  "A",
        })
        assert r.status_code == 200
        data = r.json()
        assert data["class_id"] == CLASS_ID
        assert "default_threshold" in data
        assert isinstance(data["students"], list)


class TestGapRecords:
    def test_list_gaps(self, client):
        r = client.get("/api/v1/attendance/gaps", params={
            "class_id": CLASS_ID,
        })
        assert r.status_code == 200
        gaps = r.json()
        assert isinstance(gaps, list)
        # We created at least one gap in bulk-mark test
        assert len(gaps) >= 1

    def test_list_gaps_student_filtered(self, client):
        """Student role → only sees their own gaps."""
        def student_payload():
            return {"sub": "student-B", "role": "student"}

        app.dependency_overrides[get_current_user_payload] = student_payload
        try:
            r = client.get("/api/v1/attendance/gaps", params={
                "class_id": CLASS_ID,
            })
            assert r.status_code == 200
            for gap in r.json():
                assert gap["student_id"] == "student-B"
        finally:
            app.dependency_overrides[get_current_user_payload] = override_get_current_user_payload

    def test_update_gap_status(self, client):
        # Get a gap to update
        r = client.get("/api/v1/attendance/gaps", params={"class_id": CLASS_ID})
        gaps = r.json()
        assert len(gaps) >= 1
        gap_id = gaps[0]["id"]

        r = client.put(
            f"/api/v1/attendance/gaps/{gap_id}/status",
            params={"new_status": "reviewed"},
        )
        assert r.status_code == 200
        assert r.json()["status"] == "reviewed"

    def test_delete_lecture_plan_cascades_gaps(self, client):
        """Deleting a lecture plan should cascade-delete its gap records."""
        plan_id = TestLecturePlanCRUD.plan_id
        r = client.delete(f"/api/v1/attendance/lecture-plan/{plan_id}")
        assert r.status_code == 204

        # Gaps linked to that plan should be gone
        r = client.get("/api/v1/attendance/gaps", params={"class_id": CLASS_ID})
        for gap in r.json():
            assert gap["lecture_plan_id"] != plan_id

