import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart';

class ProjectInfo {
  ProjectInfo({
    required this.id,
    required this.title,
    required this.slug,
    required this.path,
    this.description = '',
  });
  final String id;
  final String title;
  final String slug;
  final String path;
  final String description;
}

class AssetRecord {
  AssetRecord({
    required this.id,
    required this.kind,
    required this.title,
    required this.path,
    required this.content,
    this.summary = '',
    this.tags = const [],
    this.sourceLabel,
    this.sourceRefs = const [],
    this.variables = const [],
    this.provenanceMode,
  });

  final String id;
  final String kind;
  final String title;
  final String path;
  final String content;
  final String summary;
  final List<String> tags;
  final String? sourceLabel;
  final List<String> sourceRefs;
  final List<VariableCandidate> variables;
  final String? provenanceMode;

  AssetRecord copyWith({
    String? kind,
    String? title,
    String? content,
    String? provenanceMode,
    List<String>? sourceRefs,
  }) {
    return AssetRecord(
      id: id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      path: path,
      content: content ?? this.content,
      summary: summary,
      tags: tags,
      sourceLabel: sourceLabel,
      sourceRefs: sourceRefs ?? this.sourceRefs,
      variables: variables,
      provenanceMode: provenanceMode ?? this.provenanceMode,
    );
  }
}

class VariableCandidate {
  VariableCandidate({
    required this.name,
    required this.original,
    this.type = 'string',
    this.required = false,
    this.defaultValue = '',
    this.confidence = 0.8,
  });
  final String name;
  final String original;
  final String type;
  final bool required;
  final String defaultValue;
  final double confidence;
}

class ImportAnalysis {
  ImportAnalysis({
    required this.raw,
    required this.sourceLabel,
    required this.suggestedKind,
    required this.title,
    required this.objective,
    required this.variables,
    required this.sections,
    required this.constraints,
    required this.dependencies,
    required this.missingInformation,
    required this.hardCodedValues,
    required this.providerAssumptions,
    required this.reusableSections,
    required this.confidence,
    required this.contentHash,
  });

  final String raw;
  final String sourceLabel;
  final String suggestedKind;
  final String title;
  final String objective;
  final List<VariableCandidate> variables;
  final List<String> sections;
  final List<String> constraints;
  final List<String> dependencies;
  final List<String> missingInformation;
  final List<String> hardCodedValues;
  final List<String> providerAssumptions;
  final List<String> reusableSections;
  final double confidence;
  final String contentHash;
}

class RunRecord {
  RunRecord({
    required this.id,
    required this.assetTitle,
    required this.provider,
    required this.output,
    required this.status,
    required this.createdAt,
    this.error,
  });
  final String id;
  final String assetTitle;
  final String provider;
  final String output;
  final String status;
  final DateTime createdAt;
  final String? error;

  Map<String, dynamic> toJson() => {
    'id': id,
    'assetTitle': assetTitle,
    'provider': provider,
    'output': output,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    'error': error,
  };

  factory RunRecord.fromJson(Map<String, dynamic> json) => RunRecord(
    id: json['id'] as String? ?? 'run:unknown',
    assetTitle: json['assetTitle'] as String? ?? '',
    provider: json['provider'] as String? ?? 'Local preview',
    output: json['output'] as String? ?? '',
    status: json['status'] as String? ?? 'completed',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    error: json['error'] as String?,
  );
}

class PromptRepository {
  Directory? _root;
  Directory? _current;

