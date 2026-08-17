"""Initial attendance tables

Revision ID: 001
Revises:
Create Date: 2026-08-15

Creates all 6 tables for the Attendance Management System:
  - timetable_periods
  - weekly_routine
  - holidays
  - extra_off_days
  - attendance_records
  - attendance_thresholds
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers
revision = "001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ── 1. timetable_periods ─────────────────────────────────────────────────
    op.create_table(
        "timetable_periods",
        sa.Column("id",         postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("class_id",   sa.String(64),  nullable=False),
        sa.Column("name",       sa.String(64),  nullable=False),
        sa.Column("start_time", sa.Time(),       nullable=False),
        sa.Column("end_time",   sa.Time(),       nullable=False),
        sa.Column("order",      sa.Integer(),    nullable=False, server_default="0"),
        sa.Column("is_active",  sa.Boolean(),   nullable=False, server_default="true"),
        sa.Column("created_at", sa.DateTime(),  nullable=False,
                  server_default=sa.text("NOW()")),
        sa.Column("updated_at", sa.DateTime(),  nullable=False,
                  server_default=sa.text("NOW()")),
        sa.UniqueConstraint("class_id", "name", name="uq_period_class_name"),
        sa.CheckConstraint("end_time > start_time", name="ck_period_time_order"),
    )
    op.create_index("ix_timetable_periods_class_id", "timetable_periods", ["class_id"])

    # ── 2. weekly_routine ────────────────────────────────────────────────────
    day_enum = postgresql.ENUM(
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
        name="dayofweek",
        create_type=False
    )
    day_enum.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "weekly_routine",
        sa.Column("id",           postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("class_id",     sa.String(64),  nullable=False),
        sa.Column("day_of_week",  postgresql.ENUM("monday", "tuesday", "wednesday", "thursday",
                                                  "friday", "saturday", "sunday",
                                                  name="dayofweek", create_type=False),
                  nullable=False),
        sa.Column("period_id",    postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("timetable_periods.id", ondelete="CASCADE"),
                  nullable=False),
        sa.Column("subject_name", sa.String(128), nullable=False),
        sa.Column("teacher_name", sa.String(128), nullable=True),
        sa.Column("created_at",   sa.DateTime(),  nullable=False,
                  server_default=sa.text("NOW()")),
        sa.Column("updated_at",   sa.DateTime(),  nullable=False,
                  server_default=sa.text("NOW()")),
        sa.UniqueConstraint("class_id", "day_of_week", "period_id",
                             name="uq_routine_class_day_period"),
    )
    op.create_index("ix_weekly_routine_class_id", "weekly_routine", ["class_id"])

    # ── 3. holidays ──────────────────────────────────────────────────────────
    op.create_table(
        "holidays",
        sa.Column("id",          postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("class_id",    sa.String(64),  nullable=False),
        sa.Column("day_of_week", postgresql.ENUM("monday", "tuesday", "wednesday", "thursday",
                                                  "friday", "saturday", "sunday",
                                                  name="dayofweek", create_type=False),
                  nullable=False),
        sa.Column("description", sa.String(256), nullable=True),
        sa.Column("created_at",  sa.DateTime(),  nullable=False,
                  server_default=sa.text("NOW()")),
        sa.UniqueConstraint("class_id", "day_of_week", name="uq_holiday_class_day"),
    )
    op.create_index("ix_holidays_class_id", "holidays", ["class_id"])

    # ── 4. extra_off_days ────────────────────────────────────────────────────
    op.create_table(
        "extra_off_days",
        sa.Column("id",         postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("class_id",   sa.String(64),  nullable=False),
        sa.Column("off_date",   sa.Date(),       nullable=False),
        sa.Column("reason",     sa.String(256), nullable=True),
        sa.Column("created_at", sa.DateTime(),  nullable=False,
                  server_default=sa.text("NOW()")),
        sa.UniqueConstraint("class_id", "off_date", name="uq_extra_offday_class_date"),
    )
    op.create_index("ix_extra_off_days_class_id", "extra_off_days", ["class_id"])

    # ── 5. attendance_records ─────────────────────────────────────────────────
    mark_enum = postgresql.ENUM(
        "present", "absent", "off_day",
        name="attendancemark",
        create_type=False
    )
    mark_enum.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "attendance_records",
        sa.Column("id",         postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("class_id",   sa.String(64),  nullable=False),
        sa.Column("student_id", sa.String(64),  nullable=False),
        sa.Column("period_id",  postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("timetable_periods.id", ondelete="CASCADE"),
                  nullable=False),
        sa.Column("date",       sa.Date(),       nullable=False),
        sa.Column("mark",       postgresql.ENUM("present", "absent", "off_day",
                                                 name="attendancemark", create_type=False),
                  nullable=False),
        sa.Column("marked_by",  sa.String(64),  nullable=True),
        sa.Column("notes",      sa.String(256), nullable=True),
        sa.Column("created_at", sa.DateTime(),  nullable=False,
                  server_default=sa.text("NOW()")),
        sa.Column("updated_at", sa.DateTime(),  nullable=False,
                  server_default=sa.text("NOW()")),
        sa.UniqueConstraint("student_id", "period_id", "date",
                             name="uq_attendance_student_period_date"),
    )
    op.create_index("ix_attendance_records_class_id",   "attendance_records", ["class_id"])
    op.create_index("ix_attendance_records_student_id", "attendance_records", ["student_id"])

    # ── 6. attendance_thresholds ──────────────────────────────────────────────
    op.create_table(
        "attendance_thresholds",
        sa.Column("id",           postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("class_id",     sa.String(64),  nullable=False),
        sa.Column("scope",        sa.String(16),  nullable=False, server_default="global"),
        sa.Column("subject_name", sa.String(128), nullable=True),
        sa.Column("threshold",    sa.Float(),      nullable=False, server_default="75.0"),
        sa.Column("created_at",   sa.DateTime(),  nullable=False,
                  server_default=sa.text("NOW()")),
        sa.Column("updated_at",   sa.DateTime(),  nullable=False,
                  server_default=sa.text("NOW()")),
        sa.CheckConstraint("threshold >= 0 AND threshold <= 100",
                           name="ck_threshold_range"),
        sa.UniqueConstraint("class_id", "scope", "subject_name",
                             name="uq_threshold_class_scope_subject"),
    )
    op.create_index("ix_attendance_thresholds_class_id", "attendance_thresholds", ["class_id"])


def downgrade() -> None:
    op.drop_table("attendance_thresholds")
    op.drop_index("ix_attendance_records_student_id", table_name="attendance_records")
    op.drop_index("ix_attendance_records_class_id",   table_name="attendance_records")
    op.drop_table("attendance_records")
    op.drop_index("ix_extra_off_days_class_id", table_name="extra_off_days")
    op.drop_table("extra_off_days")
    op.drop_index("ix_holidays_class_id", table_name="holidays")
    op.drop_table("holidays")
    op.drop_index("ix_weekly_routine_class_id", table_name="weekly_routine")
    op.drop_table("weekly_routine")
    op.drop_index("ix_timetable_periods_class_id", table_name="timetable_periods")
    op.drop_table("timetable_periods")

    # Drop custom enums
    sa.Enum(name="attendancemark").drop(op.get_bind(), checkfirst=True)
    sa.Enum(name="dayofweek").drop(op.get_bind(), checkfirst=True)