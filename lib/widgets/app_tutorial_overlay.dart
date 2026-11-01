import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/tutorial_service.dart';
import '../providers/settings_provider.dart';
import '../models/app_language.dart';
import '../theme/premium_theme.dart';

class AppTutorialOverlay extends StatefulWidget {
  final Widget child;

  const AppTutorialOverlay({super.key, required this.child});

  @override
  State<AppTutorialOverlay> createState() => _AppTutorialOverlayState();
}

class _AppTutorialOverlayState extends State<AppTutorialOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _bounceController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _bounceAnimation;

  Rect? _targetRect;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    TutorialService.instance.addListener(_onTutorialChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateTargetPosition();
    });
  }

  @override
  void dispose() {
    TutorialService.instance.removeListener(_onTutorialChanged);
    _pulseController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void _onTutorialChanged() {
    _retryCount = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateTargetPosition();
    });
  }

  void _updateTargetPosition() {
    if (!mounted) return;

    final service = TutorialService.instance;
    if (!service.isTutorialActive) {
      if (_targetRect != null) {
        setState(() => _targetRect = null);
      }
      return;
    }

    if (service.currentStepIndex < 0 || service.currentStepIndex >= service.steps.length) {
      return;
    }

    final currentStep = service.steps[service.currentStepIndex];
    final key = currentStep.key;
    final targetContext = key.currentContext;

    if (targetContext != null && targetContext.mounted) {
      final renderBox = targetContext.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.attached) {
        final position = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;
        final rect = Rect.fromLTWH(position.dx, position.dy, size.width, size.height);

        if (_targetRect != rect) {
          setState(() {
            _targetRect = rect;
          });
        }
        return;
      }
    }

    if (_retryCount < 8) {
      _retryCount++;
      Future.delayed(const Duration(milliseconds: 60), () {
        if (mounted) _updateTargetPosition();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TutorialService.instance,
      builder: (context, _) {
        final service = TutorialService.instance;
        final isActive = service.isTutorialActive;

        return Stack(
          children: [
            widget.child,

            if (isActive)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: Consumer<SettingsProvider>(
                    builder: (context, settings, child) {
                      return _buildOverlayContent(context, service, settings.language);
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildOverlayContent(BuildContext context, TutorialService service, AppLanguage lang) {
    final screenSize = MediaQuery.of(context).size;
    final currentStep = service.steps[service.currentStepIndex];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final rect = _targetRect ?? Rect.fromLTWH(screenSize.width / 2 - 30, screenSize.height / 2 - 30, 60, 60);
    const double padding = 8.0;
    final paddedRect = Rect.fromLTRB(
      rect.left - padding,
      rect.top - padding,
      rect.right + padding,
      rect.bottom + padding,
    );

    final isTargetInLowerHalf = paddedRect.top > screenSize.height * 0.45;

    return Stack(
      children: [
        // Dark Mask Overlay with Cutout - Tapping backdrop advances to next step
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            service.nextStep();
          },
          child: CustomPaint(
            size: screenSize,
            painter: _SpotlightPainter(
              targetRect: paddedRect,
              borderRadius: 20.0,
            ),
          ),
        ),

        // Animated Pulsing Spotlight Halo Ring around Target Box
        Positioned(
          left: paddedRect.left,
          top: paddedRect.top,
          width: paddedRect.width,
          height: paddedRect.height,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.9),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.6),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Animated Bouncing Arrow Pointer Indicator
        AnimatedBuilder(
          animation: _bounceAnimation,
          builder: (context, child) {
            final dyOffset = _bounceAnimation.value;
            final isAbove = isTargetInLowerHalf;
            final topPos = isAbove
                ? (paddedRect.top - 52 - dyOffset)
                : (paddedRect.bottom + 10 + dyOffset);

            final centerX = (paddedRect.left + paddedRect.width / 2).clamp(32.0, screenSize.width - 32.0);

            return Positioned(
              left: centerX - 22,
              top: topPos,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppGradients.electric,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.6),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    isAbove ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            );
          },
        ),

        // Explanatory Floating Tooltip Card
        _buildExplanationCard(
          context: context,
          service: service,
          step: currentStep,
          isTargetInLowerHalf: isTargetInLowerHalf,
          targetRect: paddedRect,
          screenSize: screenSize,
          isDark: isDark,
          lang: lang,
        ),
      ],
    );
  }

  Widget _buildExplanationCard({
    required BuildContext context,
    required TutorialService service,
    required TutorialStep step,
    required bool isTargetInLowerHalf,
    required Rect targetRect,
    required Size screenSize,
    required bool isDark,
    required AppLanguage lang,
  }) {
    final double cardWidth = screenSize.width - 32;

    double topPosition;
    if (isTargetInLowerHalf) {
      topPosition = (targetRect.top - 280).clamp(MediaQuery.of(context).padding.top + 10, screenSize.height - 300);
    } else {
      topPosition = (targetRect.bottom + 70).clamp(100.0, screenSize.height - 290);
    }

    final totalSteps = service.steps.length;
    final currentStepNum = service.currentStepIndex + 1;

    final isLastStep = service.currentStepIndex == totalSteps - 1;
    final isFirstStep = service.currentStepIndex == 0;

    final isTagalog = lang == AppLanguage.tagalog;
    final stepBadgeLabel = isTagalog
        ? 'HAKBANG $currentStepNum SA $totalSteps'
        : 'STEP $currentStepNum OF $totalSteps';
    final skipLabel = isTagalog ? 'Laktawan' : 'Skip';
    final prevLabel = isTagalog ? 'Nakaraan' : 'Previous';
    final nextLabel = isTagalog ? 'Susunod' : 'Next';
    final finishLabel = isTagalog ? 'Tapusin' : 'Finish';

    return Positioned(
      left: 16,
      top: topPosition,
      width: cardWidth,
      child: GestureDetector(
        // Prevent background tap from firing when tapping inside card
        onTap: () {},
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F1D32) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0),
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.2),
                blurRadius: 30,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Step Indicator & Skip Button
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: AppGradients.ocean,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(step.icon, color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          stepBadgeLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      service.skipTutorial();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        skipLabel,
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Title
              Text(
                step.getTitle(lang),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F1D32),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),

              // Description Explanation
              Text(
                step.getDescription(lang),
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 18),

              // Progress Bar Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  totalSteps,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: index == service.currentStepIndex ? 22 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: index == service.currentStepIndex
                          ? AppColors.primary
                          : (isDark ? const Color(0xFF1E3A5F) : const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Action Buttons Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!isFirstStep)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        service.prevStep();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back_rounded, size: 16, color: isDark ? Colors.white : const Color(0xFF0F1D32)),
                            const SizedBox(width: 4),
                            Text(
                              prevLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: isDark ? Colors.white : const Color(0xFF0F1D32),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),

                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      service.nextStep();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: AppGradients.ocean,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isLastStep ? finishLabel : nextLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                          if (!isLastStep) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect targetRect;
  final double borderRadius;

  _SpotlightPainter({
    required this.targetRect,
    this.borderRadius = 20.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final spotlightPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          targetRect,
          Radius.circular(borderRadius),
        ),
      );

    final combinedPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      spotlightPath,
    );

    final paint = Paint()..color = Colors.black.withValues(alpha: 0.78);
    canvas.drawPath(combinedPath, paint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.borderRadius != borderRadius;
  }
}
