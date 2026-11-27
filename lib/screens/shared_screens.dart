import 'package:flutter/material.dart';

import '../app.dart';
import '../core/app_state.dart';
import '../core/booking_state_machine.dart';
import '../core/enums.dart';
import '../core/mock_data.dart';
import '../core/models.dart';
import '../core/money.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import '../widgets/common.dart';

// ---------------------------------------------------------------------------
// S10 Offer / counter-offer composer
// ---------------------------------------------------------------------------
class OfferArgs {
  const OfferArgs({this.trip, this.load, this.counterTo, required this.initialPrice});

  /// Trip the shipper offers on (S12/S13) or the driver's own trip when
  /// countering a shipper offer (S08).
  final Trip? trip;

  /// Load the driver offers on (S09) or the shipper's own load when countering.
  final Load? load;

  /// The open offer (a booking in `offered`) this screen counters.
  final Booking? counterTo;
  final int initialPrice;

  bool get isCounter => counterTo != null;
}

class S10Offer extends StatefulWidget {
  const S10Offer({super.key, required this.args});
  final OfferArgs args;

  @override
  State<S10Offer> createState() => _S10OfferState();
}

class _S10OfferState extends State<S10Offer> {
  late int _price = widget.args.initialPrice;
  final _message = TextEditingController();

  /// The booking in `offered` created or countered by this screen.
  Booking? _sentBooking;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  /// Publicada → Ofertada (or Ofertada → Ofertada for a counter-offer).
  void _send() {
    final state = AppScope.of(context);
    final a = widget.args;
    if (a.isCounter) {
      state.counterOffer(a.counterTo!, state.role!, _price, _message.text);
      setState(() => _sentBooking = a.counterTo);
      return;
    }
    final trip = a.trip ?? MockData.trips().first; // mocked carrier for load offers
    final b = state.sendOffer(trip: trip, load: a.load, fromRole: state.role!, price: _price, message: _message.text);
    setState(() => _sentBooking = b);
  }

  /// Mock: the counterpart accepts (Ofertada → Aceptada).
  void _demoAccept() {
    final state = AppScope.of(context);
    final b = _sentBooking!;
    state.acceptOffer(b);
    if (state.role == UserRole.shipper) {
      _shipperContinue(b);
    } else {
      Navigator.pushNamedAndRemoveUntil(context, Routes.s16, (r) => r.isFirst, arguments: b.id);
    }
  }

  /// Mock: the counterpart declines (Ofertada → Rechazada).
  void _demoDecline() {
    AppScope.of(context).declineOffer(_sentBooking!);
    setState(() {});
  }

  /// Ofertada → retirada por quien la envió.
  void _withdraw() {
    AppScope.of(context).withdrawOffer(_sentBooking!);
    setState(() {});
  }

  Future<void> _shipperContinue(Booking b) async {
    final state = AppScope.of(context);
    if (!state.shipper.invoiceDataComplete) {
      final ok = await Navigator.pushNamed(context, Routes.s03, arguments: 'invoice');
      if (ok != true || !mounted) return;
    }
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, Routes.s17, (r) => r.isFirst, arguments: b.id);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = AppScope.of(context);
    final locale = state.locale;
    final isDriver = state.role == UserRole.driver;
    final a = widget.args;
    final scheme = Theme.of(context).colorScheme;
    final title = a.trip != null
        ? '${a.trip!.origin} → ${a.trip!.destination}'
        : '${a.load!.origin} → ${a.load!.destination}';

