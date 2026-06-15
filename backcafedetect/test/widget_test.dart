import 'package:flutter_test/flutter_test.dart';
import 'package:backcafedetect/main.dart';

void main() {
  testWidgets('La aplicación inicia correctamente', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('INICIAR DETECCIÓN'), findsOneWidget);
  });
}