import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/pdf_generation_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/image_selection_provider.dart';
import '../../models/pdf_result.dart';

class PdfGenerationScreen extends StatefulWidget {
  const PdfGenerationScreen({super.key});

  @override
  State<PdfGenerationScreen> createState() => _PdfGenerationScreenState();
}

class _PdfGenerationScreenState extends State<PdfGenerationScreen> {
  late Future<PdfResult> _pdfGenerationFuture;
  final _pdfService = PdfGenerationService();

  @override
  void initState() {
    super.initState();
    _generatePdf();
  }

  void _generatePdf() {
    final imagePaths = context
        .read<ImageSelectionProvider>()
        .getImageFilePaths();

    _pdfGenerationFuture = _pdfService
        .generatePdfFromImages(imagePaths)
        .then((result) {
          return result;
        })
        .catchError((error) {
          debugPrint('PDF generation error: $error');
          throw error;
        });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: Scaffold(
        backgroundColor: AppTheme.bgLight,
        body: FutureBuilder<PdfResult>(
          future: _pdfGenerationFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                        strokeWidth: 4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Generating PDF...',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${context.watch<ImageSelectionProvider>().imageCount} image(s)',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 60,
                        color: AppTheme.errorColor,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        AppConstants.pdfGenerationFailed,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _generatePdf,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                        ),
                        child: const Text(AppConstants.reorder),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('Back to Review'),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasData) {
              final pdfResult = snapshot.data!;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.check_circle_outline,
                            size: 60,
                            color: AppTheme.successColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        AppConstants.pdfGeneratedSuccessfully,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushReplacementNamed(
                              '/result',
                              arguments: pdfResult,
                            );
                          },
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('View Result'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return const SizedBox();
          },
        ),
      ),
    );
  }
}
