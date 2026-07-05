/// Estratégia de corte usada na exportação.
enum ExportMode {
  /// Copia os streams sem recodificar: praticamente instantâneo e sem perda
  /// de qualidade, mas o início do corte é ajustado ao keyframe mais próximo
  /// (pode variar 1–2 s).
  fastCopy,

  /// Recodifica o trecho (H.264/AAC): corte exato no tempo pedido, porém
  /// bem mais lento.
  precise,
}
