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
