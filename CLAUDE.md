# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get                                              # install dependencies
flutter run -d chrome                                       # run locally in browser
flutter analyze                                             # lint
flutter build web --release --base-href "/restaurant-booking/"  # production build (GitHub Pages)
flutter test                                                # run tests
dart run build_runner build                                 # regenerate Riverpod code-gen providers
```

Deployment is automatic via GitHub Actions (`.github/workflows/deploy.yml`) on every push to `main` → GitHub Pages at `prenota.hiooriental.com`. The customer booking form is served at the root; the staff app lives under `/gestione/`.

## Architecture

**Stack**: Flutter Web + Supabase (Postgres + Edge Functions) + Riverpod + GoRouter.

### Supabase

- URL and anon key are in `.env` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`), loaded via `flutter_dotenv` at startup.
- **Restaurant ID is hardcoded** throughout the codebase: `2b126a92-24d5-4e83-b38c-dfc82035a0cf`. Every Supabase query filters by this ID.
- Email notifications are sent via three Deno edge functions in `supabase/functions/` (using `npm:nodemailer` with SMTP via Aruba). Deploy with `supabase functions deploy <name>`. SMTP credentials are set as Supabase secrets (`SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`).
- Real-time booking notifications (web push + in-app SnackBar) are handled by `BookingNotifier` in `lib/shared/widgets/booking_notifier.dart`, which subscribes to Supabase Realtime for INSERT events on the `bookings` table. It is wrapped around the entire app in `main.dart`.

### Two data-access patterns

The codebase uses **both** patterns; do not mix them within the same screen:

1. **Typed models** (`lib/data/models/`, `lib/data/repositories/`): `BookingModel`, `GuestModel`, `TableModel`, `AreaModel` with `fromJson`/`toJson`. Used through Riverpod providers (`bookingsByDateProvider`, etc.).
2. **Raw `Map<String, dynamic>`** with direct `Supabase.instance.client` calls: used in most feature screens (`bookings_screen.dart`, `floor_plan_screen.dart`, etc.) for flexibility with joins.

### State management (Riverpod)

Providers in `lib/core/providers/`:
- `selectedDateProvider` (`StateProvider<DateTime>`) — shared selected date, watched by BookingsScreen and CalendarScreen.
- `bookingsByDateProvider` / `filteredBookingsProvider` — autoDispose FutureProviders fed by `selectedDateProvider`.
- Screens that do their own direct Supabase fetching (e.g. `BookingsScreen`) call `_loadBookings()` imperatively and use local `setState`, bypassing Riverpod entirely.

### Routing

GoRouter in `lib/core/router.dart`. Notable patterns:
- `/bookings?date=YYYY-MM-DD&filter=da_assegnare` — opens the booking list pre-filtered to pending web bookings.
- `/floor-plan/:date` — floor plan with date as a path parameter.
- `/settings` has nested sub-routes (`tables`, `opening-hours`, `profile`).

### Feature screens

Each feature is self-contained under `lib/features/<name>/`. Key screens:

| Screen | File | Notes |
|---|---|---|
| Booking list + detail sheet | `bookings/bookings_screen.dart` | Most complex file; contains `_BookingRow`, `BookingDetailSheet`, `RejectionScreen`, and `sendTableAssignedEmail()` |
| Floor plan | `floor_plan/floor_plan_screen.dart` | Canvas-based drag-and-drop table layout |
| Schedule (Gantt) | `bookings/reservations_screen.dart` | Timeline view of bookings per table/slot |
| New booking | `bookings/new_booking_screen.dart` | Multi-step form |

`BookingDetailSheet` is a `DraggableScrollableSheet` opened via `showModalBottomSheet`. Its `onSaved` callback closes the sheet **and** refreshes the list — do not call `Navigator.pop` separately before calling `onSaved`, or the parent screen will also be popped (double-pop bug).

### Theme

All colours are static constants on `AppColors` in `lib/shared/theme/app_theme.dart`. Key values: accent red `#B7182A`, gold `#C9B06E`, teal `#00897B` (time column), green `#2E7D52` (accept), red `#DC3545` (reject).

### Web pages

Static HTML/JS pages in `web/` (`booking.html`, `booking-status.html`) are the customer-facing booking form and status page. They use the Supabase JS client directly with the same project URL and anon key hardcoded in the HTML.

### `internal_notes` field

Bookings created from the web form store JSON in `internal_notes`: `{"turno":"...","area":"..."}`. Parse it with `json.decode` or the manual regex pattern already used throughout the codebase — do not trust it as plain text.
