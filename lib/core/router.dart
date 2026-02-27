import 'package:go_router/go_router.dart';
import 'package:restaurant_booking/features/splash/splash_screen.dart';
import 'package:restaurant_booking/features/dashboard/dashboard_screen.dart';
import 'package:restaurant_booking/features/calendar/calendar_screen.dart';
import 'package:restaurant_booking/features/bookings/bookings_screen.dart';
import 'package:restaurant_booking/features/bookings/new_booking_screen.dart';
import 'package:restaurant_booking/features/bookings/booking_detail_screen.dart';
import 'package:restaurant_booking/data/models/booking_model.dart';
import 'package:restaurant_booking/features/bookings/booking_detail_screen.dart';
import 'package:restaurant_booking/data/models/booking_model.dart';
import 'package:restaurant_booking/features/guests/guests_screen.dart';
import 'package:restaurant_booking/features/reports/reports_screen.dart';
import 'package:restaurant_booking/features/settings/settings_screen.dart';
import 'package:restaurant_booking/features/bookings/reservations_screen.dart';
import 'package:restaurant_booking/features/floorplan/floorplan_screen.dart';
import 'package:restaurant_booking/features/floorplan/manage_areas_screen.dart';

final router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
    GoRoute(path: '/calendar', builder: (context, state) => const CalendarScreen()),
    GoRoute(path: '/bookings', builder: (context, state) => const BookingsScreen()),
    GoRoute(path: '/bookings/new', builder: (context, state) => const NewBookingScreen()),
    GoRoute(path: '/bookings/detail', builder: (context, state) { final booking = state.extra as BookingModel; return BookingDetailScreen(booking: booking); }),
    GoRoute(
      path: '/bookings/:id',
      builder: (context, state) {
        final booking = state.extra as dynamic;
        return BookingDetailScreen(booking: booking);
      },
    ),
    GoRoute(path: '/guests', builder: (context, state) => const GuestsScreen()),
    GoRoute(path: '/reports', builder: (context, state) => const ReportsScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    GoRoute(path: '/reservations', builder: (context, state) => const ReservationsScreen()),
    GoRoute(path: '/floorplan', builder: (context, state) => const FloorplanScreen()),
    GoRoute(path: '/floorplan/manage', builder: (context, state) => const ManageAreasScreen()),
  ],
);
