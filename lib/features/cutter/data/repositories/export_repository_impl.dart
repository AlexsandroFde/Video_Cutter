import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/file_name.dart';
import '../../domain/entities/export_event.dart';
import '../../domain/entities/export_mode.dart';
import '../../domain/entities/video_media.dart';
import '../../domain/entities/video_segment.dart';
import '../../domain/repositories/export_repository.dart';
import '../datasources/ffmpeg_datasource.dart';

class ExportRepositoryImpl implements ExportRepository {
  const ExportRepositoryImpl({required this._ffmpeg});

  final FfmpegDataSource _ffmpeg;

  @override
  Stream<ExportEvent> exportSegments({
    required VideoMedia media,
    required List<VideoSegment> segments,
    required ExportMode mode,
  }) {
    // StreamController em vez de async*: os callbacks de progresso do FFmpeg
    // precisam adicionar eventos de fora do corpo do generator.
    final controller = StreamController<ExportEvent>();

    Future<void> run() async {
      final enabled = segments.where((s) => s.enabled).toList();
      if (enabled.isEmpty) {
        throw const ExportException('Nenhum segmento habilitado para exportar.');
      }

      final outputDir = await _createOutputDir(media.title);
      // Sem recodificação o container de saída deve ser o mesmo da entrada;
      // com recodificação a saída é sempre H.264/AAC em .mp4.
      final inputExtension = p.extension(media.filePath);
      final extension = mode == ExportMode.fastCopy && inputExtension.isNotEmpty
          ? inputExtension
          : '.mp4';

      final files = <String>[];
      for (final (index, segment) in enabled.indexed) {
        controller.add(ExportSegmentProgress(
          index: index,
          total: enabled.length,
          progress: 0,
        ));
        final outputPath = p.join(
          outputDir.path,
          'parte_${'${index + 1}'.padLeft(2, '0')}$extension',
        );
        await _ffmpeg.cutSegment(
          inputPath: media.filePath,
          outputPath: outputPath,
          start: segment.start,
          end: segment.end,
          mode: mode,
          onProgress: (progress) => controller.add(ExportSegmentProgress(
            index: index,
            total: enabled.length,
            progress: progress,
          )),
        );
        files.add(outputPath);
      }
      controller.add(ExportCompleted(directory: outputDir.path, files: files));
    }

    unawaited(
      run().catchError((Object error, StackTrace stackTrace) {
        controller.addError(
          error is AppException ? error : const ExportException(),
          stackTrace,
        );
      }).whenComplete(controller.close),
    );
    return controller.stream;
  }

  Future<Directory> _createOutputDir(String title) async {
    final docs = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp = '${now.year}${two(now.month)}${two(now.day)}'
        '_${two(now.hour)}${two(now.minute)}${two(now.second)}';
    final dir = Directory(
      p.join(docs.path, 'VideoCutter', '${sanitizeFileName(title)}_$stamp'),
    );
    return dir.create(recursive: true);
  }
}
