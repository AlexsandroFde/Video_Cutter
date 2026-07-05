import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:video_cutter/core/errors/app_exception.dart';
import 'package:video_cutter/features/cutter/data/datasources/history_local_datasource.dart';
import 'package:video_cutter/features/cutter/data/repositories/history_repository_impl.dart';
import 'package:video_cutter/features/cutter/domain/entities/video_media.dart';
import 'package:video_cutter/features/cutter/domain/entities/video_segment.dart';

void main() {
  late Directory tempDir;
  late HistoryRepositoryImpl repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('video_cutter_history');
    repository = HistoryRepositoryImpl(
      local: HistoryLocalDataSource(baseDirProvider: () async => tempDir),
    );
  });

  tearDown(() => tempDir.delete(recursive: true));

  Future<String> fakeVideo(String name) async {
    final file = File(p.join(tempDir.path, name));
    await file.writeAsBytes(const [0, 1, 2, 3]);
    return file.path;
  }

  group('createProject', () {
    test('copia o vídeo local para o armazenamento do app', () async {
      final source = await fakeVideo('origem.mp4');

      final project = await repository.createProject(
        videoPath: source,
        title: 'Meu vídeo',
        origin: MediaOrigin.localFile,
      );

      expect(project.name, 'Meu vídeo');
      expect(File(project.videoPath).existsSync(), isTrue);
      expect(File(source).existsSync(), isTrue,
          reason: 'arquivo do usuário não deve ser movido');
      expect(p.extension(project.videoPath), '.mp4');
    });

    test('move o download do YouTube em vez de copiar', () async {
      final source = await fakeVideo('temp_youtube.mp4');

      final project = await repository.createProject(
        videoPath: source,
        title: 'Do YouTube',
        origin: MediaOrigin.youtube,
      );

      expect(File(project.videoPath).existsSync(), isTrue);
      expect(File(source).existsSync(), isFalse,
          reason: 'o temporário deve ser movido');
    });

    test('gera nomes únicos com sufixo numérico', () async {
      Future<String> create() async => (await repository.createProject(
            videoPath: await fakeVideo('v${DateTime.now().microsecond}.mp4'),
            title: 'Férias',
            origin: MediaOrigin.localFile,
          ))
              .name;

      expect(await create(), 'Férias');
      expect(await create(), 'Férias 2');
      expect(await create(), 'Férias 3');
    });
  });

  group('getAll', () {
    test('ordena da edição mais recente para a mais antiga', () async {
      final first = await repository.createProject(
        videoPath: await fakeVideo('a.mp4'),
        title: 'Primeiro',
        origin: MediaOrigin.localFile,
      );
      await repository.createProject(
        videoPath: await fakeVideo('b.mp4'),
        title: 'Segundo',
        origin: MediaOrigin.localFile,
      );

      // Editar o primeiro deve trazê-lo para o topo.
      await repository.saveEditState(
        first.id,
        duration: const Duration(minutes: 1),
        segments: const [
          VideoSegment(
              id: 0, start: Duration.zero, end: Duration(minutes: 1)),
        ],
      );

      final all = await repository.getAll();
      expect(all.map((e) => e.name).toList(), ['Primeiro', 'Segundo']);
    });
  });

  group('rename', () {
    test('altera o nome e persiste', () async {
      final project = await repository.createProject(
        videoPath: await fakeVideo('a.mp4'),
        title: 'Antigo',
        origin: MediaOrigin.localFile,
      );

      await repository.rename(project.id, 'Novo nome');

      final all = await repository.getAll();
      expect(all.single.name, 'Novo nome');
    });

    test('rejeita nome duplicado (ignorando maiúsculas)', () async {
      await repository.createProject(
        videoPath: await fakeVideo('a.mp4'),
        title: 'Aniversário',
        origin: MediaOrigin.localFile,
      );
      final other = await repository.createProject(
        videoPath: await fakeVideo('b.mp4'),
        title: 'Casamento',
        origin: MediaOrigin.localFile,
      );

      expect(
        () => repository.rename(other.id, 'aniversário'),
        throwsA(isA<HistoryException>()),
      );
    });

    test('rejeita nome vazio e edição inexistente', () async {
      final project = await repository.createProject(
        videoPath: await fakeVideo('a.mp4'),
        title: 'Qualquer',
        origin: MediaOrigin.localFile,
      );

      expect(
        () => repository.rename(project.id, '   '),
        throwsA(isA<HistoryException>()),
      );
      expect(
        () => repository.rename('nao-existe', 'Outro'),
        throwsA(isA<HistoryException>()),
      );
    });
  });

  group('saveEditState', () {
    test('persiste duração e segmentos (roundtrip completo)', () async {
      final project = await repository.createProject(
        videoPath: await fakeVideo('a.mp4'),
        title: 'Edição',
        origin: MediaOrigin.localFile,
      );

      const duration = Duration(minutes: 10);
      const segments = [
        VideoSegment(id: 0, start: Duration.zero, end: Duration(minutes: 4)),
        VideoSegment(
          id: 2,
          start: Duration(minutes: 4),
          end: duration,
          enabled: false,
        ),
      ];

      await repository.saveEditState(
        project.id,
        duration: duration,
        segments: segments,
      );

      final saved = (await repository.getAll()).single;
      expect(saved.duration, duration);
      expect(saved.segments, segments);
    });
  });

  group('delete', () {
    test('remove o registro e o arquivo de vídeo', () async {
      final project = await repository.createProject(
        videoPath: await fakeVideo('a.mp4'),
        title: 'Descartável',
        origin: MediaOrigin.localFile,
      );

      await repository.delete(project.id);

      expect(await repository.getAll(), isEmpty);
      expect(File(project.videoPath).existsSync(), isFalse);
    });
  });
}
