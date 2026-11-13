import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Central breakpoints for phone / tablet / desktop behaviour.
class Breakpoints {
  Breakpoints._();
  static const double compact = 600; // phones (portrait / small landscape)
  static const double medium = 1024; // tablets
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
  bool get isCompact => screenWidth < Breakpoints.compact;
  bool get isMedium => screenWidth >= Breakpoints.compact && screenWidth < Breakpoints.medium;
  bool get isExpanded => screenWidth >= Breakpoints.medium;

  /// Horizontal screen padding adapted to the device class.
  double get pagePadding => isCompact ? 12 : (isMedium ? 20 : 28);
}

/// Dialog shell that adapts to any screen: near full-width on phones, centered card with a
/// max width elsewhere; always scrollable, never taller than the visible area (keyboard aware).
class AdaptiveDialogShell extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;
  final Color backgroundColor;
  final double radius;

  const AdaptiveDialogShell({
    super.key,
    required this.child,
    this.maxWidth = 480,
    this.padding = const EdgeInsets.all(22),
    this.backgroundColor = Colors.white,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final insets = MediaQuery.viewInsetsOf(context);
    final compact = size.width < Breakpoints.compact;
    final hInset = compact ? 12.0 : 40.0;
    final vInset = compact ? 16.0 : 24.0;
    final width = math.min(maxWidth, size.width - hInset * 2);
    final maxHeight = math.max(240.0, size.height - insets.bottom - vInset * 2);

    return Dialog(
      backgroundColor: backgroundColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      insetPadding: EdgeInsets.symmetric(horizontal: hInset, vertical: vInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: maxHeight),
        child: SingleChildScrollView(padding: padding, child: child),
      ),
    );
  }
}

/// Adaptive modal: bottom sheet (full-width, keyboard aware, scrollable) on phones,
/// centered dialog on tablets/desktop. [builder] returns the CONTENT only (no Dialog).
Future<T?> showAdaptiveModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double maxWidth = 480,
  bool barrierDismissible = true,
}) {
  if (MediaQuery.sizeOf(context).width < Breakpoints.compact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: barrierDismissible,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: builder(ctx),
        ),
      ),
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => AdaptiveDialogShell(maxWidth: maxWidth, child: builder(ctx)),
  );
}

/// Drop-in adaptive equivalent for the app's existing AlertDialog flows.
/// On compact screens the dialog content is presented in a keyboard-aware sheet;
/// on larger screens it keeps Flutter's centered dialog route.
Future<T?> showResponsiveDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  bool useSafeArea = true,
}) {
  if (MediaQuery.sizeOf(context).width < Breakpoints.compact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: useSafeArea,
      isDismissible: barrierDismissible,
      enableDrag: barrierDismissible,
      backgroundColor: Colors.white,
      barrierColor: barrierColor,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          child: builder(ctx),
        ),
      ),
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    useSafeArea: useSafeArea,
    builder: builder,
  );
}

/// Adaptive replacement for bottom sheets used for menus and forms. Existing sheets stay
/// sheets on phones and become centered, scroll-constrained dialogs on wider screens.
Future<T?> showResponsiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  Color? backgroundColor,
  ShapeBorder? shape,
}) {
  if (MediaQuery.sizeOf(context).width < Breakpoints.compact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      backgroundColor: backgroundColor,
      shape: shape,
      builder: builder,
    );
  }
  final size = MediaQuery.sizeOf(context);
  return showDialog<T>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: backgroundColor,
      shape: shape,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(760, size.width - 48),
          maxHeight: size.height - 48,
        ),
        child: builder(ctx),
      ),
    ),
  );
}
