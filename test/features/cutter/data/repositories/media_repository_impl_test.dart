import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:video_cutter/core/errors/app_exception.dart';
import 'package:video_cutter/features/cutter/data/datasources/ffmpeg_datasource.dart';
import 'package:video_cutter/features/cutter/data/datasources/local_media_datasource.dart';
import 'package:video_cutter/features/cutter/data/datasources/youtube_datasource.dart';
import 'package:video_cutter/features/cutter/data/repositories/media_repository_impl.dart';
import 'package:video_cutter/features/cutter/domain/entities/video_media.dart';

/// Seletor falso que devolve um resultado fixo (ou `null` = cancelado).
class _FakeLocalMediaDataSource extends LocalMediaDataSource {
  const _FakeLocalMediaDataSource(this.picked);

  final ({String path, String name})? picked;

  @override
  Future<({String path, String name})?> pickVideo() async => picked;
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('media_repo_test');
    addTearDown(() => tempDir.deleteSync(recursive: true));
  });

  MediaRepositoryImpl repositoryPicking(({String path, String name})? picked) =>
      MediaRepositoryImpl(
        local: _FakeLocalMediaDataSource(picked),
        youtube: YoutubeDataSource(const FfmpegDataSource()),
      );

  String createFile(String name) {
    final file = File('${tempDir.path}/$name')..writeAsBytesSync(const [0]);
    return file.path;
  }

  group('pickLocalVideo', () {
    test('aceita vídeo e usa o nome sem extensão como título', () async {
      final path = createFile('ferias na praia.mp4');

      final media = await repositoryPicking((
        path: path,
        name: 'ferias na praia.mp4',
      )).pickLocalVideo();

      expect(media, isNotNull);
      expect(media!.title, 'ferias na praia');
      expect(media.origin, MediaOrigin.localFile);
    });

    test('aceita extensão de vídeo em maiúsculas', () async {
      final path = createFile('clipe.MOV');

      final media = await repositoryPicking((
        path: path,
        name: 'clipe.MOV',
      )).pickLocalVideo();

      expect(media, isNotNull);
    });

    test('recusa arquivo que não é vídeo', () async {
      final path = createFile('boleto.pdf');

      expect(
        () => repositoryPicking((
          path: path,
          name: 'boleto.pdf',
        )).pickLocalVideo(),
        throwsA(isA<MediaLoadException>()),
      );
    });

    test('recusa arquivo sem extensão', () async {
      final path = createFile('semextensao');

      expect(
        () => repositoryPicking((
          path: path,
          name: 'semextensao',
        )).pickLocalVideo(),
        throwsA(isA<MediaLoadException>()),
      );
    });

    test('cancelamento retorna null', () async {
      expect(await repositoryPicking(null).pickLocalVideo(), isNull);
    });

    test('arquivo que sumiu do disco lança erro amigável', () async {
      expect(
        () => repositoryPicking((
          path: '${tempDir.path}/sumiu.mp4',
          name: 'sumiu.mp4',
        )).pickLocalVideo(),
        throwsA(isA<MediaLoadException>()),
      );
    });
  });
}
