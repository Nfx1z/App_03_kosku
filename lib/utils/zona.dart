import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The app's clock: ALWAYS WIB (Asia/Jakarta, UTC+7), whatever the
/// device timezone is set to. Every "today / this month / at 08:00"
/// decision in the app goes through [kini] so dates, day grouping and
/// reminders always follow Indonesian time, even when the phone is
/// used abroad.
///
/// - [siapkan] pins the timezone package's local location to
///   Asia/Jakarta (needed before scheduling notifications).
/// - [kini] returns "now" as a WIB wall-clock DateTime. It pairs with
///   the naive dates stored in the DB (also wall-clock), so comparisons
///   stay consistent.
class Zona {
  Zona._();

  static bool _siap = false;

  /// Initialize the timezone database and pin the local location to
  /// Asia/Jakarta. Idempotent; safe to call repeatedly. Must run before
  /// any notification is scheduled.
  static void siapkan() {
    if (_siap) return;
    _siap = true;
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    } catch (_) {
      // Should not happen; scheduling would fall back to UTC.
    }
  }

  /// "Now" in WIB wall-clock terms (a naive DateTime whose fields are
  /// Jakarta local time). Use this instead of `DateTime.now()` wherever
  /// a day / month / hour boundary matters.
  static DateTime kini() =>
      DateTime.now().toUtc().add(const Duration(hours: 7));

  /// Today's date (WIB) without the time part.
  static DateTime hariIni() {
    final k = kini();
    return DateTime(k.year, k.month, k.day);
  }
}
