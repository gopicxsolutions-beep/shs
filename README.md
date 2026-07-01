# SHG Saathi — Mobile App UI/UX for Self-Help Groups

A complete, premium mobile-app UI/UX for a Self-Help Group (SHG) management platform, covering all five user roles (Member, Leader/President, Community Resource Person, Cluster Level Federation, Administrator) and every feature tab from the product spec — savings, loans, meetings, financial records, livelihoods, marketplace, government schemes, training, digital payments, announcements, AI-powered advisors, reports, and analytics.

Built as a mobile-first React app, rendered inside a phone frame on desktop for easy preview.

## Stack

- Vite + React 19 + TypeScript
- Tailwind CSS v4 (custom brand/gold/ink design tokens)
- react-router-dom for navigation
- recharts for charts, lucide-react for icons

## Getting started

```bash
npm install
npm run dev
```

Open the printed local URL. On desktop the app renders inside a phone frame; on a mobile viewport it fills the screen edge-to-edge.

The onboarding flow (Splash → Login → OTP → Profile Setup → Role Select) lets you pick any of the 5 roles to explore a tailored dashboard and navigation experience. Role can be changed anytime from Profile → Settings.

## Project structure

- `src/components/ui` — shared design-system primitives (Card, Button, Badge, StatCard, ProgressBar, IconTile, etc.)
- `src/components/layout` — app shell, bottom navigation, page headers, phone frame
- `src/context` — app-wide state (current user, role, language)
- `src/data` — mock data for members, savings, loans, meetings, schemes, etc.
- `src/pages` — one folder per feature module (auth, dashboard, shg, savings, loans, meetings, financial, livelihood, marketplace, schemes, training, payments, announcements, support, ai, reports, analytics, profile, admin)
- `src/routes` — route path constants and the top-level router
