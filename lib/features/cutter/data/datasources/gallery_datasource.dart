import 'package:gal/gal.dart';

import '../../../../core/errors/app_exception.dart';

/// Salva vídeos numa pasta pública do aparelho, visível na galeria
/// (`Movies/<álbum>` via MediaStore no Android; app Fotos no iOS).
class GalleryDataSource {
  const GalleryDataSource();

  /// Garante a permissão de escrita; retorna `false` se o usuário negar.
  Future<bool> ensureAccess() async {
    if (await Gal.hasAccess(toAlbum: true)) return true;
    return Gal.requestAccess(toAlbum: true);
  }

  /// Salva o vídeo em [path] no álbum [album].
  Future<void> saveVideo(String path, {required String album}) async {
    try {
      await Gal.putVideo(path, album: album);
    } on GalException catch (e) {
      throw ExportException(switch (e.type) {
        GalExceptionType.accessDenied =>
          'Sem permissão para salvar os vídeos na galeria. '
              'Conceda o acesso nas configurações do app.',
        GalExceptionType.notEnoughSpace =>
          'Sem espaço livre no aparelho para salvar os vídeos.',
        GalExceptionType.notSupportedFormat =>
          'A galeria não aceitou o formato deste vídeo. '
              'Tente exportar no modo Preciso (gera .mp4).',
        GalExceptionType.unexpected =>
          'Não foi possível salvar os vídeos na galeria.',
      });
    }
  }
}
