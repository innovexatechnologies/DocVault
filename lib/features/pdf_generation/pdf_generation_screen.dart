import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/pdf_generation_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_helper.dart';
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
    final responsivePadding = ResponsiveHelper.getResponsivePadding(context);
    final buttonHeight = ResponsiveHelper.getResponsiveButtonHeight(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.bgLight,
        body: FutureBuilder<PdfResult>(
          future: _pdfGenerationFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(responsivePadding),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: ResponsiveHelper.isTablet(context)
                            ? 100.0
                            : 80.0,
                        height: ResponsiveHelper.isTablet(context)
                            ? 100.0
                            : 80.0,
                        child: const CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                          strokeWidth: 4,
                        ),
                      ),
                      SizedBox(height: responsivePadding),
                      Text(
                        'Generating PDF...',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(
                            context,
                            mobileSize: 17,
                            tabletSize: 19,
                            desktopSize: 21,
                          ),
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: responsivePadding * 0.33),
                      Text(
                        '${context.watch<ImageSelectionProvider>().imageCount} image(s)',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(
                            context,
                            mobileSize: 13,
                            tabletSize: 14,
                            desktopSize: 15,
                          ),
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(responsivePadding),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: ResponsiveHelper.isTablet(context) ? 70.0 : 60.0,
                        color: AppTheme.errorColor,
                      ),
                      SizedBox(height: responsivePadding),
                      Text(
                        AppConstants.pdfGenerationFailed,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(
                            context,
                            mobileSize: 15,
                            tabletSize: 16,
                            desktopSize: 17,
                          ),
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: responsivePadding * 0.33),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(
                            context,
                            mobileSize: 11,
                            tabletSize: 12,
                            desktopSize: 13,
                          ),
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      SizedBox(height: responsivePadding * 1.33),
                      SizedBox(
                        height: buttonHeight,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _generatePdf,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                          ),
                          child: Text(
                            'Retry',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(
                                context,
                                mobileSize: 14,
                                tabletSize: 16,
                                desktopSize: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: responsivePadding * 0.5),
                      SizedBox(
                        height: buttonHeight,
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text(
                            'Back to Review',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(
                                context,
                                mobileSize: 14,
                                tabletSize: 16,
                                desktopSize: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasData) {
              final pdfResult = snapshot.data!;
              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(responsivePadding),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: ResponsiveHelper.isTablet(context)
                            ? 120.0
                            : 100.0,
                        height: ResponsiveHelper.isTablet(context)
                            ? 120.0
                            : 100.0,
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.check_circle_outline,
                            size: ResponsiveHelper.isTablet(context)
                                ? 70.0
                                : 60.0,
                            color: AppTheme.successColor,
                          ),
                        ),
                      ),
                      SizedBox(height: responsivePadding),
                      Text(
                        AppConstants.pdfGeneratedSuccessfully,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(
                            context,
                            mobileSize: 19,
                            tabletSize: 22,
                            desktopSize: 24,
                          ),
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: responsivePadding * 1.33),
                      SizedBox(
                        width: double.infinity,
                        height: buttonHeight,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushReplacementNamed(
                              '/result',
                              arguments: pdfResult,
                            );
                          },
                          icon: const Icon(Icons.arrow_forward),
                          label: Text(
                            'View Result',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(
                                context,
                                mobileSize: 14,
                                tabletSize: 16,
                                desktopSize: 18,
                              ),
                            ),
                          ),
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