    final sent = _sentBooking;
    if (sent != null) {
      final open = sent.status == BookingStatus.offered;
      final viewer = state.role ?? UserRole.driver;
      return AppScreen(
        title: a.isCounter ? t('s10_title_counter') : t('s10_title'),
        screenId: 'S10',
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (open) ...[
              PrimaryButton(
                key: const Key('s10_demo_accept'),
                label: t('s10_demo_accept'),
                onPressed: _demoAccept,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('s10_withdraw'),
                      onPressed: _withdraw,
                      child: Text(t('offer_withdraw')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('s10_demo_decline'),
                      onPressed: _demoDecline,
                      child: Text(t('s10_demo_decline'), textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            SecondaryButton(
              key: const Key('s10_back_home'),
              label: t('home'),
              onPressed: () => Navigator.pushNamedAndRemoveUntil(context, homeRouteFor(state.role), (r) => r.isFirst),
            ),
          ],
        ),
        children: [
          const SizedBox(height: 32),
          Icon(
            open ? Icons.send_outlined : Icons.undo,
            size: 64,
            color: open ? AppTheme.primary : AppTheme.danger,
          ),
          const SizedBox(height: 12),
          Text(
            open ? t('s10_sent') : t.bookingLabel(sent.status, viewer: viewer),
            key: const Key('s10_status'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(Fmt.usd(sent.price, locale), textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            open ? t('s10_rule') : t.bookingNotification(sent.status),
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          if (!open) ...[
            const SizedBox(height: 8),
            Text(t('offer_listing_still_published'), textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 16),
          DemoNote(t('demo_hint')),
        ],
      );
    }

    return AppScreen(
      title: a.isCounter ? t('s10_title_counter') : t('s10_title'),
      screenId: 'S10',
      bottom: PrimaryButton(
        key: const Key('s10_send'),
        label: a.isCounter ? t('s10_send_counter') : t('s10_send'),
        onPressed: _send,
      ),
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (a.counterTo != null)
          Text('${t('s08_offer_from').replaceAll(' {name}', '')}: ${Fmt.usd(a.counterTo!.price, locale)}',
              style: TextStyle(color: scheme.onSurfaceVariant)),
        SectionTitle(t('s10_price')),
        StepperRow(
          key: const Key('s10_price'),
          label: Fmt.usd(_price, locale),
          value: '',
          semanticsValue: Fmt.usd(_price, locale),
          onMinus: _price > 25 ? () => setState(() => _price -= 10) : null,
          onPlus: () => setState(() => _price += 10),
        ),
        const SizedBox(height: 8),
        if (isDriver)
          Container(
            key: const Key('s10_net_payout'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              t.f('net_payout', {'x': Fmt.integer(state.netPayout(_price), locale), 'rate': '${state.commissionPercent}'}),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          )
        else
          Text(t('s15_net_hidden'), style: TextStyle(color: scheme.onSurfaceVariant)),
        SectionTitle(t('s10_message')),
        TextField(
          key: const Key('s10_message'),
          controller: _message,
          maxLines: 3,
          decoration: InputDecoration(hintText: t('s10_message_hint')),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.mic_none),
          label: Text(t('s10_voice_note')),
        ),
        const SizedBox(height: 16),
        Text(t('s10_rule'), style: TextStyle(color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// S16 Booking detail (both roles)
// ---------------------------------------------------------------------------
class S16BookingDetail extends StatelessWidget {
  const S16BookingDetail({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = AppScope.of(context);
    final locale = state.locale;
    final b = state.bookingById(bookingId)!;
    final viewer = state.role ?? UserRole.driver;
    final isDriver = viewer == UserRole.driver;
    final scheme = Theme.of(context).colorScheme;
    final paidOrLater = const {
      BookingStatus.paid,
      BookingStatus.pickedUp,
      BookingStatus.inTransit,
      BookingStatus.delivered,
      BookingStatus.confirmed,
      BookingStatus.settled,
    }.contains(b.status);
    // A5.3: full name and plate are revealed once custody is funded, and a
    // later dispute or cancellation does not un-fund it.
    final custodyFunded = b.history.any((e) => e.status == BookingStatus.paid);
    final d = b.trip.driver;

    final confirmedAt = b.history.where((e) => e.status == BookingStatus.confirmed).map((e) => e.at).firstOrNull;

    return AppScreen(
      title: t('s16_title'),
      screenId: 'S16',
      actions: [
        IconButton(
          tooltip: t('home'),
          icon: const Icon(Icons.home_outlined),
          onPressed: () => Navigator.pushNamedAndRemoveUntil(context, homeRouteFor(state.role), (r) => r.isFirst),
        ),
      ],
      bottom: _primaryAction(context, b, viewer),
      children: [
        Text('${b.trip.origin} → ${b.trip.destination}', style: Theme.of(context).textTheme.titleLarge),
        Text(Fmt.dateTime(b.departure, locale), style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Badge16(
              key: const Key('s16_status'),
              icon: Icons.flag_outlined,
              label: t.bookingLabel(b.status, viewer: viewer),
            ),
            Text(Fmt.usd(b.price, locale), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ],
        ),
        if (b.pendingSync)
          InfoBanner(
            key: const Key('s16_pending_sync'),
            icon: Icons.cloud_upload_outlined,
            color: AppTheme.secondary,
            text: '${t('s16_pending_sync')}. ${t('s16_pending_sync_body')}',
          ),
        if (b.pendingUploads > 0)
          InfoBanner(
            icon: Icons.photo_library_outlined,
            color: AppTheme.secondary,
            text: t.f('s06_pending_uploads', {'n': '${b.pendingUploads}', 'date': Fmt.dateShort(state.now().add(const Duration(days: 6)), locale)}),
          ),
        if (!isDriver && b.status == BookingStatus.accepted) InfoBanner(text: t('s17_deadline'), icon: Icons.timer_outlined),
        if (!isDriver && paidOrLater) InfoBanner(text: t('s16_escrow'), icon: Icons.lock_outline, color: AppTheme.success),
        if (isDriver && b.status == BookingStatus.delivered) InfoBanner(text: t('s16_waiting_confirmation'), icon: Icons.hourglass_top),
        if (isDriver && b.status == BookingStatus.confirmed)
          InfoBanner(
            key: const Key('s16_payout_info'),
            icon: Icons.payments_outlined,
            color: AppTheme.success,
            text: state.earlyRateApplies && confirmedAt != null
                ? t.f('s16_payout_held', {'date': Fmt.dateShort(state.heldPayoutDate(confirmedAt), locale)})
                : t('s16_payout_pending'),
          ),
        SectionTitle(t('s16_timeline')),
        BookingTimeline(booking: b, viewer: viewer),
        TextButton.icon(
          key: const Key('s16_view_all_states'),
          onPressed: () => Navigator.pushNamed(context, Routes.timelineDemo),
          icon: const Icon(Icons.account_tree_outlined),
          label: Text(t('s16_view_all_states')),
        ),
        SectionTitle(t('s16_contact')),
        Card(
          child: ListTile(
            leading: const PhotoPlaceholder(size: 44, icon: Icons.person_outline),
            title: Text(isDriver
                ? state.shipper.name
                : (custodyFunded ? d.fullName : d.firstName)),
            subtitle: Text(
              isDriver
                  ? '${b.load?.shipperName ?? state.shipperCompany} · ${t('role_shipper')}'
                  : custodyFunded
                      ? '${d.operator} · ${d.plate}'
                      : '${d.operator} · ${t('s12_plate_note')}',
              key: const Key('s16_contact_subtitle'),
            ),
          ),
        ),
        if (!isDriver && custodyFunded)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(t('s16_full_name_revealed'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          ),
        const SizedBox(height: 8),
        Column(
          children: [
            SecondaryButton(label: t('s16_call'), icon: Icons.phone_outlined, onPressed: () {}),
            const SizedBox(height: 8),
            SecondaryButton(label: t('s16_message'), icon: Icons.chat_bubble_outline, onPressed: () {}),
          ],
        ),
        SectionTitle(t('s16_map')),
        Container(
          height: 120,
          decoration: BoxDecoration(color: AppTheme.surfaceMuted, borderRadius: BorderRadius.circular(10)),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map_outlined, color: scheme.outline),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('${t('s16_pickup_at')}: ${b.trip.origin} · ${t('s16_delivery_at')}: ${b.trip.destination}',
                      textAlign: TextAlign.center, style: TextStyle(color: scheme.outline, fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
        if (d.vehicle.tracking && b.status == BookingStatus.inTransit)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.location_searching),
            title: Text(t('s16_tracking_link')),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {},
          ),
        SectionTitle(t('s16_documents')),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.receipt_outlined),
          title: Text(t('s17_download_receipt')),
          enabled: custodyFunded,
          onTap: custodyFunded ? () {} : null,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.description_outlined),
          title: Text(t('s17_download_invoice')),
          enabled: b.status == BookingStatus.settled,
          onTap: b.status == BookingStatus.settled ? () {} : null,
        ),
        const SizedBox(height: 12),
        if (!isDriver && b.status == BookingStatus.pickedUp)
          InfoBanner(
            key: const Key('s16_no_cancel_after_pickup'),
            text: t('s16_shipper_no_cancel_after_pickup'),
            icon: Icons.report_problem_outlined,
            color: AppTheme.secondary,
          ),
        if (BookingStateMachine.canCancel(b.status, viewer))
          SecondaryButton(
            key: const Key('s16_cancel_booking'),
            label: t('s16_cancel_booking'),
            icon: Icons.cancel_outlined,
            onPressed: () => _cancelFlow(context, b, viewer),
          ),
        if (BookingStateMachine.disputable.contains(b.status)) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              key: const Key('s16_report_problem'),
              onPressed: () => Navigator.pushNamed(context, Routes.s20, arguments: b.id),
              icon: const Icon(Icons.report_problem_outlined),
              label: Text(t('s16_report_problem')),
            ),
          ),
        ],
        ..._demoControls(context, b, viewer),
      ],
    );
  }

  Widget? _primaryAction(BuildContext context, Booking b, UserRole viewer) {
    final t = context.t;
    final state = AppScope.of(context);
    final isDriver = viewer == UserRole.driver;
    switch (b.status) {
      case BookingStatus.accepted:
        if (!isDriver) {
          return PrimaryButton(
            key: const Key('s16_pay'),
            label: t('s17_title'),
            icon: Icons.payment,
            onPressed: () => Navigator.pushNamed(context, Routes.s17, arguments: b.id),
          );
        }
        return null;
      case BookingStatus.paid:
        if (isDriver) {
          return PrimaryButton(
            key: const Key('s16_pickup_evidence'),
            label: t('s16_pickup_evidence'),
            icon: Icons.photo_camera_outlined,
            onPressed: () => Navigator.pushNamed(context, Routes.s18, arguments: EvidenceArgs(bookingId: b.id, pickup: true)),
          );
        }
        return null;
      case BookingStatus.pickedUp:
        if (isDriver) {
          return PrimaryButton(
            key: const Key('s16_start_transit'),
            label: t('s16_start_transit'),
            icon: Icons.play_arrow_outlined,
            onPressed: () => _startTransit(context, b),
          );
        }
        return null;
      case BookingStatus.inTransit:
        if (isDriver) {
          return PrimaryButton(
            key: const Key('s16_delivery_evidence'),
            label: t('s16_delivery_evidence'),
            icon: Icons.photo_camera_outlined,
            onPressed: () => Navigator.pushNamed(context, Routes.s18, arguments: EvidenceArgs(bookingId: b.id, pickup: false)),
          );
        }
        return null;
      case BookingStatus.delivered:
        if (!isDriver) {
          return PrimaryButton(
            key: const Key('s16_confirm_delivery'),
            label: t('s16_confirm_delivery'),
            icon: Icons.check_circle_outline,
            onPressed: () {
              state.advance(b, BookingStatus.confirmed);
              Navigator.pushNamed(context, Routes.s19, arguments: b.id);
            },
          );
        }
        return null;
      case BookingStatus.confirmed:
      case BookingStatus.settled:
        return PrimaryButton(
          key: const Key('s16_rate'),
          label: t('s16_rate'),
          icon: Icons.star_outline,
          onPressed: () => Navigator.pushNamed(context, Routes.s19, arguments: b.id),
        );
      default:
        return null;
    }
  }

  Future<void> _startTransit(BuildContext context, Booking b) async {
    final t = context.t;
    final state = AppScope.of(context);
    if (!state.shareLocation) {
      final share = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t('s16_location_consent_title')),
          content: Text(t('s16_location_consent_body')),
          actions: [
            TextButton(key: const Key('s16_location_decline'), onPressed: () => Navigator.pop(ctx, false), child: Text(t('s16_location_decline'))),
            FilledButton(key: const Key('s16_location_accept'), onPressed: () => Navigator.pop(ctx, true), child: Text(t('s16_location_accept'))),
          ],
        ),
      );
      if (share == true) state.setShareLocation(true);
    }
    state.advance(b, BookingStatus.inTransit);
  }

  /// Shows the consequence before the confirm button (A7.6 / A10.4).
  Future<void> _cancelFlow(BuildContext context, Booking b, UserRole viewer) async {
    final t = context.t;
    final state = AppScope.of(context);
    final locale = state.locale;
    final String consequence;
    if (viewer == UserRole.shipper) {
      switch (state.refundOutcome(b)) {
        case RefundOutcome.nothingPaid:
          consequence = t('s16_cancel_unpaid');
        case RefundOutcome.partial:
          consequence = t.f('s16_cancel_refund_partial', {
            'refund': Fmt.integer(state.refundAmount(b), locale),
            'penalty': Fmt.integer(state.penaltyAmount(b), locale),
          });
        case RefundOutcome.full:
          consequence = t.f('s16_cancel_refund_full', {'x': Fmt.integer(state.refundAmount(b), locale)});
        case RefundOutcome.notAllowed:
          // The button is hidden in this state; guard against a stale tap.
          return;
      }
    } else {
      final c = strikeConsequence(state.driver.strikes);
      final base = switch (c) {
        StrikeConsequence.warning => t('s16_cancel_strike_1'),
        StrikeConsequence.rankingPenalty => t('s16_cancel_strike_2'),
        StrikeConsequence.suspension => t('s16_cancel_strike_3'),
      };
      consequence = b.status == BookingStatus.pickedUp ? '$base ${t('s16_cancel_after_pickup')}' : base;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text(t('s16_cancel_title'), style: Theme.of(ctx).textTheme.titleLarge)),
            const SizedBox(height: 12),
            InfoBanner(
              key: const Key('s16_cancel_consequence'),
              text: consequence,
              icon: viewer == UserRole.shipper ? Icons.currency_exchange : Icons.warning_amber_outlined,
              color: viewer == UserRole.shipper ? AppTheme.primary : AppTheme.danger,
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              key: const Key('s16_cancel_keep'),
              label: t('s16_cancel_keep'),
              onPressed: () => Navigator.pop(ctx, false),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                key: const Key('s16_cancel_confirm'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(t('s16_cancel_confirm')),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    if (viewer == UserRole.driver) {
      state.driverCancel(b);
    } else {
      state.advance(b, BookingStatus.cancelled);
    }
  }

  /// Mocked counterpart / system events so each role can walk the full flow.
  List<Widget> _demoControls(BuildContext context, Booking b, UserRole viewer) {
    final t = context.t;
    final state = AppScope.of(context);
    final isDriver = viewer == UserRole.driver;
    final buttons = <Widget>[];

    void demo(String key, String label, VoidCallback onTap) {
      buttons.add(OutlinedButton(key: Key(key), onPressed: onTap, child: Text(label, textAlign: TextAlign.center)));
    }

    switch (b.status) {
      case BookingStatus.accepted when isDriver:
        demo('s16_demo_paid', t('s16_demo_shipper_paid'), () => state.advance(b, BookingStatus.paid));
      case BookingStatus.paid when !isDriver:
        demo('s16_demo_pickedup', '${t('demo')}: ${t.bookingLabel(BookingStatus.pickedUp)}', () => state.advance(b, BookingStatus.pickedUp));
      case BookingStatus.pickedUp when !isDriver:
        demo('s16_demo_transit', '${t('demo')}: ${t.bookingLabel(BookingStatus.inTransit)}', () => state.advance(b, BookingStatus.inTransit));
      case BookingStatus.inTransit when !isDriver:
        demo('s16_demo_delivered', '${t('demo')}: ${t.bookingLabel(BookingStatus.delivered)}', () => state.advance(b, BookingStatus.delivered));
      case BookingStatus.delivered when isDriver:
        demo('s16_demo_confirmed', '${t('demo')}: ${t.bookingLabel(BookingStatus.confirmed)}', () => state.advance(b, BookingStatus.confirmed));
      case BookingStatus.confirmed:
        demo('s16_demo_settle', t('s16_demo_settle'), () => state.advance(b, BookingStatus.settled));
      case BookingStatus.inDispute:
        demo('s16_demo_dispute_resolved', t('s16_demo_dispute_resolved'), () => state.advance(b, BookingStatus.settled));
      default:
        break;
    }
    if (b.pendingSync) {
      demo('s16_demo_sync', '${t('demo')}: ${t('s16_pending_sync')} ✓', () => state.markSynced(b));
    }
    if (buttons.isEmpty) return const [];
    return [
      const SizedBox(height: 12),
      DemoNote(t('demo_hint')),
      Wrap(spacing: 8, runSpacing: 8, children: buttons),
    ];
  }
}

// ---------------------------------------------------------------------------
// S18 Pickup / delivery evidence (2 + 2 photos, A8.1)
// ---------------------------------------------------------------------------
class EvidenceArgs {
  const EvidenceArgs({required this.bookingId, required this.pickup});
  final String bookingId;
  final bool pickup;
}

class S18Evidence extends StatefulWidget {
  const S18Evidence({super.key, required this.args});
  final EvidenceArgs args;

  @override
  State<S18Evidence> createState() => _S18EvidenceState();
}

class _S18EvidenceState extends State<S18Evidence> {
  bool _cargo = false;
  bool _doc = false;
  final _receiver = TextEditingController();
  bool _offlineQueue = false;

  @override
  void dispose() {
    _receiver.dispose();
    super.dispose();
  }

  bool get _ready => _cargo && _doc && (widget.args.pickup || _receiver.text.trim().isNotEmpty);

  void _submit() {
    final state = AppScope.of(context);
    final b = state.bookingById(widget.args.bookingId)!;
    state.advance(
      b,
      widget.args.pickup ? BookingStatus.pickedUp : BookingStatus.delivered,
      pendingSync: _offlineQueue,
    );
    if (_offlineQueue) b.pendingUploads = 2;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final pickup = widget.args.pickup;
    final scheme = Theme.of(context).colorScheme;
    final uploaded = (_cargo ? 1 : 0) + (_doc ? 1 : 0);
    return AppScreen(
      title: pickup ? t('s18_title_pickup') : t('s18_title_delivery'),
      screenId: 'S18',
      bottom: PrimaryButton(
        key: const Key('s18_submit'),
        label: pickup ? t('s18_submit_pickup') : t('s18_submit_delivery'),
        onPressed: _ready ? _submit : null,
      ),
      children: [
        InfoBanner(text: t('s18_guide'), icon: Icons.privacy_tip_outlined),
        CaptureTrio(
          keyPrefix: 's18_cargo',
          label: t('s18_photo_cargo'),
          captured: _cargo,
          onCapture: () => setState(() => _cargo = true),
        ),
        CaptureTrio(
          keyPrefix: 's18_doc',
          label: '${t('s18_photo_doc')} · ${t('s18_photo_doc_hint')}',
          captured: _doc,
          onCapture: () => setState(() => _doc = true),
        ),
        Text(t('s18_gallery_weaker'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        if (uploaded > 0) ...[
          const SizedBox(height: 8),
          Semantics(
            label: t.f('s18_uploading', {'n': '$uploaded'}),
            child: LinearProgressIndicator(value: uploaded / 2, minHeight: 6),
          ),
          Text(t.f('s18_uploading', {'n': '$uploaded'}), style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
        if (!_ready && (!_cargo || !_doc))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(t('s18_need_photos'), style: const TextStyle(color: AppTheme.danger)),
          ),
        if (!pickup) ...[
          SectionTitle(t('s18_receiver_name')),
          Text(t('s18_receiver_notice'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          TextField(
            key: const Key('s18_receiver'),
            controller: _receiver,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: t('s18_receiver_name')),
          ),
          const SizedBox(height: 12),
          Container(
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Center(child: Text(t('s18_signature'), style: TextStyle(color: scheme.outline))),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.my_location, size: 18),
            const SizedBox(width: 6),
            Expanded(child: Text(t('s18_geotag'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant))),
          ],
        ),
        const SizedBox(height: 12),
        DemoNote(t('demo_hint')),
        SwitchListTile(
          key: const Key('s18_offline'),
          value: _offlineQueue,
          onChanged: (v) => setState(() => _offlineQueue = v),
          title: Text('${t('demo')}: ${t('s16_pending_sync')}'),
          subtitle: Text(t('s16_pending_sync_body')),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// S19 Rating
// ---------------------------------------------------------------------------
class S19Rating extends StatefulWidget {
  const S19Rating({super.key, required this.bookingId});
  final String bookingId;

  @override
  State<S19Rating> createState() => _S19RatingState();
}

class _S19RatingState extends State<S19Rating> {
  int _stars = 0;
  final Set<String> _tags = {};
  bool _sent = false;

  static const _positive = ['s19_tag_punctual', 's19_tag_careful', 's19_tag_communicative'];
  static const _negative = ['s19_tag_late', 's19_tag_damaged', 's19_tag_rude'];

  bool get _canSend => _stars > 0 && (_stars > 2 || _tags.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = AppScope.of(context);
    final b = state.bookingById(widget.bookingId)!;
    final counterpart = state.role == UserRole.shipper ? b.trip.driver.firstName : (b.load?.shipperName ?? state.shipper.name);
    final scheme = Theme.of(context).colorScheme;

    if (_sent) {
      return AppScreen(
        title: t('s19_title'),
        screenId: 'S19',
        bottom: PrimaryButton(
          key: const Key('s19_home'),
          label: t('home'),
          onPressed: () => Navigator.pushNamedAndRemoveUntil(context, homeRouteFor(state.role), (r) => r.isFirst),
        ),
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.stars, size: 72, color: AppTheme.secondary),
          const SizedBox(height: 12),
          Text(t('s19_sent'), key: const Key('s19_sent'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(t('s19_blind'), textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      );
    }

    return AppScreen(
      title: t('s19_title'),
      screenId: 'S19',
      bottom: PrimaryButton(
        key: const Key('s19_send'),
        label: t('s19_send'),
        onPressed: _canSend ? () => setState(() => _sent = true) : null,
      ),
      children: [
        Text(t.f('s19_question_driver', {'name': counterpart}), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Semantics(
          label: t('s19_title'),
          value: _stars == 1 ? t.f('s19_star_one', {'n': '1'}) : t.f('s19_star_many', {'n': '$_stars'}),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                Semantics(
                  label: i == 1 ? t.f('s19_star_one', {'n': '$i'}) : t.f('s19_star_many', {'n': '$i'}),
                  button: true,
                  selected: i <= _stars,
                  excludeSemantics: true,
                  child: IconButton(
                    key: Key('s19_star_$i'),
                    iconSize: 40,
                    tooltip: i == 1 ? t.f('s19_star_one', {'n': '$i'}) : t.f('s19_star_many', {'n': '$i'}),
                    onPressed: () => setState(() => _stars = i),
                    icon: Icon(i <= _stars ? Icons.star : Icons.star_border, color: AppTheme.secondary),
                  ),
                ),
            ],
          ),
        ),
        SectionTitle(t('s19_tags')),
        if (_stars > 0 && _stars <= 2) Text(t('s19_low_needs_tag'), style: const TextStyle(color: AppTheme.danger)),
        const SizedBox(height: 8),
        ChipSet(
          keys: _stars > 0 && _stars <= 2 ? _negative : _positive,
          selected: _tags,
          onToggle: (k, on) => setState(() => on ? _tags.add(k) : _tags.remove(k)),
        ),
        SectionTitle(t('s19_comment')),
        TextField(maxLines: 3, decoration: InputDecoration(hintText: t('s19_comment'))),
        const SizedBox(height: 12),
        Text(t('s19_blind'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// S20 Dispute
// ---------------------------------------------------------------------------
class S20Dispute extends StatefulWidget {
  const S20Dispute({super.key, required this.bookingId});
  final String bookingId;

  @override
  State<S20Dispute> createState() => _S20DisputeState();
}

class _S20DisputeState extends State<S20Dispute> {
  String? _reason;
  int _photos = 0;

  static const _reasons = ['s20_reason_noshow', 's20_reason_damage', 's20_reason_missing', 's20_reason_delay', 's20_reason_other'];

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = AppScope.of(context);
    final b = state.bookingById(widget.bookingId)!;
    final scheme = Theme.of(context).colorScheme;
    final open = b.status == BookingStatus.inDispute;

    return AppScreen(
      title: t('s20_title'),
      screenId: 'S20',
      bottom: open
          ? PrimaryButton(
              key: const Key('s20_back'),
              label: t('s16_title'),
              onPressed: () => Navigator.pop(context),
            )
          : PrimaryButton(
              key: const Key('s20_send'),
              label: t('s20_send'),
              onPressed: _reason == null
                  ? null
                  : () {
                      state.advance(b, BookingStatus.inDispute);
                      setState(() {});
                    },
            ),
      children: [
        Text('${b.trip.origin} → ${b.trip.destination}', style: Theme.of(context).textTheme.titleMedium),
        if (open) ...[
          const SizedBox(height: 16),
          InfoBanner(key: const Key('s20_sla'), text: t('s20_sla'), icon: Icons.support_agent, color: AppTheme.secondary),
          SectionTitle(t('s20_status')),
          Badge16(icon: Icons.flag_outlined, label: t.bookingLabel(BookingStatus.inDispute), color: AppTheme.secondary),
        ] else ...[
          SectionTitle(t('s20_reason')),
          RadioGroup<String>(
            groupValue: _reason,
            onChanged: (v) => setState(() => _reason = v),
            child: Column(
              children: [
                for (final r in _reasons)
                  RadioListTile<String>(
                    key: Key(r),
                    value: r,
                    title: Text(t(r)),
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
          SectionTitle(t('s20_evidence')),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => _photos++),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(t('s20_add_photo')),
              ),
              const SizedBox(width: 12),
              if (_photos > 0) Text(t.f('s14_photo_added', {'n': '$_photos'})),
            ],
          ),
          SectionTitle(t('s20_describe')),
          TextField(maxLines: 4, decoration: InputDecoration(hintText: t('s20_describe'))),
          const SizedBox(height: 8),
          Text(t('s20_sla'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// S22 Notification centre
// ---------------------------------------------------------------------------
class S22Notifications extends StatelessWidget {
  const S22Notifications({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = AppScope.of(context);
    final locale = state.locale;
    final scheme = Theme.of(context).colorScheme;
    final mine = state.notificationsFor(state.role ?? UserRole.driver);
    return AppScreen(
      title: t('s22_title'),
      screenId: 'S22',
      children: [
        InfoBanner(text: t('s22_whatsapp_primary'), icon: Icons.chat_outlined, color: AppTheme.success),
        SecondaryButton(label: t('s22_confirm_number'), icon: Icons.verified_outlined, onPressed: () {}),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.verified_user_outlined, size: 18, color: AppTheme.success),
            const SizedBox(width: 6),
            Expanded(child: Text(t('s22_official'), style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        const SizedBox(height: 4),
        Text(t('s22_rule'), style: TextStyle(color: scheme.onSurfaceVariant)),
        SectionTitle(t('s22_title')),
        if (mine.isEmpty) Text(t('s22_empty'), style: TextStyle(color: scheme.onSurfaceVariant)),
        for (final n in mine)
          ListTile(
            key: Key('s22_${n.key}_${n.bookingId}'),
            contentPadding: EdgeInsets.zero,
            leading: Icon(n.channel == 'whatsapp' ? Icons.chat : Icons.notifications_active_outlined,
                color: n.channel == 'whatsapp' ? AppTheme.success : AppTheme.primary),
            title: Text(t.f(n.key, n.args)),
            subtitle: Text('${n.channel == 'whatsapp' ? t('s22_channel_whatsapp') : t('s22_channel_push')} · ${Fmt.dateTime(n.at, locale)}'),
            onTap: n.bookingId == null ? null : () => Navigator.pushNamed(context, Routes.s16, arguments: n.bookingId),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// S23 Settings (language toggle, consents, LOPDP entry points, fleet)
// ---------------------------------------------------------------------------
class S23Settings extends StatelessWidget {
  const S23Settings({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isDriver = state.role == UserRole.driver;

    void info(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

    return AppScreen(
      title: t('s23_title'),
      screenId: 'S23',
      children: [
        SectionTitle(t('s23_language')),
        SegmentedButton<AppLocale>(
          key: const Key('s23_language'),
          segments: [
            ButtonSegment(value: AppLocale.es, label: Text(t('lang_es'))),
            ButtonSegment(value: AppLocale.en, label: Text(t('lang_en'))),
          ],
          selected: {state.locale},
          onSelectionChanged: (s) => state.setLocale(s.first),
        ),
        SectionTitle(t('s23_accessibility')),
        SwitchListTile(
          key: const Key('s23_large_text'),
          value: state.largeText,
          onChanged: state.setLargeText,
          title: Text(t('s23_large_text')),
          contentPadding: EdgeInsets.zero,
        ),
        if (isDriver) ...[
          SectionTitle(t('s23_documents')),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.folder_outlined),
            title: Text(t('s23_documents')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, Routes.s05),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_balance_outlined),
            title: Text(t('s23_bank')),
            subtitle: Text(t('s23_bank_reauth')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => info(t('s23_bank_reauth')),
          ),
        ],
        SectionTitle(t('s23_phone')),
        ListTile(
          key: const Key('s23_phone'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.phone_android_outlined),
          title: Text(t('s23_phone')),
          subtitle: Text(t('s23_phone_body')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(t('s23_phone')),
              content: Text(t('s23_phone_body')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('cancel'))),
                FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(t('continue'))),
              ],
            ),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.logout),
          title: Text(t('s23_logout_all')),
          onTap: () => info(t('s23_done')),
        ),
        SectionTitle(t('s23_consents')),
        SwitchListTile(
          key: const Key('s23_consent_location'),
          value: state.shareLocation,
          onChanged: state.setShareLocation,
          title: Text(t('s23_consent_location')),
          contentPadding: EdgeInsets.zero,
        ),
        SwitchListTile(
          value: isDriver ? state.driver.marketingOptIn : state.shipper.marketingOptIn,
          onChanged: (v) {
            if (isDriver) {
              state.driver.marketingOptIn = v;
            } else {
              state.shipper.marketingOptIn = v;
            }
            state.setLargeText(state.largeText); // trigger rebuild
          },
          title: Text(t('s23_consent_marketing')),
          contentPadding: EdgeInsets.zero,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.download_outlined),
          title: Text(t('s23_download_data')),
          onTap: () => info(t('s23_done')),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.delete_outline, color: AppTheme.danger),
          title: Text(t('s23_delete_account'), style: const TextStyle(color: AppTheme.danger)),
          onTap: () => info(t('s23_done')),
        ),
        if (isDriver) ...[
          SectionTitle(t('s23_fleet')),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.local_shipping_outlined),
            title: Text('${t(MockData.me.vehicle.bodyType)} · ${MockData.me.plate}'),
            subtitle: Text(t('badge_verified')),
          ),
          Row(
            children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => info(t('s23_done')), icon: const Icon(Icons.add), label: Text(t('s23_add_vehicle'), maxLines: 1, overflow: TextOverflow.ellipsis))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: () => info(t('s23_done')), icon: const Icon(Icons.person_add_alt), label: Text(t('s23_invite_driver'), maxLines: 1, overflow: TextOverflow.ellipsis))),
            ],
          ),
        ],
        SectionTitle(t('demo')),
        ListTile(
          key: const Key('s23_timeline_demo'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.account_tree_outlined),
          title: Text(t('s23_timeline_demo')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(context, Routes.timelineDemo),
        ),
        ListTile(
          key: const Key('s23_switch_role'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.swap_horiz),
          title: Text(t('s23_switch_role')),
          onTap: () {
            state.resetSession();
            Navigator.pushNamedAndRemoveUntil(context, Routes.s01, (_) => false);
          },
        ),
        const SizedBox(height: 8),
        Text(t('demo_hint'), style: TextStyle(fontSize: 13, color: scheme.outline)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Timeline demo: every state of the 4.5 diagram with label + notification
// ---------------------------------------------------------------------------
class TimelineDemo extends StatefulWidget {
  const TimelineDemo({super.key});

  @override
  State<TimelineDemo> createState() => _TimelineDemoState();
}

class _TimelineDemoState extends State<TimelineDemo> {
  UserRole _viewer = UserRole.driver;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = AppScope.of(context);
    final locale = state.locale;
    final scheme = Theme.of(context).colorScheme;
    final sample = DateTime(2026, 11, 27, 14);

    return AppScreen(
      title: t('td_title'),
      screenId: 'S16',
      children: [
        Text(t('td_intro'), style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        SegmentedButton<UserRole>(
          key: const Key('td_viewer'),
          segments: [
            ButtonSegment(value: UserRole.driver, label: Text(t('td_viewer_driver'))),
            ButtonSegment(value: UserRole.shipper, label: Text(t('td_viewer_shipper'))),
          ],
          selected: {_viewer},
          onSelectionChanged: (s) => setState(() => _viewer = s.first),
        ),
        SectionTitle(t('td_listing')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in ListingStatus.values)
              Badge16(key: Key('td_listing_${s.name}'), icon: Icons.flag_outlined, label: t.listingLabel(s), color: scheme.outline),
          ],
        ),
        Text('${t('bn_published_trip')} / ${t('bn_trip_lapsed')}', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        SectionTitle(t('td_booking')),
        for (final s in BookingStatus.values)
          Card(
            key: Key('td_booking_${s.name}'),
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Badge16(icon: Icons.circle, label: t.bookingLabel(s, viewer: _viewer), color: _colorFor(s, scheme)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${t('td_notification')}: ${t.f('bn_${s.name}', {'date': Fmt.dateTime(sample, locale), 'city': 'Quito', 'name': 'Luis', 'x': '450'})}',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  if (s == BookingStatus.confirmed)
                    Text(
                      t.f('bn_confirmed_held', {'date': Fmt.dateShort(DateTime(2026, 12, 4), locale)}),
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  if (s == BookingStatus.cancelled)
                    Text(t('bn_cancelled_strike'), style: TextStyle(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Color _colorFor(BookingStatus s, ColorScheme scheme) {
    switch (s) {
      case BookingStatus.cancelled:
      case BookingStatus.rejected:
      case BookingStatus.expired:
      case BookingStatus.lapsed:
        return AppTheme.danger;
      case BookingStatus.inDispute:
        return AppTheme.secondary;
      case BookingStatus.settled:
      case BookingStatus.confirmed:
        return AppTheme.success;
      default:
        return scheme.primary;
    }
  }
}
