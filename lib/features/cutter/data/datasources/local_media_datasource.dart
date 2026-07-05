import 'package:file_picker/file_picker.dart';

/// Acesso a vídeos do dispositivo através do seletor de arquivos do sistema.
class LocalMediaDataSource {
  const LocalMediaDataSource();

  /// Abre o seletor e retorna caminho + nome do vídeo escolhido, ou `null`
  /// se o usuário cancelar.
  Future<({String path, String name})?> pickVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    final file = result?.files.single;
    final path = file?.path;
    if (file == null || path == null) return null;
    return (path: path, name: file.name);
  }
}
