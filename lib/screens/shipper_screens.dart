import 'package:flutter/material.dart';

import '../app.dart';
import '../core/app_state.dart';
import '../core/enums.dart';
import '../core/mock_data.dart';
import '../core/models.dart';
import '../core/money.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'shared_screens.dart';

/// Shipper booking entry: S03 (first booking only) → S17.
Future<void> shipperBookAndPay(BuildContext context, Booking b) async {
  final state = AppScope.of(context);
  if (!state.shipper.invoiceDataComplete) {
    final ok = await Navigator.pushNamed(context, Routes.s03, arguments: 'invoice');
    if (ok != true || !context.mounted) return;
  }
  if (!context.mounted) return;
  Navigator.pushNamed(context, Routes.s17, arguments: b.id);
}

// ---------------------------------------------------------------------------
// S11 Shipper home
// ---------------------------------------------------------------------------
class S11ShipperHome extends StatefulWidget {
  const S11ShipperHome({super.key});

  @override
  State<S11ShipperHome> createState() => _S11ShipperHomeState();
}

class _S11ShipperHomeState extends State<S11ShipperHome> {
  @override
  void initState() {
    super.initState();
    final state = AppScope.read(context);
    state.visitShipperHome();
    // 4.4: install sheet on the second visit.
    if (state.shipperHomeVisits >= 2 && state.shouldOfferInstall()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showInstallSheet(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = AppScope.of(context);
    final locale = state.locale;
    final scheme = Theme.of(context).colorScheme;
    final myBookings = state.bookings.where((b) => b.trip.driver.id != MockData.me.id).toList();

    return AppScreen(
      title: t.f('s11_title', {'name': state.shipper.name}),
      screenId: 'S11',
      leading: const SizedBox.shrink(),
      actions: [
        IconButton(
          key: const Key('s11_notifications'),
          tooltip: t('notifications'),
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => Navigator.pushNamed(context, Routes.s22),
        ),
        IconButton(
          key: const Key('s11_settings'),
          tooltip: t('settings'),
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.pushNamed(context, Routes.s23),
        ),
      ],
      bottom: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              key: const Key('s11_search'),
              onPressed: () => Navigator.pushNamed(context, Routes.s12),
              icon: const Icon(Icons.search),
              label: Text(t('s11_search')),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('s11_publish_load'),
              onPressed: () => Navigator.pushNamed(context, Routes.s14),
              icon: const Icon(Icons.add_box_outlined),
              label: Text(t('s11_publish_load')),
            ),
          ),
        ],
      ),
      children: [
        const SizedBox(height: 8),
        Semantics(
          button: true,
          label: t('s11_search'),
          child: InkWell(
            key: const Key('s11_search_box'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.pushNamed(context, Routes.s12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t('s11_search_hint'), style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant))),
                ],
              ),
            ),
          ),
        ),
        if (!state.installSheetShown)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Card(
              child: ListTile(
                key: const Key('s11_install_banner'),
                leading: const Icon(Icons.install_mobile, color: AppTheme.primary),
                title: Text(t('s11_install_banner')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showInstallSheet(context),
              ),
            ),
          ),
        SectionTitle(t('s11_my_loads')),
        if (state.myLoads.isEmpty)
          Text(t('s11_no_loads'), style: TextStyle(color: scheme.onSurfaceVariant))
        else
          for (final l in state.myLoads)
            Card(
              key: Key('s11_load_${l.id}'),
              child: ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text('${l.origin} → ${l.destination}'),
                subtitle: Text('${Fmt.dateLong(l.date, locale)} · ${t.listingLabel(l.status)}'),
                trailing: Text(Fmt.usd(l.targetPrice, locale), style: const TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => Navigator.pushNamed(context, Routes.s15, arguments: l.id),
              ),
            ),
        SectionTitle(t('s11_recent')),
        if (myBookings.isEmpty)
          Text(t('s22_empty'), style: TextStyle(color: scheme.onSurfaceVariant))
        else
          for (final b in myBookings)
            Card(
              key: Key('s11_booking_${b.id}'),
              child: ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text('${b.trip.origin} → ${b.trip.destination}'),
                subtitle: Text(t.bookingLabel(b.status, viewer: UserRole.shipper)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, Routes.s16, arguments: b.id),
              ),
            ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// S12 Search results (trips) + chip row + filter sheet
