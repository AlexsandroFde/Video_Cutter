import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/edit_project.dart';
import '../../domain/entities/video_media.dart';
import '../providers.dart';

/// Estados do carregamento de mídia (arquivo local ou YouTube).
sealed class MediaState extends Equatable {
  const MediaState();

  @override
  List<Object?> get props => [];
}

final class MediaIdle extends MediaState {
  const MediaIdle();
}

final class MediaLoading extends MediaState {
  const MediaLoading({required this.message, this.progress});

  final String message;

  /// De 0 a 1; `null` exibe um indicador indeterminado.
  final double? progress;

  @override
  List<Object?> get props => [message, progress];
}

final class MediaReady extends MediaState {
  const MediaReady(this.project);

  /// Edição criada no histórico, pronta para abrir no editor.
  final EditProject project;

  @override
  List<Object?> get props => [project];
}

final class MediaFailure extends MediaState {
  const MediaFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Carrega o vídeo a ser editado, do dispositivo ou do YouTube.
class MediaController extends Notifier<MediaState> {
  @override
  MediaState build() => const MediaIdle();

  Future<void> pickLocalVideo() async {
    if (state is MediaLoading) return;
    state = const MediaLoading(message: 'Carregando vídeo…');
    try {
      final media = await ref.read(mediaRepositoryProvider).pickLocalVideo();
      if (media == null) {
        state = const MediaIdle();
        return;
      }
      state = MediaReady(await _createProject(media));
    } on AppException catch (e) {
      state = MediaFailure(e.message);
    } catch (_) {
      state = const MediaFailure('Não foi possível carregar o vídeo.');
    }
  }

  Future<void> loadFromYoutube(String url) async {
    if (state is MediaLoading) return;
    const message = 'Baixando do YouTube…';
    state = const MediaLoading(message: message);
    try {
      final media = await ref.read(mediaRepositoryProvider).fetchYoutubeVideo(
            url,
            onProgress: (progress) =>
                state = MediaLoading(message: message, progress: progress),
          );
      state = MediaReady(await _createProject(media));
    } on AppException catch (e) {
      state = MediaFailure(e.message);
    } catch (_) {
      state = const MediaFailure('Falha inesperada ao baixar o vídeo.');
    }
  }

  /// Guarda o vídeo no armazenamento do app e registra a edição no
  /// histórico, já com nome único.
  Future<EditProject> _createProject(VideoMedia media) async {
    state = const MediaLoading(message: 'Guardando no histórico…');
    final project = await ref.read(historyRepositoryProvider).createProject(
          videoPath: media.filePath,
          title: media.title,
          origin: media.origin,
          chapters: media.chapters,
        );
    ref.invalidate(historyControllerProvider);
    return project;
  }

  void reset() => state = const MediaIdle();
}
