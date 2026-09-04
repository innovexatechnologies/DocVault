import 'package:doc_vault/core/constants/app_constants.dart';
import 'package:doc_vault/features/splash/splash_screen.dart';
import 'package:doc_vault/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app launches and shows splash screen', (tester) async {
    const channel = MethodChannel('docvault/pdf_intent');
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);

    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text(AppConstants.appTagline), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 5500));
  });
}
