import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'core.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PromptflowApp());
}

class PromptflowApp extends StatelessWidget {
  const PromptflowApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5B5CE2),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'Promptflow OS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFF7F7FB),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: const WorkspacePage(),
    );
  }
}

class WorkspacePage extends StatefulWidget {
  const WorkspacePage({super.key});

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  final repository = PromptRepository();
  final searchController = TextEditingController();
  final editorController = TextEditingController();
  final runInputController = TextEditingController();
  final projectTitleController = TextEditingController();
  final projectDescriptionController = TextEditingController();

  List<ProjectInfo> projects = [];
  List<AssetRecord> assets = [];
  List<RunRecord> runs = [];
  AssetRecord? selectedAsset;
  String provider = 'Local preview';
  String search = '';
  String? errorMessage;
  bool loading = true;
  bool saving = false;
  int section = 0;

  @override
  void initState() {
    super.initState();
    searchController.addListener(() {
      setState(() => search = searchController.text.trim().toLowerCase());
    });
    _loadWorkspace();
  }

  @override
  void dispose() {
    searchController.dispose();
    editorController.dispose();
    runInputController.dispose();
    projectTitleController.dispose();
    projectDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkspace() async {
    setState(() => loading = true);
    try {
      await repository.init();
      await _reloadFromRepository();
    } catch (error) {
      errorMessage = 'Workspace unavailable: $error';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _reloadFromRepository() async {
    projects = await repository.listProjects();
    assets = await repository.loadAssets();
    runs = await repository.loadRuns();
    if (selectedAsset == null && assets.isNotEmpty) {
      _selectAsset(assets.first);
    } else if (selectedAsset != null) {
      final id = selectedAsset!.id;
      final refreshed = assets.where((asset) => asset.id == id).toList();
      if (refreshed.isNotEmpty) _selectAsset(refreshed.first);
    }
  }

  List<AssetRecord> get filteredAssets {
    if (search.isEmpty) return assets;
    return assets.where((asset) {
      final haystack =
          '${asset.title} ${asset.kind} ${asset.summary} ${asset.content}'
              .toLowerCase();
      return haystack.contains(search);
    }).toList();
  }

  void _selectAsset(AssetRecord asset) {
    selectedAsset = asset;
    editorController.text = asset.content;
  }

  Future<void> _createProject() async {
    projectTitleController.text = 'My Prompt Workspace';
    projectDescriptionController.text =
        'A local-first space for reusable AI work.';
    final created = await showDialog<ProjectInfo>(
      context: context,
      builder: (_) => CreateProjectDialog(
        titleController: projectTitleController,
        descriptionController: projectDescriptionController,
      ),
    );
    if (created == null) return;
    await repository.openProject(created.path);
    await _reloadFromRepository();
    if (mounted) setState(() {});
    _showMessage('Project created: ${created.title}');
  }

  Future<void> _importFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.trim().isEmpty) {
      _showMessage('The clipboard does not contain text.');
      return;
    }
    await _openImport(text, 'Clipboard');
  }

  Future<void> _importFile() async {
    final picked = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['md', 'txt', 'yaml', 'yml', 'json'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    String? text;
    if (file.bytes != null) {
      text = String.fromCharCodes(file.bytes!);
    } else if (file.path != null) {
      text = await File(file.path!).readAsString();
    }
    if (text == null || text.trim().isEmpty) {
      _showMessage('The selected file could not be read.');
      return;
    }
    await _openImport(text, file.name);
  }

  Future<void> _openImport(String raw, String sourceLabel) async {
    final analysis = await repository.analyzeImport(raw, sourceLabel);
    if (!mounted) return;
    final saved = await showModalBottomSheet<AssetRecord>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ImportAdaptationSheet(
        analysis: analysis,
        repository: repository,
        existingAssets: assets,
        projectTitle: projects.isEmpty
            ? 'Current project'
            : projects.first.title,
        provider: provider,
      ),
    );
    if (saved == null) return;
    await _reloadFromRepository();
    _selectAsset(saved);
    if (mounted) setState(() {});
    _showMessage('Saved as a new asset. The original was preserved.');
  }

  Future<void> _saveCurrentAsset() async {
    final asset = selectedAsset;
    if (asset == null) return;
    setState(() => saving = true);
    try {
      await File(asset.path).writeAsString(editorController.text);
      await _reloadFromRepository();
      _showMessage('Saved to the canonical project file.');
    } catch (error) {
      _showMessage('Save failed: $error');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _runCurrentAsset() async {
    final asset = selectedAsset;
    if (asset == null) {
      _showMessage('Select an asset first.');
      return;
    }
    _showMessage('Running…');
    final run = await repository.runAsset(
      asset,
      provider: provider,
      input: runInputController.text,
    );
    await _reloadFromRepository();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          run.status == 'completed' ? 'Run completed' : 'Run needs attention',
        ),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: SelectableText(
              run.output.isEmpty ? (run.error ?? 'Unknown error') : run.output,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _createWorkflow() async {
    if (selectedAsset == null) {
      _showMessage('Select an asset first.');
      return;
    }
    await repository.createWorkflowFromAsset(selectedAsset!);
    _showMessage('Workflow draft created from ${selectedAsset!.title}.');
  }

  Future<void> _openProviderSettings() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const ProviderSettingsDialog(),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: _appBar(wide),
      body: wide ? _desktopLayout() : _mobileLayout(),
    );
  }

  PreferredSizeWidget _appBar(bool wide) {
    return AppBar(
      titleSpacing: 20,
      title: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFF5B5CE2)),
          const SizedBox(width: 10),
          const Text(
            'Promptflow OS',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          if (!wide && projects.isNotEmpty) ...[
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                projects.first.title,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Import file',
          onPressed: _importFile,
          icon: const Icon(Icons.file_open_outlined),
        ),
        IconButton(
          tooltip: 'Paste prompt',
          onPressed: _importFromClipboard,
          icon: const Icon(Icons.content_paste),
        ),
        IconButton(
          tooltip: 'Provider settings',
          onPressed: _openProviderSettings,
          icon: const Icon(Icons.tune),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _desktopLayout() {
    return Row(
      children: [
        SizedBox(width: 272, child: _sidebar()),
        Expanded(
          child: Column(
            children: [
              Expanded(child: _mainSurface()),
              if (errorMessage != null) _errorBanner(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mobileLayout() {
    return Column(
      children: [
        Expanded(child: _mainSurface()),
        NavigationBar(
          selectedIndex: section.clamp(0, 4),
          onDestinationSelected: (value) => setState(() => section = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Home',
            ),
            NavigationDestination(icon: Icon(Icons.search), label: 'Find'),
            NavigationDestination(
              icon: Icon(Icons.account_tree_outlined),
              label: 'Flows',
            ),
            NavigationDestination(icon: Icon(Icons.history), label: 'Runs'),
            NavigationDestination(icon: Icon(Icons.sync), label: 'Sync'),
          ],
        ),
      ],
    );
  }

  Widget _sidebar() {
    final project = projects.isEmpty ? null : projects.first;
    return Container(
      color: const Color(0xFF202038),
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'WORKSPACE',
            style: TextStyle(
              color: Colors.white.withOpacity(.55),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          if (project != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF303052),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 17,
                    backgroundColor: Color(0xFF7475F4),
                    child: Icon(
                      Icons.folder_open,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      project.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 22),
          _navTile(Icons.dashboard_outlined, 'Overview', 0),
          _navTile(Icons.search, 'Find & reuse', 1),
          _navTile(Icons.description_outlined, 'Documents', 2),
          _navTile(Icons.account_tree_outlined, 'Promptflows', 3),
          _navTile(Icons.history, 'Runs & outputs', 4),
          _navTile(Icons.sync, 'Sync center', 5),
          const Spacer(),
          FilledButton.icon(
            onPressed: _createProject,
            icon: const Icon(Icons.add),
            label: const Text('New project'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7475F4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Local-first • files you own',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(.45),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _navTile(IconData icon, String label, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: ListTile(
        selected: section == index,
        selectedTileColor: const Color(0xFF3A3A64),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, color: Colors.white70, size: 20),
        title: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: () => setState(() => section = index),
      ),
    );
  }

  Widget _mainSurface() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showInspector = constraints.maxWidth > 980;
        return Row(
          children: [
            Expanded(child: _content()),
            if (showInspector) SizedBox(width: 340, child: _inspector()),
          ],
        );
      },
    );
  }

  Widget _content() {
    if (section == 3 || section == 4) return _runsView();
    if (section == 5) return _syncView();
    final showHero = section == 0 || section == 1;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHero) _hero(),
          if (section == 0 || section == 1 || section == 2) _searchBar(),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                section == 1
                    ? 'Reuse what you already have'
                    : 'Your reusable assets',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text('${filteredAssets.length} assets'),
            ],
          ),
          const SizedBox(height: 12),
          if (filteredAssets.isEmpty) _emptyState() else _assetList(),
          if (selectedAsset != null && (section == 0 || section == 2)) ...[
            const SizedBox(height: 24),
            _editorCard(),
          ],
        ],
      ),
    );
  }

  Widget _hero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF27274A), Color(0xFF4A4B91)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REUSE BEFORE RECREATE',
            style: TextStyle(
              color: Colors.white.withOpacity(.64),
              letterSpacing: 1.4,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            'Bring useful prompts\ninto your project in seconds.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Paste from the web, import a file, understand what was found, adapt it, turn it into a template, and run it without rewriting from scratch.',
            style: TextStyle(
              color: Colors.white.withOpacity(.76),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _importFromClipboard,
                icon: const Icon(Icons.content_paste),
                label: const Text('Paste prompt'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF30305B),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _importFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('Import file'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: 'Find prompts, templates, context, workflows…',
          suffixIcon: search.isEmpty
              ? null
              : IconButton(
                  onPressed: searchController.clear,
                  icon: const Icon(Icons.clear),
                ),
        ),
      ),
    );
  }

