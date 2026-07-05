import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/design/app_theme.dart';
import '../../../../core/design/cutter_colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/utils/duration_format.dart';
import '../../domain/entities/edit_project.dart';
import '../controllers/export_controller.dart';
import '../providers.dart';
import '../widgets/export_sheet.dart';
import '../widgets/segment_tile.dart';
import '../widgets/timeline_editor.dart';
import '../widgets/video_preview.dart';

/// Editor: player, timeline de segmentação e lista de partes.
///
/// Toda alteração nos cortes é salva no histórico automaticamente
/// (com debounce), então dá para sair e retomar a edição depois.
class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({super.key, required this.project});

  final EditProject project;

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  static const _saveDebounceDelay = Duration(milliseconds: 600);

  late final VideoPlayerController _player;
  bool _initFailed = false;
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _player = VideoPlayerController.file(File(widget.project.videoPath));
    _player.initialize().then((_) {
      if (!mounted) return;
      final duration = _player.value.duration;
      final segments = ref.read(segmentsControllerProvider.notifier);
      if (widget.project.segments.isEmpty) {
        segments.initialize(duration);
      } else {
        segments.restore(duration, widget.project.segments);
      }
      setState(() {});
    }).catchError((Object _) {
      if (mounted) setState(() => _initFailed = true);
    });
  }

  @override
  void dispose() {
    // Alteração ainda no debounce não pode se perder ao sair.
    if (_saveDebounce?.isActive ?? false) {
      _saveDebounce!.cancel();
      _persistEditState();
    }
    _player.dispose();
    super.dispose();
  }

  void _persistEditState() {
    final segmentsState = ref.read(segmentsControllerProvider);
    if (!segmentsState.isReady) return;
    ref.read(historyControllerProvider.notifier).saveEditState(
          widget.project.id,
          duration: segmentsState.duration,
          segments: segmentsState.segments,
        );
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
    if (ok) {
      HapticFeedback.lightImpact();
    } else {
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
      isScrollControlled: true,
      builder: (_) => ExportSheet(media: widget.project.media),
    );
  }

  @override
  Widget build(BuildContext context) {
    final segmentsState = ref.watch(segmentsControllerProvider);
    final theme = Theme.of(context);
    final cutter = theme.extension<CutterColors>()!;

    // Auto-save: qualquer mudança nos cortes vai para o histórico.
    ref.listen(segmentsControllerProvider, (_, next) {
      if (!next.isReady) return;
      _saveDebounce?.cancel();
      _saveDebounce = Timer(_saveDebounceDelay, _persistEditState);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.project.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _initFailed
          ? const _InitError()
          : Column(
              children: [
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      child: ColoredBox(
                        color: Colors.black,
                        child: SizedBox.expand(
                          child: VideoPreview(player: _player),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _TransportBar(
                  player: _player,
                  onSeekBy: _seekBy,
                  onSplit: _splitAtPlayhead,
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: TimelineEditor(player: _player),
                ),
                if (segmentsState.isReady)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.md,
                      AppSpacing.xl,
                      AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        Text('Pedacinhos', style: theme.textTheme.titleMedium),
                        const Spacer(),
                        Text(
                          '${segmentsState.enabledCount} de '
                          '${segmentsState.segments.length} na exportação',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  flex: 4,
                  child: !segmentsState.isReady
                      ? const SizedBox.shrink()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.xs,
                            AppSpacing.lg,
                            AppSpacing.lg,
                          ),
                          itemCount: segmentsState.segments.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final segment = segmentsState.segments[index];
                            final controller =
                                ref.read(segmentsControllerProvider.notifier);
                            return SegmentTile(
                              index: index,
                              segment: segment,
                              color: cutter.segmentColor(index),
                              ink: cutter.segmentInk,
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
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: FilledButton.icon(
          style: AppTheme.primaryAction,
          onPressed: segmentsState.isReady && segmentsState.enabledCount > 0
              ? _openExportSheet
              : null,
          icon: const Icon(Icons.ios_share_rounded),
          label: Text(
            segmentsState.enabledCount == 1
                ? 'Exportar 1 pedacinho'
                : 'Exportar ${segmentsState.enabledCount} pedacinhos',
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: player,
        builder: (context, value, _) {
          return Row(
            children: [
              IconButton(
                tooltip: 'Voltar 5 s',
                onPressed: () => onSeekBy(const Duration(seconds: -5)),
                icon: const Icon(Icons.replay_5_rounded),
              ),
              IconButton.filled(
                tooltip: value.isPlaying ? 'Pausar' : 'Reproduzir',
                iconSize: 28,
                onPressed: () =>
                    value.isPlaying ? player.pause() : player.play(),
                icon: Icon(value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded),
              ),
              IconButton(
                tooltip: 'Avançar 5 s',
                onPressed: () => onSeekBy(const Duration(seconds: 5)),
                icon: const Icon(Icons.forward_5_rounded),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Text(
                    '${value.position.label(tenths: true)} / '
                    '${value.duration.label()}',
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.tonalIcon(
                onPressed: onSplit,
                icon: const Icon(Icons.content_cut_rounded, size: 18),
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
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.heart_broken_rounded,
                size: 56, color: theme.colorScheme.error),
            const SizedBox(height: AppSpacing.md),
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
