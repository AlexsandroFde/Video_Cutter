import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/file_name.dart';
import 'ffmpeg_datasource.dart';

/// Baixa vídeos do YouTube para um arquivo local.
class YoutubeDataSource {
  const YoutubeDataSource(this._ffmpeg);

  final FfmpegDataSource _ffmpeg;

  /// Baixa o vídeo de [url] para [targetDir] e retorna caminho + título.
  ///
  /// Prefere streams muxed (áudio+vídeo juntos). Quando o YouTube só oferece
  /// streams adaptativos — o caso comum acima de 360p —, baixa vídeo e áudio
  /// separados e junta com FFmpeg sem recodificar.
  Future<({String filePath, String title})> download(
    String url,
    Directory targetDir, {
    void Function(double? progress)? onProgress,
  }) async {
    final yt = YoutubeExplode();
    try {
      final Video video;
      try {
        video = await yt.videos.get(url);
      } on ArgumentError {
        throw const InvalidYoutubeUrlException();
      } on FormatException {
        throw const InvalidYoutubeUrlException();
      }

      final manifest = await yt.videos.streamsClient.getManifest(video.id);
      final outputPath = p.join(
        targetDir.path,
        '${sanitizeFileName(video.title)}'
        '_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );

      if (manifest.muxed.isNotEmpty) {
        final stream = manifest.muxed.withHighestBitrate();
        await _saveStream(yt, stream, File(outputPath), onProgress);
      } else {
        await _downloadAdaptive(yt, manifest, outputPath, onProgress);
      }
      return (filePath: outputPath, title: video.title);
    } on AppException {
      rethrow;
    } on YoutubeExplodeException catch (e) {
      throw YoutubeDownloadException(e.message);
    } on SocketException {
      throw const YoutubeDownloadException(
        'Sem conexão com a internet. Verifique a rede e tente de novo.',
      );
    } finally {
      yt.close();
    }
  }

  /// Baixa os melhores streams de vídeo e áudio separados e os junta.
  Future<void> _downloadAdaptive(
    YoutubeExplode yt,
    StreamManifest manifest,
    String outputPath,
    void Function(double? progress)? onProgress,
  ) async {
    if (manifest.videoOnly.isEmpty || manifest.audioOnly.isEmpty) {
      throw const YoutubeDownloadException(
        'Este vídeo não tem streams disponíveis para download.',
      );
    }

    // Streams mp4 permitem juntar com `-c copy` (sem recodificar). Se o
    // áudio só existir em outro container (webm/opus), recodifica para AAC.
    final mp4Videos =
        manifest.videoOnly.where((s) => s.container.name == 'mp4').toList();
    final mp4Audios =
        manifest.audioOnly.where((s) => s.container.name == 'mp4').toList();
    final videoStream =
        (mp4Videos.isEmpty ? manifest.videoOnly.toList() : mp4Videos)
            .bestQuality;
    final audioStream = (mp4Audios.isEmpty ? manifest.audioOnly : mp4Audios)
        .withHighestBitrate();

    final dir = p.dirname(outputPath);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final videoFile = File(p.join(dir, '.yt_video_$stamp.tmp'));
    final audioFile = File(p.join(dir, '.yt_audio_$stamp.tmp'));

    final totalBytes =
        videoStream.size.totalBytes + audioStream.size.totalBytes;
    var receivedBytes = 0;
    void onChunk(int length) {
      receivedBytes += length;
      if (totalBytes > 0) onProgress?.call(receivedBytes / totalBytes);
    }

    try {
      await _saveStream(yt, videoStream, videoFile, null, onChunk: onChunk);
      await _saveStream(yt, audioStream, audioFile, null, onChunk: onChunk);
      await _ffmpeg.mux(
        videoPath: videoFile.path,
        audioPath: audioFile.path,
        outputPath: outputPath,
        copyAudio: mp4Audios.isNotEmpty,
      );
    } finally {
      for (final file in [videoFile, audioFile]) {
        if (await file.exists()) await file.delete();
      }
    }
  }

  Future<void> _saveStream(
    YoutubeExplode yt,
    StreamInfo info,
    File target,
    void Function(double? progress)? onProgress, {
    void Function(int chunkLength)? onChunk,
  }) async {
    final totalBytes = info.size.totalBytes;
    var receivedBytes = 0;
    final sink = target.openWrite();
    try {
      await for (final chunk in yt.videos.streamsClient.get(info)) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        onChunk?.call(chunk.length);
        if (totalBytes > 0) onProgress?.call(receivedBytes / totalBytes);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }
}
