import 'package:flutter_test/flutter_test.dart';
import 'package:video_cutter/features/cutter/data/datasources/youtube_chapter_parser.dart';
import 'package:video_cutter/features/cutter/domain/entities/video_chapter.dart';

void main() {
  group('parseChaptersFromDescription', () {
    test('extrai capítulos de linhas "mm:ss título"', () {
      const description = '0:00 Intro\n'
          '2:15 Corte 2\n'
          '10:40 Final';

      expect(parseChaptersFromDescription(description), const [
        VideoChapter(start: Duration.zero, title: 'Intro'),
        VideoChapter(start: Duration(minutes: 2, seconds: 15), title: 'Corte 2'),
        VideoChapter(start: Duration(minutes: 10, seconds: 40), title: 'Final'),
      ]);
    });

    test('aceita horas no formato h:mm:ss', () {
      const description = '0:00 Começo\n'
          '59:59 Quase uma hora\n'
          '1:02:45 Créditos';

      expect(parseChaptersFromDescription(description), const [
        VideoChapter(start: Duration.zero, title: 'Começo'),
        VideoChapter(
          start: Duration(minutes: 59, seconds: 59),
          title: 'Quase uma hora',
        ),
        VideoChapter(
          start: Duration(hours: 1, minutes: 2, seconds: 45),
          title: 'Créditos',
        ),
      ]);
    });

    test('ignora as linhas de texto comum ao redor', () {
      const description = 'Nosso vlog de viagem!\n'
          '\n'
          'Capítulos:\n'
          '0:00 Chegada\n'
          '3:30 Passeio\n'
          '\n'
          'Siga a gente: https://example.com/canal';

      final chapters = parseChaptersFromDescription(description);
      expect(chapters, hasLength(2));
      expect(chapters.first.title, 'Chegada');
      expect(chapters.last.title, 'Passeio');
    });

    test('aceita marcadores de lista e separadores comuns', () {
      const description = '- 0:00 - Intro\n'
          '• 1:30 • Meio\n'
          '[3:00] Fim';

      expect(parseChaptersFromDescription(description), const [
        VideoChapter(start: Duration.zero, title: 'Intro'),
        VideoChapter(start: Duration(minutes: 1, seconds: 30), title: 'Meio'),
        VideoChapter(start: Duration(minutes: 3), title: 'Fim'),
      ]);
    });

    test('timestamp no meio da frase não vira capítulo', () {
      const description = 'confira em 2:30 o melhor momento\n'
          'e em 5:00 a surpresa';

      expect(parseChaptersFromDescription(description), isEmpty);
    });

    test('timestamp colado no título (sem separador) não vira capítulo', () {
      const description = '0:00Intro\n2:15Corte';

      expect(parseChaptersFromDescription(description), isEmpty);
    });

    test('um único timestamp não vale como capítulos', () {
      expect(parseChaptersFromDescription('0:00 Intro'), isEmpty);
    });

    test('timestamps fora de ordem invalidam a lista inteira', () {
      const description = '0:00 Intro\n'
          '5:00 Meio\n'
          '2:00 Volta no tempo';

      expect(parseChaptersFromDescription(description), isEmpty);
    });

    test('timestamps repetidos invalidam a lista inteira', () {
      const description = '0:00 Intro\n0:00 De novo';

      expect(parseChaptersFromDescription(description), isEmpty);
    });

    test('linha com segundos inválidos é ignorada, o resto vale', () {
      const description = '0:00 Intro\n'
          '1:75 Horário quebrado\n'
          '3:00 Fim';

      final chapters = parseChaptersFromDescription(description);
      expect(chapters, hasLength(2));
      expect(chapters.first.title, 'Intro');
      expect(chapters.last.title, 'Fim');
    });

    test('minutos acima de 59 valem sem horas, mas não em h:mm:ss', () {
      const description = '0:00 Intro\n'
          '0:75:00 Inválido\n'
          '90:00 Uma hora e meia';

      expect(parseChaptersFromDescription(description), const [
        VideoChapter(start: Duration.zero, title: 'Intro'),
        VideoChapter(start: Duration(minutes: 90), title: 'Uma hora e meia'),
      ]);
    });

    test('descrição sem timestamps retorna vazio', () {
      expect(
        parseChaptersFromDescription('Só um textinho fofo, sem capítulos.'),
        isEmpty,
      );
    });

    test('descrição vazia retorna vazio', () {
      expect(parseChaptersFromDescription(''), isEmpty);
    });
  });
}
