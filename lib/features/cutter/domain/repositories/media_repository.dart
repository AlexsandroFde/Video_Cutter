import '../entities/video_media.dart';

/// Callback de progresso, de 0 a 1; `null` quando o total é desconhecido.
typedef ProgressCallback = void Function(double? progress);

/// Obtém vídeos de fontes externas e os disponibiliza como arquivo local.
abstract interface class MediaRepository {
  /// Abre o seletor de arquivos do sistema.
  ///
  /// Retorna `null` quando o usuário cancela a seleção.
  Future<VideoMedia?> pickLocalVideo();

  /// Baixa o vídeo de [url] (YouTube) para o armazenamento do app.
  Future<VideoMedia> fetchYoutubeVideo(String url, {ProgressCallback? onProgress});
}
