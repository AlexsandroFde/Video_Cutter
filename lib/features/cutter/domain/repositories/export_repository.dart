import '../entities/export_event.dart';
import '../entities/export_mode.dart';
import '../entities/video_media.dart';
import '../entities/video_segment.dart';

/// Corta [VideoMedia] nos segmentos habilitados e grava os arquivos gerados.
abstract interface class ExportRepository {
  /// Exporta os segmentos com `enabled == true`, na ordem em que aparecem.
  ///
  /// Emite [ExportSegmentProgress] durante o processo e encerra com
  /// [ExportCompleted]. Falhas chegam como erro do stream, sempre tipadas
  /// como `AppException`.
  Stream<ExportEvent> exportSegments({
    required VideoMedia media,
    required List<VideoSegment> segments,
    required ExportMode mode,
  });
}
