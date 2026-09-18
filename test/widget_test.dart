import 'package:flutter_test/flutter_test.dart';
import 'package:shixu/main.dart';

void main() {
  testWidgets('App initial render test', (WidgetTester tester) async {
    await tester.pumpWidget(const ShixuApp());
    expect(find.text('拾序 - 任务管理'), findsOneWidget);
  });
}
