import 'package:go_router/go_router.dart';
import 'package:restaurant_booking/features/splash/splash_screen.dart';
import 'package:restaurant_booking/features/dashboard/dashboard_screen.dart';
import 'package:restaurant_booking/features/calendar/calendar_screen.dart';
import 'package:restaurant_booking/features/bookings/bookings_screen.dart';
import 'package:restaurant_booking/features/bookings/new_booking_screen.dart';
import 'package:restaurant_booking/features/guests/guests_screen.dart';
import 'package:restaurant_booking/features/reports/reports_screen.dart';
import 'package:restaurant_booking/features/settings/settings_screen.dart';
import 'package:restaurant_booking/features/settings/opening_hours_screen.dart';
import 'package:restaurant_booking/features/settings/restaurant_profile_screen.dart';
import 'package:restaurant_booking/features/settings/tables_screen.dart';
import 'package:restaurant_booking/features/floor_plan/floor_plan_screen.dart';
import 'package:restaurant_booking/features/bookings/reservations_screen.dart';
import 'package:restaurant_booking/features/auth/login_screen.dart';
import 'package:restaurant_booking/features/settings/team_screen.dart';
import 'package:restaurant_booking/core/auth/accesso.dart';

final router = GoRouter(
  initialLocation: '/splash',
  refreshListenable: statoAccesso,
  // Il controllo passa da qui e non dalle singole schermate: scrivere a mano
  // l'indirizzo di una sezione non deve bastare per entrarci.
  redirect: (context, state) {
    final percorso = state.matchedLocation;
    final pubblica = percorso == '/login' || percorso == '/splash';

    // Finche' non sappiamo chi e', non mandiamo nessuno da nessuna parte.
    if (statoAccesso.inCaricamento) return pubblica ? null : '/splash';

    if (!statoAccesso.autenticato) return pubblica ? null : '/login';
    if (percorso == '/login') return statoAccesso.percorsoIniziale;
    if (percorso == '/senza-permessi') return null;

    final sezione = sezioneDelPercorso(percorso);
    if (sezione != null && !statoAccesso.profilo!.puoVedere(sezione)) {
      return statoAccesso.percorsoIniziale;
    }
    return null;
  },
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/senza-permessi', builder: (context, state) => const SenzaPermessiScreen()),
    GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
    GoRoute(path: '/calendar', builder: (context, state) => const CalendarScreen()),
    GoRoute(
      path: '/bookings',
      builder: (context, state) {
        final dateStr = state.uri.queryParameters['date'];
        final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
        final filter = state.uri.queryParameters['filter'];
        return BookingsScreen(initialDate: date, initialFilter: filter);
      },
    ),
    GoRoute(path: '/reservations', builder: (context, state) => const ReservationsScreen()),
    GoRoute(path: '/bookings/new', builder: (context, state) => const NewBookingScreen()),
    GoRoute(
      path: '/floor-plan/:date',
      builder: (context, state) {
        final dateStr = state.pathParameters['date']!;
        final date = DateTime.tryParse(dateStr) ?? DateTime.now();
        return FloorPlanScreen(date: date);
      },
    ),
    GoRoute(path: '/guests', builder: (context, state) => const GuestsScreen()),
    GoRoute(path: '/reports', builder: (context, state) => const ReportsScreen()),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
      routes: [
        GoRoute(path: 'tables', builder: (context, state) => const TablesScreen()),
        GoRoute(path: 'opening-hours', builder: (context, state) => const OpeningHoursScreen()),
        GoRoute(path: 'profile', builder: (context, state) => const RestaurantProfileScreen()),
        GoRoute(path: 'team', builder: (context, state) => const TeamScreen()),
      ],
    ),
  ],
);
