import 'package:flutter/material.dart';

class ResponsiveHelper {
  static const double smallMobileMaxWidth = 360;
  static const double mobileMaxWidth = 600;
  static const double tabletMaxWidth = 1200;

  static bool isSmallMobile(BuildContext context) {
    return MediaQuery.of(context).size.width <= smallMobileMaxWidth;
  }

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileMaxWidth;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileMaxWidth && width < tabletMaxWidth;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletMaxWidth;
  }

  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  static double getResponsivePadding(BuildContext context) {
    if (isSmallMobile(context)) {
      return 12;
    } else if (isMobile(context)) {
      return 16;
    } else if (isTablet(context)) {
      return 24;
    } else {
      return 32;
    }
  }

  static double horizontalPadding(BuildContext context) {
    return getResponsivePadding(context);
  }

  static double getResponsiveButtonHeight(BuildContext context) {
    if (isSmallMobile(context)) {
      return 44;
    } else if (isMobile(context)) {
      return 48;
    } else {
      return 56;
    }
  }

  static double getResponsiveFontSize(
    BuildContext context, {
    required double mobileSize,
    double? tabletSize,
    double? desktopSize,
  }) {
    if (isSmallMobile(context)) {
      return mobileSize > 13 ? mobileSize - 1.5 : mobileSize;
    } else if (isMobile(context)) {
      return mobileSize;
    } else if (isTablet(context)) {
      return tabletSize ?? mobileSize + 2;
    } else {
      return desktopSize ?? mobileSize + 4;
    }
  }

  static int getGridCrossAxisCount(BuildContext context) {
    final width = getScreenWidth(context);
    if (width < mobileMaxWidth) {
      if (isLandscape(context)) return 3;
      return 2;
    } else if (width < tabletMaxWidth) {
      return 3;
    } else {
      return 4;
    }
  }

  static double getGridSpacing(BuildContext context) {
    if (isSmallMobile(context)) {
      return 6;
    } else if (isMobile(context)) {
      return 8;
    } else if (isTablet(context)) {
      return 12;
    } else {
      return 16;
    }
  }

  static BoxConstraints getConstrainedWidth(BuildContext context) {
    final width = getScreenWidth(context);
    if (isDesktop(context)) {
      return const BoxConstraints(maxWidth: tabletMaxWidth);
    }
    return BoxConstraints(maxWidth: width);
  }
}
