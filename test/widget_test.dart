import 'package:flutter_test/flutter_test.dart';

import 'package:promptflow_os/main.dart';

void main() {
  testWidgets('Promptflow OS root renders', (tester) async {
    await tester.pumpWidget(const PromptflowApp());
    expect(find.byType(WorkspacePage), findsOneWidget);
  });
}
