import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_theme.dart';
import '../../../../core/design/tokens.dart';
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

  void _start() {
    final segments = ref.read(segmentsControllerProvider).segments;
    ref.read(exportControllerProvider.notifier).start(
          media: widget.media,
          segments: segments,
          mode: _mode,
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
          ExportSuccess(:final album, :final files) =>
            _buildSuccess(context, album, files),
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
        Text(
          switch (_mode) {
            ExportMode.fastCopy =>
              'Sem recodificar: quase instantâneo e sem perda de qualidade. '
                  'O início de cada corte é ajustado ao keyframe mais '
                  'próximo (pode variar 1–2 s).',
            ExportMode.precise =>
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
        Text(
          'Cortando parte $current de $total… ✂️',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: LinearProgressIndicator(value: overall, minHeight: 10),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${(overall * 100).toStringAsFixed(0)}%  —  mantenha o app aberto',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

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
        Text(
          'Guardando na pastinha… 💾',
          style: theme.textTheme.titleMedium,
        ),
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
    List<String> files,
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
          files.length == 1
              ? '1 pedacinho salvo na pasta "$album"'
              : '${files.length} pedacinhos salvos na pasta "$album"',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Já dá para ver tudo na sua galeria 🎀',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton.icon(
          style: AppTheme.primaryAction,
          onPressed: controller.shareAll,
          icon: const Icon(Icons.share_rounded),
          label: const Text('Compartilhar tudo'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: () {
            controller.reset();
            Navigator.of(context).pop();
          },
          child: const Text('Concluir'),
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
