# Discovery feature

- `presentation/screens/home_feed_screen.dart` — built in **Step 2**. Home
  tab shell with pull-to-refresh and an honest empty state (no fabricated
  sample data) — becomes a real `ReportCard` list, plus city/PIN/nearby
  discovery, in **Step 7**.
- `presentation/screens/search_screen.dart` — built in **Step 2**. Search
  tab shell with a real search field; wired to the backend keyword-search
  endpoint and category/status filters in **Step 8**.
- `data/` — repository calling the FastAPI `/reports` discovery endpoints
  (Step 7/8).
- `domain/` — discovery query/filter models, repository interface (Step 7/8).
