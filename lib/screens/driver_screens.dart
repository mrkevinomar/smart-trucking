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

// ---------------------------------------------------------------------------
// S06 Driver home
// ---------------------------------------------------------------------------
class S06DriverHome extends StatelessWidget {
  const S06DriverHome({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = AppScope.of(context);
    final locale = state.locale;
    final scheme = Theme.of(context).colorScheme;
    final pendingUploads = state.bookings.fold<int>(0, (n, b) => n + b.pendingUploads);
    final myBookings = state.bookings.where((b) => b.trip.driver.id == MockData.me.id).toList();

    return AppScreen(
      title: t.f('s06_title', {'name': state.driver.name}),
      screenId: 'S06',
      leading: const SizedBox.shrink(),
      actions: [
        IconButton(
          key: const Key('s06_notifications'),
          tooltip: t('notifications'),
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => Navigator.pushNamed(context, Routes.s22),
        ),
        IconButton(
          key: const Key('s06_settings'),
          tooltip: t('settings'),
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.pushNamed(context, Routes.s23),
        ),
      ],
      bottom: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              key: const Key('s06_publish'),
              onPressed: () => Navigator.pushNamed(context, Routes.s07),
              icon: const Icon(Icons.add_road),
              label: Text(t('s06_publish')),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('s06_search_loads'),
              onPressed: () => Navigator.pushNamed(context, Routes.s09),
              icon: const Icon(Icons.search),
              label: Text(t('s06_search_loads')),
            ),
          ),
        ],
      ),
      children: [
        if (pendingUploads > 0)
          InfoBanner(
            key: const Key('s06_pending_banner'),
            icon: Icons.cloud_upload_outlined,
            color: AppTheme.secondary,
            text: t.f('s06_pending_uploads', {
              'n': '$pendingUploads',
              'date': Fmt.dateShort(state.now().add(const Duration(days: 6)), locale),
            }),
          ),
        SectionTitle(t('s06_my_trips')),
        if (state.myTrips.isEmpty)
          Text(t('s06_no_trips'), style: TextStyle(color: scheme.onSurfaceVariant))
        else
          for (final trip in state.myTrips)
            Card(
              key: Key('s06_trip_${trip.id}'),
              child: ListTile(
                leading: const Icon(Icons.local_shipping_outlined),
                title: Text('${trip.origin} → ${trip.destination}'),
                subtitle: Text('${Fmt.dateWithPeriod(trip.departure, locale)} · ${t.listingLabel(trip.status)}'),
                trailing: Text(Fmt.usd(trip.price, locale), style: const TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => Navigator.pushNamed(context, Routes.s08, arguments: trip.id),
              ),
            ),
        if (myBookings.isNotEmpty) ...[
          SectionTitle(t('s06_bookings')),
          for (final b in myBookings)
            Card(
              key: Key('s06_booking_${b.id}'),
              child: ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text('${b.trip.origin} → ${b.trip.destination}'),
                subtitle: Text(t.bookingLabel(b.status, viewer: UserRole.driver)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, Routes.s16, arguments: b.id),
              ),
            ),
        ],
        SectionTitle(t('s06_loads_near')),
        for (final load in state.marketLoads.take(2))
          Card(
            child: ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text('${load.origin} → ${load.destination}'),
              subtitle: Text('${t(load.cargoType)} · ${t.f('s09_extra_km', {'km': '${load.detourKm}'})}'),
              trailing: Text(Fmt.usd(load.targetPrice, locale), style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () => Navigator.pushNamed(context, Routes.s09),
            ),
          ),
        SectionTitle(t('s06_earnings')),
        Card(
          child: ListTile(
            key: const Key('s06_earnings'),
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: Text(Fmt.usd(_balance(state), locale), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
            subtitle: Text(t('s21_balance')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, Routes.s21),
          ),
        ),
      ],
    );
  }

  static int _balance(AppState state) => state.bookings
      .where((b) => b.trip.driver.id == MockData.me.id &&
          const {BookingStatus.confirmed, BookingStatus.delivered}.contains(b.status))
      .fold(0, (n, b) => n + state.netPayout(b.price));
}

// ---------------------------------------------------------------------------
// S07 Publish trip (2 steps)
// ---------------------------------------------------------------------------
class S07PublishTrip extends StatefulWidget {
  const S07PublishTrip({super.key});

