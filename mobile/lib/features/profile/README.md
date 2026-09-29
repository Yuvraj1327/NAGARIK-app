# Profile feature

- `presentation/screens/profile_screen.dart` — built in **Step 2**. Shows
  the signed-out state (Log in / Create account) since there's no real
  auth yet. The signed-in view (user details + submitted-report history,
  with loading/empty/error states) is built in **Step 4**, once Step 3
  provides real auth state to branch on.
- `data/` — repository calling the FastAPI `/users` endpoints (Step 4).
- `domain/` — profile entity and repository interface (Step 4).
