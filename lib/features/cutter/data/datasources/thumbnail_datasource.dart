import 'dart:async';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import '../../../../core/utils/duration_format.dart';

/// Extrai quadros do vídeo com o FFmpeg, para as miniaturas da timeline e
/// do histórico.
class ThumbnailDataSource {
  const ThumbnailDataSource();

  /// Salva em [outputPath] um único quadro do instante [at], redimensionado
  /// para [height] px de altura (largura proporcional). Retorna `true` no
  /// sucesso; erros do FFmpeg viram `false` para a UI cair no ícone.
  ///
  /// `-ss` antes de `-i` faz seek por keyframe (rápido), o suficiente para
  /// uma miniatura — não precisa ser o quadro exato.
  Future<bool> extractFrame({
    required String videoPath,
    required String outputPath,
    required Duration at,
    int height = 96,
  }) {
    // scale=-2 mantém a proporção e garante largura par (exigência do JPEG).
    final command = '-y -ss ${at.ffmpegSeconds} -i "$videoPath" '
        '-frames:v 1 -vf "scale=-2:$height" -q:v 5 "$outputPath"';
    return _run(command);
  }

  Future<bool> _run(String command) {
    final completer = Completer<bool>();
    FFmpegKit.executeAsync(command, (session) async {
      final code = await session.getReturnCode();
      completer.complete(ReturnCode.isSuccess(code));
    });
    return completer.future;
  }
}
