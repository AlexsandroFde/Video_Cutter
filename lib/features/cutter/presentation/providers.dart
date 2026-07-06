import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/ffmpeg_datasource.dart';
import '../data/datasources/gallery_datasource.dart';
import '../data/datasources/history_local_datasource.dart';
import '../data/datasources/local_media_datasource.dart';
import '../data/datasources/thumbnail_datasource.dart';
import '../data/datasources/youtube_datasource.dart';
import '../data/repositories/export_repository_impl.dart';
import '../data/repositories/history_repository_impl.dart';
import '../data/repositories/media_repository_impl.dart';
import '../data/repositories/thumbnail_repository_impl.dart';
import '../domain/entities/edit_project.dart';
import '../domain/repositories/export_repository.dart';
import '../domain/repositories/history_repository.dart';
import '../domain/repositories/media_repository.dart';
import '../domain/repositories/thumbnail_repository.dart';
import 'controllers/export_controller.dart';
import 'controllers/history_controller.dart';
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

final historyLocalDataSourceProvider =
    Provider<HistoryLocalDataSource>((ref) => HistoryLocalDataSource());

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepositoryImpl(
    local: ref.watch(historyLocalDataSourceProvider),
  ),
);

final historyControllerProvider =
    AsyncNotifierProvider<HistoryController, List<EditProject>>(
        HistoryController.new);

final mediaControllerProvider =
    NotifierProvider<MediaController, MediaState>(MediaController.new);

final segmentsControllerProvider =
    NotifierProvider<SegmentsController, SegmentsState>(SegmentsController.new);

final exportControllerProvider =
    NotifierProvider<ExportController, ExportState>(ExportController.new);

final thumbnailDataSourceProvider =
    Provider<ThumbnailDataSource>((ref) => const ThumbnailDataSource());

final thumbnailRepositoryProvider = Provider<ThumbnailRepository>(
  (ref) => ThumbnailRepositoryImpl(
    ffmpeg: ref.watch(thumbnailDataSourceProvider),
    local: ref.watch(historyLocalDataSourceProvider),
  ),
);

/// Identifica um vídeo para os providers de miniatura. Como record, tem
/// igualdade estrutural — a mesma edição reaproveita o cache do provider.
typedef ThumbnailRequest = ({String id, String videoPath, int durationMs});

/// Caminho do quadro-pôster de uma edição (para o cartão do histórico), ou
/// `null` enquanto gera / se falhar.
final posterProvider =
    FutureProvider.family<String?, ThumbnailRequest>((ref, request) {
  return ref.watch(thumbnailRepositoryProvider).poster(
        id: request.id,
        videoPath: request.videoPath,
        duration: Duration(milliseconds: request.durationMs),
      );
});

/// Tira de quadros já decodificados para o fundo da trilha da timeline. As
/// imagens são liberadas quando ninguém mais assiste (ao sair do editor).
final timelineStripProvider =
    FutureProvider.autoDispose.family<List<ui.Image>, ThumbnailRequest>(
  (ref, request) async {
    final paths = await ref.watch(thumbnailRepositoryProvider).strip(
          id: request.id,
          videoPath: request.videoPath,
          duration: Duration(milliseconds: request.durationMs),
        );

    final images = <ui.Image>[];
    for (final path in paths) {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      images.add(frame.image);
    }
    ref.onDispose(() {
      for (final image in images) {
        image.dispose();
      }
    });
    return images;
  },
);
