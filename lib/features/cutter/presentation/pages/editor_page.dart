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
import '../../domain/entities/video_segment.dart';
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

  /// Corte cuja reprodução para no fim (toque na parte). Avulso: termina
  /// sozinho ao chegar lá ou quando o cursor sai do trecho.
  int? _previewSegmentId;

  /// Corte "fixado": enquanto houver foco, a reprodução fica presa a ele.
  int? _focusedSegmentId;

  /// O player só atualiza a posição a cada ~500 ms — pouco para parar no
  /// fim de um corte de 0,5 s. Este timer consulta a posição real.
  Timer? _regionTicker;
  bool _checkingRegion = false;

  @override
  void initState() {
    super.initState();
    _player = VideoPlayerController.file(File(widget.project.videoPath));
    _player
        .initialize()
        .then((_) {
          if (!mounted) return;
          final duration = _player.value.duration;
          final segments = ref.read(segmentsControllerProvider.notifier);
          if (widget.project.segments.isEmpty) {
            segments.initialize(duration);
          } else {
            segments.restore(duration, widget.project.segments);
          }
          setState(() {});
        })
        .catchError((Object _) {
          if (mounted) setState(() => _initFailed = true);
        });
    _player.addListener(_onPlayerValue);
    _regionTicker = Timer.periodic(
      const Duration(milliseconds: 80),
      (_) => _enforceRegionEnd(),
    );
  }

  @override
  void dispose() {
    // Alteração ainda no debounce não pode se perder ao sair.
    if (_saveDebounce?.isActive ?? false) {
      _saveDebounce!.cancel();
      _persistEditState();
    }
    _regionTicker?.cancel();
    _player.removeListener(_onPlayerValue);
    _player.dispose();
    super.dispose();
  }

  /// Trecho que limita a reprodução agora: o preview avulso ou o foco.
  VideoSegment? get _playbackRegion =>
      _segmentById(_previewSegmentId) ?? _segmentById(_focusedSegmentId);

  VideoSegment? _segmentById(int? id) {
    if (id == null) return null;
    final segments = ref.read(segmentsControllerProvider).segments;
    for (final segment in segments) {
      if (segment.id == id) return segment;
    }
    return null;
  }

  /// Encerra o preview avulso quando o cursor sai do trecho (seek manual).
  void _onPlayerValue() {
    final previewId = _previewSegmentId;
    if (previewId == null) return;
    final preview = _segmentById(previewId);
    if (preview == null) {
      _previewSegmentId = null; // parte deixou de existir (mesclada)
      return;
    }
    // Folga maior que o intervalo de atualização do player, para não
    // cancelar por atraso na posição durante a reprodução.
    const slack = Duration(milliseconds: 700);
    final position = _player.value.position;
    if (position < preview.start - slack || position > preview.end + slack) {
      _previewSegmentId = null;
    }
  }

  /// Pausa exatamente no fim do trecho ativo enquanto estiver tocando.
  Future<void> _enforceRegionEnd() async {
    if (_checkingRegion || !mounted || !_player.value.isPlaying) return;
    final region = _playbackRegion;
    if (region == null) return;
    _checkingRegion = true;
    try {
      final position = await _player.position;
      if (!mounted || position == null || !_player.value.isPlaying) return;
      if (position >= region.end) {
        _previewSegmentId = null;
        await _player.pause();
        await _player.seekTo(region.end);
      }
    } finally {
      _checkingRegion = false;
    }
  }

  /// Pula para o início do corte e reproduz só até o fim dele.
  Future<void> _previewSegment(VideoSegment segment) async {
    HapticFeedback.selectionClick();
    // A região só é (re)ativada depois do salto, para o limitador não
    // reagir à posição antiga do cursor.
    _previewSegmentId = null;
    final transferFocus =
        _focusedSegmentId != null && _focusedSegmentId != segment.id;
    if (transferFocus) setState(() => _focusedSegmentId = null);
    await _player.seekTo(segment.start);
    if (!mounted) return;
    _previewSegmentId = segment.id;
    // Com foco ativo, tocar em outra parte transfere o foco para ela.
    if (transferFocus) setState(() => _focusedSegmentId = segment.id);
    await _player.play();
  }

  /// Fixa (ou solta) a reprodução no corte. Ao fixar com o cursor fora do
  /// trecho, pula para o início dele.
  Future<void> _toggleFocus(VideoSegment segment) async {
    HapticFeedback.selectionClick();
    final focusing = _focusedSegmentId != segment.id;
    if (focusing) {
      final position = _player.value.position;
      if (position < segment.start || position > segment.end) {
        await _player.seekTo(segment.start);
        if (!mounted) return;
      }
    }
    setState(() {
      _focusedSegmentId = focusing ? segment.id : null;
      _previewSegmentId = null;
    });
  }

  Future<void> _togglePlayPause() async {
    if (_player.value.isPlaying) {
      await _player.pause();
      return;
    }
    const nearEnd = Duration(milliseconds: 80);
    final region = _playbackRegion;
    final position = _player.value.position;
    if (region != null) {
      // Fora do trecho (ou parado no fim dele), recomeça do início dele.
      if (position < region.start || position >= region.end - nearEnd) {
        await _player.seekTo(region.start);
      }
    } else if (_player.value.duration > Duration.zero &&
        position >= _player.value.duration - nearEnd) {
      await _player.seekTo(Duration.zero);
    }
    await _player.play();
  }

  void _persistEditState() {
    final segmentsState = ref.read(segmentsControllerProvider);
    if (!segmentsState.isReady) return;
    ref
        .read(historyControllerProvider.notifier)
        .saveEditState(
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não deu para cortar aqui: muito perto de uma divisão existente '
            '(cada parte precisa de pelo menos 0,5 s).',
          ),
        ),
      );
    }
  }

  /// Recorta o vídeo seguindo os capítulos que ele trouxe do YouTube.
  /// Substitui os cortes atuais, mas é um passo normal de undo.
  void _applyChapters() {
    HapticFeedback.lightImpact();
    final created = ref
        .read(segmentsControllerProvider.notifier)
        .applyChapters(widget.project.chapters);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          created > 0
              ? 'Prontinho! O vídeo virou $created pedacinhos, '
                    'seguindo os capítulos.'
              : 'Não deu para usar os capítulos: eles ficam fora da '
                    'duração deste vídeo.',
        ),
      ),
    );
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
        forceMaterialTransparency: true,
        title: Text(
          widget.project.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Desfazer',
            onPressed: segmentsState.canUndo
                ? () {
                    HapticFeedback.lightImpact();
                    ref.read(segmentsControllerProvider.notifier).undo();
                  }
                : null,
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: 'Refazer',
            onPressed: segmentsState.canRedo
                ? () {
                    HapticFeedback.lightImpact();
                    ref.read(segmentsControllerProvider.notifier).redo();
                  }
                : null,
            icon: const Icon(Icons.redo_rounded),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: _initFailed
          ? const _InitError()
          : Column(
              children: [
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
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
                  onPlayPause: _togglePlayPause,
                  onSeekBy: _seekBy,
                  onSplit: _splitAtPlayhead,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: TimelineEditor(
                    player: _player,
                    videoId: widget.project.id,
                    videoPath: widget.project.videoPath,
                    focusedSegmentId: _focusedSegmentId,
                    onClearFocus: () =>
                        setState(() => _focusedSegmentId = null),
                  ),
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
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (segmentsState.isReady &&
                    widget.project.chapters.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.xs,
                    ),
                    child: _ChaptersBanner(
                      count: widget.project.chapters.length,
                      onApply: _applyChapters,
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
                            final controller = ref.read(
                              segmentsControllerProvider.notifier,
                            );
                            return SegmentTile(
                              index: index,
                              segment: segment,
                              color: cutter.segmentColor(index),
                              ink: cutter.segmentInk,
                              focused: segment.id == _focusedSegmentId,
                              onTap: () => _previewSegment(segment),
                              onToggle: (_) => controller.toggle(segment.id),
                              onFocusToggle: () => _toggleFocus(segment),
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

/// Convite para cortar o vídeo pelos capítulos que ele trouxe do YouTube.
class _ChaptersBanner extends StatelessWidget {
  const _ChaptersBanner({required this.count, required this.onApply});

  final int count;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onContainer = theme.colorScheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, size: 20, color: onContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Este vídeo veio com $count capítulos do YouTube!',
              style: theme.textTheme.bodyMedium?.copyWith(color: onContainer),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          TextButton(
            onPressed: onApply,
            child: const Text('Usar capítulos'),
          ),
        ],
      ),
    );
  }
}

/// Controles de reprodução + botão de dividir no cursor.
class _TransportBar extends StatelessWidget {
  const _TransportBar({
    required this.player,
    required this.onPlayPause,
    required this.onSeekBy,
    required this.onSplit,
  });

  final VideoPlayerController player;

  /// Alternar play/pause fica com a página, que respeita o corte em foco.
  final VoidCallback onPlayPause;

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
                onPressed: onPlayPause,
                icon: Icon(
                  value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
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
            Icon(
              Icons.heart_broken_rounded,
              size: 56,
              color: theme.colorScheme.error,
            ),
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
