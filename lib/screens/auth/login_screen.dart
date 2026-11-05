import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/user_provider.dart';
import '../../services/email_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/premium_theme.dart';
import '../../widgets/top_banner.dart';
import 'register_screen.dart';

/// Helper utility for Login and Authentication validations
class LoginValidationUtils {
  // Strict Email Regex: requires valid local part, @, domain name, and TLD (e.g. .com, .ph)
  static final RegExp _emailRegex = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
  );

  // Set of disposable / temporary email domains to reject in real-world production
  static final Set<String> _disposableDomains = {
    'tempmail.com',
    'mailinator.com',
    'yopmail.com',
    '10minutemail.com',
    'guerrillamail.com',
    'trashmail.com',
    'dispostable.com',
    'getnada.com',
    'sharklasers.com',
    'temp-mail.org',
    'fakeinbox.com',
  };

  /// Check if input string contains emojis
  static bool containsEmoji(String input) {
    final RegExp emojiRegex = RegExp(
      r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
      unicode: true,
    );
    return emojiRegex.hasMatch(input);
  }

  /// Sanitize input string by removing linebreaks, tabs, and leading/trailing spaces
  static String sanitizeInput(String raw) {
    return raw.replaceAll(RegExp(r'[\r\n\t]'), '').trim();
  }

  /// Check if email is from a disposable/temporary provider
  static bool isDisposableEmail(String raw) {
    final clean = sanitizeInput(raw).toLowerCase();
    final parts = clean.split('@');
    if (parts.length != 2) return false;
    return _disposableDomains.contains(parts[1]);
  }

  /// Detect domain typos for user helpfulness (e.g. @gamil.com -> @gmail.com)
  static String? detectEmailDomainTypo(String raw) {
    final clean = sanitizeInput(raw).toLowerCase();
    if (clean.contains('@gamil.com') || clean.contains('@gnail.com')) {
      return 'Did you mean @gmail.com?';
    } else if (clean.contains('@yaho.com') || clean.contains('@yaho.co')) {
      return 'Did you mean @yahoo.com?';
    } else if (clean.contains('@hotnail.com') || clean.contains('@hotmial.com')) {
      return 'Did you mean @hotmail.com?';
    } else if (clean.contains('@outlok.com')) {
      return 'Did you mean @outlook.com?';
    }
    return null;
  }

  /// Validate Email Address format strictly
  static bool isValidEmail(String raw) {
    final clean = sanitizeInput(raw);
    if (clean.isEmpty || clean.contains(' ') || containsEmoji(clean)) return false;
    if (clean.startsWith('.') || clean.endsWith('.')) return false;
    if (clean.contains('..')) return false;

    final parts = clean.split('@');
    if (parts.length != 2) return false; // Exactly one @
    final username = parts[0];
    final domain = parts[1];

    if (username.isEmpty || domain.isEmpty) return false;
    if (!domain.contains('.') || domain.startsWith('.') || domain.endsWith('.')) return false;

    final domainParts = domain.split('.');
    if (domainParts.last.length < 2) return false;

    return _emailRegex.hasMatch(clean);
  }

  /// Validate Email Input Field Strictly
  static String? validateEmailOnly(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Email address is required.';
    }
    final clean = sanitizeInput(raw);
    if (clean.isEmpty) {
      return 'Email address is required.';
    }
    if (containsEmoji(clean) || !isValidEmail(clean)) {
      return 'Please enter a valid email address.';
    }
    if (isDisposableEmail(clean)) {
      return 'Disposable or temporary email addresses are not allowed.';
    }
    return null;
  }

  /// Validate Password field (Login)
  static String? validatePassword(String? raw) {
    if (raw == null || raw.isEmpty) {
      return 'Password is required.';
    }
    if (raw.trim().isEmpty) {
      return 'Password is required.';
    }
    if (raw.trim().length < 8) {
      return 'Password must be at least 8 characters.';
    }
    if (raw.length > 64) {
      return 'Password must not exceed 64 characters.';
    }
    return null;
  }

  /// Validate New Password Strength (Forgot Password / Reset)
  static String? validateNewPasswordStrength(String? raw) {
    if (raw == null || raw.isEmpty) {
      return 'New password is required.';
    }
    if (raw.trim().isEmpty) {
      return 'New password is required.';
    }
    if (raw.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    if (raw.length > 64) {
      return 'Password must not exceed 64 characters.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(raw)) {
      return 'Password must contain an uppercase letter.';
    }
    if (!RegExp(r'[a-z]').hasMatch(raw)) {
      return 'Password must contain a lowercase letter.';
    }
    if (!RegExp(r'[0-9]').hasMatch(raw)) {
      return 'Password must contain a number.';
    }
    if (!RegExp(r'''[!@#$%^&*(),.?\"{}|<>_+\-~`=\[\]/\\;']''').hasMatch(raw)) {
      return 'Password must contain a special character.';
    }
    return null;
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _emailTypoWarning;

  // Rate Limiting / Brute Force Lockout
  int _failedAttempts = 0;
  DateTime? _lockoutEndTime;

  late AnimationController _entranceController;
  late AnimationController _shakeController;
  late Animation<double> _bodyFade;
  late Animation<Offset> _bodySlide;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);

    _bodyFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.2, 0.8, curve: Curves.easeIn)),
    );

    _bodySlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.2, 0.9, curve: Curves.fastOutSlowIn)),
    );

    _entranceController.forward();
  }

  void _shake() {
    _shakeController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _shakeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _checkEmailTypo(String value) {
    setState(() {
      _emailTypoWarning = LoginValidationUtils.detectEmailDomainTypo(value);
    });
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;

    // Check Lockout
    if (_lockoutEndTime != null && DateTime.now().isBefore(_lockoutEndTime!)) {
      final remainingSeconds = _lockoutEndTime!.difference(DateTime.now()).inSeconds;
      _shake();
      TopBanner.show(
        context,
        'Too many failed login attempts. Please wait $remainingSeconds seconds before trying again.',
        isError: true,
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _shake();
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    final email = LoginValidationUtils.sanitizeInput(_emailController.text).toLowerCase();
    final password = _passwordController.text;

    if (!LoginValidationUtils.isValidEmail(email)) {
      _shake();
      TopBanner.show(context, 'Please enter a valid email address.', isError: true);
      setState(() => _isLoading = false);
      return;
    }

    if (LoginValidationUtils.isDisposableEmail(email)) {
      _shake();
      TopBanner.show(context, 'Disposable or temporary email addresses are not allowed.', isError: true);
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await SupabaseService.signInWithPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      final user = response.user;
      if (user != null) {
        _failedAttempts = 0; // Reset failed attempts on success

        final profileData = await SupabaseService.fetchProfile(user.id);

        if (profileData != null) {
          final role = (profileData['role'] as String?)?.toLowerCase() ?? 'customer';
          if (role != 'customer') {
            await SupabaseService.signOut();
            if (!mounted) return;
            _shake();
            TopBanner.show(context, 'Access Denied: This app is strictly for Customers only.', isError: true);
            setState(() => _isLoading = false);
            return;
          }

          final isBlocked = (profileData['is_blocked'] as bool?) ?? false;
          final status = (profileData['status'] as String?)?.toLowerCase();
          if (isBlocked || status == 'blocked' || status == 'inactive' || status == 'disabled') {
            await SupabaseService.signOut();
            if (!mounted) return;
            _shake();
            TopBanner.show(context, 'This account is currently blocked. Please contact support.', isError: true);
            setState(() => _isLoading = false);
            return;
          }
        }

        final metaVerified = (user.userMetadata?['is_verified'] as bool?) ?? false;
        final emailConfirmed = user.emailConfirmedAt != null;
        final profileVerified = (profileData?['is_verified'] as bool?) ?? false;
        final profileApproved = (profileData?['approval_status'] as String?)?.toLowerCase() == 'approved' ||
                                (profileData?['status'] as String?)?.toLowerCase() == 'active' ||
                                (profileData?['is_approved'] as bool?) == true;

        bool isVerified = metaVerified || emailConfirmed || profileVerified || profileApproved;
        if (profileData == null) {
          isVerified = true;
        }

        if (!isVerified) {
          final fullName = profileData?['full_name'] as String? ??
              user.userMetadata?['full_name'] as String? ??
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

          Navigator.of(context).push(
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
            userId: user.id,
            updates: {
              'is_verified': true,
              'status': 'active',
              'approval_status': 'approved',
              'is_approved': true,
            },
          ).catchError((e) {
            debugPrint('Login profile auto-heal notice: $e');
          });
        }

        if (!mounted) return;

        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.fetchProfileForUser(user);

        if (!mounted) return;
        _showSuccessDialog(userProvider.displayName);
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      _shake();
      _failedAttempts++;
      if (_failedAttempts >= 5) {
        _lockoutEndTime = DateTime.now().add(const Duration(seconds: 60));
        TopBanner.show(
          context,
          'Too many failed login attempts. Account locked for 60 seconds.',
          isError: true,
        );
      } else {
        String message = e.message;
        if (e.message.contains('Invalid login credentials')) {
          message = 'Invalid email address or password. (${5 - _failedAttempts} attempts left)';
        } else if (e.message.toLowerCase().contains('email not confirmed')) {
          message = 'Email address is not confirmed. Please check your email inbox.';
        } else if (e.message.toLowerCase().contains('email logins are disabled') ||
                   e.message.toLowerCase().contains('email_provider_disabled')) {
          message = 'Email login is currently disabled in system configuration.';
        }
        TopBanner.show(context, message, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _shake();
      TopBanner.show(context, 'Unable to connect to the server. Please check your network connection.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog(String name) {
    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(28.0),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    spreadRadius: 5,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        ),
                      ),
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Login Successful',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.verified_rounded, color: Color(0xFF0284C7), size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Welcome back, $name!',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF0369A1),
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Establishing secure session & loading portal...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
      }
    });
  }

  void _showForgotPasswordDialog() async {
    HapticFeedback.lightImpact();
    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: true,
      builder: (context) => ForgotPasswordDialog(
        initialEmail: _emailController.text.trim(),
      ),
    );

    if (result != null && result['password'] != null) {
      setState(() {
        if (result['email'] != null && result['email']!.isNotEmpty) {
          _emailController.text = result['email']!;
        }
        _passwordController.text = result['password']!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isDesktop = mediaQuery.size.width >= 700;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFDFF),
      body: SingleChildScrollView(
        child: AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_shakeAnimation.value, 0),
              child: child,
            );
          },
          child: Column(
            children: [
              // Top Curved Dark Arc Header
              ClipPath(
                clipper: HeaderArcClipper(),
                child: AnimatedBuilder(
                  animation: _entranceController,
                  builder: (context, child) {
                    return Container(
                      width: double.infinity,
                      height: isDesktop ? 300 : 250,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF01082D), Color(0xFF041D56), Color(0xFF0F2573)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Hero(
                                    tag: 'aquasync_header_logo',
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        gradient: AppGradients.electric,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.paletteMedium.withValues(alpha: 0.4),
                                            blurRadius: 16,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.water_drop_rounded,
                                        size: 26,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  const Text(
                                    'AQUASYNC',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 2.0,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Welcome back! Log in to order water.',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.8),
                                  letterSpacing: 0.3,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Form Body Section below the Arc
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 8.0),
                    child: SlideTransition(
                      position: _bodySlide,
                      child: FadeTransition(
                        opacity: _bodyFade,
                        child: Form(
                          key: _formKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.paletteNavy,
                                  letterSpacing: -0.5,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              const SizedBox(height: 28),

                              const Text(
                                'Email Address',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.paletteNavy,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                maxLength: 254,
                                onChanged: _checkEmailTypo,
                                inputFormatters: [
                                  FilteringTextInputFormatter.deny(RegExp(r'[\r\n\t]')),
                                ],
                                style: const TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'user@aquasync.com',
                                  counterText: '',
                                  prefixIcon: const Icon(Icons.email_outlined, color: AppColors.paletteMedium),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppColors.paletteMedium, width: 2),
                                  ),
                                ),
                                validator: LoginValidationUtils.validateEmailOnly,
                              ),
                              if (_emailTypoWarning != null) ...[
                                const SizedBox(height: 6),
                                Text(_emailTypoWarning!, style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                              const SizedBox(height: 20),

                              const Text(
                                'Password',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.paletteNavy,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                maxLength: 64,
                                inputFormatters: [
                                  FilteringTextInputFormatter.deny(RegExp(r'[\r\n\t]')),
                                ],
                                style: const TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: '••••••••',
                                  counterText: '',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.paletteMedium),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      color: AppColors.slate,
                                    ),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppColors.paletteMedium, width: 2),
                                  ),
                                ),
                                validator: LoginValidationUtils.validatePassword,
                              ),

                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _showForgotPasswordDialog,
                                  child: const Text(
                                    'Forgot password?',
                                    style: TextStyle(
                                      color: AppColors.paletteNavy,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Full Width Button
                              SizedBox(
                                height: 56,
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.paletteMidnight,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                    elevation: 6,
                                    shadowColor: AppColors.paletteMidnight.withValues(alpha: 0.35),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Login',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.8,
                                            fontFamily: 'Poppins',
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Modern Create Account CTA Card
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                                decoration: BoxDecoration(
                                  color: AppColors.paletteLight.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.paletteMedium.withValues(alpha: 0.2), width: 1.5),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      "Don't have an account? ",
                                      style: TextStyle(
                                        color: AppColors.slate,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => Navigator.pushNamed(context, '/register'),
                                      child: const Text(
                                        'Create Account',
                                        style: TextStyle(
                                          color: AppColors.paletteMedium,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          fontFamily: 'Poppins',
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Authorized Notice Footer
                              const Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.verified_user_rounded, size: 16, color: AppColors.slate),
                                    SizedBox(width: 6),
                                    Text(
                                      'Authorized AquaSync Customer Portal',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.slate,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HeaderArcClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 45);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height + 35,
      size.width,
      size.height - 45,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class ForgotPasswordDialog extends StatefulWidget {
  final String? initialEmail;

  const ForgotPasswordDialog({super.key, this.initialEmail});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  int _currentStep = 0; // 0: Request Code, 1: Verify Code & Reset Password
  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String _generatedOtp = '';
  String _targetEmail = '';
  Timer? _timer;
  int _secondsRemaining = 0;
  int _otpFailedAttempts = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startCooldownTimer() {
    _timer?.cancel();
    setState(() => _secondsRemaining = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _sendResetCode() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    final emailInput = LoginValidationUtils.sanitizeInput(_emailController.text).toLowerCase();

    if (!LoginValidationUtils.isValidEmail(emailInput)) {
      TopBanner.show(context, 'Please enter a valid email address.', isError: true);
      setState(() => _isLoading = false);
      return;
    }

    if (LoginValidationUtils.isDisposableEmail(emailInput)) {
      TopBanner.show(context, 'Disposable or temporary email addresses are not allowed.', isError: true);
      setState(() => _isLoading = false);
      return;
    }

    _targetEmail = emailInput;
    _generatedOtp = EmailService.generateOtp();
    _otpFailedAttempts = 0;

    try {
      final sent = await EmailService.sendPasswordResetOtp(
        email: _targetEmail,
        otpCode: _generatedOtp,
      );

      if (mounted) {
        _startCooldownTimer();
        setState(() => _currentStep = 1);
        if (sent) {
          TopBanner.show(
            context,
            'A 6-digit password reset code was sent to $_targetEmail! Please check your inbox.',
            isError: false,
            duration: const Duration(seconds: 4),
          );
        } else {
          final err = EmailService.lastErrorMessage.isNotEmpty
              ? EmailService.lastErrorMessage
              : 'Failed to send reset code via Resend.';
          TopBanner.show(
            context,
            'Resend Error: $err\n\nReset Code: $_generatedOtp',
            isError: true,
            duration: const Duration(seconds: 10),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        TopBanner.show(context, 'Unable to connect to server. Please try again.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendResetCode() async {
    if (_secondsRemaining > 0 || _isLoading) return;
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    _generatedOtp = EmailService.generateOtp();
    _otpFailedAttempts = 0;

    try {
      final sent = await EmailService.sendPasswordResetOtp(
        email: _targetEmail,
        otpCode: _generatedOtp,
      );

      if (mounted) {
        _startCooldownTimer();
        if (sent) {
          TopBanner.show(
            context,
            'New 6-digit reset code sent to $_targetEmail! Please check your inbox.',
            isError: false,
            duration: const Duration(seconds: 4),
          );
        } else {
          final err = EmailService.lastErrorMessage.isNotEmpty
              ? EmailService.lastErrorMessage
              : 'Failed to resend reset code via Resend.';
          TopBanner.show(
            context,
            'Resend Error: $err\n\nReset Code: $_generatedOtp',
            isError: true,
            duration: const Duration(seconds: 10),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        TopBanner.show(context, 'Error resending reset code: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyAndResetPassword() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    if (_otpFailedAttempts >= 5) {
      TopBanner.show(
        context,
        'Too many incorrect attempts. Please request a new OTP.',
        isError: true,
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    final enteredOtp = _otpController.text.trim();
    final newPassword = _newPasswordController.text;

    try {
      bool isOtpValid = false;
      bool isSupabaseAuthenticated = false;

      try {
        final res = await Supabase.instance.client.auth.verifyOTP(
          email: _targetEmail,
          token: enteredOtp,
          type: OtpType.recovery,
        );
        if (res.session != null || res.user != null) {
          isOtpValid = true;
          isSupabaseAuthenticated = true;
        }
      } catch (e) {
        try {
          final res = await Supabase.instance.client.auth.verifyOTP(
            email: _targetEmail,
            token: enteredOtp,
            type: OtpType.email,
          );
          if (res.session != null || res.user != null) {
            isOtpValid = true;
            isSupabaseAuthenticated = true;
          }
        } catch (_) {}
      }

      if (!isOtpValid) {
        if (enteredOtp == _generatedOtp) {
          isOtpValid = true;
        }
      }

      if (!isOtpValid) {
        _otpFailedAttempts++;
        if (mounted) {
          if (_otpFailedAttempts >= 5) {
            TopBanner.show(
              context,
              'Too many incorrect attempts. Please request a new OTP.',
              isError: true,
            );
          } else {
            TopBanner.show(
              context,
              'Invalid OTP code. Please check the 6-digit code sent to your inbox.',
              isError: true,
            );
          }
        }
        return;
      }

      bool passwordUpdated = false;

      if (isSupabaseAuthenticated && Supabase.instance.client.auth.currentUser != null) {
        try {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(password: newPassword),
          );
          passwordUpdated = true;
        } catch (e) {
          debugPrint('updateUser error: $e');
        }
      }

      if (!passwordUpdated) {
        try {
          final res = await Supabase.instance.client.rpc('reset_password_by_email', params: {
            'p_email': _targetEmail,
            'p_new_password': newPassword,
          });
          if (res != null) passwordUpdated = true;
        } catch (e) {
          debugPrint('RPC reset_password_by_email: $e');
        }
      }

      if (!passwordUpdated) {
        try {
          final res = await Supabase.instance.client.rpc('update_user_password', params: {
            'email_input': _targetEmail,
            'new_password_input': newPassword,
          });
          if (res != null) passwordUpdated = true;
        } catch (e) {
          debugPrint('RPC update_user_password: $e');
        }
      }

      if (!passwordUpdated) {
        throw Exception('Password update failed in Supabase database. Please ensure Supabase Auth session or RPC functions (reset_password_by_email / update_user_password) are configured.');
      }

      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}

      if (mounted) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context, {
          'email': _targetEmail,
          'password': newPassword,
        });
        TopBanner.show(
          context,
          'Password reset successfully. You can now log in using your new password.',
          isError: false,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      if (mounted) {
        TopBanner.show(
          context,
          'Failed to reset password: ${e.toString().replaceAll('Exception: ', '')}',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 20,
      shadowColor: AppColors.navy.withValues(alpha: 0.3),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _currentStep == 0 ? const Color(0xFFE6F5FF) : const Color(0xFFE0F2FE),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.paletteMedium.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _currentStep == 0 ? Icons.lock_reset_rounded : Icons.mark_email_read_rounded,
                  size: 40,
                  color: AppColors.paletteMedium,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                _currentStep == 0 ? 'Forgot Password?' : 'Reset Your Password',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.paletteNavy,
                  letterSpacing: -0.5,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _currentStep == 0
                    ? 'Enter your registered email address below.'
                    : 'A 6-digit reset code was sent to $_targetEmail. Enter it below along with your new password.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.slate,
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 20),

              Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_currentStep == 0) ...[
                      const Text(
                        'Email Address',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppColors.paletteNavy,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        maxLength: 254,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'[\r\n\t]')),
                        ],
                        style: const TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'user@aquasync.com',
                          counterText: '',
                          prefixIcon: const Icon(Icons.email_outlined, color: AppColors.paletteMedium),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.paletteMedium, width: 2),
                          ),
                        ),
                        validator: LoginValidationUtils.validateEmailOnly,
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFBAE6FD), width: 1.2),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.mark_email_read_rounded, size: 20, color: Color(0xFF0284C7)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'A 6-digit reset code has been sent to $_targetEmail. Please check your inbox.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0369A1),
                                  height: 1.35,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Text(
                        '6-Digit Reset Code',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppColors.paletteNavy,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        style: const TextStyle(
                          color: AppColors.paletteNavy,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 4.0,
                        ),
                        decoration: InputDecoration(
                          hintText: '123456',
                          counterText: '',
                          prefixIcon: const Icon(Icons.key_rounded, color: AppColors.paletteMedium),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.paletteMedium, width: 2),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'OTP is required.';
                          if (v.trim().length != 6) return 'OTP must contain exactly 6 digits.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      const Text(
                        'New Password',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppColors.paletteNavy,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: _obscureNewPassword,
                        maxLength: 64,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'[\r\n\t]')),
                        ],
                        style: const TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          counterText: '',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.paletteMedium),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNewPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: AppColors.slate,
                            ),
                            onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.paletteMedium, width: 2),
                          ),
                        ),
                        validator: LoginValidationUtils.validateNewPasswordStrength,
                      ),
                      const SizedBox(height: 14),

                      const Text(
                        'Confirm New Password',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppColors.paletteNavy,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        maxLength: 64,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'[\r\n\t]')),
                        ],
                        style: const TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          counterText: '',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.paletteMedium),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: AppColors.slate,
                            ),
                            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.paletteMedium, width: 2),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Confirm your password.';
                          if (v != _newPasswordController.text) return 'Passwords do not match.';
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : (_currentStep == 0 ? _sendResetCode : _verifyAndResetPassword),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.paletteMidnight,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(
                          _currentStep == 0 ? 'SEND RESET CODE' : 'UPDATE PASSWORD',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            fontFamily: 'Poppins',
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              if (_currentStep == 1) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _currentStep = 0),
                      child: const Text(
                        'Change Input',
                        style: TextStyle(
                          color: AppColors.slate,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: (_isLoading || _secondsRemaining > 0) ? null : _resendResetCode,
                      child: Text(
                        _secondsRemaining > 0 ? 'RESEND IN ${_secondsRemaining}s' : 'Resend Code',
                        style: TextStyle(
                          color: (_secondsRemaining > 0) ? AppColors.slate : AppColors.paletteMedium,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.slate, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Poppins'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
