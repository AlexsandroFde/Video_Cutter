import 'package:flutter/services.dart';
import 'package:gal/gal.dart';

import '../../../../core/errors/app_exception.dart';

/// Salva mídia em pastas públicas do aparelho: vídeos em `Movies/<álbum>`
/// (gal/MediaStore; app Fotos no iOS) e áudios em `Music/<álbum>` por um
/// canal nativo próprio — o gal não cobre a coleção de áudio.
class GalleryDataSource {
  const GalleryDataSource();

  static const _mediaStoreChannel = MethodChannel('video_cutter/media_store');

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

  /// Salva o áudio em [path] na pasta `Music/[album]` (Android).
  Future<void> saveAudio(String path, {required String album}) async {
    try {
      await _mediaStoreChannel.invokeMethod<void>(
        'saveAudio',
        {'path': path, 'album': album},
      );
    } on MissingPluginException {
      throw const ExportException(
        'Exportar MP3 só está disponível no Android por enquanto.',
      );
    } on PlatformException {
      throw const ExportException(
        'Não foi possível salvar o áudio na pasta Música.',
      );
    }
  }
}
