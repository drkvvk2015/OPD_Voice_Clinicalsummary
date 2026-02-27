import 'package:intl/intl.dart';

String formatDateTime(DateTime dateTime) {
  return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
}