  @override
  State<S07PublishTrip> createState() => _S07PublishTripState();
}

class _S07PublishTripState extends State<S07PublishTrip> {
  int _step = 0;
  final _origin = TextEditingController(text: 'Guayaquil');
  final _destination = TextEditingController(text: 'Quito');
  int _daysAhead = 3;
  int _window = 1; // 0 morning, 1 afternoon, 2 night
  bool _returnLeg = true;
  bool _instant = true;
  int _price = 450;
  final Set<String> _cargo = {'cargo_pallets', 'cargo_boxes'};

  @override
  void dispose() {
    _origin.dispose();
    _destination.dispose();
    super.dispose();
  }

  DateTime get _departure {
    final now = DateTime.now();
    final hour = [8, 14, 19][_window];
    return DateTime(now.year, now.month, now.day + _daysAhead, hour);
  }

  void _publish() {
    final state = AppScope.of(context);
    final trip = state.publishTrip(
      origin: _origin.text,
      destination: _destination.text,
      departure: _departure,
      price: _price,
      isReturnLeg: _returnLeg,
      instantBooking: _instant,
      cargoTypes: _cargo.toList(),
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('s07_published'))));
    Navigator.pushReplacementNamed(context, Routes.s08, arguments: trip.id);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = AppScope.of(context);
    final locale = state.locale;
    final scheme = Theme.of(context).colorScheme;

    return AppScreen(
      title: t('s07_title'),
      screenId: 'S07',
      bottom: _step == 0
          ? PrimaryButton(
              key: const Key('s07_next'),
              label: t('next'),
              onPressed: () => setState(() => _step = 1),
            )
          : PrimaryButton(
              key: const Key('s07_publish'),
              label: t('s07_publish'),
              onPressed: _publish,
            ),
      children: [
        Text('${_step + 1} / 2 · ${_step == 0 ? t('s07_step1') : t('s07_step2')}',
            style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        if (_step == 0) ...[
          TextField(
            key: const Key('s07_origin'),
            controller: _origin,
            decoration: InputDecoration(labelText: t('s07_origin'), prefixIcon: const Icon(Icons.trip_origin)),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('s07_destination'),
            controller: _destination,
            decoration: InputDecoration(labelText: t('s07_destination'), prefixIcon: const Icon(Icons.place_outlined)),
          ),
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: Text(t('s07_add_stop')),
          ),
          SectionTitle(t('s07_date')),
          StepperRow(
            label: Fmt.dateLong(_departure, locale),
            value: '+$_daysAhead d',
            onMinus: _daysAhead > 0 ? () => setState(() => _daysAhead--) : null,
            onPlus: _daysAhead < 30 ? () => setState(() => _daysAhead++) : null,
          ),
          SectionTitle(t('s07_window')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < 3; i++)
                ChoiceChip(
                  label: Text([t('s07_window_morning'), t('s07_window_afternoon'), t('s07_window_night')][i]),
                  selected: _window == i,
                  onSelected: (_) => setState(() => _window = i),
                ),
            ],
          ),
          SwitchListTile(
            key: const Key('s07_return_leg'),
            value: _returnLeg,
            onChanged: (v) => setState(() => _returnLeg = v),
            title: Text(t('s07_return_leg')),
            contentPadding: EdgeInsets.zero,
          ),
        ] else ...[
          SectionTitle(t('s07_vehicle')),
          Card(
            child: ListTile(
              leading: const PhotoPlaceholder(size: 44),
              title: Text('${t(MockData.me.vehicle.bodyType)} ${t.f('unit_tons', {'t': '8'})}'),
              subtitle: Text('${t('s07_capacity')}: ${t.f('s12_free', {'t': '5', 'm': '20'})}'),
            ),
          ),
          SectionTitle(t('s07_cargo_types')),
          ChipSet(
            keys: MockData.cargoTypeKeys,
            selected: _cargo,
            onToggle: (k, on) => setState(() => on ? _cargo.add(k) : _cargo.remove(k)),
          ),
          SectionTitle(t('s07_min_price')),
          StepperRow(
            label: Fmt.usd(_price, locale),
            value: '',
            semanticsValue: Fmt.usd(_price, locale),
            onMinus: _price > 25 ? () => setState(() => _price -= 25) : null,
            onPlus: () => setState(() => _price += 25),
          ),
          Text(t.f('s07_price_suggestion', {'x': '480'}), style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          NetPayoutBox(price: _price),
          SwitchListTile(
            key: const Key('s07_instant'),
            value: _instant,
            onChanged: (v) => setState(() => _instant = v),
            title: Text(t('s07_instant')),
            subtitle: Text(t('s07_instant_hint')),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ],
    );
  }
}

