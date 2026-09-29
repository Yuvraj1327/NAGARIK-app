# Auth feature

- `presentation/screens/login_screen.dart`, `signup_screen.dart` — built in
  **Step 2**. Full, real form validation (email format, password length,
  password match); the actual Supabase Auth calls are wired up in **Step
  3**, along with session management, logout, and protected routes.
- `data/` — repository implementation wrapping the Supabase auth client
  (Step 3).
- `domain/` — auth-related entities and the repository interface (Step 3).
