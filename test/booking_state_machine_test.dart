import 'package:flutter_test/flutter_test.dart';
import 'package:smart_trucking/core/booking_state_machine.dart';
import 'package:smart_trucking/core/enums.dart';

void main() {
  group('BookingStateMachine (AE-79 4.5)', () {
    test('every booking state has a transition entry', () {
      for (final s in BookingStatus.values) {
        expect(BookingStateMachine.transitions.containsKey(s), isTrue, reason: '$s');
      }
    });

    test('happy path is allowed end to end', () {
      final path = BookingStateMachine.happyPath;
      for (var i = 0; i < path.length - 1; i++) {
        expect(BookingStateMachine.canTransition(path[i], path[i + 1]), isTrue,
            reason: '${path[i]} -> ${path[i + 1]}');
      }
    });

    test('diagram edges are allowed', () {
      const edges = <(BookingStatus, BookingStatus)>[
        (BookingStatus.offered, BookingStatus.offered), // counter-offer
        (BookingStatus.offered, BookingStatus.accepted),
        (BookingStatus.offered, BookingStatus.rejected),
        (BookingStatus.offered, BookingStatus.expired),
        (BookingStatus.accepted, BookingStatus.paid),
        (BookingStatus.accepted, BookingStatus.lapsed),
        (BookingStatus.accepted, BookingStatus.cancelled),
        (BookingStatus.paid, BookingStatus.cancelled),
        (BookingStatus.paid, BookingStatus.pickedUp),
        (BookingStatus.paid, BookingStatus.inDispute),
        (BookingStatus.pickedUp, BookingStatus.cancelled),
        (BookingStatus.pickedUp, BookingStatus.inTransit),
        (BookingStatus.pickedUp, BookingStatus.inDispute),
        (BookingStatus.inTransit, BookingStatus.delivered),
        (BookingStatus.inTransit, BookingStatus.inDispute),
        (BookingStatus.delivered, BookingStatus.confirmed),
        (BookingStatus.delivered, BookingStatus.inDispute),
        (BookingStatus.confirmed, BookingStatus.settled),
        (BookingStatus.inDispute, BookingStatus.settled),
      ];
      for (final (from, to) in edges) {
        expect(BookingStateMachine.canTransition(from, to), isTrue, reason: '$from -> $to');
      }
    });

    test('edges not in the diagram are rejected', () {
      const forbidden = <(BookingStatus, BookingStatus)>[
        (BookingStatus.offered, BookingStatus.paid),
        (BookingStatus.accepted, BookingStatus.pickedUp),
        (BookingStatus.paid, BookingStatus.delivered),
        (BookingStatus.delivered, BookingStatus.settled),
        (BookingStatus.inTransit, BookingStatus.cancelled),
        (BookingStatus.settled, BookingStatus.offered),
        (BookingStatus.cancelled, BookingStatus.paid),
      ];
      for (final (from, to) in forbidden) {
        expect(BookingStateMachine.canTransition(from, to), isFalse, reason: '$from -> $to');
        expect(() => BookingStateMachine.transition(from, to), throwsStateError);
      }
    });

    test('terminal states have no outgoing transitions', () {
      for (final s in BookingStateMachine.terminalStates) {
        expect(BookingStateMachine.transitions[s], isEmpty, reason: '$s');
        expect(BookingStateMachine.isTerminal(s), isTrue);
      }
    });

    test('cancel visible from accepted to pickedUp; dispute from paid onwards', () {
      expect(BookingStateMachine.cancellable,
          {BookingStatus.accepted, BookingStatus.paid, BookingStatus.pickedUp});
      expect(BookingStateMachine.disputable, containsAll([
        BookingStatus.paid,
        BookingStatus.pickedUp,
        BookingStatus.inTransit,
        BookingStatus.delivered,
      ]));
      expect(BookingStateMachine.disputable, isNot(contains(BookingStatus.accepted)));
    });

    test('listing effects are typed as ListingStatus, never BookingStatus', () {
      expect(BookingStateMachine.listingEffect(BookingStatus.paid), ListingStatus.booked);
      expect(BookingStateMachine.listingEffect(BookingStatus.settled), ListingStatus.closed);
      expect(BookingStateMachine.listingEffect(BookingStatus.rejected), ListingStatus.published);
      expect(BookingStateMachine.listingEffect(BookingStatus.expired), ListingStatus.published);
      expect(BookingStateMachine.listingEffect(BookingStatus.lapsed), ListingStatus.published);
      expect(BookingStateMachine.listingEffect(BookingStatus.cancelled), ListingStatus.published);
      expect(BookingStateMachine.listingEffect(BookingStatus.inTransit), isNull);
      // Compile-time: the return type is ListingStatus?, so no booking value
      // can leak into a listing. Runtime: enums are distinct types.
      for (final s in BookingStatus.values) {
        final e = BookingStateMachine.listingEffect(s);
        expect(e == null || ListingStatus.values.contains(e), isTrue);
      }
    });
  });

  group('ListingStateMachine', () {
    test('listing lifecycle', () {
      expect(ListingStateMachine.canTransition(ListingStatus.draft, ListingStatus.published), isTrue);
      expect(ListingStateMachine.canTransition(ListingStatus.published, ListingStatus.booked), isTrue);
      expect(ListingStateMachine.canTransition(ListingStatus.booked, ListingStatus.published), isTrue);
      expect(ListingStateMachine.canTransition(ListingStatus.booked, ListingStatus.closed), isTrue);
      expect(ListingStateMachine.canTransition(ListingStatus.published, ListingStatus.lapsed), isTrue);
      expect(ListingStateMachine.canTransition(ListingStatus.lapsed, ListingStatus.published), isFalse);
      expect(ListingStateMachine.canTransition(ListingStatus.closed, ListingStatus.published), isFalse);
      expect(() => ListingStateMachine.transition(ListingStatus.closed, ListingStatus.booked), throwsStateError);
    });

    test('the two enums share no values', () {
      final bookingNames = BookingStatus.values.map((e) => e.name).toSet();
      final listingNames = ListingStatus.values.map((e) => e.name).toSet();
      // `lapsed` exists in both on purpose (Caducada applies to trips and
      // bookings in the study) but they are distinct types.
      expect(BookingStatus.lapsed, isNot(equals(ListingStatus.lapsed)));
      expect(bookingNames.length, BookingStatus.values.length);
      expect(listingNames.length, ListingStatus.values.length);
    });
  });
}
