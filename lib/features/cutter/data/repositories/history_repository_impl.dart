import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/file_name.dart';
import '../../domain/entities/edit_project.dart';
import '../../domain/entities/video_media.dart';
import '../../domain/entities/video_segment.dart';
import '../../domain/repositories/history_repository.dart';
import '../datasources/history_local_datasource.dart';
import '../models/edit_project_model.dart';

class HistoryRepositoryImpl implements HistoryRepository {
  const HistoryRepositoryImpl({required this._local});

  final HistoryLocalDataSource _local;

  @override
  Future<List<EditProject>> getAll() async {
    final models = await _local.readAll();
    models.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return [for (final model in models) model.toEntity()];
  }

  @override
  Future<EditProject> createProject({
    required String videoPath,
    required String title,
    required MediaOrigin origin,
  }) async {
    final models = await _local.readAll();
    final name = _uniqueName(
      sanitizeFileName(title),
      models.map((m) => m.name),
    );

    final id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final extension = p.extension(videoPath);
    final storedPath =
        p.join((await _local.videosDir()).path, '$id$extension');
    await _persistVideo(videoPath, storedPath, origin);

    final now = DateTime.now();
    final model = EditProjectModel(
      id: id,
      name: name,
      videoPath: storedPath,
      origin: origin,
      durationMs: 0,
      segments: const [],
      createdAt: now,
      updatedAt: now,
    );
    await _local.writeAll([...models, model]);
    return model.toEntity();
  }

  @override
  Future<EditProject> rename(String id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw const HistoryException('O nome não pode ficar vazio.');
    }

    final models = await _local.readAll();
    final clash = models.any(
      (m) => m.id != id && m.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (clash) {
      throw const HistoryException(
        'Já existe uma edição com esse nome. Escolha outro.',
      );
    }

    final index = models.indexWhere((m) => m.id == id);
    if (index == -1) {
      throw const HistoryException('Edição não encontrada no histórico.');
    }

    models[index] = models[index].copyWith(name: trimmed);
    await _local.writeAll(models);
    return models[index].toEntity();
  }

  @override
  Future<void> saveEditState(
    String id, {
    required Duration duration,
    required List<VideoSegment> segments,
  }) async {
    final models = await _local.readAll();
    final index = models.indexWhere((m) => m.id == id);
    if (index == -1) return; // edição excluída enquanto era editada
    models[index] = models[index].copyWith(
      durationMs: duration.inMilliseconds,
      segments: segments,
      updatedAt: DateTime.now(),
    );
    await _local.writeAll(models);
  }

  @override
  Future<void> delete(String id) async {
    final models = await _local.readAll();
    final index = models.indexWhere((m) => m.id == id);
    if (index == -1) return;

    final video = File(models[index].videoPath);
    try {
      if (await video.exists()) await video.delete();
    } on FileSystemException {
      // O registro sai do histórico mesmo se o arquivo resistir.
    }

    await _local.deleteThumbs(id);

    models.removeAt(index);
    await _local.writeAll(models);
  }

  /// Move (YouTube, arquivo temporário nosso) ou copia (arquivo do usuário)
  /// o vídeo para o armazenamento do app.
  Future<void> _persistVideo(
    String sourcePath,
    String targetPath,
    MediaOrigin origin,
  ) async {
    final source = File(sourcePath);
    if (origin == MediaOrigin.youtube) {
      try {
        await source.rename(targetPath);
        return;
      } on FileSystemException {
        // rename falha entre volumes; cai para copiar + apagar.
      }
      await source.copy(targetPath);
      await source.delete();
    } else {
      await source.copy(targetPath);
    }
  }

  /// Garante unicidade acrescentando um sufixo numérico: "Nome", "Nome 2"…
  String _uniqueName(String base, Iterable<String> existing) {
    final taken = {for (final name in existing) name.toLowerCase()};
    if (!taken.contains(base.toLowerCase())) return base;
    var counter = 2;
    while (taken.contains('$base $counter'.toLowerCase())) {
      counter++;
    }
    return '$base $counter';
  }
}
