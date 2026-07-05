import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
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
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: AnimatedSwitcher(
                duration: AppMotion.normal,
                switchInCurve: AppMotion.ease,
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
        const _AppBadge(),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Video Cutter',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Corte um vídeo em pedacinhos\ne compartilhe tudo de uma vez 💕',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xxl),
        if (error != null) ...[
          _ErrorBanner(message: error!),
          const SizedBox(height: AppSpacing.lg),
        ],
        _SourceCard(
          icon: Icons.video_library_rounded,
          title: 'Do meu aparelho',
          subtitle: 'Escolher um vídeo da galeria ou dos arquivos',
          onTap: controller.pickLocalVideo,
        ),
        const SizedBox(height: AppSpacing.md),
        _SourceCard(
          icon: Icons.play_circle_rounded,
          title: 'Do YouTube',
          subtitle: 'Colar o link de um vídeo para baixar',
          onTap: () async {
            final url = await showYoutubeUrlDialog(context);
            if (url != null) await controller.loadFromYoutube(url);
          },
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          'feito com ♥ para minha noiva Rebeka',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

/// Símbolo do app: tesourinha num quadrado degradê com um coração no canto.
class _AppBadge extends StatelessWidget {
  const _AppBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [scheme.primary, scheme.tertiary],
                ),
                borderRadius: BorderRadius.circular(AppRadii.xl),
              ),
              child: Icon(Icons.content_cut_rounded,
                  size: 40, color: scheme.onPrimary),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.favorite_rounded,
                    size: 18, color: scheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card de origem: ícone em chip degradê, título, descrição e chevron.
class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Icon(icon, color: scheme.onPrimaryContainer, size: 28),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
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
        const _PulsingHeart(),
        const SizedBox(height: AppSpacing.xl),
        Text(message,
            textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'isso pode levar um minutinho ☁️',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xl),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: LinearProgressIndicator(value: progress, minHeight: 10),
        ),
        if (progress != null) ...[
          const SizedBox(height: AppSpacing.sm),
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

/// Coração que pulsa devagarinho enquanto o vídeo carrega.
class _PulsingHeart extends StatefulWidget {
  const _PulsingHeart();

  @override
  State<_PulsingHeart> createState() => _PulsingHeartState();
}

class _PulsingHeartState extends State<_PulsingHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _scale = Tween(begin: 0.9, end: 1.1).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Icon(
        Icons.favorite_rounded,
        size: 64,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
