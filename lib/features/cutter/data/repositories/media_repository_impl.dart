import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/video_media.dart';
import '../../domain/repositories/media_repository.dart';
import '../datasources/local_media_datasource.dart';
import '../datasources/youtube_datasource.dart';

class MediaRepositoryImpl implements MediaRepository {
  const MediaRepositoryImpl({
    required this._local,
    required this._youtube,
  });

  final LocalMediaDataSource _local;
  final YoutubeDataSource _youtube;

  @override
  Future<VideoMedia?> pickLocalVideo() async {
    final picked = await _local.pickVideo();
    if (picked == null) return null;
    if (!File(picked.path).existsSync()) {
      throw const MediaLoadException('O arquivo selecionado não foi encontrado.');
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
    final result =
        await _youtube.download(url, tempDir, onProgress: onProgress);
    return VideoMedia(
      filePath: result.filePath,
      title: result.title,
      origin: MediaOrigin.youtube,
    );
  }
}
