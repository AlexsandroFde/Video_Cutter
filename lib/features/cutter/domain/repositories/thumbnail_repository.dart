/// Geração e cache das miniaturas de uma edição.
///
/// Os quadros são extraídos uma vez e guardados em disco (na pasta da
/// edição), então reabrir o editor ou rolar o histórico não recomeça o
/// trabalho do FFmpeg.
abstract interface class ThumbnailRepository {
  /// Um quadro representativo da edição [id], para o cartão do histórico.
  /// Retorna o caminho do arquivo, ou `null` se não foi possível gerar.
  Future<String?> poster({
    required String id,
    required String videoPath,
    required Duration duration,
  });

  /// Uma tira de quadros igualmente espaçados ao longo de [duration], para
  /// o fundo da trilha da timeline. Da esquerda para a direita; pode vir
  /// vazia se o vídeo ainda não tem duração conhecida ou o FFmpeg falhou.
  Future<List<String>> strip({
    required String id,
    required String videoPath,
    required Duration duration,
  });
}
