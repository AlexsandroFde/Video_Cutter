import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
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
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: switch (exportState) {
          ExportIdle() => _buildIdle(context),
          ExportRunning(:final current, :final total, :final overall) =>
            _buildRunning(context, current, total, overall),
          ExportSuccess(:final directory, :final files) =>
            _buildSuccess(context, directory, files),
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
        Text('Exportar segmentos', style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        SegmentedButton<ExportMode>(
          segments: const [
            ButtonSegment(
              value: ExportMode.fastCopy,
              icon: Icon(Icons.bolt),
              label: Text('Rápido'),
            ),
            ButtonSegment(
              value: ExportMode.precise,
              icon: Icon(Icons.straighten),
              label: Text('Preciso'),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (selection) =>
              setState(() => _mode = selection.first),
        ),
        const SizedBox(height: 12),
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
        const SizedBox(height: 24),
        FilledButton.icon(
          style: AppTheme.primaryAction,
          onPressed: enabledCount == 0 ? null : _start,
          icon: const Icon(Icons.content_cut),
          label: Text(
            enabledCount == 1
                ? 'Exportar 1 segmento'
                : 'Exportar $enabledCount segmentos',
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
          'Exportando parte $current de $total…',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(value: overall, minHeight: 8),
        const SizedBox(height: 8),
        Text(
          '${(overall * 100).toStringAsFixed(0)}%  —  mantenha o app aberto',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSuccess(
    BuildContext context,
    String directory,
    List<String> files,
  ) {
    final theme = Theme.of(context);
    final controller = ref.read(exportControllerProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.check_circle, size: 56, color: theme.colorScheme.primary),
        const SizedBox(height: 12),
        Text(
          files.length == 1
              ? '1 arquivo gerado'
              : '${files.length} arquivos gerados',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          directory,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: AppTheme.primaryAction,
          onPressed: controller.shareAll,
          icon: const Icon(Icons.share),
          label: const Text('Compartilhar tudo'),
        ),
        const SizedBox(height: 8),
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
        Icon(Icons.error_outline, size: 56, color: theme.colorScheme.error),
        const SizedBox(height: 12),
        Text(message,
            textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
        const SizedBox(height: 24),
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
