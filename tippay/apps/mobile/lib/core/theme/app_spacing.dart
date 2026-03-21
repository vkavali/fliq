import 'package:flutter/material.dart';

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const paddingXs = EdgeInsets.all(xs);
  static const paddingSm = EdgeInsets.all(sm);
  static const paddingMd = EdgeInsets.all(md);
  static const paddingLg = EdgeInsets.all(lg);
  static const paddingXl = EdgeInsets.all(xl);

  static const horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const horizontalLg = EdgeInsets.symmetric(horizontal: lg);

  static const verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const verticalMd = EdgeInsets.symmetric(vertical: md);
}
