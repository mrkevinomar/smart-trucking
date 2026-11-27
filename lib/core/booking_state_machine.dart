import 'enums.dart';

/// Booking state machine from AE-79 section 4.5.
///
/// The functions here are typed on [BookingStatus] only. Listing transitions
/// live in [ListingStateMachine]; a booking transition never changes a listing
/// directly, it only *reports* the side effect on the listing through
/// [listingEffect] so the caller applies it with the listing's own machine.
class BookingStateMachine {
  const BookingStateMachine._();

  /// Allowed next states for each booking state (4.5 diagram, booking nodes).
  static const Map<BookingStatus, Set<BookingStatus>> transitions = {
    BookingStatus.offered: {
      BookingStatus.offered, // one counter-offer per side (A6.1)
      BookingStatus.accepted,
      BookingStatus.rejected,
      BookingStatus.expired, // 24 h or departure (A6.2)
      BookingStatus.withdrawn, // withdrawn by the sender; listing stays published
    },
    BookingStatus.accepted: {
      BookingStatus.paid, // escrow funded in the app
      BookingStatus.lapsed, // no payment after 2 h (A6.5)
      BookingStatus.cancelled, // either party
    },
    BookingStatus.paid: {
      BookingStatus.cancelled, // refund rules (A7.6)
      BookingStatus.pickedUp, // pickup evidence
      BookingStatus.inDispute, // no-show or pickup problem (A10.5)
    },
    BookingStatus.pickedUp: {
      BookingStatus.cancelled, // driver strike (A10.4)
      BookingStatus.inTransit,
      BookingStatus.inDispute,
    },
    BookingStatus.inTransit: {
      BookingStatus.delivered, // delivery evidence
      BookingStatus.inDispute,
    },
    BookingStatus.delivered: {
      BookingStatus.confirmed, // shipper confirms or 48 h
      BookingStatus.inDispute, // within 48 h (A10.1)
    },
    BookingStatus.confirmed: {
      BookingStatus.settled, // payout net of commission
    },
    BookingStatus.inDispute: {
      BookingStatus.settled, // ops decision, 5 business days
    },
    BookingStatus.rejected: {},
    BookingStatus.expired: {},
    BookingStatus.withdrawn: {},
    BookingStatus.lapsed: {},
    BookingStatus.cancelled: {},
    BookingStatus.settled: {},
  };

  /// States in which a booking can be created from a published listing.
  /// `offered` via S10; `accepted` directly via instant booking (A6.3).
  static const Set<BookingStatus> entryStates = {
    BookingStatus.offered,
    BookingStatus.accepted,
  };

  /// Terminal for the booking itself.
  static const Set<BookingStatus> terminalStates = {
    BookingStatus.rejected,
    BookingStatus.expired,
    BookingStatus.withdrawn,
    BookingStatus.lapsed,
    BookingStatus.cancelled,
    BookingStatus.settled,
  };

  /// "Cancelar reserva" is visible from Aceptada to Recogida (4.4 S16), but
  /// Recogida → Cancelada exists only as a driver fault (A10.4): after pickup
  /// the shipper has no refund path (A7.6) and must use "Reportar un problema".
  static const Set<BookingStatus> cancellableByDriver = {
    BookingStatus.accepted,
    BookingStatus.paid,
    BookingStatus.pickedUp,
  };

  static const Set<BookingStatus> cancellableByShipper = {
    BookingStatus.accepted,
    BookingStatus.paid,
  };

  static bool canCancel(BookingStatus s, UserRole role) => role == UserRole.driver
      ? cancellableByDriver.contains(s)
      : cancellableByShipper.contains(s);

  /// "Reportar un problema" is available from Pagada onwards (A10.5).
  static const Set<BookingStatus> disputable = {
    BookingStatus.paid,
    BookingStatus.pickedUp,
    BookingStatus.inTransit,
    BookingStatus.delivered,
  };

  static bool canTransition(BookingStatus from, BookingStatus to) =>
      transitions[from]!.contains(to);

  static bool isTerminal(BookingStatus s) => terminalStates.contains(s);

  /// Applies a transition or throws [StateError] if it is not in the diagram.
  static BookingStatus transition(BookingStatus from, BookingStatus to) {
    if (!canTransition(from, to)) {
      throw StateError('Booking transition not allowed: $from -> $to');
    }
    return to;
  }

  /// The effect a booking transition has on the listing it belongs to.
  ///
  /// Returns `null` when the listing is untouched. The caller applies the
  /// returned value with [ListingStateMachine.transition]; this keeps the two
  /// objects separate while documenting the coupling from the diagram text
  /// ("Rechazada, Vencida and a withdrawn offer return the trip and the load
  /// to Publicada").
  static ListingStatus? listingEffect(BookingStatus to) {
    switch (to) {
      case BookingStatus.paid:
        return ListingStatus.booked;
      case BookingStatus.settled:
        return ListingStatus.closed;
      case BookingStatus.rejected:
      case BookingStatus.expired:
      case BookingStatus.withdrawn:
      case BookingStatus.lapsed:
      case BookingStatus.cancelled:
        return ListingStatus.published; // listing stays / returns to market
      case BookingStatus.offered:
      case BookingStatus.accepted:
      case BookingStatus.pickedUp:
      case BookingStatus.inTransit:
      case BookingStatus.delivered:
      case BookingStatus.confirmed:
      case BookingStatus.inDispute:
        return null;
    }
  }

  /// The happy path, in order, used by the S16 timeline component.
  static const List<BookingStatus> happyPath = [
    BookingStatus.offered,
    BookingStatus.accepted,
    BookingStatus.paid,
    BookingStatus.pickedUp,
    BookingStatus.inTransit,
    BookingStatus.delivered,
    BookingStatus.confirmed,
    BookingStatus.settled,
  ];
}

/// Listing (trip / load) state machine. Independent of bookings.
class ListingStateMachine {
  const ListingStateMachine._();

  static const Map<ListingStatus, Set<ListingStatus>> transitions = {
    ListingStatus.draft: {ListingStatus.published},
    ListingStatus.published: {
      ListingStatus.published, // offers come and go, listing stays live
      ListingStatus.booked,
      ListingStatus.lapsed, // departure reached without booking (A3.4)
      ListingStatus.closed, // owner cancels / closes the listing
    },
    ListingStatus.booked: {
      ListingStatus.published, // booking cancelled or lapsed, back on market
      ListingStatus.closed,
    },
    ListingStatus.lapsed: {},
    ListingStatus.closed: {},
  };

  static bool canTransition(ListingStatus from, ListingStatus to) =>
      transitions[from]!.contains(to);

  static ListingStatus transition(ListingStatus from, ListingStatus to) {
    if (!canTransition(from, to)) {
      throw StateError('Listing transition not allowed: $from -> $to');
    }
    return to;
  }
}
