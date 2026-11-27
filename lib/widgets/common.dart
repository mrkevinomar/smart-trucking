import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/booking_state_machine.dart';
import '../core/enums.dart';
import '../core/models.dart';
import '../core/money.dart';
import '../l10n/strings.dart';
import '../pwa/install_prompt.dart';
import '../theme.dart';

/// Mobile-first frame: on wide screens the content is centred at 480 px so the
/// prototype stays usable on desktop (section 4 intro).
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width <= 600) return child;
    return ColoredBox(
      color: AppTheme.surfaceMuted,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Material(elevation: 2, child: child),
        ),
      ),
    );
  }
}

/// Screen with an app bar, scrollable body and an optional fixed bottom CTA in
/// the thumb zone (4.7 "CTA inferior fijo en formularios largos").
class AppScreen extends StatelessWidget {
  const AppScreen({
    super.key,
    required this.title,
    required this.children,
    this.bottom,
    this.actions,
    this.screenId,
    this.leading,
    this.scrollKey,
  });

  final String title;
  final List<Widget> children;
  final Widget? bottom;
  final List<Widget>? actions;
  final String? screenId;
  final Widget? leading;
  final Key? scrollKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: leading,
        title: Semantics(
          header: true,
          child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        actions: [
          ...?actions,
          if (screenId != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Semantics(
                  label: 'Screen $screenId',
                  child: Text(
                    screenId!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        key: scrollKey,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: children,
      ),
      bottomNavigationBar: bottom == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: bottom,
              ),
            ),
    );
  }
}

/// Primary CTA that fills the width (48 dp min height from theme).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: icon == null
          ? FilledButton(onPressed: onPressed, child: Text(label))
          : FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
            ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: icon == null
          ? OutlinedButton(onPressed: onPressed, child: Text(label))
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
            ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

/// Small note that marks a mocked action, so reviewers know it is a demo
/// control and not product UI.
class DemoNote extends StatelessWidget {
  const DemoNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

/// Informational banner (warnings, pending uploads, escrow explanation).
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.text,
    this.icon = Icons.info_outline,
    this.color,
    this.semanticsLabel,
  });
  final String text;
  final IconData icon;
  final Color? color;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return Semantics(
      label: semanticsLabel,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: c),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

/// Icon + text badge (4.1 principle 4: never colour or icon alone).
class Badge16 extends StatelessWidget {
  const Badge16({
    super.key,
    required this.icon,
    required this.label,
    this.color,
  });
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mock image placeholder (vehicle / cargo photos).
class PhotoPlaceholder extends StatelessWidget {
  const PhotoPlaceholder({
    super.key,
    this.size = 56,
    this.icon = Icons.local_shipping_outlined,
    this.label,
  });
  final double size;
  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppTheme.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.outline),
      ),
    );
  }
}

