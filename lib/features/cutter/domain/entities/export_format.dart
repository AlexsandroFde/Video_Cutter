/// O que sai da exportação de cada segmento.
enum ExportFormat {
  /// O trecho completo, com vídeo e áudio.
  video,

  /// Só o áudio do trecho, em MP3 (sempre recodificado, corte exato).
  mp3,
}
