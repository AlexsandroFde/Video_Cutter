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

/// O corte [index] (0-based) está sendo salvo na pasta pública/galeria.
final class ExportSavingToGallery extends ExportEvent {
  const ExportSavingToGallery({required this.index, required this.total});

  final int index;
  final int total;

  @override
  List<Object?> get props => [index, total];
}

/// Todos os segmentos foram exportados e salvos com sucesso.
final class ExportCompleted extends ExportEvent {
  const ExportCompleted({
    required this.directory,
    required this.files,
    required this.album,
  });

  /// Diretório interno de trabalho (usado pelo "Compartilhar tudo").
  final String directory;

  final List<String> files;

  /// Nome da pasta pública/álbum onde os cortes ficaram visíveis.
  final String album;

  @override
  List<Object?> get props => [directory, files, album];
}
