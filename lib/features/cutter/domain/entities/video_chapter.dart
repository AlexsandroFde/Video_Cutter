import 'package:equatable/equatable.dart';

/// Um capítulo anunciado pelo autor do vídeo: onde ele começa e o título.
///
/// Vem da descrição do vídeo no YouTube — o fim de cada capítulo é o início
/// do próximo (ou o fim do vídeo, no último).
class VideoChapter extends Equatable {
  const VideoChapter({required this.start, required this.title});

  final Duration start;
  final String title;

  @override
  List<Object?> get props => [start, title];
}
