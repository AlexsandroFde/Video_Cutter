import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../controllers/media_controller.dart';
import '../providers.dart';
import '../widgets/youtube_url_dialog.dart';
import 'editor_page.dart';

/// Tela inicial: escolhe a origem do vídeo (dispositivo ou YouTube).
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaState = ref.watch(mediaControllerProvider);

    ref.listen(mediaControllerProvider, (_, next) async {
      if (next is! MediaReady) return;
      final navigator = Navigator.of(context);
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => EditorPage(media: next.media),
        ),
      );
      // Ao voltar do editor, limpa tudo para uma nova edição.
      ref.read(mediaControllerProvider.notifier).reset();
      ref.read(segmentsControllerProvider.notifier).clear();
      ref.read(exportControllerProvider.notifier).reset();
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: switch (mediaState) {
                MediaLoading(:final message, :final progress) =>
                  _LoadingView(message: message, progress: progress),
                _ => _SourcePicker(
                    error: switch (mediaState) {
                      MediaFailure(:final message) => message,
                      _ => null,
                    },
                  ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SourcePicker extends ConsumerWidget {
  const _SourcePicker({this.error});

  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(mediaControllerProvider.notifier);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.content_cut, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          'Video Cutter',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Divida um vídeo em vários segmentos\ne exporte todos de uma vez.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 40),
        if (error != null) ...[
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: theme.colorScheme.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      error!,
                      style: TextStyle(
                          color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        FilledButton.icon(
          style: AppTheme.primaryAction,
          onPressed: controller.pickLocalVideo,
          icon: const Icon(Icons.video_library_outlined),
          label: const Text('Escolher vídeo do dispositivo'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: () async {
            final url = await showYoutubeUrlDialog(context);
            if (url != null) await controller.loadFromYoutube(url);
          },
          icon: const Icon(Icons.link),
          label: const Text('Usar link do YouTube'),
        ),
      ],
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.message, this.progress});

  final String message;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message,
            textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
        const SizedBox(height: 24),
        LinearProgressIndicator(value: progress, minHeight: 8),
        if (progress != null) ...[
          const SizedBox(height: 8),
          Text(
            '${(progress! * 100).toStringAsFixed(0)}%',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
