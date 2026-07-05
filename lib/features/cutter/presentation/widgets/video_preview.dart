import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Área de reprodução do vídeo, centralizada e com proporção preservada.
class VideoPreview extends StatelessWidget {
  const VideoPreview({super.key, required this.player});

  final VideoPlayerController player;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: player,
      builder: (context, value, _) {
        if (!value.isInitialized) {
          return const Center(child: CircularProgressIndicator());
        }
        return Center(
          child: AspectRatio(
            aspectRatio: value.aspectRatio,
            child: VideoPlayer(player),
          ),
        );
      },
    );
  }
}
