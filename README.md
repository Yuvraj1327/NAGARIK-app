# NAGARIK — A Civic Good Initiative

Citizen civic-issue discovery and reporting app.

- **Frontend:** Flutter (Android + iOS) — `mobile/`
- **Backend:** FastAPI (Python) — `backend/`
- **Database / Auth / Storage:** Supabase

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full
architecture, the Flutter↔FastAPI↔Supabase auth-token flow decision, folder
structure rationale, and environment configuration.

## Repository layout

```
nagarik/
├── backend/     # FastAPI REST API
├── mobile/      # Flutter app
├── infra/       # AWS deployment templates + handover doc (Step 10)
└── docs/
    └── ARCHITECTURE.md
```

CI/CD workflow definitions live in `.github/workflows/` (`backend-ci.yml`,
`mobile-ci.yml` run automatically on push/PR; `backend-deploy.yml` is
manual-only — see [`infra/aws/README.md`](infra/aws/README.md)).

## Getting started

- Backend: see [`backend/README.md`](backend/README.md)
- Mobile: see [`mobile/README.md`](mobile/README.md)

## Development roadmap

This project is being built in 10 steps, one at a time:

1. ✅ Project Architecture & Setup
2. ✅ UI/UX Foundation
3. ✅ Authentication
4. ✅ User Profile
5. ✅ Create Report
6. ✅ Location & Media
7. ✅ Report Feed & Discovery
8. ✅ Search, Filtering & Status
9. ✅ Backend, API Integration & Testing
10. ✅ Production Deployment & Handover (preparation only — see [`infra/aws/README.md`](infra/aws/README.md); no actual deployment was performed)
