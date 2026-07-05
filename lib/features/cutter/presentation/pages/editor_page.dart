import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/duration_format.dart';
import '../../domain/entities/video_media.dart';
import '../controllers/export_controller.dart';
import '../providers.dart';
import '../widgets/export_sheet.dart';
import '../widgets/segment_tile.dart';
import '../widgets/timeline_editor.dart';
import '../widgets/video_preview.dart';

/// Editor: player, timeline de segmentação e lista de partes.
class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({super.key, required this.media});

  final VideoMedia media;

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  late final VideoPlayerController _player;
  bool _initFailed = false;

  @override
  void initState() {
    super.initState();
    _player = VideoPlayerController.file(File(widget.media.filePath));
    _player.initialize().then((_) {
      if (!mounted) return;
      ref
          .read(segmentsControllerProvider.notifier)
          .initialize(_player.value.duration);
      setState(() {});
    }).catchError((Object _) {
      if (mounted) setState(() => _initFailed = true);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _seekBy(Duration offset) {
    final duration = _player.value.duration;
    var target = _player.value.position + offset;
    if (target < Duration.zero) target = Duration.zero;
    if (target > duration) target = duration;
    _player.seekTo(target);
  }

  void _splitAtPlayhead() {
    final ok = ref
        .read(segmentsControllerProvider.notifier)
        .splitAt(_player.value.position);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
          'Não deu para cortar aqui: muito perto de uma divisão existente '
          '(cada parte precisa de pelo menos 0,5 s).',
        ),
      ));
    }
  }

  Future<void> _openExportSheet() async {
    await _player.pause();
    if (!mounted) return;
    // Descarta resultado/erro de uma exportação anterior, mas nunca
    // interrompe uma que ainda esteja em andamento.
    if (ref.read(exportControllerProvider) is! ExportRunning) {
      ref.read(exportControllerProvider.notifier).reset();
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ExportSheet(media: widget.media),
    );
  }

  @override
  Widget build(BuildContext context) {
    final segmentsState = ref.watch(segmentsControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.media.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _initFailed
          ? const _InitError()
          : Column(
              children: [
                Expanded(flex: 5, child: VideoPreview(player: _player)),
                _TransportBar(
                  player: _player,
                  onSeekBy: _seekBy,
                  onSplit: _splitAtPlayhead,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TimelineEditor(player: _player),
                ),
                const SizedBox(height: 4),
                Expanded(
                  flex: 4,
                  child: !segmentsState.isReady
                      ? const SizedBox.shrink()
                      : ListView.builder(
                          itemCount: segmentsState.segments.length,
                          itemBuilder: (context, index) {
                            final segment = segmentsState.segments[index];
                            final controller =
                                ref.read(segmentsControllerProvider.notifier);
                            return SegmentTile(
                              index: index,
                              segment: segment,
                              color: index.isEven
                                  ? scheme.primary
                                  : scheme.tertiary,
                              onTap: () => _player.seekTo(segment.start),
                              onToggle: (_) => controller.toggle(segment.id),
                              onMergeWithPrevious: index == 0
                                  ? null
                                  : () => controller.mergeWithNext(index - 1),
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton.icon(
          style: AppTheme.primaryAction,
          onPressed: segmentsState.isReady && segmentsState.enabledCount > 0
              ? _openExportSheet
              : null,
          icon: const Icon(Icons.save_alt),
          label: Text(
            segmentsState.enabledCount == 1
                ? 'Exportar 1 segmento'
                : 'Exportar ${segmentsState.enabledCount} segmentos',
          ),
        ),
      ),
    );
  }
}

/// Controles de reprodução + botão de dividir no cursor.
class _TransportBar extends StatelessWidget {
  const _TransportBar({
    required this.player,
    required this.onSeekBy,
    required this.onSplit,
  });

  final VideoPlayerController player;
  final void Function(Duration offset) onSeekBy;
  final VoidCallback onSplit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: player,
        builder: (context, value, _) {
          return Row(
            children: [
              IconButton(
                tooltip: 'Voltar 5 s',
                onPressed: () => onSeekBy(const Duration(seconds: -5)),
                icon: const Icon(Icons.replay_5),
              ),
              IconButton.filled(
                tooltip: value.isPlaying ? 'Pausar' : 'Reproduzir',
                onPressed: () =>
                    value.isPlaying ? player.pause() : player.play(),
                icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
              ),
              IconButton(
                tooltip: 'Avançar 5 s',
                onPressed: () => onSeekBy(const Duration(seconds: 5)),
                icon: const Icon(Icons.forward_5),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${value.position.label(tenths: true)} / '
                  '${value.duration.label()}',
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: onSplit,
                icon: const Icon(Icons.content_cut, size: 18),
                label: const Text('Dividir'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InitError extends StatelessWidget {
  const _InitError();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image_outlined,
                size: 56, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              'Não foi possível reproduzir este vídeo.\n'
              'O formato pode não ser suportado pelo aparelho.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
