/// Tiny hand-rolled date formatter for report timestamps.
///
/// Deliberately not using the `intl` package — this is the only place in
/// the app that needs to format a date, and one small pure-Dart function
/// covers it without adding a new dependency for it.
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatReportTimestamp(DateTime dateTime) {
  final local = dateTime.toLocal();
  final day = local.day.toString();
  final month = _months[local.month - 1];
  final year = local.year.toString();
  final hour24 = local.hour;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = hour24 < 12 ? 'AM' : 'PM';
  return '$day $month $year, $hour12:$minute $period';
}