  Widget _assetList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredAssets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) => _assetTile(filteredAssets[index]),
    );
  }

  Widget _assetTile(AssetRecord asset) {
    final selected = selectedAsset?.id == asset.id;
    final color = _kindColor(asset.kind);
    return InkWell(
      onTap: () => setState(() => _selectAsset(asset)),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFECEBFF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF7475F4) : const Color(0xFFE7E7EF),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_kindIcon(asset.kind), color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          asset.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _badge(asset.kind),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    asset.summary.isEmpty
                        ? _preview(asset.content)
                        : asset.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700, height: 1.25),
                  ),
                  if (asset.sourceLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Imported from ${asset.sourceLabel}',
                        style: TextStyle(
                          color: Colors.indigo.shade600,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'adapt')
                  await _openImport(asset.content, asset.title);
                if (value == 'workflow') await _createWorkflow();
                if (value == 'copy') {
                  await Clipboard.setData(ClipboardData(text: asset.content));
                  _showMessage('Prompt copied.');
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'adapt', child: Text('Adapt to project')),
                PopupMenuItem(
                  value: 'workflow',
                  child: Text('Add to workflow'),
                ),
                PopupMenuItem(value: 'copy', child: Text('Copy prompt')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _editorCard() {
    final asset = selectedAsset!;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE7E7EF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit asset',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        asset.title,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                _badge(asset.kind),
                IconButton(
                  tooltip: 'Add to workflow',
                  onPressed: _createWorkflow,
                  icon: const Icon(Icons.account_tree_outlined),
                ),
                IconButton(
                  tooltip: 'Copy',
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: editorController.text),
                    );
                    _showMessage('Prompt copied.');
                  },
                  icon: const Icon(Icons.copy_outlined),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: editorController,
              maxLines: 12,
              minLines: 8,
              decoration: const InputDecoration(
                hintText: 'Write or adapt your prompt…',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: runInputController,
                    decoration: const InputDecoration(
                      labelText: 'Run input',
                      prefixIcon: Icon(Icons.input),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: provider,
                  items: const ['Local preview', 'OpenAI', 'Claude', 'Gemini']
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => provider = value ?? provider),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: saving ? null : _saveCurrentAsset,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(saving ? '…' : 'Save'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _runCurrentAsset,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Run'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _inspector() {
    final asset = selectedAsset;
    if (asset == null) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: const Text(
          'Select an asset to inspect, adapt, reuse, or run it.',
        ),
      );
    }
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      child: ListView(
        children: [
          Text(
            'INSPECTOR',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            asset.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              _badge(asset.kind),
              if (asset.provenanceMode != null) _badge(asset.provenanceMode!),
            ],
          ),
          _inspectorSection(
            'Reuse actions',
            Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.auto_fix_high),
                  title: const Text('Adapt to project'),
                  onTap: () => _openImport(asset.content, asset.title),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.data_object),
                  title: const Text('Convert to template'),
                  onTap: () => _openImport(asset.content, asset.title),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.account_tree_outlined),
                  title: const Text('Add to workflow'),
                  onTap: _createWorkflow,
                ),
              ],
            ),
          ),
          _inspectorSection(
            'Provenance',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.sourceLabel == null
                      ? 'Authored in this workspace'
                      : 'Source: ${asset.sourceLabel}',
                ),
                const SizedBox(height: 6),
                Text(
                  asset.sourceRefs.isEmpty
                      ? 'No composed sources'
                      : '${asset.sourceRefs.length} linked source assets',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  asset.path,
                  style: const TextStyle(fontSize: 11, color: Colors.indigo),
                ),
              ],
            ),
          ),
          _inspectorSection(
            'Storage',
            Text(
              'Canonical Markdown + YAML\nDerived index: .promptworkspace/index.json\nCredentials: native secure storage',
              style: TextStyle(color: Colors.grey.shade700, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inspectorSection(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7E7EF)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.auto_awesome_motion_outlined,
            size: 42,
            color: Color(0xFF7475F4),
          ),
          const SizedBox(height: 10),
          const Text(
            'Nothing here yet — paste something useful.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Import first. Classify and adapt only after the app shows what it found.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _importFromClipboard,
            icon: const Icon(Icons.content_paste),
            label: const Text('Paste prompt'),
          ),
        ],
      ),
    );
  }

  Widget _runsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Runs & outputs',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (runs.isEmpty)
            _simplePanel(
              Icons.history,
              'No runs yet',
              'Select an asset, choose Local preview or a configured API provider, and run it.',
            )
          else
            ...runs.map(_runTile),
        ],
      ),
    );
  }

  Widget _runTile(RunRecord run) {
    final completed = run.status == 'completed';
    return Card(
      elevation: 0,
      child: ListTile(
        leading: Icon(
          completed ? Icons.check_circle : Icons.error,
          color: completed ? Colors.green : Colors.red,
        ),
        title: Text(run.assetTitle),
        subtitle: Text('${run.provider} • ${run.createdAt.toLocal()}'),
        trailing: IconButton(
          icon: const Icon(Icons.open_in_new),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(run.assetTitle),
              content: SingleChildScrollView(
                child: SelectableText(
                  run.output.isEmpty ? (run.error ?? '') : run.output,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _syncView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _simplePanel(
        Icons.sync,
        'Sync center',
        'Projects are stored locally first. Google Drive remains an explicit, recoverable layer around the canonical folder.',
        OutlinedButton.icon(
          onPressed: () => _showMessage(
            'Sync setup is not enabled in this MVP build; local files remain portable.',
          ),
          icon: const Icon(Icons.info_outline),
          label: const Text('View sync status'),
        ),
      ),
    );
  }

  Widget _simplePanel(
    IconData icon,
    String title,
    String description, [
    Widget? action,
  ]) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 36, color: const Color(0xFF7475F4)),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(color: Colors.grey.shade700, height: 1.45),
            ),
            if (action != null)
              Padding(padding: const EdgeInsets.only(top: 16), child: action),
          ],
        ),
      ),
    );
  }

  Widget _errorBanner() => Container(
    color: Colors.amber.shade100,
    width: double.infinity,
    padding: const EdgeInsets.all(8),
    child: Text(errorMessage!),
  );

  Widget _badge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFEDEDF8),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: Color(0xFF45466E),
      ),
    ),
  );
  Color _kindColor(String kind) => kind == 'template'
      ? Colors.orange
      : (kind == 'context'
            ? Colors.teal
            : (kind == 'instruction' ? Colors.pink : Colors.indigo));
  IconData _kindIcon(String kind) => kind == 'template'
      ? Icons.data_object
      : (kind == 'context'
            ? Icons.layers_outlined
            : (kind == 'instruction'
                  ? Icons.rule
                  : Icons.description_outlined));
  String _preview(String content) {
    final value = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    return value.substring(0, value.length.clamp(0, 180));
  }
}

