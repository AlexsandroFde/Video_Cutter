import 'package:equatable/equatable.dart';

/// Um trecho contíguo do vídeo, delimitado por [start] e [end].
///
/// Os segmentos de um vídeo são sempre contíguos e cobrem a duração inteira;
/// o que define se um trecho entra na exportação é [enabled].
class VideoSegment extends Equatable {
  const VideoSegment({
    required this.id,
    required this.start,
    required this.end,
    this.enabled = true,
  });

  /// Identificador estável dentro da sessão de edição (não muda ao dividir
  /// ou mesclar vizinhos).
  final int id;

  final Duration start;
  final Duration end;
  final bool enabled;

  Duration get length => end - start;

  VideoSegment copyWith({Duration? start, Duration? end, bool? enabled}) {
    return VideoSegment(
      id: id,
      start: start ?? this.start,
      end: end ?? this.end,
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  List<Object?> get props => [id, start, end, enabled];
}
