import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:promptflow_os/core.dart';

void main() {
  test('detects structure and variables from raw imported text', () async {
    final repository = PromptRepository();
    final analysis = await repository.analyzeImport(
      '''# Product description\n\nWrite a product description for [PRODUCT] targeting {{AUDIENCE}}.\n\nMust be concise.\n''',
      'GitHub README',
    );

    expect(analysis.suggestedKind, 'template');
    expect(analysis.title, 'Product description');
    expect(
      analysis.variables.map((item) => item.name),
      containsAll(<String>['product', 'audience']),
    );
    expect(analysis.constraints, isNotEmpty);
    expect(analysis.sourceLabel, 'GitHub README');
    expect(analysis.contentHash, startsWith('sha256:'));
    expect(analysis.contentHash.length, 71);
  });

  test('rejects unsafe URL targets and allows public HTTP URLs', () {
    expect(
      PromptRepository.isSafeHttpUrl(Uri.parse('https://example.com/prompt')),
      isTrue,
    );
    expect(
      PromptRepository.isSafeHttpUrl(Uri.parse('http://127.0.0.1:8080/prompt')),
      isFalse,
    );
    expect(
      PromptRepository.isSafeHttpUrl(Uri.parse('file:///tmp/prompt.md')),
      isFalse,
    );
    expect(
      PromptRepository.isSafeHttpUrl(Uri.parse('http://192.168.1.20/prompt')),
      isFalse,
    );
  });

  test(
    'keeps free entitlements useful while enforcing a clear upgrade boundary',
    () {
      expect(Entitlement().canImportUrl, isTrue);
      expect(Entitlement(urlImportsUsed: 3).canImportUrl, isFalse);
      expect(
        Entitlement(tier: 'pro', urlImportsUsed: 999).canImportUrl,
        isTrue,
      );
    },
  );

  test('preserves frontmatter when updating an asset revision', () async {
    final directory = await Directory.systemTemp.createTemp(
      'promptflow-revision-test',
    );
    final file = File('${directory.path}/asset.md');
    await file.writeAsString(
      '---\nschema: document/v1\nid: prompt:test\nupdated_at: 2026-01-01T00:00:00Z\n---\n\nOld body\n',
    );
    final repository = PromptRepository();
    await repository.updateAsset(
      AssetRecord(
        id: 'prompt:test',
        kind: 'prompt',
        title: 'Test',
        path: file.path,
        content: 'Old body',
      ),
      'New body',
    );
    final saved = await file.readAsString();
    expect(saved, contains('schema: document/v1'));
    expect(saved, contains('content_hash: sha256:'));
    expect(saved, contains('New body'));
    await directory.delete(recursive: true);
  });

  test('preserves per-variable inputs in run records', () {
    final run = RunRecord(
      id: 'run:test',
      assetTitle: 'Example',
      provider: 'Local preview',
      output: 'ok',
      status: 'completed',
      createdAt: DateTime.now(),
      inputs: const {'audience': 'designers'},
    );
    final restored = RunRecord.fromJson(run.toJson());
    expect(restored.inputs['audience'], 'designers');
  });

  test(
    'detects provider assumptions and missing information without an LLM',
    () async {
      final repository = PromptRepository();
      final analysis = await repository.analyzeImport(
        'Use ChatGPT to summarize this context.',
        'Clipboard',
      );

      expect(analysis.providerAssumptions, contains('chatgpt'));
      expect(analysis.missingInformation, isNotEmpty);
      expect(analysis.reusableSections, isNotEmpty);
    },
  );
}