class CreateProjectDialog extends StatelessWidget {
  const CreateProjectDialog({
    super.key,
    required this.titleController,
    required this.descriptionController,
  });
  final TextEditingController titleController;
  final TextEditingController descriptionController;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create a project'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Project name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class ImportAdaptationSheet extends StatefulWidget {
  const ImportAdaptationSheet({
    super.key,
    required this.analysis,
    required this.repository,
    required this.existingAssets,
    required this.projectTitle,
    required this.provider,
  });
  final ImportAnalysis analysis;
  final PromptRepository repository;
  final List<AssetRecord> existingAssets;
  final String projectTitle;
  final String provider;

  @override
  State<ImportAdaptationSheet> createState() => _ImportAdaptationSheetState();
}

class _ImportAdaptationSheetState extends State<ImportAdaptationSheet> {
  String destination = 'prompt';
  String mode = 'as-is';
  bool convertVariables = true;
  bool includeContext = false;
  bool saving = false;
  String? composeId;

  Future<void> _save() async {
    setState(() => saving = true);
    final composeWith = widget.existingAssets
        .where((asset) => asset.id == composeId)
        .toList();
    final asset = await widget.repository.saveImport(
      widget.analysis,
      destinationKind: destination,
      mode: mode,
      convertVariables: convertVariables,
      projectContext: includeContext ? widget.projectTitle : null,
      composeWith: composeWith,
    );
    if (mounted) Navigator.pop(context, asset);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return SafeArea(
      child: SizedBox(
        height: height * .92,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Understand → Adapt → Save'),
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _step(
                  '1',
                  'What was found',
                  'Fast local detection — no metadata required.',
                ),
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.analysis.title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            _confidence(widget.analysis.confidence),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(widget.analysis.objective),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _badge(widget.analysis.suggestedKind),
                            if (widget.analysis.variables.isNotEmpty)
                              _badge(
                                '${widget.analysis.variables.length} variables',
                              ),
                            if (widget.analysis.sections.isNotEmpty)
                              _badge(
                                '${widget.analysis.sections.length} sections',
                              ),
                            if (widget.analysis.providerAssumptions.isNotEmpty)
                              _badge('provider assumptions'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _fact(
                          'Reusable sections',
                          widget.analysis.reusableSections.join(' • '),
                        ),
                        if (widget.analysis.constraints.isNotEmpty)
                          _fact(
                            'Constraints',
                            widget.analysis.constraints.join(' • '),
                          ),
                        if (widget.analysis.missingInformation.isNotEmpty)
                          _fact(
                            'Needs your attention',
                            widget.analysis.missingInformation.join(' • '),
                          ),
                        if (widget.analysis.hardCodedValues.isNotEmpty)
                          _fact(
                            'Hard-coded candidates',
                            widget.analysis.hardCodedValues.join(', '),
                          ),
                      ],
                    ),
                  ),
                ),
                _step(
                  '2',
                  'Choose the smallest useful action',
                  'The original remains preserved in the capture folder.',
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _action('Use as-is', 'as-is', Icons.copy_all_outlined),
                    _action('Adapt to project', 'adapted', Icons.auto_fix_high),
                    _action(
                      'Convert to template',
                      'template',
                      Icons.data_object,
                    ),
                    _action(
                      'Extract components',
                      'extracted',
                      Icons.call_split,
                    ),
                    _action('Combine', 'composed', Icons.merge_type),
                    _action(
                      'Save as context',
                      'context',
                      Icons.layers_outlined,
                    ),
                    _action('Save as instruction', 'instruction', Icons.rule),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: destination,
                  decoration: const InputDecoration(labelText: 'Save as'),
                  items: const [
                    DropdownMenuItem(value: 'prompt', child: Text('Prompt')),
                    DropdownMenuItem(
                      value: 'template',
                      child: Text('Template'),
                    ),
                    DropdownMenuItem(value: 'context', child: Text('Context')),
                    DropdownMenuItem(
                      value: 'instruction',
                      child: Text('Instruction'),
                    ),
                    DropdownMenuItem(
                      value: 'reference',
                      child: Text('Reference'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => destination = value ?? destination),
                ),
                const SizedBox(height: 12),
                if (widget.analysis.variables.isNotEmpty)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: convertVariables,
                    title: const Text(
                      'Convert detected placeholders into {{variables}}',
                    ),
                    subtitle: Text(
                      widget.analysis.variables.map((v) => v.name).join(', '),
                    ),
                    onChanged: (value) =>
                        setState(() => convertVariables = value),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: includeContext,
                  title: const Text('Add current project context marker'),
                  subtitle: const Text(
                    'Only explicit project context is included; no hidden retrieval.',
                  ),
                  onChanged: (value) => setState(() => includeContext = value),
                ),
                if (widget.existingAssets.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: composeId,
                    decoration: const InputDecoration(
                      labelText: 'Combine with an existing asset (optional)',
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('No additional asset'),
                      ),
                      ...widget.existingAssets.map(
                        (asset) => DropdownMenuItem<String>(
                          value: asset.id,
                          child: Text(
                            '${asset.title} • ${asset.kind}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => composeId = value),
                  ),
                ],
                const SizedBox(height: 16),
                _step(
                  '3',
                  'Review before saving',
                  'Provider adaptation is a projection; your canonical asset stays portable.',
                ),
                Card(
                  elevation: 0,
                  color: const Color(0xFFF1F0FF),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.verified_outlined,
                          color: Color(0xFF5B5CE2),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Source: ${widget.analysis.sourceLabel}\nHash: ${widget.analysis.contentHash}\nTarget: ${destination.toUpperCase()} • ${mode.toUpperCase()} • ${widget.provider}',
                            style: const TextStyle(height: 1.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: widget.analysis.raw),
                          );
                          if (context.mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Original copied.')),
                            );
                        },
                        child: const Text('Copy original'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: saving ? null : _save,
                        icon: const Icon(Icons.save),
                        label: Text(
                          saving ? 'Saving…' : 'Save without losing original',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _step(String number, String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: const Color(0xFF5B5CE2),
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _action(String label, String value, IconData icon) => ChoiceChip(
    label: Text(label),
    avatar: Icon(icon, size: 18),
    selected: mode == value,
    onSelected: (_) => setState(() {
      mode = value;
      if (value == 'template') destination = 'template';
      if (value == 'context') destination = 'context';
      if (value == 'instruction') destination = 'instruction';
    }),
  );
  Widget _badge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFE5E4FF),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF44457A),
      ),
    ),
  );
  Widget _confidence(double value) => Text(
    '${(value * 100).round()}% detected',
    style: const TextStyle(
      color: Color(0xFF4A4B91),
      fontWeight: FontWeight.w700,
    ),
  );
  Widget _fact(String title, String value) => Padding(
    padding: const EdgeInsets.only(top: 9),
    child: RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: [
          TextSpan(
            text: '$title: ',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          TextSpan(text: value),
        ],
      ),
    ),
  );
}