  Directory get current => _current!;
  bool get hasProject => _current != null;

  Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    _root = Directory('${docs.path}${Platform.pathSeparator}PromptflowOS');
    await _root!.create(recursive: true);
    final projects = await listProjects();
    if (projects.isEmpty) {
      await createProject(
        'My Prompt Workspace',
        'A local-first space for reusable AI work.',
      );
    } else {
      await openProject(projects.first.path);
    }
  }

  Future<List<ProjectInfo>> listProjects() async {
    if (_root == null) return [];
    final result = <ProjectInfo>[];
    await for (final entity in _root!.list()) {
      if (entity is! Directory) continue;
      final manifest = File(
        '${entity.path}${Platform.pathSeparator}project.yaml',
      );
      if (!await manifest.exists()) continue;
      try {
        final yaml = loadYaml(await manifest.readAsString()) as YamlMap;
        result.add(
          ProjectInfo(
            id:
                yaml['id']?.toString() ??
                'project:${entity.uri.pathSegments.last}',
            title: yaml['title']?.toString() ?? entity.uri.pathSegments.last,
            slug: yaml['slug']?.toString() ?? entity.uri.pathSegments.last,
            path: entity.path,
            description: yaml['description']?.toString() ?? '',
          ),
        );
      } catch (_) {
        result.add(
          ProjectInfo(
            id: 'project:${entity.uri.pathSegments.last}',
            title: entity.uri.pathSegments.last,
            slug: entity.uri.pathSegments.last,
            path: entity.path,
          ),
        );
      }
    }
    result.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return result;
  }

  Future<ProjectInfo> createProject(String title, String description) async {
    final slug = _slugify(title);
    final dir = Directory('${_root!.path}${Platform.pathSeparator}$slug');
    await dir.create(recursive: true);
    for (final name in [
      'prompts',
      'templates',
      'context',
      'instructions',
      'workflows',
      'evaluations',
      'references',
      'assets',
      'runs',
      '.promptworkspace/imports',
    ]) {
      await Directory('${dir.path}${Platform.pathSeparator}$name')
          .create(recursive: true);
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final id = 'project:${_randomId()}';
    await File(
      '${dir.path}${Platform.pathSeparator}project.yaml',
    ).writeAsString(
      '''schema: project/v1\nid: $id\nslug: $slug\ntitle: ${_yamlScalar(title)}\ndescription: ${_yamlScalar(description)}\ncreated_at: $now\nupdated_at: $now\nstatus: active\ndefault_locale: en-US\nowner_scope: personal\ntags: [workspace]\nentrypoints:\n  readme: README.md\nconventions:\n  link_style: both\n  line_endings: lf\n  index_path: .promptworkspace/index.json\n  runs_retention: keep\n''',
    );
    await File('${dir.path}${Platform.pathSeparator}README.md').writeAsString(
      '# $title\n\n$description\n\nThis project is stored as ordinary Markdown and YAML so it can be opened outside the app.\n',
    );
    final project = ProjectInfo(
      id: id,
      title: title,
      slug: slug,
      path: dir.path,
      description: description,
    );
    _current = dir;
    await _writeIndex(await loadAssets());
    return project;
  }

  Future<void> openProject(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) throw Exception('Project folder not found');
    _current = dir;
    await _writeIndex(await loadAssets());
  }

  Future<List<AssetRecord>> loadAssets() async {
    if (_current == null) return [];
    final result = <AssetRecord>[];
    final roots = [
      'prompts',
      'templates',
      'context',
      'instructions',
      'references',
      'assets',
    ];
    for (final root in roots) {
      final dir = Directory('${_current!.path}${Platform.pathSeparator}$root');
      if (!await dir.exists()) continue;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is! File || !entity.path.toLowerCase().endsWith('.md'))
          continue;
        final raw = await entity.readAsString();
        result.add(_parseAsset(entity.path, raw, root));
      }
    }
    result.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return result;
  }

  Future<ImportAnalysis> analyzeImport(String raw, String sourceLabel) async {
    final trimmed = raw.trim();
    final lines = trimmed.split(RegExp(r'\r?\n'));
    final headings = lines
        .where((line) => RegExp(r'^#{1,6}\s+').hasMatch(line.trim()))
        .map((line) => line.replaceFirst(RegExp(r'^#{1,6}\s+'), '').trim())
        .where((v) => v.isNotEmpty)
        .toList();
    final variableMatches = <String, VariableCandidate>{};
    final patterns = [
      RegExp(r'\{\{\s*([A-Za-z][A-Za-z0-9_]*)\s*\}\}'),
      RegExp(r'\[([A-Z][A-Z0-9_ -]{2,40})\]'),
      RegExp(r'<([A-Z][A-Z0-9_ -]{2,40})>'),
      RegExp(r'\$([A-Za-z][A-Za-z0-9_]*)'),
    ];
    for (final pattern in patterns) {
      for (final match in pattern.allMatches(trimmed)) {
        final original = match.group(0)!;
        final rawName = match.group(1)!.trim();
        final name = _variableName(rawName);
        variableMatches[name] = VariableCandidate(
          name: name,
          original: original,
          required: true,
          confidence: original.startsWith('{{') ? 0.96 : 0.82,
        );
      }
    }
    final lower = trimmed.toLowerCase();
    final providerAssumptions = <String>[];
    for (final provider in [
      'chatgpt',
      'openai',
      'claude',
      'anthropic',
      'gemini',
    ]) {
      if (lower.contains(provider)) providerAssumptions.add(provider);
    }
    final constraints = lines
        .where(
          (line) => RegExp(
            r'^(must|should|do not|never|only|constraint|rule)\b',
            caseSensitive: false,
          ).hasMatch(line.trim()),
        )
        .map((line) => line.trim())
        .take(8)
        .toList();
    final dependencies = lines
        .where(
          (line) =>
              line.contains('[[') ||
              line.toLowerCase().contains('context') ||
              line.toLowerCase().contains('reference'),
        )
        .map((line) => line.trim())
        .take(8)
        .toList();
    final hardCodedValues = RegExp(
      r'\b(?:https?://\S+|\b\d{4,}\b|[A-Z][A-Z0-9_]{3,})\b',
    ).allMatches(trimmed).map((m) => m.group(0)!).toSet().take(12).toList();
    final title = headings.isNotEmpty
        ? headings.first
        : (lines
              .firstWhere(
                (line) => line.trim().isNotEmpty,
                orElse: () => 'Imported prompt',
              )
              .trim()
              .substring(
                0,
                min(
                  72,
                  lines
                      .firstWhere(
                        (line) => line.trim().isNotEmpty,
                        orElse: () => 'Imported prompt',
                      )
                      .trim()
                      .length,
                ),
              ));
    final objective = _objective(trimmed, headings);
    final suggestedKind = _suggestedKind(
      trimmed,
      variableMatches.length,
      headings,
    );
    final reusableSections = headings.isNotEmpty
        ? headings
        : [
            'Core instruction',
            if (variableMatches.isNotEmpty) 'Detected inputs',
            if (constraints.isNotEmpty) 'Constraints',
          ];
    final missing = <String>[];
    if (variableMatches.isNotEmpty)
      missing.add(
        'Confirm values or defaults for ${variableMatches.values.map((v) => v.name).join(', ')}',
      );
    if (providerAssumptions.isNotEmpty)
      missing.add(
        'Confirm whether provider-specific wording should be preserved',
      );
    if (trimmed.length < 80)
      missing.add('Add more context or an expected output format');
    return ImportAnalysis(
      raw: raw,
      sourceLabel: sourceLabel,
      suggestedKind: suggestedKind,
      title: title,
      objective: objective,
      variables: variableMatches.values.toList(),
      sections: headings,
      constraints: constraints,
      dependencies: dependencies,
      missingInformation: missing,
      hardCodedValues: hardCodedValues,
      providerAssumptions: providerAssumptions,
      reusableSections: reusableSections,
      confidence: min(
        0.98,
        0.55 +
            (headings.isNotEmpty ? 0.12 : 0) +
            (variableMatches.isNotEmpty ? 0.12 : 0) +
            (constraints.isNotEmpty ? 0.08 : 0),
      ),
      contentHash: _hash(trimmed),
    );
  }

  Future<AssetRecord> saveImport(
    ImportAnalysis analysis, {
    required String destinationKind,
    required String mode,
    required bool convertVariables,
    String? projectContext,
    List<AssetRecord> composeWith = const [],
  }) async {
    final safeKind = destinationKind == 'template'
        ? 'template'
        : destinationKind;
    var content = analysis.raw.trim();
    if (composeWith.isNotEmpty) {
      final combined = composeWith
          .map(
            (asset) =>
                '\n\n## Reused component: ${asset.title}\n\n${asset.content}',
          )
          .join();
      content = '$content$combined';
    }
    if (convertVariables) {
      for (final variable in analysis.variables) {
        content = content.replaceAll(variable.original, '{{${variable.name}}}');
      }
    }
    if (mode == 'adapted' &&
        projectContext != null &&
        projectContext.trim().isNotEmpty) {
      content = '## Project adaptation\n\nProject: $projectContext\n\n$content';
    }
    final id =
        '${safeKind == 'template' ? 'template' : safeKind}:${_randomId()}';
    final folder = safeKind == 'template'
        ? 'templates'
        : (safeKind == 'context'
              ? 'context'
              : (safeKind == 'instruction'
                    ? 'instructions'
                    : (safeKind == 'reference' ? 'references' : 'prompts')));
    final file = File(
      '${_current!.path}${Platform.pathSeparator}$folder${Platform.pathSeparator}${_slugify(analysis.title)}-${_randomId(short: true)}.md',
    );
    final now = DateTime.now().toUtc().toIso8601String();
    final refs = composeWith.map((asset) => asset.id).toList();
    final changed = <String>[];
    if (convertVariables && analysis.variables.isNotEmpty)
      changed.add('variables');
    if (mode == 'adapted') changed.add('project-context');
    if (composeWith.isNotEmpty) changed.add('composition');
    final frontmatter =
        '''---\nschema: document/v1\nid: $id\nkind: $safeKind\ntitle: ${_yamlScalar(analysis.title)}\nsummary: ${_yamlScalar(analysis.objective)}\ncreated_at: $now\nupdated_at: $now\nstatus: draft\ntags: [imported, reusable]\nderived_from: [${refs.join(', ')}]\ninputs:\n${analysis.variables.isEmpty ? '  []' : analysis.variables.map((v) => '  - name: ${v.name}\n    type: ${v.type}\n    required: ${v.required}\n    secret: false').join('\n')}\nprovenance:\n  source_type: ${composeWith.isNotEmpty ? 'composed' : 'imported'}\n  source_label: ${_yamlScalar(analysis.sourceLabel)}\n  source_refs: [${refs.join(', ')}]\n  imported_at: $now\n  content_hash: ${analysis.contentHash}\n  adaptation:\n    mode: $mode\n    project_id: ${_projectId()}\n    changed_sections: [${changed.join(', ')}]\nimport_analysis:\n  suggested_kind: ${analysis.suggestedKind}\n  objective: ${_yamlScalar(analysis.objective)}\n  confidence: ${analysis.confidence.toStringAsFixed(2)}\n---\n\n''';
    await file.writeAsString('$frontmatter$content\n');
    final capture = File(
      '${_current!.path}${Platform.pathSeparator}.promptworkspace${Platform.pathSeparator}imports${Platform.pathSeparator}${analysis.contentHash.replaceFirst('sha256:', '')}.txt',
    );
    await capture.writeAsString(analysis.raw);
    await _writeIndex(await loadAssets());
    return _parseAsset(file.path, await file.readAsString(), folder);
  }

  Future<AssetRecord?> createWorkflowFromAsset(AssetRecord asset) async {
    final dir = Directory(
      '${_current!.path}${Platform.pathSeparator}workflows',
    );
    await dir.create(recursive: true);
    final id = 'workflow:${_randomId()}';
    final file = File(
      '${dir.path}${Platform.pathSeparator}${_slugify(asset.title)}-flow.yaml',
    );
    await file.writeAsString(
      '''schema: workflow/v1\nid: $id\ntitle: ${_yamlScalar('${asset.title} flow')}\ndescription: A reusable flow created from ${asset.title}.\nstatus: draft\ninputs:\n  input:\n    type: string\n    required: true\n    secret: false\noutputs:\n  output:\n    type: string\n    required: true\n    secret: false\nnodes:\n  - id: use_asset\n    type: prompt\n    label: ${_yamlScalar(asset.title)}\n    ref: ${asset.id}\n    inputs:\n      input: \$input.input\n    outputs:\n      output:\n        type: string\n        required: true\n        secret: false\n  - id: output\n    type: output\n    label: Return output\n    inputs:\n      output: \$use_asset.output\n    outputs:\n      output:\n        type: string\n        required: true\n        secret: false\nedges:\n  - from: input.input\n    to: use_asset.input\n  - from: use_asset.output\n    to: output.output\nerror_policy:\n  on_unhandled_error: fail\n  max_total_provider_calls: 1\n''',
    );
    return null;
  }

  Future<List<RunRecord>> loadRuns() async {
    if (_current == null) return [];
    final file = File(
      '${_current!.path}${Platform.pathSeparator}runs${Platform.pathSeparator}history.json',
    );
    if (!await file.exists()) return [];
    try {
      final data = jsonDecode(await file.readAsString()) as List;
      return data
          .map((e) => RunRecord.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<RunRecord> runAsset(
    AssetRecord asset, {
    required String provider,
    String input = '',
  }) async {
    final rendered = asset.content.replaceAllMapped(
      RegExp(r'\{\{\s*([A-Za-z][A-Za-z0-9_]*)\s*\}\}'),
      (match) => input.isEmpty ? '[${match.group(1)}]' : input,
    );
    try {
      final output = await ProviderGateway().execute(
        provider: provider,
        prompt: rendered,
        secureStorage: const FlutterSecureStorage(),
      );
      final run = RunRecord(
        id: 'run:${_randomId()}',
        assetTitle: asset.title,
        provider: provider,
        output: output,
        status: 'completed',
        createdAt: DateTime.now(),
      );
      await _appendRun(run);
      return run;
    } catch (error) {
      final run = RunRecord(
        id: 'run:${_randomId()}',
        assetTitle: asset.title,
        provider: provider,
        output: '',
        status: 'failed',
        createdAt: DateTime.now(),
        error: error.toString(),
      );
      await _appendRun(run);
      return run;
    }
  }

  Future<void> _appendRun(RunRecord run) async {
    final file = File(
      '${_current!.path}${Platform.pathSeparator}runs${Platform.pathSeparator}history.json',
    );
    final runs = await loadRuns();
    runs.insert(0, run);
    await file.writeAsString(
      jsonEncode(runs.take(50).map((r) => r.toJson()).toList()),
    );
  }

  AssetRecord _parseAsset(String path, String raw, String folder) {
    var body = raw;
    var title = path
        .split(Platform.pathSeparator)
        .last
        .replaceAll(RegExp(r'\.md$'), '')
        .replaceAll('-', ' ');
    var kind = folder == 'templates'
        ? 'template'
        : (folder == 'context'
              ? 'context'
              : (folder == 'instructions'
                    ? 'instruction'
                    : (folder == 'references' ? 'reference' : 'prompt')));
    var summary = '';
    final sourceRefs = <String>[];
    String? sourceLabel;
    String? mode;
    if (raw.startsWith('---')) {
      final end = raw.indexOf('\n---', 3);
      if (end > 0) {
        final fm = raw.substring(3, end);
        body = raw.substring(end + 4).trim();
        try {
          final yaml = loadYaml(fm) as YamlMap;
          title = yaml['title']?.toString() ?? title;
          kind = yaml['kind']?.toString() ?? kind;
          summary = yaml['summary']?.toString() ?? '';
          sourceLabel = yaml['provenance'] is YamlMap
              ? (yaml['provenance']['source_label']?.toString())
              : null;
          mode =
              yaml['provenance'] is YamlMap &&
                  yaml['provenance']['adaptation'] is YamlMap
              ? yaml['provenance']['adaptation']['mode']?.toString()
              : null;
          if (yaml['provenance'] is YamlMap &&
              yaml['provenance']['source_refs'] is YamlList)
            sourceRefs.addAll(
              (yaml['provenance']['source_refs'] as YamlList).map(
                (e) => e.toString(),
              ),
            );
          final parsedId = yaml['id']?.toString();
          return AssetRecord(
            id: parsedId ?? '${kind}:${_hash(path)}',
            kind: kind,
            title: title,
            path: path,
            content: body,
            summary: summary,
            sourceLabel: sourceLabel,
            sourceRefs: sourceRefs,
            provenanceMode: mode,
          );
        } catch (_) {}
      }
    }
    return AssetRecord(
      id: '${kind}:${_hash(path)}',
      kind: kind,
      title: title,
      path: path,
      content: body,
      summary: summary,
      sourceLabel: sourceLabel,
      sourceRefs: sourceRefs,
      provenanceMode: mode,
    );
  }

  Future<void> _writeIndex(List<AssetRecord> assets) async {
    if (_current == null) return;
    final file = File(
      '${_current!.path}${Platform.pathSeparator}.promptworkspace${Platform.pathSeparator}index.json',
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(
        assets
            .map(
              (a) => {
                'id': a.id,
                'kind': a.kind,
                'title': a.title,
                'path': a.path,
                'summary': a.summary,
                'sourceLabel': a.sourceLabel,
              },
            )
            .toList(),
      ),
    );
  }

  String _projectId() => _current == null
      ? 'project:unknown'
      : 'project:${_current!.uri.pathSegments.last}';

  static String _slugify(String value) {
    final slug = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return slug.isEmpty ? 'untitled' : slug.substring(0, min(64, slug.length));
  }

  static String _variableName(String raw) => raw
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  static String _yamlScalar(String value) => jsonEncode(value);
  static String _randomId({bool short = false}) =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${short ? '' : Random().nextInt(9999).toRadixString(36)}';
  static String _hash(String value) =>
      'sha256:${sha256.convert(utf8.encode(value)).toString()}';
  static String _objective(String text, List<String> headings) {
    if (headings.isNotEmpty) return headings.first;
    final first = text
        .split(RegExp(r'\r?\n'))
        .map((v) => v.trim())
        .firstWhere((v) => v.isNotEmpty, orElse: () => 'Reusable prompt');
    return first.length > 180 ? '${first.substring(0, 180)}…' : first;
  }

  static String _suggestedKind(
    String text,
    int variables,
    List<String> headings,
  ) {
    final lower = text.toLowerCase();
    if (variables > 0 ||
        lower.contains('input') ||
        lower.contains('placeholder'))
      return 'template';
    if (lower.contains('context') || lower.contains('background'))
      return 'context';
    if (lower.contains('workflow') || lower.contains('step 1'))
      return 'workflow';
    if (headings.length > 3) return 'prompt';
    return 'prompt';
  }
}

class ProviderGateway {
  Future<String> execute({
    required String provider,
    required String prompt,
    required FlutterSecureStorage secureStorage,
  }) async {
    if (provider == 'Local preview') {
      return 'LOCAL PREVIEW\n\n${prompt.trim()}\n\n— This run used the deterministic local adapter. Choose an API provider in Settings for a live model call.';
    }
    final keyName = provider == 'OpenAI'
        ? 'provider_openai_key'
        : (provider == 'Claude'
              ? 'provider_anthropic_key'
              : 'provider_gemini_key');
    final apiKey = await secureStorage.read(key: keyName);
    if (apiKey == null || apiKey.trim().isEmpty)
      throw Exception(
        'No API key configured for $provider. Open Settings to add it securely.',
      );
    if (provider == 'OpenAI') {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/responses'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'model': 'gpt-5-mini', 'input': prompt}),
      );
      if (response.statusCode >= 400)
        throw Exception('OpenAI request failed (${response.statusCode}).');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final output = data['output'];
      return output is List
          ? output
                .expand((item) => (item['content'] as List? ?? const []))
                .map((part) => part['text'] ?? '')
                .join()
          : data['output_text']?.toString() ?? response.body;
    }
    if (provider == 'Claude') {
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'claude-3-5-sonnet-latest',
          'max_tokens': 1200,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        }),
      );
      if (response.statusCode >= 400)
        throw Exception('Claude request failed (${response.statusCode}).');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['content'] as List? ?? const [])
          .map((part) => part['text'] ?? '')
          .join();
    }
    final response = await http.post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
      }),
    );
    if (response.statusCode >= 400)
      throw Exception('Gemini request failed (${response.statusCode}).');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (((data['candidates'] as List? ?? const []).firstOrNull?['content']
                    as Map?)?['parts']
                as List? ??
            const [])
        .map((part) => part['text'] ?? '')
        .join();
  }
}

extension FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
