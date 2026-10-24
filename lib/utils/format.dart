import 'package:intl/intl.dart';

final _money = NumberFormat('#,##0.00');
final _date = DateFormat('dd MMM yyyy');
final _dateTime = DateFormat('dd MMM yyyy, HH:mm');

String money(num v) => _money.format(v);
String date(DateTime? d) => d == null ? '—' : _date.format(d);
String dateTime(DateTime d) => _dateTime.format(d);