// ---------------------------------------------------------------------------
class S12SearchTrips extends StatefulWidget {
  const S12SearchTrips({super.key});

  @override
  State<S12SearchTrips> createState() => _S12SearchTripsState();
}

class _S12SearchTripsState extends State<S12SearchTrips> {
  TripFilters _f = const TripFilters();
  final _searchController = TextEditingController(text: 'Guayaquil → Quito');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Trip> _apply(List<Trip> trips) {
    final out = trips.where((tr) {
      if (tr.status != ListingStatus.published) return false;
      final v = tr.driver.vehicle;
      if (_f.insurance == InsuranceFilter.insuredOnly && !v.insured) return false;
      if (_f.minCoverage > 0 && (v.insuranceCoverage ?? 0) < _f.minCoverage) return false;
      if (_f.trackingOnly && !v.tracking) return false;
      if (_f.bodyTypes.isNotEmpty && !_f.bodyTypes.contains(v.bodyType)) return false;
      if (v.freeTons < _f.minTons) return false;
      if (v.freeM3 < _f.minM3) return false;
      if (tr.driver.rating < _f.minRating) return false;
      if (_f.dateFrom != null && tr.departure.isBefore(_f.dateFrom!)) return false;
      if (_f.dateTo != null && tr.departure.isAfter(_f.dateTo!)) return false;
      return true;
    }).toList();
    out.sort((a, b) => switch (_f.sort) {
          TripSort.price => a.price.compareTo(b.price),
          TripSort.date => a.departure.compareTo(b.departure),
          TripSort.rating => b.driver.rating.compareTo(a.driver.rating),
          TripSort.bestMatch => (b.isReturnLeg ? 1 : 0).compareTo(a.isReturnLeg ? 1 : 0),
        });
    return out;
  }

