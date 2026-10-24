import 'package:intl/intl.dart';

import 'app_settings.dart';

final _money = NumberFormat('#,##0.00');
final _compact = NumberFormat.compact();
final _date = DateFormat('dd MMM yyyy');
final _dateTime = DateFormat('dd MMM yyyy, HH:mm');
final _time = DateFormat('HH:mm');
final _dayShort = DateFormat('EEE d MMM');

String money(num v) {
  final c = AppSettings.currency;
  return c.isEmpty ? _money.format(v) : '$c ${_money.format(v)}';
}

/// Short form for chart axes, e.g. 12.5K.
String compact(num v) => _compact.format(v);
String date(DateTime? d) => d == null ? '—' : _date.format(d);
String dateTime(DateTime d) => _dateTime.format(d);
String time(DateTime d) => _time.format(d);
String dayShort(DateTime d) => _dayShort.format(d);
String percent(double v) => '${v.toStringAsFixed(1)}%';
