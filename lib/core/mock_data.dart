import 'models.dart';

/// Mocked marketplace data. Dates are relative to "now" so the prototype never
/// shows stale trips; the first trip departs in ~3 days at 14:00.
class MockData {
  const MockData._();

  static DateTime _at(int daysFromNow, int hour) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + daysFromNow, hour);
  }

  static const luis = Driver(
    id: 'd1',
    firstName: 'Luis',
    fullName: 'Luis Andrade Mora',
    operator: 'Coop. Transandina',
    rating: 4.8,
    ratingCount: 63,
    completedTrips: 112,
    verified: true,
    plate: 'GBA-1234',
    vehicle: Vehicle(
      bodyType: 'body_van',
      capacityTons: 10,
      freeTons: 6,
      freeM3: 24,
      insured: true,
      insuranceCoverage: 20000,
      tracking: true,
    ),
  );

  static const ana = Driver(
    id: 'd2',
    firstName: 'Ana',
    fullName: 'Ana Zambrano Vera',
    operator: 'Cía. Translitoral',
    rating: 4.6,
    ratingCount: 12,
    completedTrips: 18,
    verified: true,
    plate: 'MBC-5678',
    vehicle: Vehicle(
      bodyType: 'body_pickup',
      capacityTons: 3.5,
      freeTons: 2,
      freeM3: 9,
      insured: false,
      tracking: false,
    ),
  );

  static const carlos = Driver(
    id: 'd3',
    firstName: 'Carlos',
    fullName: 'Carlos Yépez Salas',
    operator: 'Coop. Cotopaxi',
    rating: 4.9,
    ratingCount: 140,
    completedTrips: 260,
    verified: true,
    plate: 'PCF-9012',
    vehicle: Vehicle(
      bodyType: 'body_flatbed',
      capacityTons: 20,
      freeTons: 12,
      freeM3: 40,
      insured: true,
      insuranceCoverage: 50000,
      tracking: true,
    ),
  );

  /// The signed-in driver of the prototype (the one who publishes on S07).
  static const me = Driver(
    id: 'me',
    firstName: 'Marco',
    fullName: 'Marco Villacís Ruiz',
    operator: 'Coop. Transandina',
    rating: 4.7,
    ratingCount: 9,
    completedTrips: 9,
    verified: true,
    plate: 'GCD-3456',
    vehicle: Vehicle(
      bodyType: 'body_van',
      capacityTons: 8,
      freeTons: 5,
      freeM3: 20,
      insured: true,
      insuranceCoverage: 15000,
      tracking: true,
    ),
  );

  static List<Trip> trips() => [
        Trip(
          id: 't1',
          driver: luis,
          origin: 'Guayaquil',
          destination: 'Quito',
          departure: _at(3, 14),
          price: 450,
          referencePrice: 750,
          referenceIsEstimate: true,
          isReturnLeg: true,
          cargoTypes: ['cargo_pallets', 'cargo_boxes'],
        ),
        Trip(
          id: 't2',
          driver: ana,
          origin: 'Manta',
          destination: 'Cuenca',
          departure: _at(4, 8),
          price: 180,
          referencePrice: null, // no local reference: no strike-through, no badge
          isReturnLeg: true,
          cargoTypes: ['cargo_boxes', 'cargo_furniture'],
        ),
        Trip(
          id: 't3',
          driver: carlos,
          origin: 'Quito',
          destination: 'Machala',
          departure: _at(5, 6),
          price: 620,
          referencePrice: 900,
          referenceIsEstimate: false,
          isReturnLeg: false,
          cargoTypes: ['cargo_machinery', 'cargo_pallets'],
        ),
      ];

  static List<Load> loads() => [
        Load(
          id: 'l1',
          shipperName: 'Ferretería El Sol',
          shipperRating: 4.5,
          origin: 'Durán',
          destination: 'Latacunga',
          date: _at(3, 10),
          cargoType: 'cargo_pallets',
          weightKg: 2400,
          volumeM3: 8,
          declaredValue: 3500,
          targetPrice: 320,
          detourKm: 12,
          requiredServices: ['svc_insured'],
        ),
        Load(
          id: 'l2',
          shipperName: 'Textiles Andinos',
          shipperRating: 4.9,
          origin: 'Milagro',
          destination: 'Ambato',
          date: _at(3, 15),
          cargoType: 'cargo_boxes',
          weightKg: 900,
          volumeM3: 6,
          declaredValue: 1200,
          targetPrice: 210,
          detourKm: 28,
          requiredServices: const [],
        ),
        Load(
          id: 'l3',
          shipperName: 'AgroCosta S.A.',
          shipperRating: 4.2,
          origin: 'Babahoyo',
          destination: 'Quito',
          date: _at(4, 9),
          cargoType: 'cargo_perishable',
          weightKg: 5200,
          volumeM3: 18,
          declaredValue: 8000,
          targetPrice: 480,
          detourKm: 55,
          requiredServices: ['svc_insured', 'svc_tracking'],
        ),
      ];

  static const cargoTypeKeys = [
    'cargo_pallets',
    'cargo_boxes',
    'cargo_furniture',
    'cargo_machinery',
    'cargo_perishable',
    'cargo_construction',
  ];

  static const bodyTypeKeys = [
    'body_van',
    'body_pickup',
    'body_flatbed',
    'body_refrigerated',
    'body_container',
  ];

  static const serviceKeys = ['svc_insured', 'svc_tracking'];
}
