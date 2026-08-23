import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.isExternalPdf = false,
  });

  final bool isExternalPdf;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();

    _navigate();
  }

  void _navigate() {

    Future.delayed(
      const Duration(seconds: 2),
      () {

        if (!mounted) {
          return;
        }

        // ========================================================
        // EXTERNAL PDF
        // ========================================================

        if (widget.isExternalPdf) {
          return;
        }

        // ========================================================
        // NORMAL APP START
        // ========================================================

        Navigator.of(context)
            .pushReplacementNamed('/home');
      },
    );
  }

  @override
  Widget build(BuildContext context) {

    final isTablet =
        ResponsiveHelper.isTablet(context);

    final logoSize =
        isTablet ? 120.0 : 100.0;

    final iconSize =
        isTablet ? 70.0 : 60.0;

    final appNameFontSize =
        ResponsiveHelper.getResponsiveFontSize(
      context,
      mobileSize: 28,
      tabletSize: 36,
      desktopSize: 40,
    );

    final taglineFontSize =
        ResponsiveHelper.getResponsiveFontSize(
      context,
      mobileSize: 15,
      tabletSize: 17,
      desktopSize: 19,
    );

    final spacing =
        ResponsiveHelper.getResponsivePadding(
      context,
    );

    return Scaffold(
      backgroundColor:
          AppTheme.bgWhite,

      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,

            children: [

              // ==================================================
              // APP ICON
              // ==================================================

              Container(
                width: logoSize,
                height: logoSize,

                decoration: BoxDecoration(
                  color:
                      AppTheme.primaryColor,

                  borderRadius:
                      BorderRadius.circular(20),
                ),

                child: Center(
                  child: Icon(
                    Icons.document_scanner,
                    size: iconSize,
                    color: Colors.white,
                  ),
                ),
              ),

              SizedBox(
                height: spacing,
              ),

              // ==================================================
              // APP NAME
              // ==================================================

              Text(
                AppConstants.appName,

                style: TextStyle(
                  fontSize:
                      appNameFontSize,

                  fontWeight:
                      FontWeight.bold,

                  color:
                      AppTheme.textPrimary,
                ),
              ),

              SizedBox(
                height:
                    spacing * 0.33,
              ),

              // ==================================================
              // TAGLINE
              // ==================================================

              Text(
                AppConstants.appTagline,

                style: TextStyle(
                  fontSize:
                      taglineFontSize,

                  color:
                      AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}