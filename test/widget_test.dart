import 'package:doc_vault/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app launches and shows splash screen', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('DocVault'), findsOneWidget);
    expect(find.text('Your Documents. Secured.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
  });
}
