import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../database/app_database.dart';
import '../../providers/ai/ai_http.dart';
import '../../providers/database_provider.dart';
import '../../widgets/glass_container.dart';

enum _AssetAction { export, delete }

class AiAssetsPage extends ConsumerStatefulWidget {
  const AiAssetsPage({super.key});

  @override
  ConsumerState<AiAssetsPage> createState() => _AiAssetsPageState();
}

class _AiAssetsPageState extends ConsumerState<AiAssetsPage> {
  int _reload = 0;

  void _refresh() {
    if (!mounted) return;
    setState(() => _reload++);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: stableSurfaceColor(context),
        appBar: AppBar(
          title: const Text('AI 扩展'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Skills'),
              Tab(text: '人格'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SkillsTab(reload: _reload, onChanged: _refresh),
            _PersonasTab(reload: _reload, onChanged: _refresh),
          ],
        ),
      ),
    );
  }
}

class _SkillsTab extends ConsumerStatefulWidget {
  final int reload;
  final VoidCallback onChanged;

  const _SkillsTab({
    required this.reload,
    required this.onChanged,
  });

  @override
  ConsumerState<_SkillsTab> createState() => _SkillsTabState();
}

class _SkillsTabState extends ConsumerState<_SkillsTab> {
  final _busySkillIds = <int>{};
  final _confirmingSkillIds = <int>{};
  late Future<List<AiSkill>> _skillsFuture;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _skillsFuture = ref.read(aiServiceProvider).getSkills();
  }

  @override
  void didUpdateWidget(covariant _SkillsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reload != widget.reload) {
      _skillsFuture = ref.read(aiServiceProvider).getSkills();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AiSkill>>(
      future: _skillsFuture,
      builder: (context, snapshot) {
        final skills = snapshot.data ?? const <AiSkill>[];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton.icon(
              onPressed: _importing ? null : _importSkill,
              icon: _importing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(_importing ? '正在导入' : '导入 Skill Markdown'),
            ),
            const SizedBox(height: 12),
            if (snapshot.connectionState != ConnectionState.done &&
                !snapshot.hasData)
              const Center(child: CircularProgressIndicator())
            else if (snapshot.hasError)
              _AssetLoadError(
                title: 'Skill 加载失败',
                error: snapshot.error!,
                onRetry: widget.onChanged,
              )
            else if (skills.isEmpty)
              const ListTile(
                leading: Icon(Icons.extension_outlined),
                title: Text('暂无 Skill'),
                subtitle: Text('导入 Markdown 后，启用的 Skill 会作为额外提示词注入 Agent。'),
              )
            else
              for (final skill in skills) _buildSkillCard(skill),
          ],
        );
      },
    );
  }

  Widget _buildSkillCard(AiSkill skill) {
    final busy = _busySkillIds.contains(skill.id);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.extension_outlined),
        title: Text(skill.name),
        subtitle: Text(
          skill.description.isEmpty ? skill.contentMarkdown : skill.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: SizedBox(
          width: 108,
          child: busy
              ? const Center(
                  child: SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Switch(
                      value: skill.enabled,
                      onChanged: (value) => _setSkillEnabled(skill, value),
                    ),
                    PopupMenuButton<_AssetAction>(
                      tooltip: '更多 Skill 操作',
                      onSelected: (action) {
                        switch (action) {
                          case _AssetAction.export:
                            _exportSkill(skill);
                            break;
                          case _AssetAction.delete:
                            _confirmAndDeleteSkill(skill);
                            break;
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: _AssetAction.export,
                          child: Row(
                            children: [
                              Icon(Icons.ios_share, size: 20),
                              SizedBox(width: 12),
                              Text('导出 Skill'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: _AssetAction.delete,
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 20),
                              SizedBox(width: 12),
                              Text('删除 Skill'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _importSkill() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final file = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['md', 'markdown', 'txt'],
      );
      final path = file?.files.single.path;
      if (path == null) return;
      final assetService = ref.read(aiAssetServiceProvider);
      final selectedFile = File(path);
      assetService.validateImportFileSize(await selectedFile.length());
      final markdown = await selectedFile.readAsString();
      await assetService.importSkillMarkdown(markdown);
      if (!mounted) return;
      widget.onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Skill 已导入')),
      );
    } catch (error) {
      if (!mounted) return;
      _showAssetError(context, '导入 Skill 失败', error);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _exportSkill(AiSkill skill) async {
    if (!_startSkillOperation(skill.id)) return;
    try {
      final markdown = ref.read(aiAssetServiceProvider).exportSkillMarkdown(
            skill,
          );
      final dir = await getTemporaryDirectory();
      final safeName = skill.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File(p.join(dir.path, '$safeName.skill.md'));
      await file.writeAsString(markdown);
      await Share.shareXFiles([XFile(file.path)], text: '${skill.name} Skill');
    } catch (error) {
      if (!mounted) return;
      _showAssetError(context, '导出 Skill 失败', error);
    } finally {
      _finishSkillOperation(skill.id);
    }
  }

  Future<void> _confirmAndDeleteSkill(AiSkill skill) async {
    if (!_confirmingSkillIds.add(skill.id)) return;
    try {
      final confirmed = await _confirmDelete(
        context,
        title: '删除 Skill',
        message: '确定删除“${skill.name}”吗？此操作不可撤销。',
      );
      if (!confirmed || !mounted) return;
      if (!_startSkillOperation(skill.id)) return;
      try {
        await ref.read(aiServiceProvider).deleteSkill(skill.id);
        if (!mounted) return;
        widget.onChanged();
      } catch (error) {
        if (!mounted) return;
        _showAssetError(context, '删除 Skill 失败', error);
      } finally {
        _finishSkillOperation(skill.id);
      }
    } finally {
      _confirmingSkillIds.remove(skill.id);
    }
  }

  Future<void> _setSkillEnabled(
    AiSkill skill,
    bool enabled,
  ) async {
    if (!_startSkillOperation(skill.id)) return;
    try {
      await ref.read(aiServiceProvider).setSkillEnabled(skill.id, enabled);
      if (!mounted) return;
      widget.onChanged();
    } catch (error) {
      if (!mounted) return;
      _showAssetError(context, '更新 Skill 状态失败', error);
    } finally {
      _finishSkillOperation(skill.id);
    }
  }

  bool _startSkillOperation(int id) {
    if (_busySkillIds.contains(id)) return false;
    setState(() => _busySkillIds.add(id));
    return true;
  }

  void _finishSkillOperation(int id) {
    if (!mounted || !_busySkillIds.contains(id)) return;
    setState(() => _busySkillIds.remove(id));
  }
}

class _PersonasTab extends ConsumerStatefulWidget {
  final int reload;
  final VoidCallback onChanged;

  const _PersonasTab({
    required this.reload,
    required this.onChanged,
  });

  @override
  ConsumerState<_PersonasTab> createState() => _PersonasTabState();
}

class _PersonasTabState extends ConsumerState<_PersonasTab> {
  final _busyPersonaIds = <int>{};
  final _confirmingPersonaIds = <int>{};
  late Future<List<AiPersona>> _personasFuture;
  bool _personaDialogOpen = false;
  bool _creating = false;
  bool _importing = false;

  bool get _topActionBusy => _creating || _importing;

  @override
  void initState() {
    super.initState();
    _personasFuture = ref.read(aiServiceProvider).getPersonas();
  }

  @override
  void didUpdateWidget(covariant _PersonasTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reload != widget.reload) {
      _personasFuture = ref.read(aiServiceProvider).getPersonas();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AiPersona>>(
      future: _personasFuture,
      builder: (context, snapshot) {
        final personas = snapshot.data ?? const <AiPersona>[];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _topActionBusy ? null : _createPersona,
                    icon: _creating
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add),
                    label: Text(_creating ? '正在创建' : '新建人格'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _topActionBusy ? null : _importPersona,
                    icon: _importing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file),
                    label: Text(_importing ? '正在导入' : '导入'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (snapshot.connectionState != ConnectionState.done &&
                !snapshot.hasData)
              const Center(child: CircularProgressIndicator())
            else if (snapshot.hasError)
              _AssetLoadError(
                title: '人格加载失败',
                error: snapshot.error!,
                onRetry: widget.onChanged,
              )
            else if (personas.isEmpty)
              const ListTile(
                leading: Icon(Icons.person_outline),
                title: Text('暂无人格'),
                subtitle: Text('可以手动创建系统提示词人格，或导入 Markdown 人格文档。'),
              )
            else
              for (final persona in personas) _buildPersonaCard(persona),
          ],
        );
      },
    );
  }

  Widget _buildPersonaCard(AiPersona persona) {
    final busy = _busyPersonaIds.contains(persona.id);
    return Card(
      child: ListTile(
        leading: Icon(persona.type == 'character'
            ? Icons.theater_comedy
            : Icons.person_outline),
        title: Text(persona.name),
        subtitle: Text(
          persona.characterName ?? persona.type,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: SizedBox.square(
          dimension: 48,
          child: busy
              ? const Center(
                  child: SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : PopupMenuButton<_AssetAction>(
                  tooltip: '更多人格操作',
                  onSelected: (action) {
                    switch (action) {
                      case _AssetAction.export:
                        _exportPersona(persona);
                        break;
                      case _AssetAction.delete:
                        _confirmAndDeletePersona(persona);
                        break;
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _AssetAction.export,
                      child: Row(
                        children: [
                          Icon(Icons.ios_share, size: 20),
                          SizedBox(width: 12),
                          Text('导出人格'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: _AssetAction.delete,
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 20),
                          SizedBox(width: 12),
                          Text('删除人格'),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _createPersona() async {
    if (_topActionBusy || _personaDialogOpen) return;
    _personaDialogOpen = true;
    try {
      final draft = await showDialog<({String name, String prompt})>(
        context: context,
        builder: (_) => const _CustomPersonaDialog(),
      );
      if (draft == null || !mounted) return;
      setState(() => _creating = true);
      await ref.read(aiAssetServiceProvider).createCustomPersona(
            name: draft.name,
            systemPrompt: draft.prompt,
          );
      if (!mounted) return;
      widget.onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('人格已创建')),
      );
    } catch (error) {
      if (!mounted) return;
      _showAssetError(context, '创建人格失败', error);
    } finally {
      _personaDialogOpen = false;
      if (mounted && _creating) setState(() => _creating = false);
    }
  }

  Future<void> _importPersona() async {
    if (_topActionBusy) return;
    setState(() => _importing = true);
    try {
      final file = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['md', 'markdown', 'txt'],
      );
      final path = file?.files.single.path;
      if (path == null) return;
      final assetService = ref.read(aiAssetServiceProvider);
      final selectedFile = File(path);
      assetService.validateImportFileSize(await selectedFile.length());
      final markdown = await selectedFile.readAsString();
      await assetService.importPersonaMarkdown(markdown);
      if (!mounted) return;
      widget.onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('人格已导入')),
      );
    } catch (error) {
      if (!mounted) return;
      _showAssetError(context, '导入人格失败', error);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _exportPersona(AiPersona persona) async {
    if (!_startPersonaOperation(persona.id)) return;
    try {
      final markdown = ref.read(aiAssetServiceProvider).exportPersonaMarkdown(
            persona,
          );
      final dir = await getTemporaryDirectory();
      final safeName = persona.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File(p.join(dir.path, '$safeName.md'));
      await file.writeAsString(markdown);
      await Share.shareXFiles([XFile(file.path)], text: '${persona.name} 人格');
    } catch (error) {
      if (!mounted) return;
      _showAssetError(context, '导出人格失败', error);
    } finally {
      _finishPersonaOperation(persona.id);
    }
  }

  Future<void> _confirmAndDeletePersona(AiPersona persona) async {
    if (!_confirmingPersonaIds.add(persona.id)) return;
    try {
      final confirmed = await _confirmDelete(
        context,
        title: '删除人格',
        message: '确定删除“${persona.name}”吗？此操作不可撤销。',
      );
      if (!confirmed || !mounted) return;
      if (!_startPersonaOperation(persona.id)) return;
      try {
        await ref.read(aiServiceProvider).deletePersona(persona.id);
        if (!mounted) return;
        widget.onChanged();
      } catch (error) {
        if (!mounted) return;
        _showAssetError(context, '删除人格失败', error);
      } finally {
        _finishPersonaOperation(persona.id);
      }
    } finally {
      _confirmingPersonaIds.remove(persona.id);
    }
  }

  bool _startPersonaOperation(int id) {
    if (_busyPersonaIds.contains(id)) return false;
    setState(() => _busyPersonaIds.add(id));
    return true;
  }

  void _finishPersonaOperation(int id) {
    if (!mounted || !_busyPersonaIds.contains(id)) return;
    setState(() => _busyPersonaIds.remove(id));
  }
}

class _CustomPersonaDialog extends StatefulWidget {
  const _CustomPersonaDialog();

  @override
  State<_CustomPersonaDialog> createState() => _CustomPersonaDialogState();
}

class _CustomPersonaDialogState extends State<_CustomPersonaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _promptController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新建人格'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                maxLength: 100,
                decoration: const InputDecoration(labelText: '名称'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入人格名称' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _promptController,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(labelText: '系统提示词'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入系统提示词' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      (
        name: _nameController.text.trim(),
        prompt: _promptController.text.trim(),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _promptController.dispose();
    super.dispose();
  }
}

class _AssetLoadError extends StatelessWidget {
  final String title;
  final Object error;
  final VoidCallback onRetry;

  const _AssetLoadError({
    required this.title,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        Icons.error_outline,
        color: Theme.of(context).colorScheme.error,
      ),
      title: Text(title),
      subtitle: Text(
        describeAIError(error),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        tooltip: '重试加载',
      ),
    );
  }
}

void _showAssetError(BuildContext context, String action, Object error) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$action：${describeAIError(error)}')),
  );
}

Future<bool> _confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('删除'),
            ),
          ],
        ),
      ) ??
      false;
}