class ProviderSettingsDialog extends StatefulWidget {
  const ProviderSettingsDialog({super.key});

  @override
  State<ProviderSettingsDialog> createState() => _ProviderSettingsDialogState();
}

class _ProviderSettingsDialogState extends State<ProviderSettingsDialog> {
  final storage = const FlutterSecureStorage();
  final openai = TextEditingController();
  final anthropic = TextEditingController();
  final gemini = TextEditingController();
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    openai.text = await storage.read(key: 'provider_openai_key') ?? '';
    anthropic.text = await storage.read(key: 'provider_anthropic_key') ?? '';
    gemini.text = await storage.read(key: 'provider_gemini_key') ?? '';
    if (mounted) setState(() => loading = false);
  }

  Future<void> _save() async {
    await storage.write(key: 'provider_openai_key', value: openai.text.trim());
    await storage.write(
      key: 'provider_anthropic_key',
      value: anthropic.text.trim(),
    );
    await storage.write(key: 'provider_gemini_key', value: gemini.text.trim());
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Keys saved in secure device storage.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Provider settings'),
      content: SizedBox(
        width: 480,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  children: [
                    const Text(
                      'Keys stay outside project files, exports, and logs.',
                      style: TextStyle(height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: openai,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'OpenAI API key',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: anthropic,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Anthropic API key',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: gemini,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Gemini API key',
                      ),
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save securely')),
      ],
    );
  }
}
