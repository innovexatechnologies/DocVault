import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/image_selection_provider.dart';
import '../../core/services/document_generation_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_helper.dart';
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
  final DocumentGenerationService _documentService = DocumentGenerationService();

  bool _hasNavigated = false;
  int _imageCount = 0;

  @override
  void initState() {
    super.initState();
    // Cache image paths before async computation starts
    final imageProvider = context.read<ImageSelectionProvider>();
    _imageCount = imageProvider.imageCount;
    _startGeneration();
  }

  // ============================================================
  // GENERATE DOCUMENT
  // ============================================================

  void _startGeneration() {
    _hasNavigated = false;
    final imageProvider = context.read<ImageSelectionProvider>();
    final imagePaths = imageProvider.getImageFilePaths();

    // Start background document creation
    _generationFuture = _documentService
        .generateDocument(
          imagePaths: imagePaths,
          conversionType: widget.conversionType,
        )
        .then((result) {
      if (mounted) {
        imageProvider.clearAllImages();
      }

      // Navigate to Result Screen instantly when done
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _hasNavigated) return;
        _hasNavigated = true;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ResultScreen(pdfResult: result),
          ),
        );
      });

      return result;
    }).catchError((error) {
      debugPrint('Document generation error: $error');
      throw error;
    });
  }

  void _retryGeneration() {
    if (!mounted) return;
    setState(() {
      _startGeneration();
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
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final hasError = snapshot.hasError;

        return PopScope(
          canPop: !isLoading,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && !isLoading) {
              Navigator.of(context).maybePop();
            }
          },
          child: Scaffold(
            backgroundColor: colorScheme.surface,
            appBar: hasError
                ? AppBar(
                    backgroundColor: colorScheme.surface,
                    foregroundColor: colorScheme.onSurface,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Back to Review',
                    ),
                    title: const Text('Generation Failed'),
                  )
                : null,
            body: SafeArea(
              child: Builder(
                builder: (context) {
                  if (isLoading) {
                    return _buildLoadingState(
                      context,
                      responsivePadding,
                      colorScheme,
                      itemUnit,
                    );
                  }

                  if (hasError) {
                    return _buildErrorState(
                      context,
                      responsivePadding,
                      buttonHeight,
                      colorScheme,
                      snapshot.error,
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // LOADING STATE
  // ============================================================

  Widget _buildLoadingState(
    BuildContext context,
    double responsivePadding,
    ColorScheme colorScheme,
    String itemUnit,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(responsivePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: ResponsiveHelper.isTablet(context) ? 120 : 100,
              height: ResponsiveHelper.isTablet(context) ? 120 : 100,
              decoration: BoxDecoration(
                color: widget.conversionType.badgeColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  color: widget.conversionType.badgeColor,
                  strokeWidth: 4,
                ),
              ),
            ),
            SizedBox(height: responsivePadding),
            Text(
              'Generating ${widget.conversionType.label}...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(
                  context,
                  mobileSize: 18,
                  tabletSize: 20,
                  desktopSize: 22,
                ),
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_imageCount $itemUnit',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(
                  context,
                  mobileSize: 13,
                  tabletSize: 14,
                  desktopSize: 15,
                ),
                color: colorScheme.onSurface.withValues(alpha: 0.60),
              ),
            ),
            SizedBox(height: responsivePadding),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.onSurface.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: widget.conversionType.badgeColor,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Optimizing pages for fast creation. Please wait...',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState(
    BuildContext context,
    double responsivePadding,
    double buttonHeight,
    ColorScheme colorScheme,
    Object? error,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(responsivePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: ResponsiveHelper.isTablet(context) ? 120 : 100,
              height: ResponsiveHelper.isTablet(context) ? 120 : 100,
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: ResponsiveHelper.isTablet(context) ? 70 : 60,
                color: AppTheme.errorColor,
              ),
            ),
            SizedBox(height: responsivePadding),
            Text(
              '${widget.conversionType.shortName} generation failed',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(
                  context,
                  mobileSize: 18,
                  tabletSize: 20,
                  desktopSize: 22,
                ),
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.errorColor.withValues(alpha: 0.20),
                ),
              ),
              child: Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(
                    context,
                    mobileSize: 11,
                    tabletSize: 12,
                    desktopSize: 13,
                  ),
                  height: 1.5,
                  color: colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ),
            SizedBox(height: responsivePadding),
            SizedBox(
              width: double.infinity,
              height: buttonHeight,
              child: ElevatedButton.icon(
                onPressed: _retryGeneration,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      mobileSize: 14,
                      tabletSize: 16,
                      desktopSize: 18,
                    ),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.conversionType.badgeColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: buttonHeight,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text(
                  'Back to Review',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      mobileSize: 14,
                      tabletSize: 16,
                      desktopSize: 18,
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
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
}