/// "Recibes USD X después de la comisión del N %" (copy table), with the rate
/// that applies to this driver (A7.4).
class NetPayoutBox extends StatelessWidget {
  const NetPayoutBox({super.key, required this.price});
  final int price;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = AppScope.of(context);
    final net = state.netPayout(price);
    return Container(
      key: const Key('net_payout'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payments_outlined, color: AppTheme.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.f('net_payout', {
                    'x': Fmt.integer(net, state.locale),
                    'rate': '${state.commissionPercent}',
                  }),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (state.earlyRateApplies)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 32),
              child: Text(t('net_payout_early'), style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// S08 Trip detail (driver view): offers received, accept / counter / decline
// ---------------------------------------------------------------------------
class S08TripDetail extends StatelessWidget {
  const S08TripDetail({super.key, required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = AppScope.of(context);
    final locale = state.locale;
    final trip = state.myTrips.firstWhere((x) => x.id == tripId);
    final offers = state.offersFor(trip.id);
    final scheme = Theme.of(context).colorScheme;
    final bookingOnTrip = state.bookings.where((b) => b.trip.id == trip.id).toList();

    void acceptOffer(Offer o) {
      state.removeOffer(trip.id, o);
      final b = state.createBooking(trip: trip, price: o.price, entry: BookingStatus.accepted);
      Navigator.pushNamed(context, Routes.s16, arguments: b.id);
    }

    void instantBooking() {
      final b = state.createBooking(trip: trip, price: trip.price, entry: BookingStatus.accepted);
      Navigator.pushNamed(context, Routes.s16, arguments: b.id);
    }

    return AppScreen(
      title: t('s08_title'),
      screenId: 'S08',
      bottom: trip.status == ListingStatus.published
          ? Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('s08_cancel_trip'),
                    onPressed: () => _cancelTrip(context, trip),
                    child: Text(t('s08_cancel_trip')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => Navigator.pushNamed(context, Routes.s07),
                    child: Text(t('s08_edit')),
                  ),
                ),
              ],
            )
          : null,
      children: [
        Text('${trip.origin} → ${trip.destination}', style: Theme.of(context).textTheme.titleLarge),
        Text(Fmt.dateTime(trip.departure, locale), style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            Badge16(icon: Icons.flag_outlined, label: t.listingLabel(trip.status)),
            if (trip.isReturnLeg) Badge16(icon: Icons.u_turn_left, label: t('badge_return'), color: AppTheme.secondary),
            if (trip.instantBooking) Badge16(icon: Icons.bolt, label: t('s08_instant_badge')),
          ],
        ),
        const SizedBox(height: 12),
        Text(Fmt.usd(trip.price, locale), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        NetPayoutBox(price: trip.price),
        if (bookingOnTrip.isNotEmpty) ...[
          SectionTitle(t('s06_bookings')),
          for (final b in bookingOnTrip)
            Card(
              child: ListTile(
                key: Key('s08_booking_${b.id}'),
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(t.bookingLabel(b.status, viewer: UserRole.driver)),
                subtitle: Text(Fmt.usd(b.price, locale)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, Routes.s16, arguments: b.id),
              ),
            ),
        ],
        SectionTitle(t('s08_offers')),
        if (offers.isEmpty) Text(t('s08_no_offers'), style: TextStyle(color: scheme.onSurfaceVariant)),
        for (final o in offers)
          Card(
            key: Key('s08_offer_${o.id}'),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.f('s08_offer_from', {'name': 'Paula · Textiles Andinos'}), style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(Fmt.usd(o.price, locale), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  if (o.message.isNotEmpty) Text('"${o.message}"', style: TextStyle(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Text(t.f('net_payout', {'x': Fmt.integer(state.netPayout(o.price), locale), 'rate': '${state.commissionPercent}'}),
                      style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          key: Key('s08_accept_${o.id}'),
                          onPressed: () => acceptOffer(o),
                          child: Text(t('s08_accept')),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton(
                          key: Key('s08_counter_${o.id}'),
                          onPressed: o.counterUsed
                              ? null
                              : () => Navigator.pushNamed(
                                    context,
                                    Routes.s10,
                                    arguments: OfferArgs(trip: trip, counterTo: o, initialPrice: o.price + 30),
                                  ),
                          child: Text(t('s08_counter'), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => state.removeOffer(trip.id, o),
                      child: Text(t('s08_decline')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (trip.status == ListingStatus.published) ...[
          const SizedBox(height: 8),
          DemoNote(t('demo_hint')),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('s08_demo_offer'),
                  onPressed: () => state.addOffer(trip.id, UserRole.shipper, trip.price - 50, 'Puedo recibir a las 14:00'),
                  child: Text(t('s08_demo_offer'), textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  key: const Key('s08_demo_instant'),
                  onPressed: trip.instantBooking ? instantBooking : null,
                  child: Text(t('s08_demo_instant'), textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _cancelTrip(BuildContext context, Trip trip) {
    final t = context.t;
    final state = AppScope.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('s08_cancel_trip')),
        content: Text(t('s08_cancel_trip_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('cancel'))),
          FilledButton(
            onPressed: () {
              state.cancelTrip(trip);
              Navigator.pop(ctx);
            },
            child: Text(t('confirm')),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// S09 Loads on my route + filter sheet (4.3)
// ---------------------------------------------------------------------------
class S09SearchLoads extends StatefulWidget {
  const S09SearchLoads({super.key});

  @override
  State<S09SearchLoads> createState() => _S09SearchLoadsState();
}

class _S09SearchLoadsState extends State<S09SearchLoads> {
  LoadFilters _filters = const LoadFilters();
  int _sort = 0; // 0 detour, 1 price, 2 date

  List<Load> _apply(List<Load> loads) {
    final me = MockData.me.vehicle;
    var out = loads.where((l) {
      if (l.detourKm > _filters.detourKm) return false;
      if (_filters.cargoTypes.isNotEmpty && !_filters.cargoTypes.contains(l.cargoType)) return false;
      if (_filters.fitsMyVehicle && (l.weightKg > me.freeTons * 1000 || l.volumeM3 > me.freeM3)) return false;
      if (l.targetPrice < _filters.minPrice) return false;
      if (_filters.dateFrom != null && l.date.isBefore(_filters.dateFrom!)) return false;
      if (_filters.dateTo != null && l.date.isAfter(_filters.dateTo!)) return false;
      return true;
    }).toList();
    out.sort((a, b) => switch (_sort) {
          1 => b.targetPrice.compareTo(a.targetPrice),
          2 => a.date.compareTo(b.date),
          _ => a.detourKm.compareTo(b.detourKm),
        });
    return out;
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<LoadFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => LoadFilterSheet(initial: _filters),
    );
    if (result != null) setState(() => _filters = result);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = AppScope.of(context);
    final results = _apply(state.marketLoads);
    final scheme = Theme.of(context).colorScheme;

    return AppScreen(
      title: t('s09_title'),
      screenId: 'S09',
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ActionChip(
                key: const Key('s09_filters'),
                avatar: const Icon(Icons.tune, size: 18),
                label: Text(_filters.activeCount > 0 ? '${t('s09_filters')} (${_filters.activeCount})' : t('s09_filters')),
                onPressed: _openFilters,
              ),
              const SizedBox(width: 8),
              Text('${t('s09_sort')}:', style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(width: 6),
              for (var i = 0; i < 3; i++) ...[
                ChoiceChip(
                  label: Text([t('s09_sort_detour'), t('s09_sort_price'), t('s09_sort_date')][i]),
                  selected: _sort == i,
                  onSelected: (_) => setState(() => _sort = i),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            InputChip(
              label: Text(t.f('s09_detour_value', {'km': '${_filters.detourKm}'})),
              avatar: const Icon(Icons.alt_route, size: 18),
              onPressed: _openFilters,
            ),
            if (_filters.fitsMyVehicle)
              InputChip(
                key: const Key('s09_chip_fits'),
                label: Text(t('s09_fits')),
                onDeleted: () => setState(() => _filters = _filters.copyWith(fitsMyVehicle: false)),
              ),
            for (final c in _filters.cargoTypes)
              InputChip(
                label: Text(t(c)),
                onDeleted: () => setState(() => _filters = _filters.copyWith(cargoTypes: {..._filters.cargoTypes}..remove(c))),
              ),
            if (_filters.minPrice > 0)
              InputChip(
                label: Text('≥ ${Fmt.usd(_filters.minPrice, state.locale)}'),
                onDeleted: () => setState(() => _filters = _filters.copyWith(minPrice: 0)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(t.f('s09_result_count', {'n': '${results.length}'}), style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        // Map placeholder (list + map per 4.3; maps routing is out of scope).
        Container(
          constraints: const BoxConstraints(minHeight: 110),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceMuted,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, color: scheme.outline),
              const SizedBox(width: 8),
              Flexible(child: Text('${t('s16_map')} · Guayaquil → Quito', style: TextStyle(color: scheme.outline))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (results.isEmpty) InfoBanner(text: t('s09_no_results'), icon: Icons.search_off),
        for (final l in results) ...[
          LoadCard(
            load: l,
            onOffer: () => Navigator.pushNamed(
              context,
              Routes.s10,
              arguments: OfferArgs(load: l, initialPrice: l.targetPrice),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// S09 bottom sheet: detour radius stepper (10–80 km, default 40), date
/// window, cargo type chips, "cabe en mi vehículo" (default on), min price.
class LoadFilterSheet extends StatefulWidget {
  const LoadFilterSheet({super.key, required this.initial});
  final LoadFilters initial;

  @override
  State<LoadFilterSheet> createState() => _LoadFilterSheetState();
}

class _LoadFilterSheetState extends State<LoadFilterSheet> {
  late LoadFilters f = widget.initial;
  int _dateDays = 0; // 0 = any, 3 = next 3 days, 7 = next 7 days

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final locale = AppScope.of(context).locale;
    return FilterSheetFrame(
      title: t('s09_filters'),
      onClear: () => setState(() {
        f = const LoadFilters();
        _dateDays = 0;
      }),
      onApply: () => Navigator.pop(context, f),
      children: [
        SectionTitle(t('s09_detour')),
        StepperRow(
          key: const Key('s09_detour_stepper'),
          label: t('s09_detour'),
          value: t.f('s09_detour_value', {'km': '${f.detourKm}'}),
          onMinus: f.detourKm > 10 ? () => setState(() => f = f.copyWith(detourKm: f.detourKm - 10)) : null,
          onPlus: f.detourKm < 80 ? () => setState(() => f = f.copyWith(detourKm: f.detourKm + 10)) : null,
        ),
        SectionTitle(t('s09_dates')),
        Wrap(
          spacing: 8,
          children: [
            for (final d in [0, 3, 7])
              ChoiceChip(
                label: Text(d == 0 ? t('s12_f_insurance_any') : '≤ ${Fmt.dateShort(DateTime.now().add(Duration(days: d)), locale)}'),
                selected: _dateDays == d,
                onSelected: (_) => setState(() {
                  _dateDays = d;
                  f = LoadFilters(
                    detourKm: f.detourKm,
                    cargoTypes: f.cargoTypes,
                    fitsMyVehicle: f.fitsMyVehicle,
                    minPrice: f.minPrice,
                    dateFrom: d == 0 ? null : DateTime.now(),
                    dateTo: d == 0 ? null : DateTime.now().add(Duration(days: d, hours: 23)),
                  );
                }),
              ),
          ],
        ),
        SectionTitle(t('s09_cargo_type')),
        ChipSet(
          keys: MockData.cargoTypeKeys,
          selected: f.cargoTypes,
          onToggle: (k, on) => setState(() {
            final s = {...f.cargoTypes};
            on ? s.add(k) : s.remove(k);
            f = f.copyWith(cargoTypes: s);
          }),
        ),
        SwitchListTile(
          key: const Key('s09_fits_switch'),
          value: f.fitsMyVehicle,
          onChanged: (v) => setState(() => f = f.copyWith(fitsMyVehicle: v)),
          title: Text(t('s09_fits')),
          contentPadding: EdgeInsets.zero,
        ),
        SectionTitle(t('s09_min_price')),
        StepperRow(
          label: t('s09_min_price'),
          value: Fmt.usd(f.minPrice, locale),
          onMinus: f.minPrice > 0 ? () => setState(() => f = f.copyWith(minPrice: f.minPrice - 50)) : null,
          onPlus: () => setState(() => f = f.copyWith(minPrice: f.minPrice + 50)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// S21 Earnings and payouts
// ---------------------------------------------------------------------------
class S21Earnings extends StatelessWidget {
  const S21Earnings({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = AppScope.of(context);
    final locale = state.locale;
    final scheme = Theme.of(context).colorScheme;
    final mine = state.bookings.where((b) => b.trip.driver.id == MockData.me.id).toList();
    final payable = mine.where((b) => const {
          BookingStatus.paid,
          BookingStatus.pickedUp,
          BookingStatus.inTransit,
          BookingStatus.delivered,
          BookingStatus.confirmed,
          BookingStatus.settled,
        }.contains(b.status));

    final balance = payable
        .where((b) => b.status != BookingStatus.settled)
        .fold(0, (n, b) => n + state.netPayout(b.price));

    return AppScreen(
      title: t('s21_title'),
      screenId: 'S21',
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('s21_balance'), style: TextStyle(color: scheme.onSurfaceVariant)),
                Text(Fmt.usd(balance, locale), key: const Key('s21_balance'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        if (!state.driver.rucProvided)
          InfoBanner(
            key: const Key('s21_ruc_reminder'),
            text: t('s21_ruc_reminder'),
            icon: Icons.badge_outlined,
            color: AppTheme.secondary,
          ),
        if (state.earlyRateApplies)
          InfoBanner(key: const Key('s21_first_three'), text: t('s21_first_three'), icon: Icons.schedule),
        SectionTitle(t('s21_history')),
        if (payable.isEmpty) Text(t('s22_empty'), style: TextStyle(color: scheme.onSurfaceVariant)),
        for (final b in payable) _PayoutRow(booking: b),
        SectionTitle(t('s21_invoices')),
        for (final b in payable.where((b) => b.status == BookingStatus.settled))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined),
            title: Text('${t('s21_commission').replaceAll(' ({rate} %)', '')} · ${b.id}'),
            subtitle: Text(Fmt.usd(Commission.commissionAmount(b.price, state.driver.completedBookings - 1), locale)),
            trailing: const Icon(Icons.download_outlined),
            onTap: () {},
          ),
      ],
    );
  }
}

class _PayoutRow extends StatelessWidget {
  const _PayoutRow({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = AppScope.of(context);
    final locale = state.locale;
    final b = booking;
    final rate = state.commissionPercent;
    final net = state.netPayout(b.price);
    final scheme = Theme.of(context).colorScheme;

    final (statusLabel, color) = switch (b.status) {
      BookingStatus.settled => (t('s21_status_sent'), AppTheme.success),
      BookingStatus.confirmed when state.earlyRateApplies => (t('s21_status_held'), AppTheme.secondary),
      _ => (t('s21_status_pending'), scheme.outline),
    };

    DateTime? expected;
    final confirmedAt = b.history.where((e) => e.status == BookingStatus.confirmed).map((e) => e.at).firstOrNull;
    if (b.status == BookingStatus.confirmed && confirmedAt != null) {
      expected = state.earlyRateApplies ? state.heldPayoutDate(confirmedAt) : confirmedAt.add(const Duration(days: 1));
    }

    return Card(
      key: Key('s21_payout_${b.id}'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('${b.trip.origin} → ${b.trip.destination}', style: const TextStyle(fontWeight: FontWeight.w600))),
                Flexible(child: Badge16(icon: Icons.circle, label: statusLabel, color: color)),
              ],
            ),
            if (expected != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(t.f('s21_expected', {'date': Fmt.dateShort(expected, locale)}), style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
            const Divider(height: 20),
            _line(t('s21_gross'), Fmt.usd(b.price, locale)),
            _line(t.f('s21_commission', {'rate': '$rate'}), '- ${Fmt.usd(b.price - net, locale)}'),
            _line(t('s21_net'), Fmt.usd(net, locale), bold: true),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value, {bool bold = false}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400, fontSize: bold ? 17 : 15);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
