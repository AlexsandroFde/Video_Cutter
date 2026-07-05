import 'package:flutter/material.dart';

import '../../../../core/utils/duration_format.dart';
import '../../domain/entities/video_segment.dart';

/// Item da lista de segmentos: intervalo, duração e controles.
class SegmentTile extends StatelessWidget {
  const SegmentTile({
    super.key,
    required this.index,
    required this.segment,
    required this.color,
    required this.ink,
    required this.onTap,
    required this.onToggle,
    this.onMergeWithPrevious,
  });

  final int index;
  final VideoSegment segment;

  /// Pastel que identifica o segmento (mesmo da timeline).
  final Color color;

  /// Cor de texto sobre [color].
  final Color ink;

  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  /// Remove o corte no início deste segmento; `null` para o primeiro.
  final VoidCallback? onMergeWithPrevious;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;

    return ListTile(
      onTap: onTap,
      tileColor: scheme.surfaceContainerLow,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor:
            segment.enabled ? color : scheme.surfaceContainerHighest,
        child: Text(
          '${index + 1}',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: segment.enabled ? ink : muted,
          ),
        ),
      ),
      title: Text(
        'Parte ${index + 1}',
        style: theme.textTheme.titleMedium?.copyWith(
          color: segment.enabled ? null : muted,
        ),
      ),
      subtitle: Text(
        '${segment.start.label(tenths: true)} – '
        '${segment.end.label(tenths: true)}'
        '  •  ${segment.length.label(tenths: true)}',
        style: theme.textTheme.bodySmall?.copyWith(color: muted),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onMergeWithPrevious != null)
            IconButton(
              tooltip: 'Mesclar com a parte anterior',
              icon: const Icon(Icons.call_merge_rounded),
              onPressed: onMergeWithPrevious,
            ),
          Switch(value: segment.enabled, onChanged: onToggle),
        ],
      ),
    );
  }
}
