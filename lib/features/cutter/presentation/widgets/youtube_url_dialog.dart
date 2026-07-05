import 'package:flutter/material.dart';

/// Pede um link do YouTube; retorna a URL digitada ou `null` se cancelado.
Future<String?> showYoutubeUrlDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => const _YoutubeUrlDialog(),
  );
}

class _YoutubeUrlDialog extends StatefulWidget {
  const _YoutubeUrlDialog();

  @override
  State<_YoutubeUrlDialog> createState() => _YoutubeUrlDialogState();
}

class _YoutubeUrlDialogState extends State<_YoutubeUrlDialog> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(
      () => setState(() => _hasText = _controller.text.trim().isNotEmpty),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Link do YouTube'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _hasText ? _submit() : null,
            decoration: const InputDecoration(
              hintText: 'https://youtube.com/watch?v=…',
              prefixIcon: Icon(Icons.link_rounded),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cole o endereço do vídeo que você quer cortar 🎬',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 40)),
          onPressed: _hasText ? _submit : null,
          child: const Text('Baixar'),
        ),
      ],
    );
  }
}
