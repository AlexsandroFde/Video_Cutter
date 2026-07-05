/// Data curta e humana para o histórico: "hoje às 14:32", "ontem às 09:10"
/// ou "04/07/2026".
String friendlyDateTime(DateTime value, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  final time = '${two(value.hour)}:${two(value.minute)}';

  final today = DateTime(reference.year, reference.month, reference.day);
  final day = DateTime(value.year, value.month, value.day);
  final difference = today.difference(day).inDays;

  if (difference == 0) return 'hoje às $time';
  if (difference == 1) return 'ontem às $time';
  return '${two(value.day)}/${two(value.month)}/${value.year}';
}
