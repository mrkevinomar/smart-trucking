import 'package:flutter/widgets.dart';

import 'booking_state_machine.dart';
import 'enums.dart';
import 'mock_data.dart';
import 'models.dart';
import 'money.dart';

/// In-memory state of the prototype. Nothing is persisted; the study's PWA
/// storage rules (tokens in HttpOnly cookies, queue scoped to the signed-in
/// user) are respected trivially because the mock keeps no tokens at all.
class AppState extends ChangeNotifier {
  AppState({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  // ---- Session -----------------------------------------------------------
  AppLocale locale = AppLocale.es;
  UserRole? role;
  String phone = '';
  bool largeText = false;
  bool shareLocation = false;

  /// Whether the PWA install sheet was already offered in this session.
  bool installSheetShown = false;
  int shipperHomeVisits = 0;

  // ---- Profiles ----------------------------------------------------------
  final DriverProfile driver = DriverProfile(name: 'Marco');
  final ShipperProfile shipper = ShipperProfile(name: 'Paula');

  // ---- Listings and bookings --------------------------------------------
  final List<Trip> marketTrips = MockData.trips();
  final List<Load> marketLoads = MockData.loads();
  final List<Trip> myTrips = [];
  final List<Load> myLoads = [];
  final Map<String, List<Offer>> offersByListing = {};
  final List<Booking> bookings = [];
  final List<AppNotification> notifications = [];

  int _seq = 0;
  String _nextId(String prefix) => '$prefix${++_seq}';

  // ---- Session actions ---------------------------------------------------
  void setLocale(AppLocale l) {
    if (locale == l) return;
    locale = l;
    notifyListeners();
  }

  void chooseRole(UserRole r) {
    role = r;
    notifyListeners();
  }

  void setLargeText(bool v) {
    largeText = v;
    notifyListeners();
  }

  void setShareLocation(bool v) {
    shareLocation = v;
    notifyListeners();
  }

  void markInstallSheetShown() {
    installSheetShown = true;
    notifyListeners();
  }

  /// Returns true when the install sheet should be shown now (4.3: after
  /// approval for drivers; 4.4: on the shipper's second visit to S11).
  bool shouldOfferInstall() => !installSheetShown;

  void visitShipperHome() {
    shipperHomeVisits++;
  }

  void resetSession() {
    role = null;
    phone = '';
    installSheetShown = false;
    shipperHomeVisits = 0;
    notifyListeners();
  }

  // ---- Driver ------------------------------------------------------------
  void setVerification(VerificationState s) {
    driver.verification = s;
    notifyListeners();
  }

  int get commissionPercent => Commission.ratePercent(driver.completedBookings);
  int netPayout(num price) => Commission.netPayout(price, driver.completedBookings);
  bool get earlyRateApplies =>
      driver.completedBookings < Commission.earlyBookings;

  Trip publishTrip({
    required String origin,
    required String destination,
    required DateTime departure,
    required int price,
    required bool isReturnLeg,
    required bool instantBooking,
    required List<String> cargoTypes,
  }) {
    final trip = Trip(
      id: _nextId('mt'),
      driver: MockData.me,
      origin: origin,
      destination: destination,
      departure: departure,
      price: price,
      referencePrice: (price * 1.6).round(),
      isReturnLeg: isReturnLeg,
      instantBooking: instantBooking,
      cargoTypes: cargoTypes,
      status: ListingStatus.published,
    );
    myTrips.insert(0, trip);
    notifyListeners();
    return trip;
  }

  void cancelTrip(Trip trip) {
    trip.status = ListingStateMachine.transition(trip.status, ListingStatus.closed);
    offersByListing.remove(trip.id);
    notifyListeners();
  }

  // ---- Shipper -----------------------------------------------------------
  Load publishLoad({
    required String origin,
    required String destination,
    required DateTime date,
    required String cargoType,
    required int weightKg,
    required double volumeM3,
    required int declaredValue,
    required int targetPrice,
    required List<String> requiredServices,
  }) {
    final load = Load(
      id: _nextId('ml'),
      shipperName: shipper.name,
      shipperRating: 4.7,
      origin: origin,
      destination: destination,
      date: date,
      cargoType: cargoType,
      weightKg: weightKg,
      volumeM3: volumeM3,
      declaredValue: declaredValue,
      targetPrice: targetPrice,
      requiredServices: requiredServices,
    );
    myLoads.insert(0, load);
    notifyListeners();
    return load;
  }

  // ---- Offers (S10) ------------------------------------------------------
  List<Offer> offersFor(String listingId) => offersByListing[listingId] ?? const [];

  /// Adds an offer on a listing. Mocked counterpart offers use [fromRole]
  /// opposite to the signed-in role.
  Offer addOffer(String listingId, UserRole fromRole, int price, String message,
      {bool counter = false}) {
    final offer = Offer(
      id: _nextId('o'),
      fromRole: fromRole,
      price: price,
      message: message,
      counterUsed: counter,
    );
    offersByListing.putIfAbsent(listingId, () => []).add(offer);
    notifyListeners();
    return offer;
  }

  void removeOffer(String listingId, Offer offer) {
    offersByListing[listingId]?.remove(offer);
    notifyListeners();
  }

  // ---- Bookings ----------------------------------------------------------
  Booking? bookingById(String id) {
    for (final b in bookings) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Creates a booking in an entry state (offered or accepted for instant
  /// booking, A6.3). Listing stays `published` until payment.
  Booking createBooking({
    required Trip trip,
    Load? load,
    required int price,
    required BookingStatus entry,
  }) {
    assert(BookingStateMachine.entryStates.contains(entry));
    final b = Booking(
      id: _nextId('b'),
      trip: trip,
      load: load,
      price: price,
      status: entry,
      departure: trip.departure,
      history: [BookingEvent(entry, _clock())],
    );
    bookings.insert(0, b);
    _notify(b, entry);
    notifyListeners();
    return b;
  }

  /// Applies a booking transition through the state machine and the listing
  /// side effect through the listing machine. Throws on invalid transitions.
  void advance(Booking b, BookingStatus to, {bool pendingSync = false}) {
    b.status = BookingStateMachine.transition(b.status, to);
    b.history.add(BookingEvent(to, _clock(), pendingSync: pendingSync));
    b.pendingSync = pendingSync;
    final effect = BookingStateMachine.listingEffect(to);
    if (effect != null && ListingStateMachine.canTransition(b.trip.status, effect)) {
      b.trip.status = ListingStateMachine.transition(b.trip.status, effect);
    }
    if (to == BookingStatus.settled && b.trip.driver.id == MockData.me.id) {
      driver.completedBookings++;
    }
    if (to == BookingStatus.paid) {
      shipper.firstBookingDone = true;
    }
    _notify(b, to);
    notifyListeners();
  }

  /// Driver cancellation: counts as a strike (A10.4).
  void driverCancel(Booking b) {
    driver.strikes++;
    advance(b, BookingStatus.cancelled);
  }

  void markSynced(Booking b) {
    b.pendingSync = false;
    notifyListeners();
  }

  void _notify(Booking b, BookingStatus s) {
    notifications.insert(
      0,
      AppNotification(
        at: _clock(),
        text: 'bn_${s.name}',
        channel: _moneyOrAppointment(s) ? 'whatsapp' : 'push',
      ),
    );
  }

  bool _moneyOrAppointment(BookingStatus s) => const {
        BookingStatus.accepted,
        BookingStatus.paid,
        BookingStatus.pickedUp,
        BookingStatus.delivered,
        BookingStatus.confirmed,
        BookingStatus.settled,
        BookingStatus.cancelled,
        BookingStatus.inDispute,
      }.contains(s);

  /// Payout date for a held payout (A7.2 D3): confirmation + 48 h + 5
  /// business days.
  DateTime heldPayoutDate(DateTime confirmedAt) {
    var d = confirmedAt.add(const Duration(hours: 48));
    var added = 0;
    while (added < 5) {
      d = d.add(const Duration(days: 1));
      if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) {
        added++;
      }
    }
    return d;
  }

  DateTime now() => _clock();
}

/// Provides [AppState] down the tree and rebuilds dependents on change.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing above this context');
    return scope!.notifier!;
  }

  /// Reads the state without registering a dependency; safe in `initState`.
  static AppState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing above this context');
    return scope!.notifier!;
  }
}
