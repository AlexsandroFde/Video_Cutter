import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/edit_project.dart';
import '../../domain/entities/video_segment.dart';
import '../providers.dart';

/// Lista do histórico de edições e suas operações de CRUD.
class HistoryController extends AsyncNotifier<List<EditProject>> {
  @override
  Future<List<EditProject>> build() =>
      ref.watch(historyRepositoryProvider).getAll();

  /// Renomeia e recarrega; propaga `HistoryException` (nome vazio ou
  /// duplicado) para a UI exibir no diálogo.
  Future<void> rename(String id, String newName) async {
    await ref.read(historyRepositoryProvider).rename(id, newName);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await ref.read(historyRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }

  /// Persiste o estado dos cortes sem recarregar a lista — o editor chama
  /// isso com frequência (auto-save); a Home recarrega ao voltar.
  Future<void> saveEditState(
    String id, {
    required Duration duration,
    required List<VideoSegment> segments,
  }) {
    return ref
        .read(historyRepositoryProvider)
        .saveEditState(id, duration: duration, segments: segments);
  }
}
