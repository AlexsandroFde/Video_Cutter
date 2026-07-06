import '../entities/edit_project.dart';
import '../entities/video_chapter.dart';
import '../entities/video_media.dart';
import '../entities/video_segment.dart';

/// CRUD do histórico de edições.
abstract interface class HistoryRepository {
  /// Todas as edições, da mais recente para a mais antiga.
  Future<List<EditProject>> getAll();

  /// Cria uma edição a partir do vídeo em [videoPath], movendo-o (YouTube)
  /// ou copiando-o (arquivo do usuário) para o armazenamento do app.
  ///
  /// O nome nasce de [title] e recebe um sufixo numérico se já existir.
  /// [chapters] guarda os capítulos que o vídeo trouxe do YouTube.
  Future<EditProject> createProject({
    required String videoPath,
    required String title,
    required MediaOrigin origin,
    List<VideoChapter> chapters = const [],
  });

  /// Renomeia a edição [id]; lança `HistoryException` para nome vazio,
  /// duplicado ou edição inexistente.
  Future<EditProject> rename(String id, String newName);

  /// Salva o estado atual dos cortes da edição [id].
  Future<void> saveEditState(
    String id, {
    required Duration duration,
    required List<VideoSegment> segments,
  });

  /// Remove a edição [id] e o vídeo que ela guardava.
  Future<void> delete(String id);
}
