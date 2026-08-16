import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/image_selection_provider.dart';
import 'features/splash/splash_screen.dart';
import 'features/home/home_screen.dart';
import 'features/home/source_selection_screen.dart';
import 'features/camera/camera_screen.dart';
import 'features/image_selection/gallery_screen.dart';
import 'features/pdf_generation/review_screen.dart';
import 'features/pdf_generation/pdf_generation_screen.dart';
import 'features/pdf_result/result_screen.dart';
import 'models/pdf_result.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ImageSelectionProvider()),
      ],
      child: MaterialApp(
        title: 'DocVault',
        theme: AppTheme.lightTheme(),
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/home': (context) => const HomeScreen(),
          '/source-selection': (context) => const SourceSelectionScreen(),
          '/camera': (context) => const CameraScreen(),
          '/gallery': (context) => const GalleryScreen(),
          '/review': (context) => const ReviewScreen(),
          '/pdf-generation': (context) => const PdfGenerationScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/result') {
            final pdfResult = settings.arguments as PdfResult;
            return MaterialPageRoute(
              builder: (context) => ResultScreen(pdfResult: pdfResult),
            );
          }
          return null;
        },
      ),
    );
  }
}
