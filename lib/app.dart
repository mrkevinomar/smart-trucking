import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_state.dart';
import 'core/enums.dart';
import 'l10n/strings.dart';
import 'screens/driver_screens.dart';
import 'screens/onboarding_screens.dart';
import 'screens/shared_screens.dart';
import 'screens/shipper_screens.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// Route names, one per screen id of the AE-79 inventory (4.2).
class Routes {
  const Routes._();
  static const s01 = '/';
  static const s02 = '/s02-otp';
  static const s03 = '/s03-profile';
  static const s04 = '/s04-onboarding';
  static const s05 = '/s05-verification';
  static const s06 = '/s06-driver-home';
  static const s07 = '/s07-publish-trip';
  static const s08 = '/s08-trip-detail';
  static const s09 = '/s09-search-loads';
  static const s10 = '/s10-offer';
  static const s11 = '/s11-shipper-home';
  static const s12 = '/s12-search-trips';
  static const s13 = '/s13-trip-detail';
  static const s14 = '/s14-publish-load';
  static const s15 = '/s15-load-detail';
  static const s16 = '/s16-booking';
  static const s17 = '/s17-payment';
  static const s18 = '/s18-evidence';
  static const s19 = '/s19-rating';
  static const s20 = '/s20-dispute';
  static const s21 = '/s21-earnings';
  static const s22 = '/s22-notifications';
  static const s23 = '/s23-settings';
  static const timelineDemo = '/timeline-demo';
}

class SmartTruckingApp extends StatelessWidget {
  const SmartTruckingApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          final t = Strings(state.locale);
          return MaterialApp(
            title: t('app_name'),
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            locale: Locale(state.locale.name),
            supportedLocales: const [Locale('es'), Locale('en')],
            localizationsDelegates: [
              StringsDelegate(state.locale),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(
                  textScaler: TextScaler.linear(state.largeText ? 1.3 : 1.0),
                ),
                child: PhoneFrame(child: child ?? const SizedBox.shrink()),
              );
            },
            initialRoute: Routes.s01,
            onGenerateRoute: _onGenerateRoute,
          );
        },
      ),
    );
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments;
    Widget page;
    switch (settings.name) {
      case Routes.s01:
        page = const S01Welcome();
      case Routes.s02:
        page = const S02Otp();
      case Routes.s03:
        page = S03Profile(invoiceMode: args == 'invoice');
      case Routes.s04:
        page = const S04Onboarding();
      case Routes.s05:
        page = const S05Verification();
      case Routes.s06:
        page = const S06DriverHome();
      case Routes.s07:
        page = const S07PublishTrip();
      case Routes.s08:
        page = S08TripDetail(tripId: args as String);
      case Routes.s09:
        page = const S09SearchLoads();
      case Routes.s10:
        page = S10Offer(args: args as OfferArgs);
      case Routes.s11:
        page = const S11ShipperHome();
      case Routes.s12:
        page = const S12SearchTrips();
      case Routes.s13:
        page = S13TripDetailShipper(tripId: args as String);
      case Routes.s14:
        page = const S14PublishLoad();
      case Routes.s15:
        page = S15LoadDetail(loadId: args as String);
      case Routes.s16:
        page = S16BookingDetail(bookingId: args as String);
      case Routes.s17:
        page = S17Payment(bookingId: args as String);
      case Routes.s18:
        page = S18Evidence(args: args as EvidenceArgs);
      case Routes.s19:
        page = S19Rating(bookingId: args as String);
      case Routes.s20:
        page = S20Dispute(bookingId: args as String);
      case Routes.s21:
        page = const S21Earnings();
      case Routes.s22:
        page = const S22Notifications();
      case Routes.s23:
        page = const S23Settings();
      case Routes.timelineDemo:
        page = const TimelineDemo();
      default:
        page = const S01Welcome();
    }
    return MaterialPageRoute<void>(builder: (_) => page, settings: settings);
  }
}

/// Home route for the signed-in role.
String homeRouteFor(UserRole? role) =>
    role == UserRole.shipper ? Routes.s11 : Routes.s06;
