import 'package:flutter_test/flutter_test.dart';
import 'package:video_cutter/features/cutter/data/models/edit_project_model.dart';
import 'package:video_cutter/features/cutter/domain/entities/video_chapter.dart';
import 'package:video_cutter/features/cutter/domain/entities/video_media.dart';

void main() {
  final base = EditProjectModel(
    id: 'abc',
    name: 'Meu vídeo',
    videoPath: '/videos/abc.mp4',
    origin: MediaOrigin.youtube,
    durationMs: 60000,
    segments: const [],
    createdAt: DateTime(2026, 7, 1),
    updatedAt: DateTime(2026, 7, 2),
    chapters: const [
      VideoChapter(start: Duration.zero, title: 'Intro'),
      VideoChapter(start: Duration(seconds: 30), title: 'Final'),
    ],
  );

  group('chapters no JSON', () {
    test('sobrevivem à ida e volta toJson/fromJson', () {
      final restored = EditProjectModel.fromJson(base.toJson());

      expect(restored.toEntity().chapters, const [
        VideoChapter(start: Duration.zero, title: 'Intro'),
        VideoChapter(start: Duration(seconds: 30), title: 'Final'),
      ]);
    });

    test('histórico antigo sem o campo chapters carrega vazio', () {
      final json = base.toJson()..remove('chapters');

      final restored = EditProjectModel.fromJson(json);

      expect(restored.chapters, isEmpty);
      expect(restored.toEntity().chapters, isEmpty);
    });

    test('copyWith preserva os capítulos (auto-save não os apaga)', () {
      final updated = base.copyWith(durationMs: 90000);

      expect(updated.chapters, base.chapters);
    });

    test('entidade expõe os capítulos também via media', () {
      final entity = base.toEntity();

      expect(entity.media.chapters, entity.chapters);
    });
  });
}
