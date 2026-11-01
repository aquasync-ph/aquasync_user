import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum SweetAlertType {
  success,
  error,
  warning,
  info,
}

class SweetAlert extends StatefulWidget {
  final String message;
  final String? title;
  final SweetAlertType type;
  final Duration duration;
  final bool autoDismiss;
  final VoidCallback? onConfirm;

  const SweetAlert({
    super.key,
    required this.message,
    this.title,
    this.type = SweetAlertType.success,
    this.duration = const Duration(milliseconds: 2800),
    this.autoDismiss = true,
    this.onConfirm,
  });

  static Future<void> show(
    BuildContext context,
    String message, {
    bool isError = false,
    SweetAlertType? type,
    String? title,
    Duration duration = const Duration(milliseconds: 2800),
    bool autoDismiss = true,
    VoidCallback? onConfirm,
  }) async {
    final alertType = type ?? (isError ? SweetAlertType.error : SweetAlertType.success);

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogCtx) {
        return SweetAlert(
          message: message,
          title: title,
          type: alertType,
          duration: duration,
          autoDismiss: autoDismiss,
          onConfirm: onConfirm,
        );
      },
    );
  }

  static Future<bool?> showConfirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Yes, Proceed',
    String cancelText = 'Cancel',
    bool isDanger = true,
  }) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
        final titleTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final bodyTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
        final primaryColor = isDanger ? const Color(0xFFEF4444) : const Color(0xFF0284C7);

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          elevation: 16,
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: dialogBg,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.22),
                  blurRadius: 28,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.35),
                      width: 2.5,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isDanger ? Icons.warning_amber_rounded : Icons.help_outline_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: titleTextColor,
                    letterSpacing: -0.3,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: bodyTextColor,
                    height: 1.4,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogCtx, false),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: borderColor, width: 1.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: Text(
                            cancelText,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: bodyTextColor,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(dialogCtx, true),
                          style: ElevatedButton.styleFrom(
                            elevation: 4,
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: Text(
                            confirmText,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  State<SweetAlert> createState() => _SweetAlertState();
}

class _SweetAlertState extends State<SweetAlert> with SingleTickerProviderStateMixin {
  Timer? _timer;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _animController.forward();

    if (widget.autoDismiss) {
      _timer = Timer(widget.duration, () {
        _closeDialog();
      });
    }
  }

  void _closeDialog() {
    if (_timer?.isActive ?? false) {
      _timer?.cancel();
    }
    if (mounted && Navigator.canPop(context)) {
      Navigator.of(context, rootNavigator: true).pop();
      widget.onConfirm?.call();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color primaryColor;
    IconData iconData;
    String defaultTitle;

    switch (widget.type) {
      case SweetAlertType.error:
        primaryColor = const Color(0xFFEF4444);
        iconData = Icons.close_rounded;
        defaultTitle = 'Notice';
        break;
      case SweetAlertType.warning:
        primaryColor = const Color(0xFFF59E0B);
        iconData = Icons.priority_high_rounded;
        defaultTitle = 'Warning';
        break;
      case SweetAlertType.info:
        primaryColor = const Color(0xFF0284C7);
        iconData = Icons.info_outline_rounded;
        defaultTitle = 'Notice';
        break;
      case SweetAlertType.success:
      default:
        primaryColor = const Color(0xFF10B981);
        iconData = Icons.check_rounded;
        defaultTitle = 'Success!';
        break;
    }

    String displayTitle = widget.title ?? defaultTitle;
    String displayMessage = widget.message;

    if (widget.title == null) {
      if (displayMessage.startsWith('🔔')) {
        displayMessage = displayMessage.replaceFirst('🔔', '').trim();
        displayTitle = 'Notification';
        if (displayMessage.contains(': ')) {
          final parts = displayMessage.split(': ');
          displayTitle = parts[0].trim();
          displayMessage = parts.sublist(1).join(': ').trim();
        }
      } else if (displayMessage.contains('updated:')) {
        final parts = displayMessage.split('updated:');
        displayTitle = '${parts[0].trim()} Updated';
        displayMessage = parts[1].trim();
      } else if (displayMessage.contains('pinned:')) {
        final parts = displayMessage.split('pinned:');
        displayTitle = '${parts[0].trim()} Pinned';
        displayMessage = parts[1].trim();
      }
    }

    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final bodyTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          elevation: 16,
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: dialogBg,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.22),
                  blurRadius: 28,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.35),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.25),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        iconData,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  displayTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: titleTextColor,
                    letterSpacing: -0.3,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  displayMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: bodyTextColor,
                    height: 1.4,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _closeDialog,
                    style: ElevatedButton.styleFrom(
                      elevation: 4,
                      shadowColor: primaryColor.withValues(alpha: 0.4),
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        fontFamily: 'Poppins',
                      ),
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

class TopBanner {
  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(milliseconds: 2800),
    String? title,
    VoidCallback? onConfirm,
  }) {
    SweetAlert.show(
      context,
      message,
      isError: isError,
      title: title,
      duration: duration,
      onConfirm: onConfirm,
    );
  }
}
