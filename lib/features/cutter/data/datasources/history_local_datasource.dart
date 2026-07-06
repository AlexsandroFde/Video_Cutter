import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/edit_project_model.dart';

/// Persistência do histórico em `<documentos>/VideoCutter/history.json`,
/// com os vídeos das edições em `<documentos>/VideoCutter/videos/`.
///
/// [baseDirProvider] é injetável para os testes apontarem para um
/// diretório temporário.
class HistoryLocalDataSource {
  HistoryLocalDataSource({Future<Directory> Function()? baseDirProvider})
      : _baseDirProvider = baseDirProvider ?? _defaultBaseDir;

  final Future<Directory> Function() _baseDirProvider;

  static Future<Directory> _defaultBaseDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'VideoCutter'));
  }

  Future<List<EditProjectModel>> readAll() async {
    final file = await _historyFile();
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    if (content.trim().isEmpty) return [];
    final decoded = jsonDecode(content) as List<dynamic>;
    return [
      for (final entry in decoded)
        EditProjectModel.fromJson(entry as Map<String, dynamic>),
    ];
  }

  Future<void> writeAll(List<EditProjectModel> entries) async {
    final file = await _historyFile();
    // Escrita atômica: grava num temporário e troca, para uma queda no meio
    // da gravação nunca corromper o histórico inteiro.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(
      jsonEncode([for (final entry in entries) entry.toJson()]),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await tmp.rename(file.path);
  }

  /// Pasta onde ficam os vídeos das edições (criada se necessário).
  Future<Directory> videosDir() async {
    final base = await _baseDirProvider();
    return Directory(p.join(base.path, 'videos')).create(recursive: true);
  }

  /// Pasta das miniaturas da edição [id] (criada se necessário).
  Future<Directory> thumbsDir(String id) async {
    final base = await _baseDirProvider();
    return Directory(p.join(base.path, 'thumbs', id)).create(recursive: true);
  }

  /// Apaga todas as miniaturas da edição [id] (silencioso se não houver).
  Future<void> deleteThumbs(String id) async {
    final base = await _baseDirProvider();
    final dir = Directory(p.join(base.path, 'thumbs', id));
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } on FileSystemException {
      // Miniaturas são descartáveis: um resquício no disco não é problema.
    }
  }

  Future<File> _historyFile() async {
    final base = await _baseDirProvider();
    await base.create(recursive: true);
    return File(p.join(base.path, 'history.json'));
  }
}
