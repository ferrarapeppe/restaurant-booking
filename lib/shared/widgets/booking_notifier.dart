import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

class BookingNotifier extends StatefulWidget {
  final Widget child;
  const BookingNotifier({super.key, required this.child});

  @override
  State<BookingNotifier> createState() => _BookingNotifierState();
}

class _BookingNotifierState extends State<BookingNotifier> {
  static const _restaurantId = '2b126a92-24d5-4e83-b38c-dfc82035a0cf';
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _requestPermission();
    _subscribe();
  }

  void _requestPermission() {
    try {
      js.context.callMethod('eval', ['''
        if ("Notification" in window) {
          Notification.requestPermission();
        }
        if ("serviceWorker" in navigator) {
          navigator.serviceWorker.register("/firebase-messaging-sw.js");
        }
      ''']);
    } catch (_) {}
  }

  void _showNativeNotification(String title, String body) {
    try {
      js.context.callMethod('eval', ['''
        if ("Notification" in window && Notification.permission === "granted") {
          navigator.serviceWorker.ready.then(function(reg) {
            reg.showNotification("$title", {
              body: "$body",
              icon: "/icons/Icon-192.png",
              badge: "/icons/Icon-192.png",
              vibrate: [200, 100, 200],
              tag: "nuova-prenotazione",
              renotify: true,
            });
          });
        }
      ''']);
    } catch (_) {}
  }

  void _subscribe() {
    _channel = Supabase.instance.client
        .channel('bookings-web')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'restaurant_id',
            value: _restaurantId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            final source = record['source']?.toString() ?? '';
            if (source == 'web' && mounted) {
              final date = record['date']?.toString() ?? '';
              final time = record['time_start']?.toString().substring(0, 5) ?? '';
              final party = record['party_size']?.toString() ?? '?';
              _showNativeNotification(
                '🍽️ Nuova prenotazione web!',
                '$date alle $time • $party persone',
              );
              _showInAppNotification(record);
            }
          },
        )
        .subscribe();
  }

  void _showInAppNotification(Map<String, dynamic> record) {
    final date = record['date']?.toString() ?? '';
    final time = record['time_start']?.toString().substring(0, 5) ?? '';
    final party = record['party_size']?.toString() ?? '?';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 12),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.accent, width: 2),
        ),
        content: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accentLight, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.notifications_active, color: AppColors.accent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Nuova prenotazione web!', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
            Text('$date alle $time • $party persone', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ])),
        ]),
        action: SnackBarAction(label: 'OK', textColor: AppColors.accent, onPressed: () {}),
      ),
    );
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
