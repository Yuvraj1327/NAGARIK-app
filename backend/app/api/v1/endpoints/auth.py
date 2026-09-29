"""
Auth endpoints — placeholder.

Signup/login/session management happen against Supabase Auth directly from
the Flutter app (see docs/ARCHITECTURE.md for the full rationale), so this
router is not expected to grow large. It is reserved for any auth-adjacent
backend concerns (e.g. a "sync profile row on first login" webhook) that
surface once Step 3 is implemented.

Intentionally empty until Step 3.
"""

from fastapi import APIRouter

router = APIRouter()
