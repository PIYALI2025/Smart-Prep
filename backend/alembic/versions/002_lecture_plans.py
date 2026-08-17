"""Add lecture plans and coverage tables

Revision ID: 002
Revises: 001
Create Date: 2026-08-17
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "002"
down_revision = "001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ── 1. lecture_plans ──────────────────────────────────────────────────────
    op.create_table(
        "lecture_plans",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("class_id", sa.String(64), nullable=False),
        sa.Column("subject_name", sa.String(128), nullable=False),
        sa.Column("topic_number", sa.Integer(), nullable=False),
        sa.Column("topic_title", sa.String(256), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.text("NOW()")),
        sa.UniqueConstraint("class_id", "subject_name", "topic_number", name="uq_lecture_plan_class_subject_topic"),
    )
    op.create_index("ix_lecture_plans_class_id", "lecture_plans", ["class_id"])

    # ── 2. lecture_coverage ───────────────────────────────────────────────────
    op.create_table(
        "lecture_coverage",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("class_id", sa.String(64), nullable=False),
        sa.Column("period_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("timetable_periods.id", ondelete="CASCADE"), nullable=False),
        sa.Column("lecture_plan_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("lecture_plans.id", ondelete="CASCADE"), nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("taught_by", sa.String(64), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.text("NOW()")),
        sa.UniqueConstraint("period_id", "date", "lecture_plan_id", name="uq_coverage_period_date_plan"),
    )
    op.create_index("ix_lecture_coverage_class_id", "lecture_coverage", ["class_id"])


def downgrade() -> None:
    op.drop_index("ix_lecture_coverage_class_id", table_name="lecture_coverage")
    op.drop_table("lecture_coverage")
    op.drop_index("ix_lecture_plans_class_id", table_name="lecture_plans")
    op.drop_table("lecture_plans")