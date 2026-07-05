/// Converte [input] em um nome de arquivo seguro em qualquer plataforma.
String sanitizeFileName(String input, {int maxLength = 60}) {
  var name = input
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (name.length > maxLength) {
    name = name.substring(0, maxLength).trim();
  }
  return name.isEmpty ? 'video' : name;
}
