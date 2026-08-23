import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/document_generation_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_helper.dart';
import '../../core/providers/image_selection_provider.dart';
import '../../models/conversion_type.dart';
import '../../models/pdf_result.dart';
import '../pdf_result/result_screen.dart';

class PdfGenerationScreen extends StatefulWidget {
  final ConversionType conversionType;

  const PdfGenerationScreen({
    super.key,
    this.conversionType = ConversionType.pdf,
  });

  @override
  State<PdfGenerationScreen> createState() => _PdfGenerationScreenState();
}

class _PdfGenerationScreenState extends State<PdfGenerationScreen> {
  late Future<DocumentResult> _generationFuture;
  final _documentService = DocumentGenerationService();

  @override
  void initState() {
    super.initState();
    _generateDocument();
  }

  void _generateDocument() {
    final imagePaths = context.read<ImageSelectionProvider>().getImageFilePaths();

    _generationFuture = _documentService
        .generateDocument(
          imagePaths: imagePaths,
          conversionType: widget.conversionType,
        )
        .catchError((error) {
          debugPrint('Document generation error: $error');
          throw error;
        });
  }

  @override
  Widget build(BuildContext context) {
    final responsivePadding = ResponsiveHelper.getResponsivePadding(context);
    final buttonHeight = ResponsiveHelper.getResponsiveButtonHeight(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final itemUnit = widget.conversionType == ConversionType.ppt ? 'slide(s)' : 'image(s)';

    return FutureBuilder<DocumentResult>(
      future: _generationFuture,
      builder: (context, snapshot) {
        final isError = snapshot.hasError;

        return PopScope(
          canPop: isError,
          onPopInvokedWithResult: (didPop, result) {
            if (isError && !didPop) {
              Navigator.of(context).maybePop();
            }
          },
          child: Scaffold(
            backgroundColor: colorScheme.surface,
            appBar: isError
                ? AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Back to Review',
                    ),
                  )
                : null,
            body: Builder(
              builder: (context) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(responsivePadding),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: ResponsiveHelper.isTablet(context) ? 100.0 : 80.0,
                            height: ResponsiveHelper.isTablet(context) ? 100.0 : 80.0,
                            child: CircularProgressIndicator(
                              color: widget.conversionType.badgeColor,
                              strokeWidth: 4,
                            ),
                          ),
                          SizedBox(height: responsivePadding),
                          Text(
                            'Generating ${widget.conversionType.label}...',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(
                                context,
                                mobileSize: 17,
                                tabletSize: 19,
                                desktopSize: 21,
                              ),
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(height: responsivePadding * 0.33),
                          Text(
                            '${context.watch<ImageSelectionProvider>().imageCount} $itemUnit',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(
                                context,
                                mobileSize: 13,
                                tabletSize: 14,
                                desktopSize: 15,
                              ),
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
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
                            '${widget.conversionType.shortName} generation failed',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(
                                context,
                                mobileSize: 15,
                                tabletSize: 16,
                                desktopSize: 17,
                              ),
                              color: colorScheme.onSurface,
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
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          SizedBox(height: responsivePadding * 1.33),
                          SizedBox(
                            height: buttonHeight,
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _generateDocument,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.conversionType.badgeColor,
                                foregroundColor: Colors.white,
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
                  final result = snapshot.data!;
                  return Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(responsivePadding),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: ResponsiveHelper.isTablet(context) ? 120.0 : 100.0,
                            height: ResponsiveHelper.isTablet(context) ? 120.0 : 100.0,
                            decoration: BoxDecoration(
                              color: AppTheme.successColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.check_circle_outline,
                                size: ResponsiveHelper.isTablet(context) ? 70.0 : 60.0,
                                color: AppTheme.successColor,
                              ),
                            ),
                          ),
                          SizedBox(height: responsivePadding),
                          Text(
                            '${widget.conversionType.shortName} Created Successfully!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(
                                context,
                                mobileSize: 19,
                                tabletSize: 22,
                                desktopSize: 24,
                              ),
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(height: responsivePadding * 1.33),
                          SizedBox(
                            width: double.infinity,
                            height: buttonHeight,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => ResultScreen(pdfResult: result),
                                  ),
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
                                backgroundColor: widget.conversionType.badgeColor,
                                foregroundColor: Colors.white,
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
      },
    );
  }
}
