import '../../domain/entities/video_chapter.dart';

/// `[h:]mm:ss` no começo da linha, título em seguida. Tolera marcador de
/// lista antes ("- ", "• ") e o timestamp entre colchetes ou parênteses.
/// Grupos: horas (opcional), minutos, segundos, título.
final _chapterLine = RegExp(
  r'^(?:[-–—•*]\s*)?[\[\(]?(?:(\d{1,2}):)?(\d{1,2}):(\d{2})[\]\)]?[\s\-–—:•]+(.+)$',
);

/// Extrai capítulos da descrição de um vídeo do YouTube.
///
/// O youtube_explode_dart não expõe capítulos como campo estruturado; a
/// convenção do YouTube é o autor listá-los na descrição, um por linha, com
/// o timestamp antes do título ("0:00 Intro", "1:02:45 Créditos").
///
/// A lista só vale quando há pelo menos dois capítulos e os tempos são
/// estritamente crescentes — qualquer outra coisa é tratada como texto
/// comum e retorna vazio, e o vídeo segue sem capítulos.
List<VideoChapter> parseChaptersFromDescription(String description) {
  final chapters = <VideoChapter>[];
  for (final line in description.split('\n')) {
    final match = _chapterLine.firstMatch(line.trim());
    if (match == null) continue;

    final hasHours = match.group(1) != null;
    final hours = hasHours ? int.parse(match.group(1)!) : 0;
    final minutes = int.parse(match.group(2)!);
    final seconds = int.parse(match.group(3)!);
    // "1:75" é horário quebrado, não capítulo; minutos >59 só valem sem
    // horas ("90:00" = um vídeo de hora e meia sem usar h:mm:ss).
    if (seconds > 59 || (hasHours && minutes > 59)) continue;

    final title = match.group(4)!.trim();
    if (title.isEmpty) continue;

    chapters.add(
      VideoChapter(
        start: Duration(hours: hours, minutes: minutes, seconds: seconds),
        title: title,
      ),
    );
  }

  if (chapters.length < 2) return const [];
  for (var i = 1; i < chapters.length; i++) {
    if (chapters[i].start <= chapters[i - 1].start) return const [];
  }
  return chapters;
}
