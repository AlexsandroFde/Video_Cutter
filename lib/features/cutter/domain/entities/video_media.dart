import 'package:equatable/equatable.dart';

/// De onde o vídeo foi obtido.
enum MediaOrigin { localFile, youtube }

/// Vídeo carregado e pronto para edição — sempre um arquivo local, mesmo
/// quando a origem é o YouTube (o download acontece antes).
class VideoMedia extends Equatable {
  const VideoMedia({
    required this.filePath,
    required this.title,
    required this.origin,
  });

  final String filePath;
  final String title;
  final MediaOrigin origin;

  @override
  List<Object?> get props => [filePath, title, origin];
}