  Future<void> _openFilters() async {
    final r = await showModalBottomSheet<TripFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TripFilterSheet(initial: _f),
    );
    if (r != null) setState(() => _f = r);
  }

  void _book(Trip trip) {
    final state = AppScope.of(context);
    final b = state.createBooking(trip: trip, price: trip.price, entry: BookingStatus.accepted);
    shipperBookAndPay(context, b);
  }

  void _offer(Trip trip) => Navigator.pushNamed(context, Routes.s10, arguments: OfferArgs(trip: trip, initialPrice: trip.price - 30));

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = AppScope.of(context);
    final results = _apply(state.marketTrips);
    final scheme = Theme.of(context).colorScheme;
    final locale = state.locale;

    final sortLabels = {
      TripSort.bestMatch: t('s12_sort_best'),
      TripSort.price: t('s12_sort_price'),
      TripSort.date: t('s12_sort_date'),
      TripSort.rating: t('s12_sort_rating'),
    };

    return AppScreen(
      title: t('s12_title'),
      screenId: 'S12',
      children: [
        Semantics(
          label: t('s11_search'),
          textField: true,
          child: TextField(
            key: const Key('s12_search_box'),
            decoration: InputDecoration(
              labelText: t('s11_search'),
              hintText: t('s11_search_hint'),
              prefixIcon: const Icon(Icons.search),
            ),
            controller: _searchController,
          ),
        ),
        const SizedBox(height: 10),
        // Chip row: "Filtros" + active filters as removable chips (4.4).
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ActionChip(
                key: const Key('s12_filters'),
                avatar: const Icon(Icons.tune, size: 18),
                label: Text(_f.activeCount > 0 ? '${t('s12_filters')} (${_f.activeCount})' : t('s12_filters')),
                onPressed: _openFilters,
              ),
              const SizedBox(width: 6),
              if (_f.insurance == InsuranceFilter.insuredOnly)
                _chip(t('s12_f_insurance_only'), () => _f = _f.copyWith(insurance: InsuranceFilter.any)),
              if (_f.trackingOnly) _chip(t('s12_f_tracking'), () => _f = _f.copyWith(trackingOnly: false)),
              for (final b in _f.bodyTypes) _chip(t(b), () => _f = _f.copyWith(bodyTypes: {..._f.bodyTypes}..remove(b))),
              if (_f.minTons > 0) _chip('≥ ${t.f('unit_tons', {'t': '${_f.minTons.toInt()}'})}', () => _f = _f.copyWith(minTons: 0)),
              if (_f.minM3 > 0) _chip('≥ ${t.f('unit_m3', {'x': '${_f.minM3.toInt()}'})}', () => _f = _f.copyWith(minM3: 0)),
              if (_f.minRating > 0) _chip('★ ≥ ${Fmt.rating(_f.minRating, locale)}', () => _f = _f.copyWith(minRating: 0)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Sort chips above the list (A5.1 default best match).
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final s in TripSort.values) ...[
                ChoiceChip(
                  key: Key('s12_sort_${s.name}'),
                  label: Text(sortLabels[s]!),
                  selected: _f.sort == s,
                  onSelected: (_) => setState(() => _f = _f.copyWith(sort: s)),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (results.isEmpty) InfoBanner(key: const Key('s12_no_results'), text: t('s12_no_results'), icon: Icons.search_off),
        for (final tr in results) ...[
          TripCard(
            trip: tr,
            onBook: () => _book(tr),
            onOffer: () => _offer(tr),
            onTap: () => Navigator.pushNamed(context, Routes.s13, arguments: tr.id),
          ),
          const SizedBox(height: 10),
        ],
        Text(t('s12_plate_note'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _chip(String label, VoidCallback onDelete) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: InputChip(label: Text(label), onDeleted: () => setState(onDelete)),
      );
}

/// S12 bottom sheet (4.4 "Filtros de S12"): date range, insurance, tracking,
/// body type, min tonnage, min dimensions, rating; "Aplicar" fixed, "Limpiar".
class TripFilterSheet extends StatefulWidget {
  const TripFilterSheet({super.key, required this.initial});
  final TripFilters initial;

  @override
  State<TripFilterSheet> createState() => _TripFilterSheetState();
}

class _TripFilterSheetState extends State<TripFilterSheet> {
  late TripFilters f = widget.initial;
  int _dateDays = 0;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final locale = AppScope.of(context).locale;
    return FilterSheetFrame(
      title: t('s12_filters'),
      onClear: () => setState(() {
        f = TripFilters(sort: f.sort);
        _dateDays = 0;
      }),
      onApply: () => Navigator.pop(context, f),
      children: [
        SectionTitle(t('s12_f_dates')),
        Wrap(
          spacing: 8,
          children: [
            for (final d in [0, 3, 7])
              ChoiceChip(
                label: Text(d == 0 ? t('s12_f_insurance_any') : '≤ ${Fmt.dateShort(DateTime.now().add(Duration(days: d)), locale)}'),
                selected: _dateDays == d,
                onSelected: (_) => setState(() {
                  _dateDays = d;
                  f = TripFilters(
                    insurance: f.insurance,
                    minCoverage: f.minCoverage,
                    trackingOnly: f.trackingOnly,
                    bodyTypes: f.bodyTypes,
                    minTons: f.minTons,
                    minM3: f.minM3,
                    minRating: f.minRating,
                    sort: f.sort,
                    dateFrom: d == 0 ? null : DateTime.now(),
                    dateTo: d == 0 ? null : DateTime.now().add(Duration(days: d, hours: 23)),
                  );
                }),
              ),
          ],
        ),
        SectionTitle(t('s12_f_insurance')),
        SegmentedButton<InsuranceFilter>(
          key: const Key('s12_f_insurance'),
          segments: [
            ButtonSegment(value: InsuranceFilter.any, label: Text(t('s12_f_insurance_any'))),
            ButtonSegment(value: InsuranceFilter.insuredOnly, label: Text(t('s12_f_insurance_only'))),
          ],
          selected: {f.insurance},
          onSelectionChanged: (s) => setState(() => f = f.copyWith(insurance: s.first)),
        ),
        if (f.insurance == InsuranceFilter.insuredOnly)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: StepperRow(
              label: t('s12_f_min_coverage'),
              value: Fmt.usd(f.minCoverage, locale),
              onMinus: f.minCoverage > 0 ? () => setState(() => f = f.copyWith(minCoverage: f.minCoverage - 5000)) : null,
              onPlus: () => setState(() => f = f.copyWith(minCoverage: f.minCoverage + 5000)),
            ),
          ),
        SwitchListTile(
          key: const Key('s12_f_tracking'),
          value: f.trackingOnly,
          onChanged: (v) => setState(() => f = f.copyWith(trackingOnly: v)),
          title: Text(t('s12_f_tracking')),
          contentPadding: EdgeInsets.zero,
        ),
        SectionTitle(t('s12_f_body')),
        ChipSet(
          keys: MockData.bodyTypeKeys,
          selected: f.bodyTypes,
          onToggle: (k, on) => setState(() {
            final s = {...f.bodyTypes};
            on ? s.add(k) : s.remove(k);
            f = f.copyWith(bodyTypes: s);
          }),
        ),
        SectionTitle(t('s12_f_min_tons')),
        StepperRow(
          key: const Key('s12_f_min_tons'),
          label: t('s12_f_min_tons'),
          value: t.f('unit_tons', {'t': '${f.minTons.toInt()}'}),
          onMinus: f.minTons > 0 ? () => setState(() => f = f.copyWith(minTons: f.minTons - 1)) : null,
          onPlus: f.minTons < 30 ? () => setState(() => f = f.copyWith(minTons: f.minTons + 1)) : null,
        ),
        SectionTitle(t('s12_f_min_m3')),
        StepperRow(
          label: t('s12_f_min_m3'),
          value: t.f('unit_m3', {'x': '${f.minM3.toInt()}'}),
          onMinus: f.minM3 > 0 ? () => setState(() => f = f.copyWith(minM3: f.minM3 - 5)) : null,
          onPlus: f.minM3 < 100 ? () => setState(() => f = f.copyWith(minM3: f.minM3 + 5)) : null,
        ),
        SectionTitle(t('s12_f_rating')),
        Wrap(
          spacing: 8,
          children: [
            for (final r in [0.0, 4.0, 4.5, 4.8])
              ChoiceChip(
                label: Text(r == 0 ? t('s12_f_insurance_any') : '★ ≥ ${Fmt.rating(r, locale)}'),
                selected: f.minRating == r,
                onSelected: (_) => setState(() => f = f.copyWith(minRating: r)),
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// S13 Trip detail (shipper view)
// ---------------------------------------------------------------------------
class S13TripDetailShipper extends StatelessWidget {
  const S13TripDetailShipper({super.key, required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = AppScope.of(context);
    final locale = state.locale;
    final trip = state.marketTrips.firstWhere((x) => x.id == tripId);
    final d = trip.driver;
    final v = d.vehicle;
    final scheme = Theme.of(context).colorScheme;

    void book() {
      final b = state.createBooking(trip: trip, price: trip.price, entry: BookingStatus.accepted);
      shipperBookAndPay(context, b);
    }

    return AppScreen(
      title: t('s13_title'),
      screenId: 'S13',
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            key: const Key('s13_book'),
            label: t('s13_book_instant'),
            icon: Icons.bolt,
            onPressed: trip.instantBooking ? book : null,
          ),
          const SizedBox(height: 8),
          SecondaryButton(
            key: const Key('s13_offer'),
            label: t('s12_offer'),
            onPressed: () => Navigator.pushNamed(context, Routes.s10, arguments: OfferArgs(trip: trip, initialPrice: trip.price - 30)),
          ),
        ],
      ),
      children: [
        Text('${trip.origin} → ${trip.destination}', style: Theme.of(context).textTheme.titleLarge),
        Text(Fmt.dateTime(trip.departure, locale), style: TextStyle(color: scheme.onSurfaceVariant)),
        if (!trip.instantBooking) InfoBanner(text: t('s13_instant_off')),
        SectionTitle(t('s13_driver')),
        Card(
          child: ListTile(
            leading: const PhotoPlaceholder(size: 48, icon: Icons.person_outline),
            title: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(d.firstName, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (d.verified) Badge16(icon: Icons.verified_outlined, label: t('badge_verified'), color: AppTheme.success),
              ],
            ),
            subtitle: Text('${t('s13_operator')}: ${d.operator}\n★ ${Fmt.rating(d.rating, locale)} (${d.ratingCount}) · ${t.f('s13_trips_done', {'n': '${d.completedTrips}'})}'),
            isThreeLine: true,
          ),
        ),
        SectionTitle(t('s13_vehicle')),
        Row(
          children: [
            PhotoPlaceholder(size: 80, label: t('s12_plate_note')),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${t(v.bodyType)} ${t.f('unit_tons', {'t': '${v.capacityTons.toInt()}'})}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  Text(t.f('s12_free', {'t': '${v.freeTons.toInt()}', 'm': '${v.freeM3.toInt()}'})),
                  Text(t('s12_plate_note'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
        SectionTitle(t('s13_services')),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (v.insured) Badge16(icon: Icons.shield_outlined, label: v.insuranceCoverage == null ? t('svc_insured') : t.f('svc_insured_amount', {'x': Fmt.integer(v.insuranceCoverage!, locale)})),
            if (v.tracking) Badge16(icon: Icons.location_searching, label: t('svc_tracking')),
            if (trip.isReturnLeg) Badge16(icon: Icons.u_turn_left, label: t('badge_return'), color: AppTheme.secondary),
            for (final c in trip.cargoTypes) Badge16(icon: Icons.inventory_2_outlined, label: t(c), color: scheme.outline),
          ],
        ),
        SectionTitle(t('s13_price')),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            Text(Fmt.usd(trip.price, locale), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
            if (trip.referencePrice != null) ...[
              Text('${t.f('s12_before', {'x': Fmt.integer(trip.referencePrice!, locale)})}${trip.referenceIsEstimate ? ' ${t('s12_estimate')}' : ''}',
                  style: TextStyle(decoration: TextDecoration.lineThrough, color: scheme.onSurfaceVariant)),
              Badge16(icon: Icons.savings_outlined, label: t.f('s12_save', {'p': '${trip.savingPercent}'}), color: AppTheme.success),
            ] else
              Text(t('s12_no_reference'), style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 8),
        InfoBanner(text: t('s16_escrow'), icon: Icons.lock_outline, color: AppTheme.success),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// S14 Publish load (2 steps)
// ---------------------------------------------------------------------------
class S14PublishLoad extends StatefulWidget {
  const S14PublishLoad({super.key});

  @override
  State<S14PublishLoad> createState() => _S14PublishLoadState();
}

class _S14PublishLoadState extends State<S14PublishLoad> {
  int _step = 0;
  final _origin = TextEditingController(text: 'Guayaquil');
  final _destination = TextEditingController(text: 'Quito');
  int _daysAhead = 3;
  bool _flexible = true;
  String _cargo = 'cargo_pallets';
  int _weight = 1200;
  int _volume = 6;
  final _declared = TextEditingController(text: '2500');
  int _photos = 0;
  final Set<String> _services = {};
  bool _insuredOnly = false;
  bool _helpLoading = false;
  int _target = 380;

  @override
  void dispose() {
    _origin.dispose();
    _destination.dispose();
    _declared.dispose();
    super.dispose();
  }

  void _publish() {
    final state = AppScope.of(context);
    final now = DateTime.now();
    final load = state.publishLoad(
      origin: _origin.text,
      destination: _destination.text,
      date: DateTime(now.year, now.month, now.day + _daysAhead, 10),
      cargoType: _cargo,
      weightKg: _weight,
      volumeM3: _volume.toDouble(),
      declaredValue: int.tryParse(_declared.text) ?? 0,
      targetPrice: _target,
      requiredServices: _services.toList(),
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('s14_published'))));
    Navigator.pushReplacementNamed(context, Routes.s15, arguments: load.id);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final locale = AppScope.of(context).locale;
    final scheme = Theme.of(context).colorScheme;
    final canPublish = _photos >= 1 && (int.tryParse(_declared.text) ?? 0) > 0;
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day + _daysAhead);

    return AppScreen(
      title: t('s14_title'),
      screenId: 'S14',
      bottom: _step == 0
          ? PrimaryButton(key: const Key('s14_next'), label: t('next'), onPressed: () => setState(() => _step = 1))
          : PrimaryButton(key: const Key('s14_publish'), label: t('s14_publish'), onPressed: canPublish ? _publish : null),
      children: [
        Text('${_step + 1} / 2 · ${_step == 0 ? t('s14_step1') : t('s14_step2')}', style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        if (_step == 0) ...[
          TextField(key: const Key('s14_origin'), controller: _origin, decoration: InputDecoration(labelText: t('s14_origin'), prefixIcon: const Icon(Icons.trip_origin))),
          const SizedBox(height: 12),
          TextField(controller: _destination, decoration: InputDecoration(labelText: t('s14_destination'), prefixIcon: const Icon(Icons.place_outlined))),
          SectionTitle(t('s14_date')),
          StepperRow(
            label: Fmt.dateLong(date, locale),
            value: '+$_daysAhead d',
            onMinus: _daysAhead > 0 ? () => setState(() => _daysAhead--) : null,
            onPlus: _daysAhead < 30 ? () => setState(() => _daysAhead++) : null,
          ),
          SwitchListTile(
            value: _flexible,
            onChanged: (v) => setState(() => _flexible = v),
            title: Text(t('s14_flexible')),
            contentPadding: EdgeInsets.zero,
          ),
        ] else ...[
          SectionTitle(t('s14_cargo_type')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in MockData.cargoTypeKeys)
                ChoiceChip(label: Text(t(k)), selected: _cargo == k, onSelected: (_) => setState(() => _cargo = k)),
            ],
          ),
          const SizedBox(height: 12),
          StepperRow(
            label: t('s14_weight'),
            value: Fmt.integer(_weight, locale),
            onMinus: _weight > 100 ? () => setState(() => _weight -= 100) : null,
            onPlus: () => setState(() => _weight += 100),
          ),
          StepperRow(
            label: t('s14_volume'),
            value: '$_volume',
            onMinus: _volume > 1 ? () => setState(() => _volume--) : null,
            onPlus: () => setState(() => _volume++),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('s14_declared'),
            controller: _declared,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: t('s14_declared_value'), prefixText: 'USD ', helperText: t('s14_declared_note'), helperMaxLines: 2),
          ),
          SectionTitle(t('s14_photos')),
          Row(
            children: [
              FilledButton.tonalIcon(
                key: const Key('s14_add_photo'),
                onPressed: () => setState(() => _photos++),
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(t('s14_add_photo')),
              ),
              const SizedBox(width: 12),
              Text(t.f('s14_photo_added', {'n': '$_photos'})),
            ],
          ),
          SectionTitle(t('s14_services')),
          Text(t('s14_services_hint'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          ChipSet(
            keys: MockData.serviceKeys,
            selected: _services,
            onToggle: (k, on) => setState(() => on ? _services.add(k) : _services.remove(k)),
          ),
          SwitchListTile(
            value: _insuredOnly,
            onChanged: (v) => setState(() => _insuredOnly = v),
            title: Text(t('s14_insured_only')),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            value: _helpLoading,
            onChanged: (v) => setState(() => _helpLoading = v),
            title: Text(t('s14_help_loading')),
            contentPadding: EdgeInsets.zero,
          ),
          SectionTitle(t('s14_target_price')),
          StepperRow(
            label: Fmt.usd(_target, locale),
            value: '',
            semanticsValue: Fmt.usd(_target, locale),
            onMinus: _target > 25 ? () => setState(() => _target -= 10) : null,
            onPlus: () => setState(() => _target += 10),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// S15 Load detail (shipper view): offers received, accept → S03/S17
// ---------------------------------------------------------------------------
class S15LoadDetail extends StatelessWidget {
  const S15LoadDetail({super.key, required this.loadId});
  final String loadId;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = AppScope.of(context);
    final locale = state.locale;
    final load = state.myLoads.firstWhere((x) => x.id == loadId);
    final offers = state.offersFor(load.id);
    final scheme = Theme.of(context).colorScheme;
    final luis = MockData.trips().first;

    void accept(Booking b) {
      state.acceptOffer(b);
      shipperBookAndPay(context, b);
    }

    return AppScreen(
      title: t('s15_title'),
      screenId: 'S15',
      children: [
        Text('${load.origin} → ${load.destination}', style: Theme.of(context).textTheme.titleLarge),
        Text(Fmt.dateLong(load.date, locale), style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            Badge16(icon: Icons.flag_outlined, label: t.listingLabel(load.status)),
            Badge16(icon: Icons.inventory_2_outlined, label: t(load.cargoType)),
            Badge16(icon: Icons.scale_outlined, label: t.f('unit_kg', {'x': Fmt.integer(load.weightKg, locale)})),
            Badge16(icon: Icons.view_in_ar_outlined, label: t.f('unit_m3', {'x': '${load.volumeM3.toInt()}'})),
          ],
        ),
        const SizedBox(height: 12),
        Text('${t('s14_target_price')}: ${Fmt.usd(load.targetPrice, locale)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        Text(t('s15_net_hidden'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        SectionTitle(t('s15_offers')),
        if (offers.isEmpty) Text(t('s15_no_offers'), style: TextStyle(color: scheme.onSurfaceVariant)),
        for (final b in offers)
          Builder(builder: (context) {
            final o = b.offer!;
            final mine = o.fromRole == UserRole.shipper; // my counter-offer awaiting the driver
            return Card(
              key: Key('s15_offer_${b.id}'),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const PhotoPlaceholder(size: 40, icon: Icons.person_outline),
                        const SizedBox(width: 10),
                        Expanded(child: Text('${luis.driver.firstName} · ${luis.driver.operator}', style: const TextStyle(fontWeight: FontWeight.w600))),
                        Flexible(child: Badge16(icon: Icons.verified_outlined, label: t('badge_verified'), color: AppTheme.success)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      mine ? t.bookingLabel(BookingStatus.offered, viewer: UserRole.shipper) : t.bookingLabel(BookingStatus.offered, viewer: UserRole.driver),
                      style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                    ),
                    Text(Fmt.usd(o.price, locale), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    if (o.message.isNotEmpty) Text('"${o.message}"', style: TextStyle(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 10),
                    if (mine)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              key: Key('s15_withdraw_${b.id}'),
                              onPressed: () => state.withdrawOffer(b),
                              child: Text(t('offer_withdraw')),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: FilledButton.tonal(
                              key: Key('s15_demo_accept_${b.id}'),
                              onPressed: () => accept(b),
                              child: Text(t('s10_demo_accept'), textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        ],
                      )
                    else ...[
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(key: Key('s15_accept_${b.id}'), onPressed: () => accept(b), child: Text(t('s15_accept'))),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: OutlinedButton(
                              key: Key('s15_counter_${b.id}'),
                              onPressed: o.counterUsed
                                  ? null
                                  : () => Navigator.pushNamed(context, Routes.s10, arguments: OfferArgs(load: load, counterTo: b, initialPrice: o.price - 20)),
                              child: Text(t('s15_counter'), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(key: Key('s15_decline_${b.id}'), onPressed: () => state.declineOffer(b), child: Text(t('s15_decline'))),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        if (load.status == ListingStatus.published) ...[
          const SizedBox(height: 8),
          DemoNote(t('demo_hint')),
          OutlinedButton(
            key: const Key('s15_demo_offer'),
            onPressed: () => state.sendOffer(trip: luis, load: load, fromRole: UserRole.driver, price: load.targetPrice + 40, message: 'Recojo a las 10:00'),
            child: Text(t('s15_demo_offer')),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// S17 Payment (mocked PSP)
// ---------------------------------------------------------------------------
class S17Payment extends StatefulWidget {
  const S17Payment({super.key, required this.bookingId});
  final String bookingId;

  @override
  State<S17Payment> createState() => _S17PaymentState();
}

class _S17PaymentState extends State<S17Payment> {
  int _method = 0; // 0 card, 1 transfer
  bool _processing = false;
  bool _paid = false;

  Future<void> _pay() async {
    setState(() => _processing = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final state = AppScope.of(context);
    final b = state.bookingById(widget.bookingId)!;
    state.advance(b, BookingStatus.paid);
    setState(() {
      _processing = false;
      _paid = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = AppScope.of(context);
    final locale = state.locale;
    final b = state.bookingById(widget.bookingId)!;
    final s = state.shipper;
    final scheme = Theme.of(context).colorScheme;

    if (_paid) {
      return AppScreen(
        title: t('s17_title'),
        screenId: 'S17',
        bottom: PrimaryButton(
          key: const Key('s17_go_booking'),
          label: t('s17_go_booking'),
          onPressed: () => Navigator.pushNamedAndRemoveUntil(context, Routes.s16, (r) => r.isFirst, arguments: b.id),
        ),
        children: [
          const SizedBox(height: 32),
          const Icon(Icons.lock_outline, size: 72, color: AppTheme.success),
          const SizedBox(height: 12),
          Text(t('s17_paid_title'), key: const Key('s17_paid'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(t('s17_paid_body'), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          SecondaryButton(label: t('s17_download_receipt'), icon: Icons.receipt_outlined, onPressed: () {}),
          const SizedBox(height: 8),
          SecondaryButton(label: t('s17_download_invoice'), icon: Icons.description_outlined, onPressed: () {}),
        ],
      );
    }

    return AppScreen(
      title: t('s17_title'),
      screenId: 'S17',
      bottom: PrimaryButton(
        key: const Key('s17_pay'),
        label: _processing ? '…' : t.f('s17_pay', {'x': Fmt.integer(b.price, locale)}),
        icon: Icons.lock_outline,
        onPressed: _processing ? null : _pay,
      ),
      children: [
        InfoBanner(text: t('s17_deadline'), icon: Icons.timer_outlined),
        SectionTitle(t('s17_invoice_to')),
        Card(
          child: ListTile(
            key: const Key('s17_invoice_data'),
            title: Text(s.invoiceName),
            subtitle: Text('${s.taxId}\n${s.invoiceAddress}\n${s.invoiceEmail}'),
            isThreeLine: true,
            trailing: TextButton(
              key: const Key('s17_edit'),
              onPressed: () async {
                await Navigator.pushNamed(context, Routes.s03, arguments: 'invoice');
                if (mounted) setState(() {});
              },
              child: Text(t('s17_edit')),
            ),
          ),
        ),
        SectionTitle(t('s17_method')),
        RadioGroup<int>(
          groupValue: _method,
          onChanged: (v) => setState(() => _method = v ?? 0),
          child: Column(
            children: [
              RadioListTile<int>(
                key: const Key('s17_card'),
                value: 0,
                title: Text(t('s17_card')),
                secondary: const Icon(Icons.credit_card),
                contentPadding: EdgeInsets.zero,
              ),
              RadioListTile<int>(
                key: const Key('s17_transfer'),
                value: 1,
                title: Text(t('s17_transfer')),
                secondary: const Icon(Icons.account_balance_outlined),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        if (_method == 0) ...[
          const SizedBox(height: 8),
          TextField(decoration: InputDecoration(labelText: t('s17_card'), hintText: '4242 4242 4242 4242', prefixIcon: const Icon(Icons.credit_card))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: TextField(decoration: const InputDecoration(labelText: 'MM/AA', hintText: '12/28'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(decoration: const InputDecoration(labelText: 'CVV', hintText: '123'))),
            ],
          ),
        ],
        SectionTitle(t('s17_total')),
        Text(Fmt.usd(b.price, locale), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        InfoBanner(text: t('s17_escrow'), icon: Icons.lock_outline, color: AppTheme.success),
        Text(t('s15_net_hidden'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        DemoNote(t('s17_demo_psp')),
      ],
    );
  }
}
