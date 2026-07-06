import 'package:equatable/equatable.dart';

import 'video_chapter.dart';
import 'video_media.dart';
import 'video_segment.dart';

/// Uma edição salva no histórico: o vídeo (copiado para o armazenamento do
/// app) e o estado dos cortes, retomável a qualquer momento.
class EditProject extends Equatable {
  const EditProject({
    required this.id,
    required this.name,
    required this.videoPath,
    required this.origin,
    required this.duration,
    required this.segments,
    required this.createdAt,
    required this.updatedAt,
    this.chapters = const [],
  });

  final String id;

  /// Nome exibido e usado nos arquivos exportados — único no histórico,
  /// para os downloads nunca repetirem nome.
  final String name;

  /// Cópia persistente do vídeo, de propriedade do app.
  final String videoPath;

  final MediaOrigin origin;

  /// Duração conhecida do vídeo; [Duration.zero] antes da primeira abertura.
  final Duration duration;

  /// Estado salvo dos cortes; vazio quando a edição nunca foi aberta.
  final List<VideoSegment> segments;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Capítulos que o vídeo trouxe do YouTube; vazio quando não há.
  final List<VideoChapter> chapters;

  /// Representação do vídeo para o player e a exportação.
  VideoMedia get media => VideoMedia(
        filePath: videoPath,
        title: name,
        origin: origin,
        chapters: chapters,
      );

  @override
  List<Object?> get props => [
        id, name, videoPath, origin, duration, segments, //
        createdAt, updatedAt, chapters,
      ];
}
