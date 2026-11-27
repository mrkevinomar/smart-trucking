import 'enums.dart';

/// Commission rules from AE-79 A7.4: 10 %, 5 % on a driver's first three
/// bookings.
class Commission {
  const Commission._();

  static const double standardRate = 0.10;
  static const double earlyRate = 0.05;
  static const int earlyBookings = 3;

  /// Rate that applies to a driver with [completedBookings] settled bookings.
  static double rateFor(int completedBookings) =>
      completedBookings < earlyBookings ? earlyRate : standardRate;

  /// Rate as the integer shown in copy ("10 %").
  static int ratePercent(int completedBookings) =>
      (rateFor(completedBookings) * 100).round();

  /// Net payout for the driver, rounded to whole USD.
  static int netPayout(num price, int completedBookings) =>
      (price * (1 - rateFor(completedBookings))).round();

  static int commissionAmount(num price, int completedBookings) =>
      price.round() - netPayout(price, completedBookings);
}

/// Refund rule A7.6: full refund more than 24 h before departure; within 24 h
/// a 20 % penalty is paid to the driver.
class RefundRule {
  const RefundRule._();

  static const double latePenalty = 0.20;

  static bool isLate(Duration untilDeparture) =>
      untilDeparture <= const Duration(hours: 24);

  static int refund(num price, Duration untilDeparture) => isLate(untilDeparture)
      ? (price * (1 - latePenalty)).round()
      : price.round();

  static int penalty(num price, Duration untilDeparture) =>
      price.round() - refund(price, untilDeparture);
}

/// Driver strike rule A10.4: 1st warning, 2nd ranking penalty 30 days,
/// 3rd suspension. [existingStrikes] is the count before this cancellation.
enum StrikeConsequence { warning, rankingPenalty, suspension }

StrikeConsequence strikeConsequence(int existingStrikes) {
  if (existingStrikes <= 0) return StrikeConsequence.warning;
  if (existingStrikes == 1) return StrikeConsequence.rankingPenalty;
  return StrikeConsequence.suspension;
}

/// Formats money and dates following the 4.6 "Unidades y fechas" row.
class Fmt {
  const Fmt._();

  /// "USD 1.000" (ES) / "USD 1,000" (EN). Always a space after USD.
  static String usd(num amount, AppLocale locale) =>
      'USD ${integer(amount.round(), locale)}';

  static String integer(int n, AppLocale locale) {
    final sep = locale == AppLocale.es ? '.' : ',';
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(sep);
    }
    return (n < 0 ? '-' : '') + buf.toString();
  }

  /// Rating "4,8" (ES) / "4.8" (EN).
  static String rating(double r, AppLocale locale) {
    final s = r.toStringAsFixed(1);
    return locale == AppLocale.es ? s.replaceAll('.', ',') : s;
  }

  static const _weekdaysEs = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  static const _weekdaysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _monthsEs = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];
  static const _monthsEn = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "jue 27 nov, 14:00" (ES) / "Thu 27 Nov, 14:00" (EN). 24 h clock.
  static String dateTime(DateTime d, AppLocale locale) {
    final wd = (locale == AppLocale.es ? _weekdaysEs : _weekdaysEn)[d.weekday - 1];
    final mo = (locale == AppLocale.es ? _monthsEs : _monthsEn)[d.month - 1];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$wd ${d.day} $mo, $hh:$mm';
  }

  /// "jue 27 nov" / "Thu 27 Nov".
  static String dateLong(DateTime d, AppLocale locale) {
    final wd = (locale == AppLocale.es ? _weekdaysEs : _weekdaysEn)[d.weekday - 1];
    final mo = (locale == AppLocale.es ? _monthsEs : _monthsEn)[d.month - 1];
    return '$wd ${d.day} $mo';
  }

  /// Short form "4 dic" / "4 Dec".
  static String dateShort(DateTime d, AppLocale locale) {
    final mo = (locale == AppLocale.es ? _monthsEs : _monthsEn)[d.month - 1];
    return '${d.day} $mo';
  }

  /// "jue 27 nov, tarde" style used on S12 cards.
  static String dateWithPeriod(DateTime d, AppLocale locale) {
    final period = d.hour < 12
        ? (locale == AppLocale.es ? 'mañana' : 'morning')
        : (locale == AppLocale.es ? 'tarde' : 'afternoon');
    return '${dateLong(d, locale)}, $period';
  }
}
