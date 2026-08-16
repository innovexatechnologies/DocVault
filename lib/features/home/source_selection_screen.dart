import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_helper.dart';

class SourceSelectionScreen extends StatelessWidget {
  const SourceSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveHelper.getResponsivePadding(context);
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.bgLight,
        appBar: AppBar(
          title: const Text(AppConstants.createPdf),
          backgroundColor: AppTheme.bgWhite,
          foregroundColor: AppTheme.textPrimary,
          elevation: 1,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: isMobile ? 20.0 : 40.0),
                  Text(
                    'Choose Source',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(
                        context,
                        mobileSize: 20,
                        tabletSize: 24,
                        desktopSize: 28,
                      ),
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: isMobile ? 6.0 : 12.0),
                  Text(
                    'Select where to get your documents from',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(
                        context,
                        mobileSize: 12,
                        tabletSize: 14,
                        desktopSize: 16,
                      ),
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  SizedBox(height: isMobile ? 30.0 : 60.0),
                  if (isTablet)
                    Row(
                      children: [
                        Expanded(
                          child: _buildSourceOption(
                            context,
                            title: AppConstants.camera,
                            icon: Icons.camera_alt,
                            color: AppTheme.primaryColor,
                            onTap: () =>
                                Navigator.of(context).pushNamed('/camera'),
                          ),
                        ),
                        SizedBox(width: padding),
                        Expanded(
                          child: _buildSourceOption(
                            context,
                            title: AppConstants.gallery,
                            icon: Icons.image,
                            color: AppTheme.accentColor,
                            onTap: () =>
                                Navigator.of(context).pushNamed('/gallery'),
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildSourceOption(
                          context,
                          title: AppConstants.camera,
                          icon: Icons.camera_alt,
                          color: AppTheme.primaryColor,
                          onTap: () =>
                              Navigator.of(context).pushNamed('/camera'),
                        ),
                        SizedBox(height: isMobile ? 16.0 : 24.0),
                        _buildSourceOption(
                          context,
                          title: AppConstants.gallery,
                          icon: Icons.image,
                          color: AppTheme.accentColor,
                          onTap: () =>
                              Navigator.of(context).pushNamed('/gallery'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSourceOption(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        decoration: BoxDecoration(
          color: AppTheme.bgWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: isMobile ? 48.0 : 60.0, color: color),
            SizedBox(height: isMobile ? 12.0 : 16.0),
            Text(
              title,
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(
                  context,
                  mobileSize: 16,
                  tabletSize: 18,
                  desktopSize: 20,
                ),
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: isMobile ? 6.0 : 8.0),
            Text(
              title == AppConstants.camera
                  ? 'Capture new documents with camera'
                  : 'Select existing images from gallery',
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
          ],
        ),
      ),
    );
  }
}
