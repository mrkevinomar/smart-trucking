import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_trucking/app.dart';
import 'package:smart_trucking/core/app_state.dart';
import 'package:smart_trucking/core/enums.dart';
import 'package:smart_trucking/core/models.dart';

Future<AppState> pumpApp(WidgetTester tester, {AppState? state}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final s = state ?? AppState();
  await tester.pumpWidget(SmartTruckingApp(state: s));
  await tester.pumpAndSettle();
  return s;
}

Future<void> tapKey(WidgetTester tester, String key, {bool scroll = true}) async {
  final finder = find.byKey(Key(key));
  if (scroll) {
    if (finder.evaluate().isEmpty) {
      // Lazily built ListView child: scroll the page until it exists.
      await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
    } else {
      await tester.ensureVisible(finder);
    }
    await tester.pumpAndSettle();
  }
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Scrolls the first ListView back to the top (ListView keeps its offset
/// across route pops, so banners above the fold may be unbuilt).
Future<void> scrollTop(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
  await tester.pumpAndSettle();
}

/// Scroll the first ListView down until [finder] is visible, then tap it.
Future<void> scrollTap(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> signIn(WidgetTester tester, String roleKey) async {
  await tapKey(tester, roleKey);
  expect(find.text('Ingresa con tu teléfono'), findsOneWidget); // S02
  await tapKey(tester, 's02_send');
  await tester.enterText(find.byKey(const Key('s02_code')), '123456');
  await tapKey(tester, 's02_verify', scroll: false);
}

void main() {
  group('S01 / S02', () {
    testWidgets('Spanish is the default copy on S01', (tester) async {
      await pumpApp(tester);
      expect(find.text('Soy conductor'), findsOneWidget);
      expect(find.text('Necesito mover carga'), findsOneWidget);
    });

    testWidgets('S02 shows wrong-code and lock-out copy (4.6 OTP rows)', (tester) async {
      await pumpApp(tester);
      await tapKey(tester, 's01_driver');
      await tapKey(tester, 's02_send');
      await tester.enterText(find.byKey(const Key('s02_code')), '000000');
      await tapKey(tester, 's02_verify', scroll: false);
      expect(find.text('Código incorrecto. Te quedan 4 intentos.'), findsOneWidget);
      await tapKey(tester, 's02_demo_lock');
      expect(find.text('Demasiados intentos. Pide un código nuevo en 15 minutos.'), findsOneWidget);
      await tapKey(tester, 's02_back_to_code');
      await tapKey(tester, 's02_demo_cap');
      expect(find.textContaining('Alcanzaste el máximo de códigos por hoy'), findsOneWidget);
    });
  });

  group('Driver journey', () {
    testWidgets('S01 → S02 → S03 → S04 → S05 → install sheet → S06 → S07 → S08 → S16 → S18 → S19 → S21',
        (tester) async {
      final state = await pumpApp(tester);
      await signIn(tester, 's01_driver');

      // S03 profile
      expect(find.text('Tu perfil'), findsOneWidget);
      await tapKey(tester, 's03_save');

      // S04 wizard: 5 steps
      expect(find.text('Alta del conductor'), findsOneWidget);
      await tapKey(tester, 's04_consent');
      await tapKey(tester, 's04_cedula_camera');
      await tapKey(tester, 's04_selfie_camera');
      await tapKey(tester, 's04_next', scroll: false);
      expect(find.text('Vehículo'), findsOneWidget);
      await tapKey(tester, 's04_registration_camera');
      await tapKey(tester, 's04_vehicle_camera');
      await tapKey(tester, 's04_next', scroll: false);
      await tapKey(tester, 's04_permit_camera');
      await tapKey(tester, 's04_next', scroll: false);
      await tapKey(tester, 's04_licence_camera');
      await tapKey(tester, 's04_next', scroll: false);
      expect(find.text('Servicios'), findsOneWidget);
      await tapKey(tester, 's04_next', scroll: false); // submit
      expect(find.text('Documentos enviados'), findsOneWidget);
      await tapKey(tester, 's04_see_status', scroll: false);

      // S05: pending → exhausted copy → approved
      expect(find.text('Estado de verificación'), findsOneWidget);
      expect(find.byKey(const Key('s05_explore')), findsOneWidget);
      await tapKey(tester, 's05_demo_exhausted');
      expect(find.textContaining('No pudimos verificar este documento'), findsOneWidget);
      await tapKey(tester, 's05_demo_rejected');
      expect(find.textContaining('Rechazamos tu matrícula'), findsOneWidget);
      await tapKey(tester, 's05_demo_approved');
      await tapKey(tester, 's05_continue', scroll: false);

      // Install sheet (4.3) with official domain
      expect(find.text('Agrega Smart Trucking a tu inicio'), findsOneWidget);
      expect(find.text('Dominio oficial: smarttrucking.ec'), findsOneWidget);
      await tapKey(tester, 'install_later', scroll: false);

      // S06 home
      expect(find.text('Hola, Marco'), findsOneWidget);
      await tapKey(tester, 's06_publish', scroll: false);

      // S07 publish trip: step 1 → step 2 with net payout at 5 % (first bookings)
      expect(find.text('Publicar viaje'), findsWidgets);
      expect(find.byKey(const Key('s07_return_leg')), findsOneWidget);
      await tapKey(tester, 's07_next', scroll: false);
      await tester.scrollUntilVisible(find.byKey(const Key('s07_instant')), 200, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('s07_instant')), findsOneWidget);
      expect(find.textContaining('Recibes USD 428 después de la comisión del 5 %'), findsOneWidget);
      await tapKey(tester, 's07_publish', scroll: false);

      // S08 trip detail: receive an offer, accept it → S16
      expect(find.text('Mi viaje'), findsOneWidget);
      expect(state.myTrips, hasLength(1));
      await tapKey(tester, 's08_demo_offer');
      final offer = state.offersFor(state.myTrips.first.id).single;
      expect(find.textContaining('Recibes USD'), findsWidgets);
      await tapKey(tester, 's08_accept_${offer.id}');

      // S16 accepted → shipper pays (demo) → pickup evidence (S18)
      expect(find.text('Reserva'), findsOneWidget);
      final booking = state.bookings.single;
      expect(booking.status, BookingStatus.accepted);
      await tapKey(tester, 's16_demo_paid');
      expect(booking.status, BookingStatus.paid);
      expect(find.byKey(const Key('s16_cancel_booking')), findsOneWidget);
      await tapKey(tester, 's16_pickup_evidence', scroll: false);

      expect(find.text('Evidencia de recogida'), findsOneWidget);
      await tapKey(tester, 's18_cargo_camera');
      await tapKey(tester, 's18_doc_camera');
      await tapKey(tester, 's18_offline'); // queue it: "pendiente de sincronizar"
      await tapKey(tester, 's18_submit', scroll: false);
      expect(booking.status, BookingStatus.pickedUp);
      await scrollTop(tester);
      expect(find.byKey(const Key('s16_pending_sync')), findsOneWidget);
      await tapKey(tester, 's16_demo_sync');
      await scrollTop(tester);
      expect(find.byKey(const Key('s16_pending_sync')), findsNothing);

      // Start transit with location consent → delivery evidence
      await tapKey(tester, 's16_start_transit', scroll: false);
      expect(find.text('Compartir tu ubicación en vivo'), findsOneWidget);
      await tapKey(tester, 's16_location_accept', scroll: false);
      expect(booking.status, BookingStatus.inTransit);
      await tapKey(tester, 's16_delivery_evidence', scroll: false);
      expect(find.text('Evidencia de entrega'), findsOneWidget);
      await tapKey(tester, 's18_cargo_camera');
      await tapKey(tester, 's18_doc_camera');
      await tester.enterText(find.byKey(const Key('s18_receiver')), 'Juan Pérez');
      await tester.pumpAndSettle();
      await tapKey(tester, 's18_submit', scroll: false);
      expect(booking.status, BookingStatus.delivered);
      await scrollTop(tester);
      expect(find.text('Esperando confirmación (48 h)'), findsOneWidget);

      // Shipper confirms (demo) → held payout copy → settle → rate
      await tapKey(tester, 's16_demo_confirmed');
      expect(booking.status, BookingStatus.confirmed);
      await scrollTop(tester);
      expect(find.textContaining('Tu pago llega el'), findsOneWidget);
      await tapKey(tester, 's16_demo_settle');
      expect(booking.status, BookingStatus.settled);
      await tapKey(tester, 's16_rate', scroll: false);
      expect(find.text('Calificar'), findsWidgets);
      await tapKey(tester, 's19_star_5', scroll: false);
      await tapKey(tester, 's19_send', scroll: false);
      expect(find.byKey(const Key('s19_sent')), findsOneWidget);
      await tapKey(tester, 's19_home', scroll: false);

      // S21 earnings
      expect(find.text('Hola, Marco'), findsOneWidget);
      await scrollTap(tester, find.byKey(const Key('s06_earnings')));
      expect(find.text('Ganancias y pagos'), findsOneWidget);
      expect(find.byKey(const Key('s21_first_three')), findsOneWidget);
      expect(find.byKey(Key('s21_payout_${booking.id}')), findsOneWidget);
    });

    testWidgets('S09 filter sheet: detour 40 km default, fits-my-vehicle on, Aplicar / Limpiar', (tester) async {
      final state = await pumpApp(tester);
      state.chooseRole(UserRole.driver);
      state.driver.verification = VerificationState.approved;
      state.markInstallSheetShown();
      await tester.pumpWidget(SmartTruckingApp(state: state));
      await tester.pumpAndSettle();
      await tapKey(tester, 's01_driver'); // goes to S02
      await tapKey(tester, 's02_send');
      await tester.enterText(find.byKey(const Key('s02_code')), '123456');
      await tapKey(tester, 's02_verify', scroll: false);
      await tapKey(tester, 's03_save');
      // Skip wizard by jumping to S05 → approved → S06 → S09
      await tester.pumpAndSettle();
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.pushNamed(Routes.s09);
      await tester.pumpAndSettle();

      expect(find.text('Cargas en mi ruta'), findsOneWidget);
      expect(find.text('40 km'), findsOneWidget);
      expect(find.byKey(const Key('s09_chip_fits')), findsOneWidget);
      // Default: load l3 (5.2 t, 55 km) is hidden by detour and fit.
      expect(find.byKey(const Key('load_card_l1')), findsOneWidget);
      expect(find.byKey(const Key('load_card_l3')), findsNothing);

      await tapKey(tester, 's09_filters', scroll: false);
      expect(find.byKey(const Key('filter_apply')), findsOneWidget);
      expect(find.byKey(const Key('filter_clear')), findsOneWidget);
      expect(find.byKey(const Key('s09_fits_switch')), findsOneWidget);
      // Widen detour to 80 km and turn off "fits".
      final plus = find.descendant(of: find.byKey(const Key('s09_detour_stepper')), matching: find.byIcon(Icons.add));
      for (var i = 0; i < 4; i++) {
        await tester.tap(plus);
        await tester.pump();
      }
      await tester.tap(find.byKey(const Key('s09_fits_switch')));
      await tester.pumpAndSettle();
      await tapKey(tester, 'filter_apply', scroll: false);
      expect(find.text('80 km'), findsOneWidget);
      expect(find.byKey(const Key('s09_chip_fits')), findsNothing);
      await tester.scrollUntilVisible(find.byKey(const Key('load_card_l3')), 200, scrollable: find.byType(Scrollable).first);
      expect(find.byKey(const Key('load_card_l3')), findsOneWidget);

      // Offer on a load → S10 shows the net payout for the driver
      await scrollTap(tester, find.byKey(const Key('load_offer_l1')));
      expect(find.text('Hacer una oferta'), findsWidgets);
      expect(find.byKey(const Key('s10_net_payout')), findsOneWidget);
      await tapKey(tester, 's10_send', scroll: false);
      expect(find.text('Oferta enviada'), findsOneWidget);
    });

    testWidgets('driver cancel shows the strike consequence before confirming', (tester) async {
      final state = AppState();
      state.chooseRole(UserRole.driver);
      final trip = state.marketTrips.first;
      final b = state.createBooking(trip: trip, price: 450, entry: BookingStatus.accepted);
      state.advance(b, BookingStatus.paid);
      await pumpApp(tester, state: state);
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(Routes.s16, arguments: b.id);
      await tester.pumpAndSettle();

      await scrollTap(tester, find.byKey(const Key('s16_cancel_booking')));
      expect(find.text('Antes de cancelar'), findsOneWidget);
      expect(find.textContaining('1.ª cancelación'), findsOneWidget);
      expect(b.status, BookingStatus.paid); // nothing happened yet
      await tapKey(tester, 's16_cancel_keep', scroll: false);
      expect(b.status, BookingStatus.paid);
      await scrollTap(tester, find.byKey(const Key('s16_cancel_booking')));
      await tapKey(tester, 's16_cancel_confirm', scroll: false);
      expect(b.status, BookingStatus.cancelled);
      expect(state.driver.strikes, 1);
      expect(trip.status, ListingStatus.published);
    });
  });

  group('Shipper journey', () {
    testWidgets('S01 → S02 → S11 → S14 → S15 → S10 → S03 → S17 → S16 → S19', (tester) async {
      final state = await pumpApp(tester);
      await signIn(tester, 's01_shipper');

      // S11 home
      expect(find.text('Hola, Paula'), findsOneWidget);
      await tapKey(tester, 's11_publish_load', scroll: false);

      // S14 publish load
      expect(find.text('Publicar carga'), findsWidgets);
      await tapKey(tester, 's14_next', scroll: false);
      expect(find.byKey(const Key('s14_declared')), findsOneWidget);
      await tapKey(tester, 's14_add_photo');
      await tapKey(tester, 's14_publish', scroll: false);

      // S15 load detail: receive offer, accept → S03 (first booking) → S17
      expect(find.text('Mi carga'), findsOneWidget);
      await tapKey(tester, 's15_demo_offer');
      final offer = state.offersFor(state.myLoads.first.id).single;
      await tapKey(tester, 's15_accept_${offer.id}');
      expect(find.text('Datos para tu factura'), findsWidgets); // S03 invoice mode (title + section)
      expect(find.byKey(const Key('s03_tax_id')), findsOneWidget);
      await tapKey(tester, 's03_save', scroll: false);

      // S17 payment
      expect(find.text('Pago'), findsOneWidget);
      expect(find.byKey(const Key('s17_card')), findsOneWidget);
      expect(find.byKey(const Key('s17_transfer')), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('Retenemos tu pago'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('Retenemos tu pago'), findsOneWidget);
      await tapKey(tester, 's17_pay', scroll: false);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('s17_paid')), findsOneWidget);
      await tapKey(tester, 's17_go_booking', scroll: false);

      // S16 tracking: full name revealed after payment, escrow copy
      final b = state.bookings.single;
      expect(b.status, BookingStatus.paid);
      expect(find.text('Luis Andrade Mora'), findsOneWidget);
      expect(find.text('Tu pago queda protegido hasta que confirmes la entrega'), findsOneWidget);
      // Demo: driver side progresses
      await tapKey(tester, 's16_demo_pickedup');
      await tapKey(tester, 's16_demo_transit');
      await tapKey(tester, 's16_demo_delivered');
      expect(b.status, BookingStatus.delivered);
      await tapKey(tester, 's16_confirm_delivery', scroll: false);
      expect(b.status, BookingStatus.confirmed);

      // S19 rating (low rating needs a tag)
      expect(find.text('¿Cómo fue trabajar con Luis?'), findsOneWidget);
      await tapKey(tester, 's19_star_2', scroll: false);
      expect(find.text('Con 2 estrellas o menos, elige al menos una etiqueta.'), findsOneWidget);
      await tester.tap(find.text('Llegó tarde'));
      await tester.pumpAndSettle();
      await tapKey(tester, 's19_send', scroll: false);
      expect(find.byKey(const Key('s19_sent')), findsOneWidget);
    });

    testWidgets('S12 cards: reference variant shows strike-through + badge, no-reference variant hides both',
        (tester) async {
      final state = AppState()..chooseRole(UserRole.shipper);
      await pumpApp(tester, state: state);
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(Routes.s12);
      await tester.pumpAndSettle();

      expect(find.text('Viajes disponibles'), findsOneWidget);
      // t1: Guayaquil → Quito, USD 450 before USD 750 (estimado), Ahorra 40 %
      expect(find.byKey(const Key('trip_ref_t1')), findsOneWidget);
      expect(find.byKey(const Key('trip_saving_t1')), findsOneWidget);
      expect(find.text('Ahorra 40 %'), findsOneWidget);
      expect(find.textContaining('antes USD 750 (estimado)'), findsOneWidget);
      // t2: Manta → Cuenca, no reference
      await tester.scrollUntilVisible(find.byKey(const Key('trip_card_t2')), 200, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('trip_noref_t2')), findsOneWidget);
      expect(find.text('Aún sin referencia local'), findsOneWidget);
      expect(find.byKey(const Key('trip_ref_t2')), findsNothing);
      expect(find.byKey(const Key('trip_saving_t2')), findsNothing);
    });

    testWidgets('S12 filter sheet: Aplicar in thumb zone, Limpiar, insured-only filters results', (tester) async {
      final state = AppState()..chooseRole(UserRole.shipper);
      await pumpApp(tester, state: state);
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(Routes.s12);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('s12_sort_bestMatch')), findsOneWidget); // A5.1 default
      await tapKey(tester, 's12_filters', scroll: false);
      expect(find.byKey(const Key('filter_apply')), findsOneWidget);
      expect(find.byKey(const Key('filter_clear')), findsOneWidget);
      expect(find.byKey(const Key('s12_f_tracking')), findsOneWidget);
      expect(find.byKey(const Key('s12_f_min_tons')), findsOneWidget);
      await tester.tap(find.text('Solo asegurados'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'filter_apply', scroll: false);
      // Ana (t2) is not insured → hidden; active filter chip visible.
      expect(find.byKey(const Key('trip_card_t1')), findsOneWidget);
      expect(find.text('Solo asegurados'), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const Key('trip_card_t3')), 200, scrollable: find.byType(Scrollable).first);
      expect(find.byKey(const Key('trip_card_t2')), findsNothing);

      // Clear
      await tester.scrollUntilVisible(find.byKey(const Key('s12_filters')), -200, scrollable: find.byType(Scrollable).first);
      await tapKey(tester, 's12_filters', scroll: false);
      await tapKey(tester, 'filter_clear', scroll: false);
      await tapKey(tester, 'filter_apply', scroll: false);
      expect(find.text('Solo asegurados'), findsNothing);
    });

    testWidgets('shipper cancel within 24 h shows the 20 % refund consequence first', (tester) async {
      final state = AppState()..chooseRole(UserRole.shipper);
      final trip = state.marketTrips.first;
      // Force departure within 24 h.
      final soon = Trip(
        id: 'soon', driver: trip.driver, origin: 'Guayaquil', destination: 'Quito',
        departure: DateTime.now().add(const Duration(hours: 5)), price: 450, isReturnLeg: true,
      );
      final b = state.createBooking(trip: soon, price: 450, entry: BookingStatus.accepted);
      state.advance(b, BookingStatus.paid);
      await pumpApp(tester, state: state);
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(Routes.s16, arguments: b.id);
      await tester.pumpAndSettle();

      await scrollTap(tester, find.byKey(const Key('s16_cancel_booking')));
      expect(find.textContaining('Recibirás USD 360; USD 90 van al conductor'), findsOneWidget);
      expect(b.status, BookingStatus.paid);
      await tapKey(tester, 's16_cancel_confirm', scroll: false);
      expect(b.status, BookingStatus.cancelled);
    });

    testWidgets('S16 "Reportar un problema" → S20 → EnDisputa', (tester) async {
      final state = AppState()..chooseRole(UserRole.shipper);
      final b = state.createBooking(trip: state.marketTrips.first, price: 450, entry: BookingStatus.accepted);
      state.advance(b, BookingStatus.paid);
      await pumpApp(tester, state: state);
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(Routes.s16, arguments: b.id);
      await tester.pumpAndSettle();
      await scrollTap(tester, find.byKey(const Key('s16_report_problem')));
      expect(find.text('Reportar un problema'), findsWidgets);
      await tapKey(tester, 's20_reason_noshow');
      await tapKey(tester, 's20_send', scroll: false);
      expect(b.status, BookingStatus.inDispute);
      expect(find.byKey(const Key('s20_sla')), findsOneWidget);
    });
  });

  group('Cross-cutting', () {
    testWidgets('S23 EN toggle switches the copy table; ES is default', (tester) async {
      final state = AppState()..chooseRole(UserRole.driver);
      await pumpApp(tester, state: state);
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(Routes.s23);
      await tester.pumpAndSettle();
      expect(find.text('Configuración'), findsOneWidget);
      expect(find.text('Idioma'), findsOneWidget);
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(state.locale, AppLocale.en);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Configuración'), findsNothing);
      await tester.tap(find.text('Español'));
      await tester.pumpAndSettle();
      expect(find.text('Configuración'), findsOneWidget);
    });

    testWidgets('Timeline demo shows every 4.5 booking state and the listing states', (tester) async {
      final state = AppState()..chooseRole(UserRole.driver);
      await pumpApp(tester, state: state);
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(Routes.timelineDemo);
      await tester.pumpAndSettle();
      for (final s in ListingStatus.values) {
        expect(find.byKey(Key('td_listing_${s.name}')), findsOneWidget);
      }
      for (final s in BookingStatus.values) {
        final f = find.byKey(Key('td_booking_${s.name}'));
        await tester.scrollUntilVisible(f, 150, scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        expect(f, findsOneWidget, reason: '$s');
      }
      await tester.scrollUntilVisible(find.byKey(const Key('td_booking_paid')), -150, scrollable: find.byType(Scrollable).first);
      expect(find.text('Pagada y protegida'), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const Key('td_booking_inDispute')), 150, scrollable: find.byType(Scrollable).first);
      expect(find.text('En revisión'), findsOneWidget);
    });

    testWidgets('S16 links to the timeline demo', (tester) async {
      final state = AppState()..chooseRole(UserRole.driver);
      final b = state.createBooking(trip: state.marketTrips.first, price: 450, entry: BookingStatus.accepted);
      await pumpApp(tester, state: state);
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(Routes.s16, arguments: b.id);
      await tester.pumpAndSettle();
      await scrollTap(tester, find.byKey(const Key('s16_view_all_states')));
      expect(find.text('Estados de la reserva'), findsWidgets); // title + section header
    });
  });
}
