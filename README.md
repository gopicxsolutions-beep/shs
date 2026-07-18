# NavaSakhi — Mobile App for Self-Help Groups

A native mobile app for a Self-Help Group (SHG) management platform, covering all five user roles (Member, Leader/President, Community Resource Person, Cluster Level Federation, Administrator) and every feature tab from the product spec — savings, loans, meetings, financial records, livelihoods, marketplace, government schemes, training, digital payments, announcements, AI-powered advisors, reports, and analytics.

This is a Flutter rewrite of an earlier React prototype. The onboarding flow and dashboards for all 5 roles are implemented; remaining feature modules are scaffolded as placeholder screens and are being ported one at a time.

## Stack

- Flutter (Dart)
- go_router for navigation
- provider for app state
- fl_chart for charts
- shared_preferences for local persistence
- supabase_flutter for backend (auth, database)

## Getting started

```bash
flutter pub get
flutter run -d chrome --dart-define-from-file=.env.json
```

Copy `.env.json.example` to `.env.json` and fill in your Supabase project URL and anon/publishable key (never the service-role key — that belongs server-side only, e.g. in Supabase Edge Functions, not in this client app). `.env.json` is gitignored.

The onboarding flow (Splash → Login → OTP → Profile Setup → Role Select) lets you pick any of the 5 roles to explore a tailored dashboard and navigation experience.

## Project structure

- `lib/widgets` — shared design-system primitives (Card, Button, Badge, StatCard, ProgressBar, IconTile, etc.)
- `lib/layout` — app shell, bottom navigation, page headers
- `lib/state` — app-wide state (current user, role, language) via `AppState` (ChangeNotifier)
- `lib/data` — mock data for members, savings, loans, meetings, schemes, etc. (being migrated to Supabase tables)
- `lib/pages` — one folder per feature module (auth, dashboard, and placeholders for the rest)
- `lib/routes` — route path constants (`paths.dart`) and the go_router config (`router.dart`)
- `lib/config/env.dart` — compile-time Supabase config read from `--dart-define-from-file=.env.json`
