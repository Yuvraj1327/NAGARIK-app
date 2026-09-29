# Reports feature

- `presentation/screens/create_report_screen.dart` — built in **Step 2**.
  The full Category -> Description -> Location -> Photos -> Review stepper,
  with real validation at each step. Actually saving the report is **Step
  5**; live device location and image picking/upload are **Step 6** (both
  steps currently show an explanatory message instead of silently no-oping).
- `presentation/screens/report_detail_screen.dart` — built in **Step 2**.
  Static layout; becomes reachable from the feed once **Step 7** wires
  tappable report cards to it with real data.
- `presentation/widgets/report_card.dart` — built in **Step 2**. Used by
  the create-report review step now, and by the feed/search results from
  Step 7/8 onward.
- `domain/report_draft.dart` — built in **Step 2**. Holds in-progress form
  state for the create-report flow; becomes the basis for the real
  submission DTO in Step 5.
- `data/` — repository calling the FastAPI `/reports` endpoints (Step 5).
