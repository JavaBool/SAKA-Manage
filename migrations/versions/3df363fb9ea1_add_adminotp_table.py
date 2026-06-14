"""Add AdminOTP table

Revision ID: 3df363fb9ea1
Revises: c59d26a417ea
Create Date: 2026-06-14 12:02:54.423593

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '3df363fb9ea1'
down_revision = 'c59d26a417ea'
branch_labels = None
depends_on = None


def upgrade():
    # Only create the new admin_otps table
    op.create_table('admin_otps',
    sa.Column('email', sa.String(length=120), nullable=False),
    sa.Column('otp', sa.String(length=6), nullable=False),
    sa.Column('expires_at', sa.Float(), nullable=False),
    sa.PrimaryKeyConstraint('email')
    )


def downgrade():
    op.drop_table('admin_otps')
