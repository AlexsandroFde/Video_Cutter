/// Exceções tipadas da aplicação.
///
/// Toda falha esperada é convertida para uma [AppException] na camada de
/// dados, para que a apresentação exiba apenas [message] — nunca erros crus.
sealed class AppException implements Exception {
  const AppException(this.message);

  /// Mensagem amigável, pronta para ser exibida ao usuário.
  final String message;

  @override
  String toString() => message;
}

/// O link informado não é um vídeo válido do YouTube.
final class InvalidYoutubeUrlException extends AppException {
  const InvalidYoutubeUrlException()
      : super('Link do YouTube inválido. Verifique o endereço e tente de novo.');
}

/// Falha ao baixar o vídeo do YouTube.
final class YoutubeDownloadException extends AppException {
  const YoutubeDownloadException([String? details])
      : super(details ?? 'Não foi possível baixar o vídeo do YouTube.');
}

/// Falha ao carregar um vídeo do dispositivo.
final class MediaLoadException extends AppException {
  const MediaLoadException([String? details])
      : super(details ?? 'Não foi possível carregar o vídeo.');
}

/// O FFmpeg terminou com código de erro.
final class FfmpegException extends AppException {
  const FfmpegException([String? details])
      : super(details ?? 'O processamento do vídeo falhou.');
}

/// Falha ao exportar os segmentos.
final class ExportException extends AppException {
  const ExportException([String? details])
      : super(details ?? 'Falha ao exportar os segmentos.');
}

/// Operação inválida no histórico de edições.
final class HistoryException extends AppException {
  const HistoryException([String? details])
      : super(details ?? 'Não foi possível atualizar o histórico.');
}
