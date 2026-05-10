class DateFormatter {
  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  static String formatShort(DateTime date) {
    final month = _months[date.month - 1];
    return '${date.day} $month ${date.year}';
  }
}
