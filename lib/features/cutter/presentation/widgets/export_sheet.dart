import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_theme.dart';
import '../../../../core/design/tokens.dart';
import '../../domain/entities/export_format.dart';
import '../../domain/entities/export_mode.dart';
import '../../domain/entities/video_media.dart';
import '../controllers/export_controller.dart';
import '../providers.dart';

/// Bottom sheet de exportação: escolha do modo, progresso e compartilhamento.
class ExportSheet extends ConsumerStatefulWidget {
  const ExportSheet({super.key, required this.media});

  final VideoMedia media;

  @override
  ConsumerState<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<ExportSheet> {
  /// Nome exibido da pasta pública (mantido igual ao usado na exportação).
  static const _albumLabel = 'Video Cutter';

  ExportMode _mode = ExportMode.fastCopy;
  ExportFormat _format = ExportFormat.video;

  /// O canal de MediaStore de áudio só existe no Android.
  bool get _mp3Available => defaultTargetPlatform == TargetPlatform.android;

  void _start() {
    final segments = ref.read(segmentsControllerProvider).segments;
    ref.read(exportControllerProvider.notifier).start(
          media: widget.media,
          segments: segments,
          mode: _mode,
          format: _format,
        );
  }

  @override
  Widget build(BuildContext context) {
    final exportState = ref.watch(exportControllerProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: AnimatedSize(
        duration: AppMotion.normal,
        curve: AppMotion.ease,
        child: switch (exportState) {
          ExportIdle() => _buildIdle(context),
          ExportRunning(:final current, :final total, :final overall) =>
            _buildRunning(context, current, total, overall),
          ExportPublishing(:final current, :final total, :final overall) =>
            _buildPublishing(context, current, total, overall),
          ExportSuccess(:final album, :final count, :final format) =>
            _buildSuccess(context, album, count, format),
          ExportFailure(:final message) => _buildFailure(context, message),
        },
      ),
    );
  }

  Widget _buildIdle(BuildContext context) {
    final theme = Theme.of(context);
    final enabledCount = ref.watch(
      segmentsControllerProvider.select((s) => s.enabledCount),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Exportar pedacinhos', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.lg),
        if (_mp3Available) ...[
          SegmentedButton<ExportFormat>(
            segments: const [
              ButtonSegment(
                value: ExportFormat.video,
                icon: Icon(Icons.movie_rounded),
                label: Text('Vídeo'),
              ),
              ButtonSegment(
                value: ExportFormat.mp3,
                icon: Icon(Icons.music_note_rounded),
                label: Text('Só o áudio (MP3)'),
              ),
            ],
            selected: {_format},
            onSelectionChanged: (selection) =>
                setState(() => _format = selection.first),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (_format == ExportFormat.video) ...[
          SegmentedButton<ExportMode>(
            segments: const [
              ButtonSegment(
                value: ExportMode.fastCopy,
                icon: Icon(Icons.bolt_rounded),
                label: Text('Rápido'),
              ),
              ButtonSegment(
                value: ExportMode.precise,
                icon: Icon(Icons.straighten_rounded),
                label: Text('Preciso'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) =>
                setState(() => _mode = selection.first),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(
          switch ((_format, _mode)) {
            (ExportFormat.mp3, _) =>
              'Extrai só o áudio de cada pedacinho, em MP3, com corte '
                  'exato. Os arquivos vão para a pasta Música.',
            (_, ExportMode.fastCopy) =>
              'Sem recodificar: quase instantâneo e sem perda de qualidade. '
                  'O início de cada corte é ajustado ao keyframe mais '
                  'próximo (pode variar 1–2 s).',
            (_, ExportMode.precise) =>
              'Recodifica cada trecho (H.264/AAC): corte exato no tempo '
                  'marcado, porém bem mais demorado.',
          },
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton.icon(
          style: AppTheme.primaryAction,
          onPressed: enabledCount == 0 ? null : _start,
          icon: const Icon(Icons.content_cut_rounded),
          label: Text(
            enabledCount == 1
                ? 'Exportar 1 pedacinho'
                : 'Exportar $enabledCount pedacinhos',
          ),
        ),
      ],
    );
  }

  Widget _buildRunning(
    BuildContext context,
    int current,
    int total,
    double overall,
  ) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _LovingLine(phrases: _runningPhrases),
        const SizedBox(height: AppSpacing.lg),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: LinearProgressIndicator(value: overall, minHeight: 10),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Parte $current de $total  •  ${(overall * 100).toStringAsFixed(0)}%'
          '  —  mantenha o app aberto',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  /// Frases fofas que se revezam enquanto os cortes são feitos.
  static const _runningPhrases = [
    'quase lá, meu bem',
    'preparando tudo com carinho',
    'cuidando de cada pedacinho',
    'só mais um pouquinho, meu amor',
    'fazendo com todo o meu amor 💖',
    'já já fica pronto, viu?',
  ];

  /// Frases da etapa de salvar na galeria.
  static const _publishingPhrases = [
    'guardando com carinho',
    'colocando tudo no lugarzinho',
    'quase pronto, meu amor',
  ];

  Widget _buildPublishing(
    BuildContext context,
    int current,
    int total,
    double overall,
  ) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _LovingLine(phrases: _publishingPhrases),
        const SizedBox(height: AppSpacing.lg),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: LinearProgressIndicator(value: overall, minHeight: 10),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Salvando o pedacinho $current de $total em '
          '"${_ExportSheetState._albumLabel}"',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _buildSuccess(
    BuildContext context,
    String album,
    int count,
    ExportFormat format,
  ) {
    final theme = Theme.of(context);
    final controller = ref.read(exportControllerProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _CelebrationHeart(),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Prontinho! 💖',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          count == 1
              ? '1 pedacinho baixado na pasta "$album"'
              : '$count pedacinhos baixados na pasta "$album"',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          switch (format) {
            ExportFormat.video => 'Já dá para ver tudo na sua galeria',
            ExportFormat.mp3 => 'Já dá para ouvir tudo na pasta Música',
          },
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton.icon(
          style: AppTheme.primaryAction,
          onPressed: () {
            controller.reset();
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.check_rounded),
          label: const Text('Concluir'),
        ),
      ],
    );
  }

  Widget _buildFailure(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.heart_broken_rounded,
            size: 56, color: theme.colorScheme.error),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Ops… algo deu errado',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(message,
            textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          style: AppTheme.primaryAction,
          onPressed: () =>
              ref.read(exportControllerProvider.notifier).reset(),
          child: const Text('Tentar de novo'),
        ),
      ],
    );
  }
}

/// Frase carinhosa que se troca sozinha durante a espera, com um fade
/// suave — dá a sensação de alguém torcendo do outro lado.
class _LovingLine extends StatefulWidget {
  const _LovingLine({required this.phrases});

  final List<String> phrases;

  @override
  State<_LovingLine> createState() => _LovingLineState();
}

class _LovingLineState extends State<_LovingLine> {
  static const _interval = Duration(seconds: 3);

  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_interval, (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % widget.phrases.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedSwitcher(
      duration: AppMotion.normal,
      switchInCurve: AppMotion.ease,
      switchOutCurve: AppMotion.ease,
      child: Text(
        widget.phrases[_index],
        key: ValueKey(_index),
        style: theme.textTheme.titleMedium,
      ),
    );
  }
}

/// Coração que entra "quicando" quando a exportação termina.
class _CelebrationHeart extends StatelessWidget {
  const _CelebrationHeart();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.slow,
      curve: AppMotion.bouncy,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.favorite_rounded,
            size: 40, color: scheme.onPrimaryContainer),
      ),
    );
  }
}
