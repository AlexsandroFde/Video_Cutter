import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/video_media.dart';
import '../../domain/repositories/media_repository.dart';
import '../datasources/local_media_datasource.dart';
import '../datasources/youtube_datasource.dart';

class MediaRepositoryImpl implements MediaRepository {
  const MediaRepositoryImpl({required this._local, required this._youtube});

  final LocalMediaDataSource _local;
  final YoutubeDataSource _youtube;

  /// Extensões de vídeo aceitas ao escolher um arquivo do aparelho.
  ///
  /// O seletor já pede `video/*`, mas alguns gerenciadores de arquivo
  /// deixam escolher qualquer coisa — esta lista é a garantia final.
  static const videoExtensions = {
    '3g2', '3gp', 'avi', 'flv', 'm2ts', 'm4v', 'mkv', 'mov', 'mp4', //
    'mpeg', 'mpg', 'mts', 'ogv', 'ts', 'webm', 'wmv',
  };

  @override
  Future<VideoMedia?> pickLocalVideo() async {
    final picked = await _local.pickVideo();
    if (picked == null) return null;
    final extension = p
        .extension(picked.name)
        .replaceFirst('.', '')
        .toLowerCase();
    if (!videoExtensions.contains(extension)) {
      throw const MediaLoadException(
        'Esse arquivo não é um vídeo. Escolha um vídeo do aparelho '
        '(MP4, MOV, MKV…).',
      );
    }
    if (!File(picked.path).existsSync()) {
      throw const MediaLoadException(
        'O arquivo selecionado não foi encontrado.',
      );
    }
    return VideoMedia(
      filePath: picked.path,
      title: p.basenameWithoutExtension(picked.name),
      origin: MediaOrigin.localFile,
    );
  }

  @override
  Future<VideoMedia> fetchYoutubeVideo(
    String url, {
    ProgressCallback? onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final result = await _youtube.download(
      url,
      tempDir,
      onProgress: onProgress,
    );
    return VideoMedia(
      filePath: result.filePath,
      title: result.title,
      origin: MediaOrigin.youtube,
    );
  }
}