/// S16 booking timeline (shared component, 4.5). Shows the happy path with
/// the reached states filled, plus any branch state (cancelled, lapsed,
/// in dispute, rejected, expired) appended when the booking is there.
class BookingTimeline extends StatelessWidget {
  const BookingTimeline({
    super.key,
    required this.booking,
    required this.viewer,
  });
  final Booking booking;
  final UserRole viewer;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = AppScope.of(context);
    final reached = booking.history.map((e) => e.status).toSet();
    final steps = <BookingStatus>[...BookingStateMachine.happyPath];
    final current = booking.status;
    final branch = !steps.contains(current) ? current : null;
    if (branch != null) {
      // Insert the branch right after the last reached happy-path state.
      var idx = 0;
      for (var i = 0; i < steps.length; i++) {
        if (reached.contains(steps[i])) idx = i + 1;
      }
      steps.insert(idx, branch);
      steps.removeRange(idx + 1, steps.length);
    }
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: '${t('s16_timeline')}: ${t.bookingLabel(current, viewer: viewer)}',
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            _TimelineRow(
              label: t.bookingLabel(steps[i], viewer: viewer),
              time: _timeFor(steps[i], state),
              done: reached.contains(steps[i]),
              current: steps[i] == current,
              last: i == steps.length - 1,
              pendingSync: booking.history.any(
                (e) => e.status == steps[i] && e.pendingSync,
              ),
              color: _colorFor(steps[i], scheme),
            ),
        ],
      ),
    );
  }

  String? _timeFor(BookingStatus s, AppState state) {
    for (final e in booking.history) {
      if (e.status == s) return Fmt.dateTime(e.at, state.locale);
    }
    return null;
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

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.time,
    required this.done,
    required this.current,
    required this.last,
    required this.pendingSync,
    required this.color,
  });
  final String label;
  final String? time;
  final bool done;
  final bool current;
  final bool last;
  final bool pendingSync;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final scheme = Theme.of(context).colorScheme;
    final dotColor = done ? color : scheme.outlineVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Column(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? dotColor : Colors.white,
                  border: Border.all(color: dotColor, width: 2),
                ),
                child: done
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              if (!last)
                Container(
                  width: 2,
                  height: 36,
                  color: done ? dotColor : scheme.outlineVariant,
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                    color: done ? scheme.onSurface : scheme.outline,
                  ),
                ),
                if (time != null)
                  Text(time!, style: TextStyle(color: scheme.onSurfaceVariant)),
                if (pendingSync)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Badge16(
                      icon: Icons.cloud_upload_outlined,
                      label: t('s16_pending_sync'),
                      color: AppTheme.secondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// PWA install sheet (4.3 / 4.4). Shows the official domain so a look-alike
/// clone can be recognised (5.6), iOS manual steps, and triggers the native
/// `beforeinstallprompt` when the browser offers it.
Future<void> showInstallSheet(BuildContext context) async {
  final state = AppScope.of(context);
  state.markInstallSheetShown();
  final t = context.t;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.install_mobile, size: 32, color: AppTheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      t('install_title'),
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(t('install_body')),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.verified_user_outlined, size: 18, color: AppTheme.success),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    t('install_domain'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(t('install_ios'), style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            PrimaryButton(
              key: const Key('install_cta'),
              label: t('install_cta'),
              icon: Icons.add_to_home_screen,
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(ctx);
                final accepted = InstallPrompt.isAvailable ? await InstallPrompt.show() : false;
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(accepted ? t('install_done') : t('install_unavailable')),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                key: const Key('install_later'),
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(t('install_later')),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Stepper row used in filter sheets ("selectores numéricos").
class StepperRow extends StatelessWidget {
  const StepperRow({
    super.key,
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    this.semanticsValue,
  });
  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final String? semanticsValue;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      value: semanticsValue ?? value,
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
          IconButton.outlined(
            onPressed: onMinus,
            icon: const Icon(Icons.remove),
            tooltip: '-',
          ),
          SizedBox(
            width: 72,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton.outlined(
            onPressed: onPlus,
            icon: const Icon(Icons.add),
            tooltip: '+',
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet frame for filters: scrollable content, "Aplicar" fixed in the
/// thumb zone and a "Limpiar" link.
class FilterSheetFrame extends StatelessWidget {
  const FilterSheetFrame({
    super.key,
    required this.title,
    required this.children,
    required this.onApply,
    required this.onClear,
  });
  final String title;
  final List<Widget> children;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
                  ),
                ),
                TextButton(
                  key: const Key('filter_clear'),
                  onPressed: onClear,
                  child: Text(t('clear')),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              children: children,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: PrimaryButton(
              key: const Key('filter_apply'),
              label: t('apply'),
              onPressed: onApply,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip row helper for multi-select sets.
class ChipSet extends StatelessWidget {
  const ChipSet({
    super.key,
    required this.keys,
    required this.selected,
    required this.onToggle,
  });
  final List<String> keys;
  final Set<String> selected;
  final void Function(String key, bool on) onToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final k in keys)
          FilterChip(
            label: Text(t(k)),
            selected: selected.contains(k),
            onSelected: (on) => onToggle(k, on),
          ),
      ],
    );
  }
}

/// S12 / S13 trip card. Hides strike-through and saving badge when the trip
/// has no reference price (4.1 principle 2, copy table "Ahorro").
class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.trip,
    required this.onBook,
    required this.onOffer,
    this.onTap,
  });
  final Trip trip;
  final VoidCallback onBook;
  final VoidCallback onOffer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final locale = AppScope.of(context).locale;
    final d = trip.driver;
    final v = d.vehicle;
    final scheme = Theme.of(context).colorScheme;
    final hasRef = trip.referencePrice != null;

    return Card(
      key: Key('trip_card_${trip.id}'),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${trip.origin} → ${trip.destination}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      Fmt.dateWithPeriod(trip.departure, locale),
                      textAlign: TextAlign.end,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text('${d.firstName} · ${d.operator}', overflow: TextOverflow.ellipsis),
                  ),
                  const Icon(Icons.star, size: 16, color: AppTheme.secondary),
                  const SizedBox(width: 2),
                  Text(t.f('rating_count', {
                    'r': Fmt.rating(d.rating, locale),
                    'n': '${d.ratingCount}',
                  })),
                ],
              ),
              if (d.verified)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Badge16(icon: Icons.verified_outlined, label: t('badge_verified'), color: AppTheme.success),
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  PhotoPlaceholder(label: '${t(v.bodyType)} ${t('s12_plate_note')}'),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${t(v.bodyType)} ${t.f('unit_tons', {'t': _num(v.capacityTons, locale)})}',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(t.f('s12_free', {
                          't': _num(v.freeTons, locale),
                          'm': _num(v.freeM3, locale),
                        })),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (v.insured)
                    Badge16(
                      icon: Icons.shield_outlined,
                      label: v.insuranceCoverage == null
                          ? t('svc_insured')
                          : t.f('svc_insured_amount', {'x': _short(v.insuranceCoverage!)}),
                    ),
                  if (v.tracking)
                    Badge16(icon: Icons.location_searching, label: t('svc_tracking')),
                  if (trip.isReturnLeg)
                    Badge16(icon: Icons.u_turn_left, label: t('badge_return'), color: AppTheme.secondary),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Fmt.usd(trip.price, locale),
                    key: Key('trip_price_${trip.id}'),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 10),
                  if (hasRef) ...[
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: t('s12_why_cheaper'),
                        child: InkWell(
                          key: Key('trip_ref_${trip.id}'),
                          onTap: () => _whyCheaper(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              '${t.f('s12_before', {'x': Fmt.integer(trip.referencePrice!, locale)})}'
                              '${trip.referenceIsEstimate ? ' ${t('s12_estimate')}' : ''}',
                              style: TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      child: Badge16(
                        key: Key('trip_saving_${trip.id}'),
                        icon: Icons.savings_outlined,
                        label: t.f('s12_save', {'p': '${trip.savingPercent}'}),
                        color: AppTheme.success,
                      ),
                    ),
                  ] else
                    Expanded(
                      child: Text(
                        t('s12_no_reference'),
                        key: Key('trip_noref_${trip.id}'),
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      key: Key('trip_book_${trip.id}'),
                      onPressed: trip.instantBooking ? onBook : null,
                      child: Text(t('s12_book')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      key: Key('trip_offer_${trip.id}'),
                      onPressed: onOffer,
                      child: Text(t('s12_offer')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _whyCheaper(BuildContext context) {
    final t = context.t;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('s12_why_cheaper')),
        content: Text(t('s12_why_cheaper_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('close'))),
        ],
      ),
    );
  }

  static String _num(double v, AppLocale locale) {
    final s = v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
    return locale == AppLocale.es ? s.replaceAll('.', ',') : s;
  }

  static String _short(int usd) => usd >= 1000 ? '${usd ~/ 1000}k' : '$usd';
}

/// S09 load card.
class LoadCard extends StatelessWidget {
  const LoadCard({
    super.key,
    required this.load,
    required this.onOffer,
  });
  final Load load;
  final VoidCallback onOffer;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final locale = AppScope.of(context).locale;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: Key('load_card_${load.id}'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${load.origin} → ${load.destination}',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Flexible(child: Text(Fmt.dateLong(load.date, locale), style: TextStyle(color: scheme.onSurfaceVariant))),
              ],
            ),
            const SizedBox(height: 6),
            Text(t.f('s09_extra_km', {'km': '${load.detourKm}'}),
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Badge16(icon: Icons.inventory_2_outlined, label: t(load.cargoType)),
                Badge16(icon: Icons.scale_outlined, label: t.f('unit_kg', {'x': Fmt.integer(load.weightKg, locale)})),
                Badge16(icon: Icons.view_in_ar_outlined, label: t.f('unit_m3', {'x': TripCard._num(load.volumeM3, locale)})),
                for (final s in load.requiredServices)
                  Badge16(icon: s == 'svc_insured' ? Icons.shield_outlined : Icons.location_searching, label: t(s), color: AppTheme.secondary),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('s09_target_price'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                      Text(Fmt.usd(load.targetPrice, locale),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const Icon(Icons.star, size: 16, color: AppTheme.secondary),
                const SizedBox(width: 2),
                Flexible(child: Text('${Fmt.rating(load.shipperRating, locale)} · ${load.shipperName}', overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: Key('load_offer_${load.id}'),
                onPressed: onOffer,
                child: Text(t('s09_offer')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simulated capture button trio (4.3 S04 "tomar foto / galería / PDF").
class CaptureTrio extends StatelessWidget {
  const CaptureTrio({
    super.key,
    required this.label,
    required this.captured,
    required this.onCapture,
    this.keyPrefix,
  });
  final String label;
  final bool captured;
  final VoidCallback onCapture;
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
              if (captured)
                Badge16(icon: Icons.check_circle_outline, label: t('s04_captured'), color: AppTheme.success),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, style: BorderStyle.solid),
            ),
            child: Icon(captured ? Icons.image_outlined : Icons.photo_camera_outlined, size: 40, color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  key: keyPrefix == null ? null : Key('${keyPrefix}_camera'),
                  onPressed: onCapture,
                  child: Text(t('s04_take_photo'), textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: onCapture,
                  child: Text(t('s04_gallery'), textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: onCapture,
                  child: Text(t('s04_pdf'), textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
