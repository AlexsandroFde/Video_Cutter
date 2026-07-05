/// Formatações de [Duration] usadas na UI e nos comandos FFmpeg.
extension DurationFormatX on Duration {
  /// Rótulo compacto para a UI: `03:21`, `1:02:45` ou, com [tenths],
  /// `03:21.4`.
  String label({bool tenths = false}) {
    final h = inHours;
    final m = inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = inSeconds.remainder(60).toString().padLeft(2, '0');
    final base = h > 0 ? '$h:$m:$s' : '$m:$s';
    if (!tenths) return base;
    final t = inMilliseconds.remainder(1000) ~/ 100;
    return '$base.$t';
  }

  /// Segundos com precisão de milissegundos, no formato aceito pelo FFmpeg
  /// em `-ss` e `-t` (ex.: `12.345`).
  String get ffmpegSeconds => (inMilliseconds / 1000).toStringAsFixed(3);
}
