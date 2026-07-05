import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/utils/duration_format.dart';
import '../../domain/entities/video_segment.dart';

/// Item da lista de segmentos: intervalo, duração e controles.
///
/// Tocar no item dá um preview do corte (pula para o começo e para no fim);
/// o pino fixa a reprodução nele.
class SegmentTile extends StatelessWidget {
  const SegmentTile({
    super.key,
    required this.index,
    required this.segment,
    required this.color,
    required this.ink,
    required this.focused,
    required this.onTap,
    required this.onToggle,
    required this.onFocusToggle,
    this.onMergeWithPrevious,
  });

  final int index;
  final VideoSegment segment;

  /// Pastel que identifica o segmento (mesmo da timeline).
  final Color color;

  /// Cor de texto sobre [color].
  final Color ink;

  /// Reprodução fixada neste corte (pino ativo).
  final bool focused;

  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onFocusToggle;

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
      shape: focused
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
              side: BorderSide(color: scheme.primary, width: 1.5),
            )
          : null,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: segment.enabled
            ? color
            : scheme.surfaceContainerHighest,
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
          IconButton(
            tooltip: focused
                ? 'Tirar do foco'
                : 'Manter em foco (reproduz só esta parte)',
            visualDensity: VisualDensity.compact,
            color: focused ? scheme.primary : muted,
            icon: Icon(
              focused ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            ),
            onPressed: onFocusToggle,
          ),
          if (onMergeWithPrevious != null)
            IconButton(
              tooltip: 'Mesclar com a parte anterior',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.call_merge_rounded),
              onPressed: onMergeWithPrevious,
            ),
          Switch(value: segment.enabled, onChanged: onToggle),
        ],
      ),
    );
  }
}
