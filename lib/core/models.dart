import 'enums.dart';

class Vehicle {
  const Vehicle({
    required this.bodyType,
    required this.capacityTons,
    required this.freeTons,
    required this.freeM3,
    required this.insured,
    this.insuranceCoverage,
    required this.tracking,
  });

  final String bodyType; // key in copy table: 'body_van', 'body_pickup', ...
  final double capacityTons;
  final double freeTons;
  final double freeM3;
  final bool insured;
  final int? insuranceCoverage; // USD
  final bool tracking;
}

class Driver {
  const Driver({
    required this.id,
    required this.firstName,
    required this.fullName,
    required this.operator,
    required this.rating,
    required this.ratingCount,
    required this.completedTrips,
    required this.verified,
    required this.vehicle,
    required this.plate,
  });

  final String id;
  final String firstName;
  final String fullName; // revealed only after payment (A5.3)
  final String operator;
  final double rating;
  final int ratingCount;
  final int completedTrips;
  final bool verified;
  final Vehicle vehicle;
  final String plate; // blurred before payment
}

class Trip {
  Trip({
    required this.id,
    required this.driver,
    required this.origin,
    required this.destination,
    required this.departure,
    required this.price,
    this.referencePrice,
    this.referenceIsEstimate = true,
    required this.isReturnLeg,
    this.instantBooking = true,
    this.cargoTypes = const [],
    this.status = ListingStatus.published,
  });

  final String id;
  final Driver driver;
  final String origin;
  final String destination;
  final DateTime departure;
  final int price;

  /// Reference price from the same zone (A3.5). `null` = no reference, so the
  /// card hides the strike-through price and the saving badge.
  final int? referencePrice;
  final bool referenceIsEstimate;
  final bool isReturnLeg;
  final bool instantBooking;
  final List<String> cargoTypes;
  ListingStatus status;

  int? get savingPercent => referencePrice == null
      ? null
      : (((referencePrice! - price) / referencePrice!) * 100).round();
}

class Load {
  Load({
    required this.id,
    required this.shipperName,
    required this.shipperRating,
    required this.origin,
    required this.destination,
    required this.date,
    required this.cargoType,
    required this.weightKg,
    required this.volumeM3,
    required this.declaredValue,
    required this.targetPrice,
    this.detourKm = 0,
    this.requiredServices = const [],
    this.status = ListingStatus.published,
  });

  final String id;
  final String shipperName;
  final double shipperRating;
  final String origin;
  final String destination;
  final DateTime date;
  final String cargoType; // copy key 'cargo_*'
  final int weightKg;
  final double volumeM3;
  final int declaredValue;
  final int targetPrice;
  final int detourKm;
  final List<String> requiredServices;
  ListingStatus status;
}

class Offer {
  const Offer({
    required this.id,
    required this.fromRole,
    required this.price,
    required this.message,
    required this.counterUsed,
  });

  final String id;
  final UserRole fromRole;
  final int price;
  final String message;

  /// One counter-offer per side (A6.1).
  final bool counterUsed;
}

class BookingEvent {
  const BookingEvent(this.status, this.at, {this.pendingSync = false});
  final BookingStatus status;
  final DateTime at;

  /// Written locally, not yet sent (4.7 offline queue, visual only).
  final bool pendingSync;
}

class Booking {
  Booking({
    required this.id,
    required this.trip,
    required this.load,
    required this.price,
    required this.status,
    required this.departure,
    this.offer,
    List<BookingEvent>? history,
    this.pendingSync = false,
    this.pendingUploads = 0,
  }) : history = history ?? [BookingEvent(status, DateTime.now())];

  final String id;
  final Trip trip;
  final Load? load;
  int price;
  BookingStatus status;

  /// Latest offer payload while the booking is `offered` (who sent it, the
  /// message, whether the counter-offer was used).
  Offer? offer;

  /// Listing this booking was opened on (the driver's trip or the shipper's
  /// load); used to list open offers on S08 / S15.
  String get listingId => load?.id ?? trip.id;
  final DateTime departure;
  final List<BookingEvent> history;
  bool pendingSync;
  int pendingUploads;

  /// Time left until departure as seen at [now]; callers pass the app clock
  /// so tests and demos control it.
  Duration untilDepartureAt(DateTime now) => departure.difference(now);
}

/// Driver onboarding (S04 / S05).
enum VerificationState { pending, approved, rejected, exhausted }

class DriverProfile {
  DriverProfile({
    this.name = '',
    this.email = '',
    this.marketingOptIn = false,
    this.verification = VerificationState.pending,
    this.completedBookings = 0,
    this.strikes = 0,
    this.rucProvided = false,
  });

