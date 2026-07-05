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
    required this.onTap,
    required this.onToggle,
    this.onMergeWithPrevious,
  });

  final int index;
  final VideoSegment segment;
  final Color color;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  /// Remove o corte no início deste segmento; `null` para o primeiro.
  final VoidCallback? onMergeWithPrevious;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: segment.enabled
            ? color
            : theme.colorScheme.surfaceContainerHighest,
        child: Text(
          '${index + 1}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: segment.enabled ? theme.colorScheme.onPrimary : muted,
          ),
        ),
      ),
      title: Text(
        'Parte ${index + 1}',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: segment.enabled ? null : muted,
        ),
      ),
      subtitle: Text(
        '${segment.start.label(tenths: true)} – '
        '${segment.end.label(tenths: true)}'
        '  •  ${segment.length.label(tenths: true)}',
        style: TextStyle(color: muted),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onMergeWithPrevious != null)
            IconButton(
              tooltip: 'Mesclar com a parte anterior',
              icon: const Icon(Icons.call_merge),
              onPressed: onMergeWithPrevious,
            ),
          Switch(value: segment.enabled, onChanged: onToggle),
        ],
      ),
    );
  }
}
