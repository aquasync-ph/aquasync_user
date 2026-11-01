import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/supabase_service.dart';
import '../../services/email_service.dart';
import '../../widgets/top_banner.dart';
import 'register_screen.dart';
import '../../theme/premium_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _waveController;
  late AnimationController _rippleController;
  late AnimationController _glowController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );

    _glowAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _mainController.forward();
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    final nav = Navigator.of(context);
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;

    final currentUser = SupabaseService.currentUser;
    if (currentUser != null) {
      try {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.fetchProfileForUser(currentUser);
        if (!mounted) return;

        final profileData = await SupabaseService.fetchProfile(currentUser.id);

        final metaVerified = (currentUser.userMetadata?['is_verified'] as bool?) ?? false;
        final emailConfirmed = currentUser.emailConfirmedAt != null;
        final profileVerified = (profileData?['is_verified'] as bool?) ?? false;
        final profileApproved = (profileData?['approval_status'] as String?)?.toLowerCase() == 'approved' ||
                                (profileData?['status'] as String?)?.toLowerCase() == 'active' ||
                                (profileData?['is_approved'] as bool?) == true;

        bool isVerified = metaVerified || emailConfirmed || profileVerified || profileApproved;
        if (profileData == null) {
          isVerified = true;
        }

        if (!isVerified) {
          final email = currentUser.email ?? '';
          final fullName = profileData?['full_name'] as String? ??
              currentUser.userMetadata?['full_name'] as String? ??
              'Valued Customer';

          final otpCode = EmailService.generateOtp();
          await EmailService.sendAccountVerificationOtp(
            email: email,
            name: fullName,
            otpCode: otpCode,
          );

          if (!mounted) return;

          TopBanner.show(
            context,
            'Account unverified. A 6-digit verification code was sent to $email.',
            isError: false,
          );

          nav.pushReplacement(
            MaterialPageRoute(
              builder: (context) => RegisterScreen(
                isVerificationOnly: true,
                email: email,
                fullName: fullName,
                initialOtp: otpCode,
              ),
            ),
          );
          return;
        }

        if (profileData != null &&
            ((profileData['is_verified'] == false) ||
             profileData['approval_status'] == 'pending' ||
             profileData['status'] == 'pending' ||
             profileData['is_approved'] == false)) {
          SupabaseService.updateProfile(
            userId: currentUser.id,
            updates: {
              'is_verified': true,
              'status': 'active',
              'approval_status': 'approved',
              'is_approved': true,
            },
          ).catchError((e) {
            debugPrint('Splash profile auto-heal notice: $e');
          });
        }

        if (!mounted) return;
        nav.pushReplacementNamed('/main');
        return;
      } catch (_) {}
    }

    if (mounted) {
      nav.pushReplacementNamed('/login');
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _waveController.dispose();
    _rippleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paletteMidnight,
      body: Stack(
        children: [
          // Dark Ocean Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF01082D), Color(0xFF041D56), Color(0xFF0F2573)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Animated Organic Flowing Water Waves at Bottom
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return CustomPaint(
                size: Size.infinite,
                painter: WaterWavePainter(_waveController.value),
              );
            },
          ),

          // Animated Water Ripples
          AnimatedBuilder(
            animation: _rippleController,
            builder: (context, child) {
              return CustomPaint(
                size: Size.infinite,
                painter: WaterRipplePainter(_rippleController.value),
              );
            },
          ),

          // Rising Water Bubbles Animation
          const _FloatingWaterBubbles(),

          // Center Branding Section
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_mainController, _glowController]),
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Connected Hero Water Drop Sphere Logo
                        Hero(
                          tag: 'aquasync_header_logo',
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Transform.scale(
                                scale: _glowAnimation.value,
                                child: Container(
                                  width: 150,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                                        blurRadius: 50,
                                        spreadRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(26),
                                decoration: BoxDecoration(
                                  gradient: AppGradients.electric,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.paletteMedium.withValues(alpha: 0.45),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.water_drop_rounded,
                                  size: 68,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        const Text(
                          'AQUASYNC',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 3.0,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 8),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.water, color: Color(0xFF38BDF8), size: 14),
                              SizedBox(width: 6),
                              Text(
                                'PREMIUM WATER LOGISTICS • USER APP',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 2.0,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 80),

                        // Liquid Progress Bar & Shimmer
                        SizedBox(
                          width: 150,
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: const LinearProgressIndicator(
                                  backgroundColor: Colors.white12,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                                  minHeight: 3,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'LOADING WATER PORTAL...',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white.withValues(alpha: 0.45),
                                  letterSpacing: 1.5,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class WaterWavePainter extends CustomPainter {
  final double animationValue;

  WaterWavePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final wave1 = Paint()
      ..color = const Color(0xFF266CA9).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final wave2 = Paint()
      ..color = const Color(0xFFADE1FB).withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final path1 = Path();
    final path2 = Path();

    final baseHeight = size.height * 0.78;

    path1.moveTo(0, size.height);
    path1.lineTo(0, baseHeight);

    path2.moveTo(0, size.height);
    path2.lineTo(0, baseHeight + 10);

    for (double x = 0; x <= size.width; x += 5) {
      final y1 = baseHeight + math.sin((x / size.width * 2 * math.pi) + (animationValue * 2 * math.pi)) * 14;
      path1.lineTo(x, y1);

      final y2 = baseHeight + 10 + math.sin((x / size.width * 2 * math.pi) - (animationValue * 2 * math.pi) + math.pi / 2) * 18;
      path2.lineTo(x, y2);
    }

    path1.lineTo(size.width, size.height);
    path1.close();

    path2.lineTo(size.width, size.height);
    path2.close();

    canvas.drawPath(path2, wave2);
    canvas.drawPath(path1, wave1);
  }

  @override
  bool shouldRepaint(covariant WaterWavePainter oldDelegate) => true;
}

class WaterRipplePainter extends CustomPainter {
  final double animationValue;

  WaterRipplePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < 3; i++) {
      final progress = (animationValue + i * 0.33) % 1.0;
      final radius = progress * (size.width * 0.55);
      final opacity = (1.0 - progress).clamp(0.0, 1.0) * 0.35;

      final paint = Paint()
        ..color = const Color(0xFFADE1FB).withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 + (1.0 - progress) * 3.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant WaterRipplePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class _FloatingWaterBubbles extends StatefulWidget {
  const _FloatingWaterBubbles();

  @override
  State<_FloatingWaterBubbles> createState() => _FloatingWaterBubblesState();
}

class _FloatingWaterBubblesState extends State<_FloatingWaterBubbles> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = _controller.value;
        return Stack(
          children: [
            _buildBubble(bottom: val * 450 + 40, left: 50, size: 26, opacity: 0.25),
            _buildBubble(bottom: val * 580 + 30, right: 70, size: 20, opacity: 0.30),
            _buildBubble(bottom: val * 380 + 120, left: 190, size: 16, opacity: 0.20),
            _buildBubble(bottom: val * 620 + 90, right: 150, size: 32, opacity: 0.18),
          ],
        );
      },
    );
  }

  Widget _buildBubble({
    required double bottom,
    double? left,
    double? right,
    required double size,
    required double opacity,
  }) {
    return Positioned(
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF38BDF8).withValues(alpha: opacity),
          border: Border.all(
            color: Colors.white.withValues(alpha: opacity * 1.5),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF38BDF8).withValues(alpha: opacity * 0.5),
              blurRadius: 10,
            ),
          ],
        ),
      ),
    );
  }
}
