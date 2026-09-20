import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../database/app_database.dart';
import '../../providers/ai/ai_asset_service.dart';
import 'ai_markdown_style.dart';

class PersonaEditDraft {
  final String name;
  final String systemPrompt;
  final String documentMarkdown;

  const PersonaEditDraft({
    required this.name,
    required this.systemPrompt,
    required this.documentMarkdown,
  });
}

Future<PersonaEditDraft?> showPersonaEditorDialog(
  BuildContext context, {
  required AiPersona persona,
  bool startInEditMode = false,
}) {
  return showDialog<PersonaEditDraft>(
    context: context,
    builder: (_) => _PersonaEditorDialog(
      persona: persona,
      startInEditMode: startInEditMode,
    ),
  );
}

class _PersonaEditorDialog extends StatefulWidget {
  final AiPersona persona;
  final bool startInEditMode;

  const _PersonaEditorDialog({
    required this.persona,
    required this.startInEditMode,
  });

  @override
  State<_PersonaEditorDialog> createState() => _PersonaEditorDialogState();
}

class _PersonaEditorDialogState extends State<_PersonaEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _promptController;
  late final TextEditingController _documentController;
  late bool _editing;

  @override
  void initState() {
    super.initState();
    _editing = widget.startInEditMode;
    _nameController = TextEditingController(text: widget.persona.name);
    _promptController =
        TextEditingController(text: widget.persona.systemPrompt);
    _documentController =
        TextEditingController(text: widget.persona.documentMarkdown);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      title: Row(
        children: [
          Icon(
            widget.persona.type == 'character'
                ? Icons.theater_comedy_rounded
                : Icons.person_rounded,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.persona.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.visibility_outlined, size: 17),
                label: Text('预览'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.edit_outlined, size: 17),
                label: Text('编辑'),
              ),
            ],
            selected: {_editing},
            onSelectionChanged: (selection) {
              setState(() => _editing = selection.first);
            },
          ),
        ],
      ),
      content: SizedBox(
        width: 680,
        height: (size.height * 0.68).clamp(320.0, 720.0).toDouble(),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: _editing ? _buildEditor() : _buildPreview(theme),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
        if (_editing)
          FilledButton.icon(
            key: const Key('persona-editor-save'),
            onPressed: _submit,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('保存修改'),
          ),
      ],
    );
  }

  Widget _buildPreview(ThemeData theme) {
    final document = _documentController.text.trim();
    final prompt = _promptController.text.trim();
    return Column(
      key: const ValueKey('persona-preview'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              avatar: const Icon(Icons.badge_outlined, size: 16),
              label: Text(
                widget.persona.type == 'character' ? '角色人格' : '自定义人格',
              ),
            ),
            if (widget.persona.characterName?.trim().isNotEmpty == true)
              Chip(label: Text('角色：${widget.persona.characterName}')),
          ],
        ),
        if (prompt.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('系统提示词', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(prompt),
          ),
        ],
        const SizedBox(height: 12),
        Text('人格文档', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: document.isEmpty
                ? const Center(child: Text('暂无人格文档'))
                : Markdown(
                    data: document,
                    padding: const EdgeInsets.all(14),
                    selectable: true,
                    styleSheet: aiMarkdownStyleSheet(theme),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditor() {
    return Form(
      key: _formKey,
      child: ListView(
        key: const ValueKey('persona-edit'),
        children: [
          TextFormField(
            controller: _nameController,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: '人格名称',
              prefixIcon: Icon(Icons.label_outline),
            ),
            validator: (value) =>
                value == null || value.trim().isEmpty ? '请输入人格名称' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _promptController,
            minLines: 3,
            maxLines: 7,
            decoration: const InputDecoration(
              labelText: '系统提示词',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _documentController,
            minLines: 10,
            maxLines: 22,
            maxLength: AIAssetService.maxImportedMarkdownChars,
            decoration: const InputDecoration(
              labelText: '人格 Markdown 文档',
              alignLabelWithHint: true,
              helperText: '可直接修改生成的人格设定和示例语气',
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final prompt = _promptController.text.trim();
    final document = _documentController.text.trim();
    if (prompt.isEmpty && document.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('系统提示词和人格文档不能同时为空')),
      );
      return;
    }
    Navigator.pop(
      context,
      PersonaEditDraft(
        name: _nameController.text.trim(),
        systemPrompt: prompt,
        documentMarkdown: document,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _promptController.dispose();
    _documentController.dispose();
    super.dispose();
  }
}
