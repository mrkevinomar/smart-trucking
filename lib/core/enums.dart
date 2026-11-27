/// Status of a *listing* (a published trip or a published load).
///
/// Kept deliberately separate from [BookingStatus]: a listing can stay
/// `published` while several offers (bookings) come and go. The AE-79 study
/// (section 4.5 and the QA / UX notes) requires that no transition mixes the
/// two objects, so each has its own enum and its own transition function in
/// `booking_state_machine.dart`.
enum ListingStatus {
  draft,
  published,

  /// A booking on this listing reached `paid`; the listing is off the market.
  booked,

  /// The trip reached its departure time without a booking (A3.4).
  lapsed,

  /// The booking on this listing was settled or the owner closed it.
  closed,
}

/// Status of a *booking* (an offer that may become a paid trip).
///
/// One value per node of the 4.5 state diagram that belongs to the booking.
/// `Publicada` in that diagram is the listing state before any booking exists
/// and is therefore [ListingStatus.published], not a value here.
enum BookingStatus {
  /// Ofertada — offer sent / received (a counter-offer keeps this state).
  offered,

  /// Aceptada — accepted, awaiting payment (2 h, A6.5).
  accepted,

  /// Rechazada — offer declined by the receiving side.
  rejected,

  /// Vencida — offer expired (24 h or departure, A6.2).
  expired,

  /// Retirada — offer withdrawn by the side that sent it (4.5
  /// "Ofertada → Publicada: retirada por quien la envió"). Terminal for the
  /// booking; the listing stays published.
  withdrawn,

  /// Caducada — accepted but not paid within 2 h (A6.5).
  lapsed,

  /// Pagada — escrow funded in the app.
  paid,

  /// Recogida — pickup evidence uploaded.
  pickedUp,

  /// EnTransito — on the way.
  inTransit,

  /// Entregada — delivery evidence uploaded, waiting 48 h confirmation.
  delivered,

  /// Confirmada — shipper confirmed or 48 h passed.
  confirmed,

  /// Liquidada — payout sent net of commission.
  settled,

  /// Cancelada — cancelled by either party.
  cancelled,

  /// EnDisputa — a problem was reported.
  inDispute,
}

enum UserRole { driver, shipper }

enum ListingKind { trip, load }

/// UI language. Spanish is the default (4.1 principle 5).
enum AppLocale { es, en }
