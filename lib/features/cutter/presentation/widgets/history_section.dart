import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/cutter_colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/friendly_date.dart';
import '../../domain/entities/edit_project.dart';
import '../../domain/entities/video_media.dart';
import '../providers.dart';

/// Lista "Suas edições": abrir, renomear e excluir projetos do histórico.
class HistorySection extends ConsumerWidget {
  const HistorySection({super.key, required this.onOpen});

  final void Function(EditProject project) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final history = ref.watch(historyControllerProvider);

    return switch (history) {
      AsyncData(:final value) when value.isEmpty => const SizedBox.shrink(),
      AsyncData(:final value) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Row(
                children: [
                  Text('Suas edições', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  Text(
                    '${value.length}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final (index, project) in value.indexed) ...[
              _HistoryTile(project: project, index: index, onOpen: onOpen),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      AsyncError() => Text(
          'Não deu para carregar o histórico.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.error),
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

/// Miniatura do cartão: o quadro-pôster do vídeo, com o ícone colorido
/// como espera (enquanto gera) e como reserva (se falhar).
class _ProjectThumb extends ConsumerWidget {
  const _ProjectThumb({required this.project, required this.index});

  final EditProject project;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cutter = Theme.of(context).extension<CutterColors>()!;
    final poster = ref.watch(
      posterProvider((
        id: project.id,
        videoPath: project.videoPath,
        durationMs: project.duration.inMilliseconds,
      )),
    );

    Widget fallback() => Container(
          alignment: Alignment.center,
          color: cutter.segmentColor(index),
          child: Icon(
            project.origin == MediaOrigin.youtube
                ? Icons.play_circle_rounded
                : Icons.movie_rounded,
            color: cutter.segmentInk,
          ),
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: SizedBox(
        width: 56,
        height: 44,
        child: switch (poster) {
          AsyncData(:final String value) => Image.file(
              File(value),
              width: 56,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback(),
            ),
          _ => fallback(),
        },
      ),
    );
  }
}

enum _TileAction { rename, delete }

class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({
    required this.project,
    required this.index,
    required this.onOpen,
  });

  final EditProject project;
  final int index;
  final void Function(EditProject project) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final parts = project.segments.length;
    final partsLabel = switch (parts) {
      0 => 'ainda sem cortes',
      1 => '1 pedacinho',
      _ => '$parts pedacinhos',
    };

    return Card(
      child: ListTile(
        onTap: () => onOpen(project),
        leading: _ProjectThumb(project: project, index: index),
        title: Text(
          project.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Text(
          '$partsLabel • ${friendlyDateTime(project.updatedAt)}',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        trailing: PopupMenuButton<_TileAction>(
          tooltip: 'Opções',
          onSelected: (action) => switch (action) {
            _TileAction.rename => _rename(context, ref),
            _TileAction.delete => _confirmDelete(context, ref),
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: _TileAction.rename,
              child: ListTile(
                leading: Icon(Icons.edit_rounded),
                title: Text('Renomear'),
              ),
            ),
            PopupMenuItem(
              value: _TileAction.delete,
              child: ListTile(
                leading: Icon(Icons.delete_outline_rounded),
                title: Text('Excluir'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) {
    return showDialog<void>(
      context: context,
      builder: (_) => _RenameDialog(project: project),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir "${project.name}"?'),
        content: const Text(
          'O vídeo e os cortes salvos no histórico serão removidos. '
          'Os pedacinhos já baixados na galeria continuam lá.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(historyControllerProvider.notifier).delete(project.id);
    }
  }
}

class _RenameDialog extends ConsumerStatefulWidget {
  const _RenameDialog({required this.project});

  final EditProject project;

  @override
  ConsumerState<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends ConsumerState<_RenameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.project.name);
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(historyControllerProvider.notifier)
          .rename(widget.project.id, _controller.text);
      if (mounted) Navigator.of(context).pop();
    } on AppException catch (e) {
      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Renomear edição'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: 'Nome da edição',
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
