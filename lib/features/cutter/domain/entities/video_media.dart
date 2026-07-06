import 'package:equatable/equatable.dart';

import 'video_chapter.dart';

/// De onde o vídeo foi obtido.
enum MediaOrigin { localFile, youtube }

/// Vídeo carregado e pronto para edição — sempre um arquivo local, mesmo
/// quando a origem é o YouTube (o download acontece antes).
class VideoMedia extends Equatable {
  const VideoMedia({
    required this.filePath,
    required this.title,
    required this.origin,
    this.chapters = const [],
  });

  final String filePath;
  final String title;
  final MediaOrigin origin;

  /// Capítulos anunciados na descrição do vídeo (YouTube). Vazio para
  /// arquivo local ou vídeo sem capítulos.
  final List<VideoChapter> chapters;

  @override
  List<Object?> get props => [filePath, title, origin, chapters];
}
