"""002: add lecture_plan_entries, gap_records tables and late mark

Revision ID: 002
Revises: 001
Create Date: 2026-08-16
"""
from alembic import op
import sqlalchemy as sa

# revision identifiers
revision = '002'
down_revision = '001'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ---------- lecture_plan_entries ----------
    op.create_table(
        'lecture_plan_entries',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('class_id', sa.String(64), nullable=False, index=True),
        sa.Column('section', sa.String(16), nullable=False, server_default='A', index=True),
        sa.Column('subject_name', sa.String(128), nullable=False, index=True),
        sa.Column('period_id', sa.String(36),
                  sa.ForeignKey('timetable_periods.id', ondelete='CASCADE'),
                  nullable=False),
        sa.Column('date', sa.Date(), nullable=False, index=True),
        sa.Column('teacher_id', sa.String(64), nullable=True),
        sa.Column('topic', sa.String(256), nullable=False),
        sa.Column('subtopics', sa.String(512), nullable=True),
        sa.Column('exam_weightage', sa.Float(), nullable=False, server_default='5.0'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.UniqueConstraint('class_id', 'section', 'date', 'period_id',
                            name='uq_lecture_plan_class_sec_date_period'),
    )

    # ---------- gap_records ----------
    op.create_table(
        'gap_records',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('student_id', sa.String(64), nullable=False, index=True),
        sa.Column('lecture_plan_id', sa.String(36),
                  sa.ForeignKey('lecture_plan_entries.id', ondelete='CASCADE'),
                  nullable=False),
        sa.Column('class_id', sa.String(64), nullable=False, index=True),
        sa.Column('subject_name', sa.String(128), nullable=False),
        sa.Column('date', sa.Date(), nullable=False),
        sa.Column('period_id', sa.String(36),
                  sa.ForeignKey('timetable_periods.id', ondelete='CASCADE'),
                  nullable=False),
        sa.Column('reason', sa.String(64), nullable=False, server_default='absence'),
        sa.Column('priority_score', sa.Float(), nullable=False, server_default='5.0'),
        sa.Column('status', sa.String(32), nullable=False, server_default='unresolved'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.UniqueConstraint('student_id', 'lecture_plan_id',
                            name='uq_gap_student_lecture_plan'),
    )


def downgrade() -> None:
    op.drop_table('gap_records')
    op.drop_table('lecture_plan_entries')
