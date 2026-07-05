import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/export_event.dart';
import '../../domain/entities/export_mode.dart';
import '../../domain/entities/video_media.dart';
import '../../domain/entities/video_segment.dart';
import '../providers.dart';

/// Estados da exportação dos segmentos.
sealed class ExportState extends Equatable {
  const ExportState();

  @override
  List<Object?> get props => [];
}

final class ExportIdle extends ExportState {
  const ExportIdle();
}

final class ExportRunning extends ExportState {
  const ExportRunning({
    required this.current,
    required this.total,
    required this.progress,
  });

  /// Segmento em processamento, 1-based (pronto para exibição).
  final int current;

  final int total;

  /// Progresso dentro do segmento atual, de 0 a 1.
  final double progress;

  /// Progresso geral da exportação, de 0 a 1.
  double get overall =>
      total == 0 ? 0 : ((current - 1 + progress) / total).clamp(0.0, 1.0);

  @override
  List<Object?> get props => [current, total, progress];
}

/// Os cortes ficaram prontos e estão sendo salvos na pasta pública.
final class ExportPublishing extends ExportState {
  const ExportPublishing({required this.current, required this.total});

  /// Arquivo sendo salvo, 1-based (pronto para exibição).
  final int current;

  final int total;

  double get overall =>
      total == 0 ? 0 : (current / total).clamp(0.0, 1.0);

  @override
  List<Object?> get props => [current, total];
}

final class ExportSuccess extends ExportState {
  const ExportSuccess({
    required this.directory,
    required this.files,
    required this.album,
  });

  final String directory;
  final List<String> files;

  /// Pasta pública/álbum onde os cortes ficaram visíveis.
  final String album;

  @override
  List<Object?> get props => [directory, files, album];
}

final class ExportFailure extends ExportState {
  const ExportFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Dispara a exportação e acompanha o progresso emitido pelo repositório.
class ExportController extends Notifier<ExportState> {
  StreamSubscription<ExportEvent>? _subscription;

  @override
  ExportState build() {
    ref.onDispose(() => _subscription?.cancel());
    return const ExportIdle();
  }

  void start({
    required VideoMedia media,
    required List<VideoSegment> segments,
    required ExportMode mode,
  }) {
    if (state is ExportRunning) return;
    final total = segments.where((s) => s.enabled).length;
    state = ExportRunning(current: 1, total: total, progress: 0);

    _subscription = ref
        .read(exportRepositoryProvider)
        .exportSegments(media: media, segments: segments, mode: mode)
        .listen(
      (event) {
        switch (event) {
          case ExportSegmentProgress(:final index, :final total, :final progress):
            state = ExportRunning(
              current: index + 1,
              total: total,
              progress: progress,
            );
          case ExportSavingToGallery(:final index, :final total):
            state = ExportPublishing(current: index + 1, total: total);
          case ExportCompleted(:final directory, :final files, :final album):
            state = ExportSuccess(
              directory: directory,
              files: files,
              album: album,
            );
        }
      },
      onError: (Object error, StackTrace _) {
        state = ExportFailure(
          error is AppException
              ? error.message
              : 'Falha inesperada na exportação.',
        );
      },
    );
  }

  /// Compartilha todos os arquivos exportados de uma vez (share sheet do SO).
  Future<void> shareAll() async {
    final current = state;
    if (current is! ExportSuccess) return;
    await SharePlus.instance.share(ShareParams(
      files: [for (final path in current.files) XFile(path)],
      title: 'Segmentos do vídeo',
    ));
  }

  void reset() {
    _subscription?.cancel();
    state = const ExportIdle();
  }
}
