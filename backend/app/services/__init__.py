"""
Business logic layer.

Routes (app/api/v1/endpoints/*) stay thin and delegate to services here,
which in turn talk to Supabase via app/integrations/supabase_client.py.
This keeps request/response handling separate from business rules, and
keeps the business rules testable without spinning up FastAPI.
"""
