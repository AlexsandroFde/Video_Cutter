import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/ffmpeg_datasource.dart';
import '../data/datasources/gallery_datasource.dart';
import '../data/datasources/local_media_datasource.dart';
import '../data/datasources/youtube_datasource.dart';
import '../data/repositories/export_repository_impl.dart';
import '../data/repositories/media_repository_impl.dart';
import '../domain/repositories/export_repository.dart';
import '../domain/repositories/media_repository.dart';
import 'controllers/export_controller.dart';
import 'controllers/media_controller.dart';
import 'controllers/segments_controller.dart';

/// Composição de dependências da feature (datasources → repositórios →
/// controllers). A UI conhece apenas os providers de controller e os
/// contratos do domínio.

final ffmpegDataSourceProvider =
    Provider<FfmpegDataSource>((ref) => const FfmpegDataSource());

final localMediaDataSourceProvider =
    Provider<LocalMediaDataSource>((ref) => const LocalMediaDataSource());

final youtubeDataSourceProvider = Provider<YoutubeDataSource>(
  (ref) => YoutubeDataSource(ref.watch(ffmpegDataSourceProvider)),
);

final mediaRepositoryProvider = Provider<MediaRepository>(
  (ref) => MediaRepositoryImpl(
    local: ref.watch(localMediaDataSourceProvider),
    youtube: ref.watch(youtubeDataSourceProvider),
  ),
);

final galleryDataSourceProvider =
    Provider<GalleryDataSource>((ref) => const GalleryDataSource());

final exportRepositoryProvider = Provider<ExportRepository>(
  (ref) => ExportRepositoryImpl(
    ffmpeg: ref.watch(ffmpegDataSourceProvider),
    gallery: ref.watch(galleryDataSourceProvider),
  ),
);

final mediaControllerProvider =
    NotifierProvider<MediaController, MediaState>(MediaController.new);

final segmentsControllerProvider =
    NotifierProvider<SegmentsController, SegmentsState>(SegmentsController.new);

final exportControllerProvider =
    NotifierProvider<ExportController, ExportState>(ExportController.new);
