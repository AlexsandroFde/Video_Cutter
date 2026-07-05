import 'package:flutter_test/flutter_test.dart';
import 'package:video_cutter/core/utils/duration_format.dart';

void main() {
  group('label', () {
    test('formata minutos e segundos', () {
      expect(const Duration(minutes: 3, seconds: 21).label(), '03:21');
    });

    test('inclui horas quando necessário', () {
      expect(
        const Duration(hours: 1, minutes: 2, seconds: 45).label(),
        '1:02:45',
      );
    });

    test('inclui décimos quando pedido', () {
      expect(
        const Duration(minutes: 3, seconds: 21, milliseconds: 456)
            .label(tenths: true),
        '03:21.4',
      );
    });
  });

  group('ffmpegSeconds', () {
    test('emite segundos com três casas decimais', () {
      expect(
        const Duration(seconds: 12, milliseconds: 345).ffmpegSeconds,
        '12.345',
      );
      expect(Duration.zero.ffmpegSeconds, '0.000');
    });
  });
}
