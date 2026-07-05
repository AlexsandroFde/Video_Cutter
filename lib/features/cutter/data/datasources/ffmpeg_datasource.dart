import 'dart:async';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/duration_format.dart';
import '../../domain/entities/export_mode.dart';

/// Executa comandos FFmpeg: corte de trechos e junção de streams.
class FfmpegDataSource {
  const FfmpegDataSource();

  /// Recorta o trecho [start]..[end] de [inputPath] para [outputPath].
  ///
  /// [onProgress] recebe o avanço dentro do trecho, de 0 a 1.
  Future<void> cutSegment({
    required String inputPath,
    required String outputPath,
    required Duration start,
    required Duration end,
    required ExportMode mode,
    void Function(double progress)? onProgress,
  }) async {
    final length = end - start;
    // `-ss` antes de `-i` faz seek por keyframe (rápido); com recodificação
    // o corte continua exato porque os frames são decodificados a partir dali.
    final codecArgs = switch (mode) {
      ExportMode.fastCopy => '-c copy -avoid_negative_ts make_zero',
      ExportMode.precise =>
        '-c:v libx264 -preset veryfast -crf 20 -c:a aac -movflags +faststart',
    };
    final command = '-y -ss ${start.ffmpegSeconds} -i "$inputPath" '
        '-t ${length.ffmpegSeconds} $codecArgs "$outputPath"';

    await _run(
      command,
      onTimeMs: length.inMilliseconds == 0 || onProgress == null
          ? null
          : (timeMs) =>
              onProgress((timeMs / length.inMilliseconds).clamp(0.0, 1.0)),
    );
  }

  /// Junta um stream só de vídeo e um só de áudio em um único arquivo.
  ///
  /// Usado para vídeos do YouTube disponíveis apenas em streams adaptativos.
  Future<void> mux({
    required String videoPath,
    required String audioPath,
    required String outputPath,
    bool copyAudio = true,
  }) {
    final audioCodec = copyAudio ? 'copy' : 'aac';
    return _run('-y -i "$videoPath" -i "$audioPath" '
        '-c:v copy -c:a $audioCodec -movflags +faststart "$outputPath"');
  }

  Future<void> _run(String command, {void Function(int timeMs)? onTimeMs}) {
    final completer = Completer<void>();
    FFmpegKit.executeAsync(
      command,
      (session) async {
        final code = await session.getReturnCode();
        if (ReturnCode.isSuccess(code)) {
          completer.complete();
        } else {
          completer.completeError(
            FfmpegException(
              'O FFmpeg terminou com erro (código ${code?.getValue() ?? '?'}).',
            ),
          );
        }
      },
      null,
      onTimeMs == null ? null : (statistics) => onTimeMs(statistics.getTime()),
    );
    return completer.future;
  }
}
