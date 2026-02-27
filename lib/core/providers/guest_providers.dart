import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_booking/data/models/booking_model.dart';
import 'package:restaurant_booking/data/repositories/guest_repository.dart';

final guestRepositoryProvider = Provider<GuestRepository>((ref) => GuestRepository());

final guestSearchProvider = StateProvider<String>((ref) => '');

final guestsProvider = FutureProvider.autoDispose<List<GuestModel>>((ref) async {
  final search = ref.watch(guestSearchProvider);
  return ref.watch(guestRepositoryProvider).getGuests(search: search);
});
