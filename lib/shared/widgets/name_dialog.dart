import 'package:flutter/material.dart';

/// Asks for a name, with [message] above the field when given. Returns it
/// trimmed, or null when cancelled. With [allowEmpty], an empty name comes
/// back as '' rather than keeping the dialog open. [maxLength] caps the
/// name, in characters.
Future<String?> askName(
  BuildContext context, {
  required String title,
  required String action,
  String initial = '',
  String? message,
  bool allowEmpty = false,
  int? maxLength,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(
      title: title,
      action: action,
      initial: initial,
      message: message,
      allowEmpty: allowEmpty,
      maxLength: maxLength,
    ),
  );
}

class _NameDialog extends StatefulWidget {
  final String title;
  final String action;
  final String initial;
  final String? message;
  final bool allowEmpty;
  final int? maxLength;

  const _NameDialog({
    required this.title,
    required this.action,
    required this.initial,
    this.message,
    this.allowEmpty = false,
    this.maxLength,
  });

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _name = TextEditingController(
    text: widget.maxLength != null && widget.initial.length > widget.maxLength!
        ? widget.initial.substring(0, widget.maxLength!)
        : widget.initial,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isNotEmpty || widget.allowEmpty) Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      key: const Key('nameDialogField'),
      controller: _name,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
      maxLength: widget.maxLength,
      decoration: const InputDecoration(labelText: 'Name'),
      onSubmitted: (_) => _submit(),
    );
    return AlertDialog(
      title: Text(widget.title),
      content: widget.message == null
          ? field
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(widget.message!), const SizedBox(height: 12), field],
            ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: Text(widget.action)),
      ],
    );
  }
}
