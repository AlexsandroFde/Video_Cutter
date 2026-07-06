import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/repositories/thumbnail_repository.dart';
import '../datasources/history_local_datasource.dart';
import '../datasources/thumbnail_datasource.dart';

class ThumbnailRepositoryImpl implements ThumbnailRepository {
  const ThumbnailRepositoryImpl({
    required this._ffmpeg,
    required this._local,
  });

  final ThumbnailDataSource _ffmpeg;
  final HistoryLocalDataSource _local;

  @override
  Future<String?> poster({
    required String id,
    required String videoPath,
    required Duration duration,
  }) async {
    final dir = await _local.thumbsDir(id);
    final file = File(p.join(dir.path, 'poster.jpg'));
    if (await file.exists()) return file.path;

    final ok = await _ffmpeg.extractFrame(
      videoPath: videoPath,
      outputPath: file.path,
      at: _posterAt(duration),
      height: 120,
    );
    return ok && await file.exists() ? file.path : null;
  }

  @override
  Future<List<String>> strip({
    required String id,
    required String videoPath,
    required Duration duration,
  }) async {
    if (duration <= Duration.zero) return const [];
    final count = _stripCount(duration);
    final dir = await _local.thumbsDir(id);

    final paths = <String>[];
    for (var i = 0; i < count; i++) {
      // Nome com a contagem para uma mudança de densidade regenerar limpo.
      final file = File(p.join(dir.path, 'strip_${count}_$i.jpg'));
      if (!await file.exists()) {
        final ok = await _ffmpeg.extractFrame(
          videoPath: videoPath,
          outputPath: file.path,
          // Centro da fatia i, para o quadro representar bem seu trecho.
          at: duration * ((i + 0.5) / count),
          height: 72,
        );
        if (!ok || !await file.exists()) return const [];
      }
      paths.add(file.path);
    }
    return paths;
  }

  /// Um quadro logo no comecinho (mas não o 0, que costuma ser preto), ou o
  /// meio de vídeos muito curtos.
  Duration _posterAt(Duration duration) {
    if (duration <= Duration.zero) return Duration.zero;
    if (duration <= const Duration(seconds: 3)) return duration * 0.35;
    return const Duration(seconds: 1);
  }

  /// Quantidade de quadros da tira: mais para vídeos longos, mas dentro de
  /// um teto para não afogar o FFmpeg nem o disco.
  int _stripCount(Duration duration) =>
      (duration.inSeconds / 6).round().clamp(6, 16);
}
