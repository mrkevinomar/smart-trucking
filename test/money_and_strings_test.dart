import 'package:flutter_test/flutter_test.dart';
import 'package:smart_trucking/core/app_state.dart';
import 'package:smart_trucking/core/booking_state_machine.dart';
import 'package:smart_trucking/core/enums.dart';
import 'package:smart_trucking/core/mock_data.dart';
import 'package:smart_trucking/core/models.dart';
import 'package:smart_trucking/core/money.dart';
import 'package:smart_trucking/l10n/strings.dart';

void main() {
  group('Commission (A7.4)', () {
    test('10 % standard, 5 % on the first three bookings', () {
      expect(Commission.ratePercent(0), 5);
      expect(Commission.ratePercent(2), 5);
      expect(Commission.ratePercent(3), 10);
      expect(Commission.ratePercent(50), 10);
    });

    test('net payout matches the copy-table example (USD 450 → USD 405 at 10 %)', () {
      expect(Commission.netPayout(450, 3), 405);
      expect(Commission.netPayout(450, 0), 428); // 5 %: 427.5 rounds to 428
      expect(Commission.commissionAmount(450, 3), 45);
    });
  });

  group('RefundRule (A7.6)', () {
    const early = Duration(hours: 30);
    const late = Duration(hours: 5);
    test('paid, more than 24 h before departure: full refund', () {
      expect(RefundRule.outcome(BookingStatus.paid, early), RefundOutcome.full);
      expect(RefundRule.refund(450, BookingStatus.paid, early), 450);
      expect(RefundRule.penalty(450, BookingStatus.paid, early), 0);
    });
    test('paid, within 24 h: 20 % penalty (USD 450 → USD 360 + USD 90)', () {
      expect(RefundRule.outcome(BookingStatus.paid, late), RefundOutcome.partial);
      expect(RefundRule.refund(450, BookingStatus.paid, late), 360);
      expect(RefundRule.penalty(450, BookingStatus.paid, late), 90);
    });
    test('accepted (nothing paid): no refund and no penalty', () {
      expect(RefundRule.outcome(BookingStatus.accepted, early), RefundOutcome.nothingPaid);
      expect(RefundRule.refund(450, BookingStatus.accepted, late), 0);
    });
    test('after pickup the shipper has no refund path regardless of time', () {
      for (final s in [BookingStatus.pickedUp, BookingStatus.inTransit, BookingStatus.delivered]) {
        expect(RefundRule.outcome(s, early), RefundOutcome.notAllowed, reason: '$s');
        expect(RefundRule.refund(450, s, early), 0);
        expect(RefundRule.penalty(450, s, late), 0);
      }
    });
  });

  group('Strike rule (A10.4)', () {
    test('1st warning, 2nd ranking penalty, 3rd suspension', () {
      expect(strikeConsequence(0), StrikeConsequence.warning);
      expect(strikeConsequence(1), StrikeConsequence.rankingPenalty);
      expect(strikeConsequence(2), StrikeConsequence.suspension);
    });
  });

  group('Fmt (4.6 units and dates)', () {
    final d = DateTime(2026, 11, 26, 14, 0); // a Thursday
    test('ES: "jue 26 nov, 14:00", short "4 dic", USD 1.000', () {
      expect(Fmt.dateTime(d, AppLocale.es), 'jue 26 nov, 14:00');
      expect(Fmt.dateShort(DateTime(2026, 12, 4), AppLocale.es), '4 dic');
      expect(Fmt.usd(1000, AppLocale.es), 'USD 1.000');
      expect(Fmt.rating(4.8, AppLocale.es), '4,8');
    });
    test('EN: "Thu 26 Nov, 14:00", short "4 Dec", USD 1,000', () {
      expect(Fmt.dateTime(d, AppLocale.en), 'Thu 26 Nov, 14:00');
      expect(Fmt.dateShort(DateTime(2026, 12, 4), AppLocale.en), '4 Dec');
      expect(Fmt.usd(1000, AppLocale.en), 'USD 1,000');
      expect(Fmt.rating(4.8, AppLocale.en), '4.8');
    });
    test('24 h clock, no 12 h markers', () {
      expect(Fmt.dateTime(DateTime(2026, 11, 26, 19, 5), AppLocale.es), 'jue 26 nov, 19:05');
      expect(Fmt.dateTime(DateTime(2026, 11, 26, 19, 5), AppLocale.en), isNot(contains('PM')));
    });
  });

  group('Strings', () {
    test('ES and EN tables have identical keys', () {
      expect(Strings.es.keys.toSet(), Strings.en.keys.toSet());
    });
    test('net payout copy from the table', () {
      const es = Strings(AppLocale.es);
      const en = Strings(AppLocale.en);
      expect(es.f('net_payout', {'x': '405', 'rate': '10'}),
          'Recibes USD 405 después de la comisión del 10 %');
      expect(en.f('net_payout', {'x': '405', 'rate': '10'}),
          'You receive USD 405 after the 10 % commission');
    });
    test('every booking state has a label and a notification in both languages', () {
      for (final loc in AppLocale.values) {
        final t = Strings(loc);
        for (final s in BookingStatus.values) {
          expect(t.bookingLabel(s), isNot('bs_${s.name}'), reason: '$loc $s label');
          expect(t.bookingNotification(s), isNot('bn_${s.name}'), reason: '$loc $s notification');
        }
        for (final s in ListingStatus.values) {
          expect(t.listingLabel(s), isNot('ls_${s.name}'));
        }
      }
    });
    test('WhatsApp-style notifications carry no amounts (v1.8 rule)', () {
      for (final key in ['bn_offered', 'bn_pickedUp', 'bn_settled', 'bn_cancelled']) {
        expect(Strings.es[key], isNot(contains('USD')), reason: key);
        expect(Strings.en[key], isNot(contains('USD')), reason: key);
      }
    });
  });

  group('AppState', () {
    test('booking advance applies listing effect through the listing machine', () {
      final state = AppState(clock: () => DateTime(2026, 11, 27, 10));
      final trip = state.marketTrips.first;
      final b = state.createBooking(trip: trip, price: 450, entry: BookingStatus.accepted);
      expect(trip.status, ListingStatus.published);
      state.advance(b, BookingStatus.paid);
      expect(trip.status, ListingStatus.booked);
      state.advance(b, BookingStatus.pickedUp);
      state.advance(b, BookingStatus.inTransit);
      state.advance(b, BookingStatus.delivered);
      state.advance(b, BookingStatus.confirmed);
      state.advance(b, BookingStatus.settled);
      expect(trip.status, ListingStatus.closed);
      expect(b.history.map((e) => e.status).toList(), [
        BookingStatus.accepted,
        BookingStatus.paid,
        BookingStatus.pickedUp,
        BookingStatus.inTransit,
        BookingStatus.delivered,
        BookingStatus.confirmed,
        BookingStatus.settled,
      ]);
    });

    test('invalid advance throws and leaves state untouched', () {
      final state = AppState();
      final b = state.createBooking(trip: state.marketTrips.first, price: 450, entry: BookingStatus.accepted);
      expect(() => state.advance(b, BookingStatus.delivered), throwsStateError);
      expect(b.status, BookingStatus.accepted);
    });

    test('cancelled booking returns the listing to published', () {
      final state = AppState();
      final trip = state.marketTrips.first;
      final b = state.createBooking(trip: trip, price: 450, entry: BookingStatus.accepted);
      state.advance(b, BookingStatus.paid);
      expect(trip.status, ListingStatus.booked);
      state.advance(b, BookingStatus.cancelled);
      expect(trip.status, ListingStatus.published);
    });

    test('driver cancellation adds a strike', () {
      final state = AppState();
      final b = state.createBooking(trip: state.marketTrips.first, price: 450, entry: BookingStatus.accepted);
      state.driverCancel(b);
      expect(state.driver.strikes, 1);
      expect(b.status, BookingStatus.cancelled);
    });

    test('settling my own trip increments completed bookings (commission rate)', () {
      final state = AppState();
      final trip = state.publishTrip(
        origin: 'A', destination: 'B', departure: DateTime.now().add(const Duration(days: 2)),
        price: 400, isReturnLeg: true, instantBooking: true, cargoTypes: const [],
      );
      expect(trip.driver.id, MockData.me.id);
      expect(state.commissionPercent, 5);
      final b = state.createBooking(trip: trip, price: 400, entry: BookingStatus.accepted);
      for (final s in [
        BookingStatus.paid, BookingStatus.pickedUp, BookingStatus.inTransit,
        BookingStatus.delivered, BookingStatus.confirmed, BookingStatus.settled,
      ]) {
        state.advance(b, s);
      }
      expect(state.driver.completedBookings, 1);
    });

    test('offer lifecycle goes through the machine: offered → counter → accepted', () {
      final state = AppState();
      final trip = state.marketTrips.first;
      final b = state.sendOffer(trip: trip, fromRole: UserRole.shipper, price: 400, message: 'hola');
      expect(b.status, BookingStatus.offered);
      expect(state.offersFor(trip.id), [b]);
      expect(trip.status, ListingStatus.published);
      state.counterOffer(b, UserRole.driver, 430, 'mejor 430');
      expect(b.status, BookingStatus.offered);
      expect(b.price, 430);
      expect(b.offer!.counterUsed, isTrue);
      expect(b.history.map((e) => e.status).toList(), [BookingStatus.offered, BookingStatus.offered]);
      state.acceptOffer(b);
      expect(b.status, BookingStatus.accepted);
      expect(state.offersFor(trip.id), isEmpty);
    });

    test('withdrawn and declined offers are terminal and leave the listing published', () {
      final state = AppState();
      final trip = state.marketTrips.first;
      final w = state.sendOffer(trip: trip, fromRole: UserRole.shipper, price: 400);
      state.withdrawOffer(w);
      expect(w.status, BookingStatus.withdrawn);
      expect(BookingStateMachine.isTerminal(w.status), isTrue);
      expect(() => state.advance(w, BookingStatus.accepted), throwsStateError);
      final d = state.sendOffer(trip: trip, fromRole: UserRole.shipper, price: 400);
      state.declineOffer(d);
      expect(d.status, BookingStatus.rejected);
      expect(trip.status, ListingStatus.published);
      expect(state.offersFor(trip.id), isEmpty);
      expect(state.notifications.first.text, 'bn_rejected');
    });

    test('cancelling a trip expires its open offers', () {
      final state = AppState();
      final trip = state.publishTrip(
        origin: 'A', destination: 'B', departure: DateTime.now().add(const Duration(days: 2)),
        price: 400, isReturnLeg: true, instantBooking: true, cargoTypes: const [],
      );
      final o = state.sendOffer(trip: trip, fromRole: UserRole.shipper, price: 350);
      state.cancelTrip(trip);
      expect(o.status, BookingStatus.expired);
      expect(trip.status, ListingStatus.closed);
    });

    test('refund outcome uses booking state and the app clock', () {
      final now = DateTime(2026, 11, 27, 10);
      final state = AppState(clock: () => now);
      final soon = Trip(
        id: 'soon', driver: state.marketTrips.first.driver, origin: 'A', destination: 'B',
        departure: now.add(const Duration(hours: 5)), price: 450, isReturnLeg: true,
      );
      final b = state.createBooking(trip: soon, price: 450, entry: BookingStatus.accepted);
      expect(state.refundOutcome(b), RefundOutcome.nothingPaid);
      state.advance(b, BookingStatus.paid);
      expect(state.refundOutcome(b), RefundOutcome.partial);
      expect(state.refundAmount(b), 360);
      expect(state.penaltyAmount(b), 90);
      state.advance(b, BookingStatus.pickedUp);
      expect(state.refundOutcome(b), RefundOutcome.notAllowed);
      expect(BookingStateMachine.canCancel(b.status, UserRole.shipper), isFalse);
    });

    test('held payout date = confirmation + 48 h + 5 business days', () {
      final state = AppState();
      // Thu 26 Nov 2026 14:00 + 48 h = Sat 28 Nov; +5 business days = Fri 4 Dec.
      final d = state.heldPayoutDate(DateTime(2026, 11, 26, 14));
      expect(d.month, 12);
      expect(d.day, 4);
    });
  });
}
