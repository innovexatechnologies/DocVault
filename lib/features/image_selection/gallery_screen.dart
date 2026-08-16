import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/gallery_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_helper.dart';
import '../../core/providers/image_selection_provider.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final _galleryService = GalleryService();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _pickImages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final imagePaths = await _galleryService.pickImages();

      if (mounted) {
        if (imagePaths.isEmpty) {
          setState(() {
            _isLoading = false;
          });
          return;
        }

        context.read<ImageSelectionProvider>().addImages(imagePaths, 'gallery');

        // Navigate to review
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/review');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to pick images';
        });
      }
    }
  }

  void _goToCamera() {
    Navigator.of(context).pop();
    Navigator.of(context).pushNamed('/camera');
  }

  @override
  Widget build(BuildContext context) {
    final responsivePadding = ResponsiveHelper.getResponsivePadding(context);
    final buttonHeight = ResponsiveHelper.getResponsiveButtonHeight(context);
    final titleFontSize = ResponsiveHelper.getResponsiveFontSize(
      context,
      mobileSize: 20,
      tabletSize: 24,
      desktopSize: 26,
    );
    final descriptionFontSize = ResponsiveHelper.getResponsiveFontSize(
      context,
      mobileSize: 13,
      tabletSize: 14,
      desktopSize: 15,
    );
    final buttonLabelFontSize = ResponsiveHelper.getResponsiveFontSize(
      context,
      mobileSize: 14,
      tabletSize: 16,
      desktopSize: 18,
    );
    final iconSize = ResponsiveHelper.isTablet(context) ? 70 : 60;

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop();
        return false;
      },
      child: Scaffold(
        backgroundColor: AppTheme.bgLight,
        appBar: AppBar(
          title: const Text(AppConstants.gallery),
          backgroundColor: AppTheme.bgWhite,
          foregroundColor: AppTheme.textPrimary,
          elevation: 1,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(responsivePadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icon
                Center(
                  child: Container(
                    width: ResponsiveHelper.isTablet(context) ? 120 : 100,
                    height: ResponsiveHelper.isTablet(context) ? 120 : 100,
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.image,
                        size: iconSize,
                        color: AppTheme.accentColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: responsivePadding),
                // Title
                Text(
                  'Select Images',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: responsivePadding * 0.33),
                // Description
                Text(
                  'Choose one or multiple images from your gallery',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: descriptionFontSize,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: EdgeInsets.only(top: responsivePadding * 0.67),
                    child: Container(
                      padding: EdgeInsets.all(responsivePadding * 0.5),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.errorColor),
                      ),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: ResponsiveHelper.getResponsiveFontSize(
                            context,
                            mobileSize: 11,
                            tabletSize: 12,
                            desktopSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                SizedBox(height: responsivePadding * 1.67),
                // Pick Images Button
                SizedBox(
                  height: buttonHeight,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _pickImages,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      disabledBackgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_photo_alternate),
                              SizedBox(width: responsivePadding * 0.33),
                              Text(
                                'Pick Images',
                                style: TextStyle(
                                  fontSize: buttonLabelFontSize,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                SizedBox(height: responsivePadding * 0.5),
                // Use Camera Instead
                SizedBox(
                  height: buttonHeight,
                  child: OutlinedButton(
                    onPressed: _goToCamera,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_alt),
                        SizedBox(width: responsivePadding * 0.33),
                        Text(
                          'Use Camera Instead',
                          style: TextStyle(
                            fontSize: buttonLabelFontSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
