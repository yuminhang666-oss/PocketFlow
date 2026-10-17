import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NoteEditor extends StatefulWidget {
  const NoteEditor({super.key, required this.initialNote});
  final String initialNote;
  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late final _controller = TextEditingController(text: widget.initialNote);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('添加备注', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            inputFormatters: [_CodeUnitLimitFormatter(500)],
            decoration: const InputDecoration(hintText: '例如：食堂午餐（选填）'),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, child) =>
                Text('${value.text.length}/500', textAlign: TextAlign.end),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context, _controller.text),
            child: const Text('完成'),
          ),
        ],
      ),
    ),
  );
}

/// v1 uses UTF-16 code units. Reject a whole edit instead of splitting emoji.
class _CodeUnitLimitFormatter extends TextInputFormatter {
  _CodeUnitLimitFormatter(this.limit);
  final int limit;
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.text.length <= limit ? newValue : oldValue;
}