  String name;
  String email;
  bool marketingOptIn;
  VerificationState verification;

  /// Settled bookings so far; drives the commission rate (A7.4).
  int completedBookings;

  /// Cancellation strikes (A10.4).
  int strikes;
  bool rucProvided;
}

class ShipperProfile {
  ShipperProfile({
    this.name = '',
    this.email = '',
    this.marketingOptIn = false,
    this.taxId = '',
    this.invoiceName = '',
    this.invoiceAddress = '',
    this.invoiceEmail = '',
    this.firstBookingDone = false,
  });

  String name;
  String email;
  bool marketingOptIn;
  String taxId; // cédula / RUC
  String invoiceName;
  String invoiceAddress;
  String invoiceEmail;
  bool firstBookingDone;

  bool get invoiceDataComplete => taxId.isNotEmpty && invoiceName.isNotEmpty;
}

/// S09 filter sheet model (section 4.3).
class LoadFilters {
  const LoadFilters({
    this.detourKm = 40, // A5.2 default, adjustable 10–80
    this.dateFrom,
    this.dateTo,
    this.cargoTypes = const {},
    this.fitsMyVehicle = true,
    this.minPrice = 0,
  });

  final int detourKm;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final Set<String> cargoTypes;
  final bool fitsMyVehicle;
  final int minPrice;

  LoadFilters copyWith({
    int? detourKm,
    DateTime? dateFrom,
    DateTime? dateTo,
    Set<String>? cargoTypes,
    bool? fitsMyVehicle,
    int? minPrice,
  }) =>
      LoadFilters(
        detourKm: detourKm ?? this.detourKm,
        dateFrom: dateFrom ?? this.dateFrom,
        dateTo: dateTo ?? this.dateTo,
        cargoTypes: cargoTypes ?? this.cargoTypes,
        fitsMyVehicle: fitsMyVehicle ?? this.fitsMyVehicle,
        minPrice: minPrice ?? this.minPrice,
      );

  int get activeCount =>
      (detourKm != 40 ? 1 : 0) +
      (dateFrom != null || dateTo != null ? 1 : 0) +
      (cargoTypes.isNotEmpty ? 1 : 0) +
      (!fitsMyVehicle ? 1 : 0) +
      (minPrice > 0 ? 1 : 0);
}

enum TripSort { bestMatch, price, date, rating }

enum InsuranceFilter { any, insuredOnly }

/// S12 filter sheet model (section 4.4).
class TripFilters {
  const TripFilters({
    this.dateFrom,
    this.dateTo,
    this.insurance = InsuranceFilter.any,
    this.minCoverage = 0,
    this.trackingOnly = false,
    this.bodyTypes = const {},
    this.minTons = 0,
    this.minM3 = 0,
    this.minRating = 0,
    this.sort = TripSort.bestMatch, // A5.1
  });

  final DateTime? dateFrom;
  final DateTime? dateTo;
  final InsuranceFilter insurance;
  final int minCoverage;
  final bool trackingOnly;
  final Set<String> bodyTypes;
  final double minTons;
  final double minM3;
  final double minRating;
  final TripSort sort;

  TripFilters copyWith({
    DateTime? dateFrom,
    DateTime? dateTo,
    InsuranceFilter? insurance,
    int? minCoverage,
    bool? trackingOnly,
    Set<String>? bodyTypes,
    double? minTons,
    double? minM3,
    double? minRating,
    TripSort? sort,
  }) =>
      TripFilters(
        dateFrom: dateFrom ?? this.dateFrom,
        dateTo: dateTo ?? this.dateTo,
        insurance: insurance ?? this.insurance,
        minCoverage: minCoverage ?? this.minCoverage,
        trackingOnly: trackingOnly ?? this.trackingOnly,
        bodyTypes: bodyTypes ?? this.bodyTypes,
        minTons: minTons ?? this.minTons,
        minM3: minM3 ?? this.minM3,
        minRating: minRating ?? this.minRating,
        sort: sort ?? this.sort,
      );

  int get activeCount =>
      (dateFrom != null || dateTo != null ? 1 : 0) +
      (insurance != InsuranceFilter.any ? 1 : 0) +
      (trackingOnly ? 1 : 0) +
      (bodyTypes.isNotEmpty ? 1 : 0) +
      (minTons > 0 ? 1 : 0) +
      (minM3 > 0 ? 1 : 0) +
      (minRating > 0 ? 1 : 0);
}

class AppNotification {
  const AppNotification({
    required this.at,
    required this.text,
    required this.channel,
  });
  final DateTime at;
  final String text;
  final String channel; // 'whatsapp' | 'push'
}
