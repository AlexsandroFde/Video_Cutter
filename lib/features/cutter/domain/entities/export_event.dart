import 'package:equatable/equatable.dart';

/// Eventos emitidos pelo repositório durante a exportação dos segmentos.
sealed class ExportEvent extends Equatable {
  const ExportEvent();

  @override
  List<Object?> get props => [];
}

/// Progresso do segmento [index] (0-based); [progress] vai de 0 a 1 dentro
/// do segmento atual.
final class ExportSegmentProgress extends ExportEvent {
  const ExportSegmentProgress({
    required this.index,
    required this.total,
    required this.progress,
  });

  final int index;
  final int total;
  final double progress;

  @override
  List<Object?> get props => [index, total, progress];
}

/// Todos os segmentos foram exportados com sucesso.
final class ExportCompleted extends ExportEvent {
  const ExportCompleted({required this.directory, required this.files});

  final String directory;
  final List<String> files;

  @override
  List<Object?> get props => [directory, files];
}
