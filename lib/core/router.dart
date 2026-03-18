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

final router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
    GoRoute(path: '/calendar', builder: (context, state) => const CalendarScreen()),
    GoRoute(path: '/bookings', builder: (context, state) => const BookingsScreen()),
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
      ],
    ),
  ],
);
