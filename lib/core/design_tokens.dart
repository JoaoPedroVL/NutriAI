// Tokens de design centralizados — elimina magic numbers e garante consistência.
// Use em vez de valores hardcoded: AppSpacing.md, AppRadius.lg, AppChart.height, etc.

import 'package:flutter/material.dart';

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
}

class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 28.0;
  static const double pill = 999.0;
}

class AppIconSize {
  static const double xs = 14.0;
  static const double sm = 18.0;
  static const double md = 22.0;
  static const double lg = 26.0;
  static const double xl = 32.0;
  static const double xxl = 44.0;
  static const double xxxl = 60.0;
}

class AppChart {
  static const double height = 190.0;
  static const double heightCompact = 150.0;
}

class AppTouchTarget {
  static const double minSize = 48.0;
  static const double compact = 40.0; // apenas onde espaço é crítico
}

class AppElevation {
  static const double level0 = 0.0;
  static const double level1 = 1.0;
  static const double level2 = 4.0;
  static const double level3 = 8.0;
}

class AppAnimation {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);
  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasis = Curves.easeInOutCubic;
}

class AppBreakpoints {
  static const double mobile = 600.0;
  static const double tablet = 900.0;
  static const double desktop = 1200.0;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobile;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobile &&
      MediaQuery.of(context).size.width < desktop;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktop;
}