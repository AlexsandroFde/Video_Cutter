import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/file_name.dart';
import '../../domain/entities/export_event.dart';
import '../../domain/entities/export_format.dart';
import '../../domain/entities/export_mode.dart';
import '../../domain/entities/video_media.dart';
import '../../domain/entities/video_segment.dart';
import '../../domain/repositories/export_repository.dart';
import '../datasources/ffmpeg_datasource.dart';
import '../datasources/gallery_datasource.dart';

class ExportRepositoryImpl implements ExportRepository {
  const ExportRepositoryImpl({required this._ffmpeg, required this._gallery});

  /// Pasta pública onde os cortes ficam visíveis (galeria/gerenciador).
  static const albumName = 'Video Cutter';

  final FfmpegDataSource _ffmpeg;
  final GalleryDataSource _gallery;

  @override
  Stream<ExportEvent> exportSegments({
    required VideoMedia media,
    required List<VideoSegment> segments,
    required ExportMode mode,
    required ExportFormat format,
  }) {
    // StreamController em vez de async*: os callbacks de progresso do FFmpeg
    // precisam adicionar eventos de fora do corpo do generator.
    final controller = StreamController<ExportEvent>();

    Future<void> run() async {
      final enabled = segments.where((s) => s.enabled).toList();
      if (enabled.isEmpty) {
        throw const ExportException('Nenhum segmento habilitado para exportar.');
      }

      // Pede a permissão antes de começar a cortar, para o usuário não
      // esperar a exportação inteira e só então descobrir a negativa.
      if (!await _gallery.ensureAccess()) {
        throw const ExportException(
          'Sem permissão para salvar os vídeos na galeria. '
          'Conceda o acesso e tente de novo.',
        );
      }

      final outputDir = await _createOutputDir(media.title);
      // MP3 define a extensão; no vídeo sem recodificação o container de
      // saída deve ser o mesmo da entrada, e recodificado vira .mp4.
      final inputExtension = p.extension(media.filePath);
      final extension = switch (format) {
        ExportFormat.mp3 => '.mp3',
        ExportFormat.video
            when mode == ExportMode.fastCopy && inputExtension.isNotEmpty =>
          inputExtension,
        ExportFormat.video => '.mp4',
      };

      // O título vem do nome da edição, único no histórico — assim os
      // arquivos baixados nunca repetem nome.
      final baseName = sanitizeFileName(media.title);

      final files = <String>[];
      for (final (index, segment) in enabled.indexed) {
        controller.add(ExportSegmentProgress(
          index: index,
          total: enabled.length,
          progress: 0,
        ));
        final outputPath = p.join(
          outputDir.path,
          '$baseName - parte ${'${index + 1}'.padLeft(2, '0')}$extension',
        );
        await _ffmpeg.cutSegment(
          inputPath: media.filePath,
          outputPath: outputPath,
          start: segment.start,
          end: segment.end,
          mode: mode,
          format: format,
          onProgress: (progress) => controller.add(ExportSegmentProgress(
            index: index,
            total: enabled.length,
            progress: progress,
          )),
        );
        files.add(outputPath);
      }

      // Publica os cortes na pasta pública: vídeos em Movies/, MP3 em Music/.
      for (final (index, file) in files.indexed) {
        controller.add(
          ExportSavingToGallery(index: index, total: files.length),
        );
        switch (format) {
          case ExportFormat.video:
            await _gallery.saveVideo(file, album: albumName);
          case ExportFormat.mp3:
            await _gallery.saveAudio(file, album: albumName);
        }
      }

      // Os arquivos de trabalho já foram copiados para a pasta pública;
      // não há por que ocupar armazenamento interno com duplicatas.
      try {
        await outputDir.delete(recursive: true);
      } on FileSystemException {
        // Falha na limpeza não compromete a exportação.
      }

      controller.add(ExportCompleted(
        count: files.length,
        album: albumName,
        format: format,
      ));
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
