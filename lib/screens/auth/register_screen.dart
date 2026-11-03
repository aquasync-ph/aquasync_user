import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/user_provider.dart';
import '../../services/supabase_service.dart';
import '../../services/email_service.dart';
import '../../services/tutorial_service.dart';
import '../../theme/premium_theme.dart';
import '../../widgets/top_banner.dart';
import '../location_picker_screen.dart';

/// Helper utility for Registration Validations
class RegisterValidationUtils {
  static final RegExp _emailRegex = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
  );

  static final RegExp _fullNameRegex = RegExp(
    r"^[a-zA-ZñÑ\s\.\-\']+$",
  );

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

  // Valid Philippine Mobile Network Prefixes (Globe/TM, Smart/TNT/Sun, DITO)
  static final Set<String> _validPhMobilePrefixes = {
    // Globe & TM
    '0905', '0906', '0915', '0916', '0917', '0926', '0927', '0935', '0936', '0937',
    '0945', '0953', '0954', '0955', '0956', '0965', '0966', '0967', '0975', '0976', '0977', '0995', '0997',
    // Smart, TNT & Sun
    '0908', '0918', '0919', '0920', '0921', '0928', '0929', '0938', '0939', '0946',
    '0947', '0948', '0949', '0951', '0961', '0998', '0999', '0922', '0923', '0924',
    '0925', '0931', '0932', '0933', '0934', '0941', '0942', '0943', '0944',
    // DITO
    '0991', '0992', '0993', '0994', '0895', '0896', '0897', '0898',
  };

  static final List<String> _weakPasswords = [
    '12345678',
    'password',
    'password123',
    'qwerty123',
    '11111111',
    '123456789',
    '1234567890',
    'aquasync123',
    'admin123',
  ];

  static bool containsEmoji(String input) {
    final RegExp emojiRegex = RegExp(
      r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
      unicode: true,
    );
    return emojiRegex.hasMatch(input);
  }

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

  /// Validate Full Name (letters, spaces, period, hyphen, apostrophe allowed)
  static String? validateFullName(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Full name is required.';
    }
    final clean = sanitizeInput(raw).replaceAll(RegExp(r'\s+'), ' ');
    if (clean.length < 2) {
      return 'Full name must be at least 2 characters.';
    }
    if (clean.length > 100) {
      return 'Full name must not exceed 100 characters.';
    }
    if (containsEmoji(clean) || !_fullNameRegex.hasMatch(clean)) {
      return 'Please enter a valid name (letters, spaces, period, hyphen, apostrophe only).';
    }

    // Check for 4 or more identical consecutive characters
    if (RegExp(r'(.)\1{3,}').hasMatch(clean.toLowerCase())) {
      return 'Please enter a valid full name.';
    }

    // Check for obvious test gibberish
    const testWords = ['asdfgh', 'qwerty', 'testing', 'user123', 'testtest', 'abcdef'];
    for (var tw in testWords) {
      if (clean.toLowerCase().contains(tw)) {
        return 'Please enter a valid full name.';
      }
    }

    return null;
  }

  /// Validate Email Address strictly
  static String? validateEmail(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Email address is required.';
    }
    final clean = sanitizeInput(raw);
    if (clean.isEmpty || clean.contains(' ') || containsEmoji(clean)) {
      return 'Please enter a valid email address.';
    }
    if (clean.startsWith('.') || clean.endsWith('.')) {
      return 'Please enter a valid email address.';
    }
    if (clean.contains('..')) {
      return 'Please enter a valid email address.';
    }

    final parts = clean.split('@');
    if (parts.length != 2) return 'Please enter a valid email address.';
    final username = parts[0];
    final domain = parts[1];

    if (username.isEmpty || domain.isEmpty) return 'Please enter a valid email address.';
    if (!domain.contains('.') || domain.startsWith('.') || domain.endsWith('.')) {
      return 'Please enter a valid email address.';
    }
    if (domain.split('.').last.length < 2) {
      return 'Please enter a valid email address.';
    }

    if (isDisposableEmail(clean)) {
      return 'Disposable or temporary email addresses are not allowed.';
    }

    if (!_emailRegex.hasMatch(clean)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  /// Validate Phone Number: Exactly 11 digits starting with "09" & valid telecom prefix
  static String? validatePhone(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Phone number is required.';
    }
    final clean = sanitizeInput(raw).replaceAll(RegExp(r'[\s\-]'), '');
    if (containsEmoji(clean)) {
      return 'Please enter a valid Philippine mobile number.';
    }
    if (!RegExp(r'^\d+$').hasMatch(clean)) {
      return 'Numbers only. Letters and special characters are not allowed.';
    }
    if (!clean.startsWith('09')) {
      return 'Phone number must start with 09.';
    }
    if (clean.length != 11) {
      return 'Phone number must contain exactly 11 digits.';
    }

    final prefix = clean.substring(0, 4);
    if (!_validPhMobilePrefixes.contains(prefix)) {
      return 'Please enter a valid PH mobile number with a recognized network prefix (Globe, Smart, DITO, TNT, Sun).';
    }

    return null;
  }

  /// Validate Delivery Address Quality
  static String? validateAddress(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Delivery address is required.';
    }
    final clean = sanitizeInput(raw);
    if (clean.length < 5) {
      return 'Delivery address must be at least 5 characters.';
    }
    if (clean.length > 200) {
      return 'Delivery address must not exceed 200 characters.';
    }

    final words = clean.split(RegExp(r'\s+')).where((w) => w.length >= 2).toList();
    if (words.length < 2) {
      return 'Please enter a complete delivery address (e.g., House No. and Street).';
    }

    if (RegExp(r'(.)\1{4,}').hasMatch(clean)) {
      return 'Please enter a valid, complete delivery address.';
    }

    return null;
  }

  /// Validate Landmark / Delivery Notes
  static String? validateLandmark(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final clean = sanitizeInput(raw);
    if (clean.length > 250) {
      return 'Delivery notes must not exceed 250 characters.';
    }
    return null;
  }

  /// Validate Password Complexity & Security Rules
  static String? validatePassword(String? raw, {String? fullName, String? email, String? phone}) {
    if (raw == null || raw.isEmpty) {
      return 'Password is required.';
    }
    if (raw.trim().isEmpty) {
      return 'Password is required.';
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

    final lowerPass = raw.toLowerCase();
    for (var weak in _weakPasswords) {
      if (lowerPass == weak) {
        return 'Password is too weak. Please choose a more secure password.';
      }
    }

    if (fullName != null && fullName.trim().length >= 3) {
      final cleanName = fullName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
      if (cleanName.length >= 4 && lowerPass == cleanName) {
        return 'Password should not be your full name.';
      }
    }
    if (email != null && email.contains('@')) {
      final username = email.split('@').first.toLowerCase();
      if (username.length >= 4 && lowerPass == username) {
        return 'Password should not be your email username.';
      }
    }
    if (phone != null && phone.trim().length >= 7) {
      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.length >= 7 && lowerPass == cleanPhone) {
        return 'Password should not be your phone number.';
      }
    }

    return null;
  }
}

class RegisterScreen extends StatefulWidget {
  final bool isVerificationOnly;
  final String? email;
  final String? fullName;
  final String? initialOtp;

  const RegisterScreen({
    super.key,
    this.isVerificationOnly = false,
    this.email,
    this.fullName,
    this.initialOtp,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Step 0: Personal, Step 1: Address, Step 2: Security, Step 3: Verification
  int _currentStep = 0;

  final _formKey0 = GlobalKey<FormState>();
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _agreedToTerms = false;
  String? _emailTypoWarning;

  // Controllers
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();

  String _selectedBarangay = 'Select Barangay';
  final List<String> _barangayList = [
    'Select Barangay',
    'Barangay San Antonio',
    'Barangay San Jose',
    'Barangay San Miguel',
    'Barangay San Roque',
    'Barangay Poblacion',
    'Barangay Santa Cruz',
    'Barangay Santo Tomas',
    'Barangay Bagong Silang',
    'Barangay Maligaya',
    'Barangay Central',
  ];

  double? _selectedLatitude;
  double? _selectedLongitude;

  double _passwordStrength = 0.0;
  String _strengthLabel = '';
  Color _strengthColor = Colors.grey;

  // Password requirement check states
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  // OTP Verification state
  String _generatedOtp = '';
  int _resendSecondsRemaining = 0;
  Timer? _resendTimer;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVerificationOnly) {
      _currentStep = 3;
      if (widget.email != null && widget.email!.isNotEmpty) {
        _emailController.text = widget.email!;
      }
      if (widget.fullName != null && widget.fullName!.isNotEmpty) {
        _fullNameController.text = widget.fullName!;
      }
      if (widget.initialOtp != null && widget.initialOtp!.isNotEmpty) {
        _generatedOtp = widget.initialOtp!;
      }
      _startCooldownTimer();
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _landmarkController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength(String value) {
    setState(() {
      _hasMinLength = value.length >= 8 && value.length <= 64;
      _hasUppercase = RegExp(r'[A-Z]').hasMatch(value);
      _hasLowercase = RegExp(r'[a-z]').hasMatch(value);
      _hasNumber = RegExp(r'[0-9]').hasMatch(value);
      _hasSpecialChar = RegExp(r'''[!@#$%^&*(),.?\"{}|<>_+\-~`=\[\]/\\;']''').hasMatch(value);

      int matchedCriteria = 0;
      if (_hasMinLength) matchedCriteria++;
      if (_hasUppercase) matchedCriteria++;
      if (_hasLowercase) matchedCriteria++;
      if (_hasNumber) matchedCriteria++;
      if (_hasSpecialChar) matchedCriteria++;

      _passwordStrength = matchedCriteria / 5.0;

      if (value.isEmpty) {
        _strengthLabel = '';
        _strengthColor = Colors.grey;
      } else if (matchedCriteria <= 2) {
        _strengthLabel = 'Weak';
        _strengthColor = Colors.red;
      } else if (matchedCriteria == 3 || matchedCriteria == 4) {
        _strengthLabel = 'Moderate';
        _strengthColor = Colors.amber[700]!;
      } else {
        _strengthLabel = 'Very Strong & Secure';
        _strengthColor = Colors.green;
      }
    });
  }

  void _checkEmailTypo(String value) {
    final lower = value.toLowerCase().trim();
    if (lower.contains('@gamil.com') || lower.contains('@gnail.com')) {
      setState(() => _emailTypoWarning = 'Did you mean @gmail.com?');
    } else if (lower.contains('@yaho.com')) {
      setState(() => _emailTypoWarning = 'Did you mean @yahoo.com?');
    } else if (lower.contains('@hotnail.com')) {
      setState(() => _emailTypoWarning = 'Did you mean @hotmail.com?');
    } else {
      setState(() => _emailTypoWarning = null);
    }
  }

  void _showError(String msg) {
    TopBanner.show(context, msg, isError: true);
  }

  void _startCooldownTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsRemaining = 120);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendSecondsRemaining > 0) {
        setState(() => _resendSecondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _pickLocationOnMap() async {
    HapticFeedback.lightImpact();
    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
    );

    if (result != null && mounted) {
      setState(() {
        _addressController.text = result.address;
        _selectedLatitude = result.latitude;
        _selectedLongitude = result.longitude;
      });

      TopBanner.show(context, 'Delivery location pinned on map: ${result.address}', isError: false);
    }
  }

  /// Step Navigation with Async DB Validation
  Future<void> _nextStep() async {
    if (_isLoading) return;
    HapticFeedback.lightImpact();

    // STEP 0: Personal Details & Duplicate Account Check
    if (_currentStep == 0) {
      if (!_formKey0.currentState!.validate()) return;

      setState(() => _isLoading = true);

      final email = RegisterValidationUtils.sanitizeInput(_emailController.text).toLowerCase();
      final rawPhone = RegisterValidationUtils.sanitizeInput(_phoneController.text);
      final normalizedE164 = '+63${rawPhone.substring(1)}';

      try {
        // Check duplicate Email in database
        final emailCheck = await SupabaseService.client
            .from('profiles')
            .select('id')
            .eq('email', email)
            .maybeSingle();

        if (emailCheck != null) {
          _showError('This email address is already registered.');
          setState(() => _isLoading = false);
          return;
        }

        // Check duplicate Phone in database
        final phoneCheck = await SupabaseService.client
            .from('profiles')
            .select('id')
            .or('phone.eq.$rawPhone,phone.eq.$normalizedE164')
            .maybeSingle();

        if (phoneCheck != null) {
          _showError('This phone number is already registered.');
          setState(() => _isLoading = false);
          return;
        }

        setState(() {
          _isLoading = false;
          _currentStep = 1;
        });
      } catch (e) {
        setState(() => _isLoading = false);
        setState(() => _currentStep = 1);
      }
    }
    // STEP 1: Delivery Address Validation
    else if (_currentStep == 1) {
      if (!_formKey1.currentState!.validate()) return;

      if (_selectedBarangay == 'Select Barangay' || _selectedBarangay.isEmpty) {
        _showError('Please select your barangay.');
        return;
      }

      if (_selectedLatitude == null || _selectedLongitude == null) {
        _showError('Please select your delivery location on the map.');
        return;
      }

      setState(() => _currentStep = 2);
    }
    // STEP 2: Security & Terms Validation -> Trigger Registration OTP
    else if (_currentStep == 2) {
      if (!_formKey2.currentState!.validate()) return;

      final passErr = RegisterValidationUtils.validatePassword(
        _passwordController.text,
        fullName: _fullNameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
      );
      if (passErr != null) {
        _showError(passErr);
        return;
      }

      if (_passwordController.text != _confirmPasswordController.text) {
        _showError('Passwords do not match. Please re-check.');
        return;
      }

      if (!_agreedToTerms) {
        _showError('You must agree to the Terms and Conditions to create an account.');
        _showTermsAndConditionsDialog();
        return;
      }

      await _sendVerificationOtpAndProceed();
    }
  }

  Future<void> _sendVerificationOtpAndProceed() async {
    final fullName = RegisterValidationUtils.sanitizeInput(_fullNameController.text);
    final email = RegisterValidationUtils.sanitizeInput(_emailController.text).toLowerCase();

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    _generatedOtp = EmailService.generateOtp();

    try {
      // 1. Try Supabase Auth native OTP (sends directly from Supabase verified SMTP to Gmail)
      try {
        await SupabaseService.client.auth.signInWithOtp(
          email: email,
          shouldCreateUser: false,
          data: {'full_name': fullName},
        );
      } catch (e) {
        debugPrint('Supabase signInWithOtp notice: $e');
      }

      // 2. Send via Brevo EmailService for rich branding
      await EmailService.sendAccountVerificationOtp(
        email: email,
        name: fullName,
        otpCode: _generatedOtp,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _currentStep = 3;
      });

      _startCooldownTimer();
      TopBanner.show(context, 'A 6-digit verification code was sent to $email. Please check your inbox.', isError: false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Fallback to proceed even if SMTP throws, ensuring user is never blocked
        setState(() {
          _currentStep = 3;
        });
        _startCooldownTimer();
        TopBanner.show(context, 'Verification code generated for $email.', isError: false);
      }
    }
  }

  void _showTermsAndConditionsDialog() {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0F1D32) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F1D32);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0);

    bool hasScrolledToBottom = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final ScrollController scrollController = ScrollController();

            scrollController.addListener(() {
              if (scrollController.hasClients) {
                final maxScroll = scrollController.position.maxScrollExtent;
                final currentScroll = scrollController.position.pixels;
                if (maxScroll <= 15 || currentScroll >= maxScroll - 25) {
                  if (!hasScrolledToBottom) {
                    setModalState(() => hasScrolledToBottom = true);
                  }
                }
              }
            });

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (scrollController.hasClients) {
                if (scrollController.position.maxScrollExtent <= 20) {
                  if (!hasScrolledToBottom) {
                    setModalState(() => hasScrolledToBottom = true);
                  }
                }
              }
            });

            return Dialog(
              backgroundColor: cardBg,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(color: borderColor, width: 1.5),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420, maxHeight: 640),
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: AppGradients.ocean,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.gavel_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Terms & Privacy Policy',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                'AquaSync Refill Station Customer Agreement',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: subTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(dialogContext),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: subTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(height: 1, color: borderColor),
                    const SizedBox(height: 12),

                    Expanded(
                      child: RawScrollbar(
                        controller: scrollController,
                        thumbVisibility: true,
                        thickness: 5,
                        radius: const Radius.circular(10),
                        thumbColor: AppColors.primary.withValues(alpha: 0.6),
                        child: SingleChildScrollView(
                          controller: scrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(right: 10, top: 4, bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Last Updated: AquaSync Refill Station Terms v2.4',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                              ),
                              const SizedBox(height: 10),
                              _buildTermsSection(
                                title: '1. Service & Account Agreement',
                                content: 'By creating an account on AquaSync, you agree to provide accurate, truthful information including your full name, active mobile number, and valid delivery address with GPS location pin. Your account is non-transferable.',
                                textColor: textColor,
                                subTextColor: subTextColor,
                              ),
                              _buildTermsSection(
                                title: '2. Water Ordering & Delivery Geofencing',
                                content: 'Water refill orders are subject to operational hours and active delivery coverage. Orders placed outside the allowed proximity boundary will be restricted.',
                                textColor: textColor,
                                subTextColor: subTextColor,
                              ),
                              _buildTermsSection(
                                title: '3. Gallon Container Care Policy',
                                content: 'Customer-borrowed water gallons remain station property. Customers are responsible for keeping borrowed gallons clean, undamaged, and free from hazardous liquids.',
                                textColor: textColor,
                                subTextColor: subTextColor,
                              ),
                              _buildTermsSection(
                                title: '4. Privacy Policy & Data Collection',
                                content: 'AquaSync respects your personal privacy. We collect your name, phone number, address, and GPS coordinates solely for processing water deliveries and sending alerts.',
                                textColor: textColor,
                                subTextColor: subTextColor,
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: hasScrolledToBottom
                            ? const Color(0xFF10B981).withValues(alpha: 0.12)
                            : Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: hasScrolledToBottom
                              ? const Color(0xFF10B981).withValues(alpha: 0.4)
                              : Colors.amber.shade700.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            hasScrolledToBottom ? Icons.check_circle_rounded : Icons.south_rounded,
                            color: hasScrolledToBottom ? const Color(0xFF10B981) : Colors.amber.shade800,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              hasScrolledToBottom
                                  ? 'You have reached the bottom. You may now accept below.'
                                  : 'Please scroll down to the bottom to unlock the agreement button.',
                              style: TextStyle(
                                color: hasScrolledToBottom ? const Color(0xFF10B981) : Colors.amber.shade900,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    ElevatedButton(
                      onPressed: hasScrolledToBottom
                          ? () {
                              HapticFeedback.mediumImpact();
                              setState(() {
                                _agreedToTerms = true;
                              });
                              Navigator.pop(dialogContext);
                              TopBanner.show(context, 'Terms & Privacy Policy accepted successfully!', isError: false);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ).copyWith(
                        elevation: WidgetStateProperty.all(0),
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: hasScrolledToBottom ? AppGradients.ocean : null,
                          color: hasScrolledToBottom ? null : (isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                hasScrolledToBottom ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                                color: hasScrolledToBottom ? Colors.white : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                hasScrolledToBottom ? 'I AGREE TO TERMS & PRIVACY POLICY' : 'SCROLL TO BOTTOM TO AGREE',
                                style: TextStyle(
                                  color: hasScrolledToBottom ? Colors.white : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTermsSection({
    required String title,
    required String content,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: subTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resendVerificationOtp() async {
    if (_resendSecondsRemaining > 0 || _isResending) return;

    final fullName = RegisterValidationUtils.sanitizeInput(_fullNameController.text);
    final email = RegisterValidationUtils.sanitizeInput(_emailController.text);

    HapticFeedback.lightImpact();
    setState(() => _isResending = true);

    _generatedOtp = EmailService.generateOtp();

    try {
      final sent = await EmailService.sendAccountVerificationOtp(
        email: email,
        name: fullName,
        otpCode: _generatedOtp,
      );

      if (!mounted) return;

      setState(() => _isResending = false);

      if (sent) {
        _startCooldownTimer();
        TopBanner.show(context, 'New 6-digit code successfully sent to $email.', isError: false);
      } else {
        _showError('Failed to resend verification code via SMTP. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isResending = false);
        _showError('Error resending email: $e');
      }
    }
  }

  void _prevStep() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_currentStep > 0) _currentStep--;
    });
  }

  Future<void> _verifyAndRegister() async {
    final entered = _otpController.text.trim();
    final email = RegisterValidationUtils.sanitizeInput(_emailController.text).toLowerCase();

    if (entered.length != 6) {
      HapticFeedback.vibrate();
      _showError('OTP must contain exactly 6 digits.');
      return;
    }

    bool isOtpValid = false;

    // 1. Try Supabase Auth verifyOTP
    try {
      final res = await SupabaseService.client.auth.verifyOTP(
        email: email,
        token: entered,
        type: OtpType.signup,
      );
      if (res.session != null || res.user != null) {
        isOtpValid = true;
      }
    } catch (_) {
      try {
        final res = await SupabaseService.client.auth.verifyOTP(
          email: email,
          token: entered,
          type: OtpType.email,
        );
        if (res.session != null || res.user != null) {
          isOtpValid = true;
        }
      } catch (_) {}
    }

    // 2. Check against local generated OTP
    if (!isOtpValid) {
      if (entered == _generatedOtp) {
        isOtpValid = true;
      }
    }

    if (!isOtpValid) {
      HapticFeedback.vibrate();
      _showError('Invalid OTP code. Please check your email inbox.');
      return;
    }

    HapticFeedback.mediumImpact();

    if (widget.isVerificationOnly) {
      await _completeVerificationOnly();
    } else {
      await _completeRegistration();
    }
  }

  Future<void> _completeVerificationOnly() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    setState(() => _isLoading = true);

    try {
      final user = SupabaseService.currentUser;
      if (user != null) {
        try {
          await SupabaseService.client.auth.updateUser(
            UserAttributes(data: {
              'is_verified': true,
              'status': 'active',
              'approval_status': 'approved',
              'is_approved': true,
            }),
          );
        } catch (_) {}

        try {
          await SupabaseService.updateProfile(
            userId: user.id,
            updates: {
              'is_verified': true,
              'status': 'active',
              'approval_status': 'approved',
              'is_approved': true,
            },
          );
        } catch (_) {}

        await userProvider.fetchProfileForUser(user);
        await TutorialService.instance.resetTutorial(user.id);

        if (!mounted) return;

        _showVerificationSuccessDialog(widget.fullName ?? 'Valued Customer');

        await Future.delayed(const Duration(milliseconds: 2000));
        if (!mounted) return;

        TopBanner.show(context, 'Account created successfully. You can now log in.', isError: false);
        Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
      } else {
        _showError('Session expired. Please sign in again.');
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to complete verification: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _completeRegistration() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final fullName = RegisterValidationUtils.sanitizeInput(_fullNameController.text);
    final email = RegisterValidationUtils.sanitizeInput(_emailController.text).toLowerCase();
    final password = _passwordController.text; // Case sensitive
    final rawPhone = RegisterValidationUtils.sanitizeInput(_phoneController.text);
    final phoneE164 = '+63${rawPhone.substring(1)}';

    final streetAddress = RegisterValidationUtils.sanitizeInput(_addressController.text);
    final landmark = RegisterValidationUtils.sanitizeInput(_landmarkController.text);
    final fullAddress = landmark.isNotEmpty
        ? '$streetAddress, $_selectedBarangay (Landmark: $landmark)'
        : '$streetAddress, $_selectedBarangay';

    setState(() => _isLoading = true);

    try {
      final response = await SupabaseService.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'phone': phoneE164,
          'address': fullAddress,
          'role': 'customer',
          'is_verified': true,
          'status': 'active',
          'approval_status': 'approved',
          'is_approved': true,
          if (_selectedLatitude != null) 'latitude': _selectedLatitude,
          if (_selectedLongitude != null) 'longitude': _selectedLongitude,
        },
      );

      if (!mounted) return;

      final user = response.user;
      if (user != null) {
        if (response.session == null) {
          try {
            await SupabaseService.signInWithPassword(email: email, password: password);
          } catch (_) {}
        }

        final currentUser = SupabaseService.currentUser ?? user;

        try {
          await SupabaseService.client.auth.updateUser(
            UserAttributes(data: {
              'full_name': fullName,
              'phone': phoneE164,
              'address': fullAddress,
              'role': 'customer',
              'is_verified': true,
              'status': 'active',
              'approval_status': 'approved',
              'is_approved': true,
              if (_selectedLatitude != null) 'latitude': _selectedLatitude,
              if (_selectedLongitude != null) 'longitude': _selectedLongitude,
            }),
          );
        } catch (_) {}

        try {
          await SupabaseService.updateProfile(
            userId: currentUser.id,
            updates: {
              'full_name': fullName,
              'phone': phoneE164,
              'address': fullAddress,
              'role': 'customer',
              'is_verified': true,
              'status': 'active',
              'approval_status': 'approved',
              'is_approved': true,
              if (_selectedLatitude != null) 'latitude': _selectedLatitude,
              if (_selectedLongitude != null) 'longitude': _selectedLongitude,
            },
          );
        } catch (_) {}

        try {
          await SupabaseService.client.from('gallons').insert({
            'customer_id': currentUser.id,
            'label': '$fullName\'s Standard Container',
            'type': 'Purified 5-Gallon',
            'status': 'available',
            'condition': 'Good Condition (Assigned)',
          });
        } catch (_) {}

        await userProvider.fetchProfileForUser(currentUser);
        await TutorialService.instance.resetTutorial(currentUser.id);

        if (!mounted) return;

        _showVerificationSuccessDialog(fullName);

        await Future.delayed(const Duration(milliseconds: 2000));
        if (!mounted) return;

        TopBanner.show(context, 'Account created successfully. You can now log in.', isError: false);
        Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();

      String message = e.message;
      if (e.message.contains('already registered') || e.message.contains('already in use')) {
        message = 'This email address is already registered.';
      }
      _showError(message);
    } catch (e) {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      _showError('Unable to connect to the server. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showVerificationSuccessDialog(String name) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => Dialog(
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
                    'Account Created',
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
                              'Welcome to AquaSync, $name!',
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
                    'Account registered successfully. Directing to portal...',
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
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isDesktop = mediaQuery.size.width >= 700;
    final hasKeyboard = mediaQuery.viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFDFF),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Curved Dark Arc Header
            ClipPath(
              clipper: HeaderArcClipper(),
              child: Container(
                width: double.infinity,
                height: isDesktop ? 290 : (hasKeyboard ? 120 : 250),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF01082D), Color(0xFF041D56), Color(0xFF0F2573)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: _currentStep == 3 ? 0.05 : 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.arrow_back_rounded,
                                  color: _currentStep == 3 ? Colors.white.withValues(alpha: 0.3) : Colors.white,
                                ),
                                onPressed: _currentStep == 3
                                    ? () {
                                        TopBanner.show(context, 'Please complete verification. You cannot go back.', isError: true);
                                      }
                                    : (widget.isVerificationOnly
                                        ? () => Navigator.of(context).pop()
                                        : (_currentStep > 0 ? _prevStep : () => Navigator.of(context).pop())),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              widget.isVerificationOnly ? 'EMAIL VERIFICATION' : 'CREATE ACCOUNT',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.5,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                        if (!hasKeyboard) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(
                              widget.isVerificationOnly
                                  ? 'Verify your email address to complete sign in'
                                  : (_currentStep == 0
                                      ? 'Step 0: Personal Information'
                                      : _currentStep == 1
                                          ? 'Step 1: Delivery Address'
                                          : _currentStep == 2
                                              ? 'Step 2: Security & Terms'
                                              : 'Step 3: Verification Code'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.8),
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Form Body Container
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 3-Step Segmented Progress Bar
                      if (!widget.isVerificationOnly) ...[
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0).withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            children: [
                              _buildSegmentedStep(0, '0. Personal'),
                              _buildSegmentedStep(1, '1. Address'),
                              _buildSegmentedStep(2, '2. Security'),
                              _buildSegmentedStep(3, '3. Verify'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Card Container
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: mediaQuery.size.width < 380 ? 16.0 : 24.0,
                          vertical: 24.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: AppColors.borderLight,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.paletteMedium.withValues(alpha: 0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _currentStep == 0
                                  ? 'Personal Information'
                                  : _currentStep == 1
                                      ? 'Delivery Address'
                                      : _currentStep == 2
                                          ? 'Security & Terms'
                                          : 'Email Verification',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppColors.paletteNavy,
                                letterSpacing: -0.3,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            const SizedBox(height: 22),

                            // STEP 0: PERSONAL INFORMATION
                            if (_currentStep == 0)
                              Form(
                                key: _formKey0,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const Text('Full Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.paletteNavy, fontFamily: 'Poppins')),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _fullNameController,
                                      enabled: !_isLoading,
                                      maxLength: 100,
                                      textCapitalization: TextCapitalization.words,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.deny(RegExp(r'[\r\n\t]')),
                                      ],
                                      style: const TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold, fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: 'Juan Dela Cruz',
                                        counterText: '',
                                        prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.paletteMedium),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.paletteMedium, width: 2)),
                                      ),
                                      validator: RegisterValidationUtils.validateFullName,
                                    ),
                                    const SizedBox(height: 18),

                                    const Text('Email Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.paletteNavy, fontFamily: 'Poppins')),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      enabled: !_isLoading,
                                      maxLength: 254,
                                      onChanged: _checkEmailTypo,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.deny(RegExp(r'[\r\n\t]')),
                                      ],
                                      style: const TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold, fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: 'johnmark@gmail.com',
                                        counterText: '',
                                        prefixIcon: const Icon(Icons.email_outlined, color: AppColors.paletteMedium),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.paletteMedium, width: 2)),
                                      ),
                                      validator: RegisterValidationUtils.validateEmail,
                                    ),
                                    if (_emailTypoWarning != null) ...[
                                      const SizedBox(height: 6),
                                      Text(_emailTypoWarning!, style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                    const SizedBox(height: 18),

                                    const Text('Philippine Phone Number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.paletteNavy, fontFamily: 'Poppins')),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      enabled: !_isLoading,
                                      maxLength: 11,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(11),
                                      ],
                                      style: const TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold, fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: '09171234567',
                                        counterText: '',
                                        prefixIcon: const Icon(Icons.phone_iphone_rounded, color: AppColors.paletteMedium),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.paletteMedium, width: 2)),
                                      ),
                                      validator: RegisterValidationUtils.validatePhone,
                                    ),
                                  ],
                                ),
                              ),

                            // STEP 1: DELIVERY ADDRESS
                            if (_currentStep == 1)
                              Form(
                                key: _formKey1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const Text('Complete Street / House Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.paletteNavy, fontFamily: 'Poppins')),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _addressController,
                                      maxLines: 2,
                                      enabled: !_isLoading,
                                      maxLength: 200,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.deny(RegExp(r'[\r\n\t]')),
                                      ],
                                      style: const TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold, fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: '123 Rizal Street, House 45-A',
                                        counterText: '',
                                        prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.paletteMedium),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.paletteMedium, width: 2)),
                                      ),
                                      validator: RegisterValidationUtils.validateAddress,
                                    ),
                                    const SizedBox(height: 18),

                                    const Text('Barangay', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.paletteNavy, fontFamily: 'Poppins')),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      value: _selectedBarangay,
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(Icons.map_outlined, color: AppColors.paletteMedium),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.paletteMedium, width: 2)),
                                      ),
                                      items: _barangayList.map((bg) {
                                        return DropdownMenuItem<String>(
                                          value: bg,
                                          child: Text(
                                            bg,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: bg == 'Select Barangay' ? FontWeight.normal : FontWeight.bold,
                                              color: bg == 'Select Barangay' ? AppColors.slate : AppColors.darkText,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: _isLoading
                                          ? null
                                          : (val) {
                                              if (val != null) {
                                                setState(() => _selectedBarangay = val);
                                              }
                                            },
                                      validator: (val) {
                                        if (val == null || val == 'Select Barangay' || val.trim().isEmpty) {
                                          return 'Please select your barangay.';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 18),

                                    const Text('Landmark / Delivery Notes (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.paletteNavy, fontFamily: 'Poppins')),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _landmarkController,
                                      enabled: !_isLoading,
                                      maxLength: 250,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.deny(RegExp(r'[\r\n\t]')),
                                      ],
                                      style: const TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold, fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: 'e.g. Blue gate beside the sari-sari store',
                                        counterText: '',
                                        prefixIcon: const Icon(Icons.flag_outlined, color: AppColors.paletteMedium),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.paletteMedium, width: 2)),
                                      ),
                                      validator: RegisterValidationUtils.validateLandmark,
                                    ),
                                    const SizedBox(height: 16),

                                    // Map Pin Button
                                    InkWell(
                                      onTap: _isLoading ? null : _pickLocationOnMap,
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                        decoration: BoxDecoration(
                                          color: _selectedLatitude != null
                                              ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                              : AppColors.paletteLight.withValues(alpha: 0.3),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: _selectedLatitude != null
                                                ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                                : AppColors.paletteMedium.withValues(alpha: 0.4),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              _selectedLatitude != null ? Icons.check_circle_rounded : Icons.map_rounded,
                                              color: _selectedLatitude != null ? const Color(0xFF10B981) : AppColors.paletteMedium,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                _selectedLatitude != null ? 'MAP PIN CONFIRMED (TAP TO CHANGE)' : 'PIN EXACT LOCATION ON MAP',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: _selectedLatitude != null ? const Color(0xFF047857) : AppColors.paletteNavy,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 12,
                                                  letterSpacing: 0.8,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // STEP 2: SECURITY & TERMS
                            if (_currentStep == 2)
                              Form(
                                key: _formKey2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const Text('Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.paletteNavy, fontFamily: 'Poppins')),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: !_isPasswordVisible,
                                      enabled: !_isLoading,
                                      maxLength: 64,
                                      onChanged: _checkPasswordStrength,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.deny(RegExp(r'[\r\n\t]')),
                                      ],
                                      style: const TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold, fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: '••••••••',
                                        counterText: '',
                                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.paletteMedium),
                                        suffixIcon: IconButton(
                                          icon: Icon(_isPasswordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.slate),
                                          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.paletteMedium, width: 2)),
                                      ),
                                      validator: (v) => RegisterValidationUtils.validatePassword(
                                        v,
                                        fullName: _fullNameController.text,
                                        email: _emailController.text,
                                        phone: _phoneController.text,
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    if (_passwordController.text.isNotEmpty) ...[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: LinearProgressIndicator(
                                          value: _passwordStrength,
                                          backgroundColor: Colors.grey[200],
                                          valueColor: AlwaysStoppedAnimation<Color>(_strengthColor),
                                          minHeight: 6,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text('Security Level: $_strengthLabel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _strengthColor)),
                                      const SizedBox(height: 8),
                                      _buildReqItem('8 to 64 characters', _hasMinLength, AppColors.darkText, AppColors.slate),
                                      _buildReqItem('One uppercase & lowercase', _hasUppercase && _hasLowercase, AppColors.darkText, AppColors.slate),
                                      _buildReqItem('One number & special character', _hasNumber && _hasSpecialChar, AppColors.darkText, AppColors.slate),
                                      const SizedBox(height: 12),
                                    ],

                                    const Text('Confirm Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.paletteNavy, fontFamily: 'Poppins')),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _confirmPasswordController,
                                      obscureText: !_isConfirmPasswordVisible,
                                      enabled: !_isLoading,
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
                                          icon: Icon(_isConfirmPasswordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.slate),
                                          onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.paletteMedium, width: 2)),
                                      ),
                                      validator: (v) {
                                        if (v == null || v.isEmpty) return 'Please confirm your password.';
                                        if (v != _passwordController.text) return 'Passwords do not match.';
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 18),

                                    // Terms & Conditions Checkbox Row
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: Checkbox(
                                            value: _agreedToTerms,
                                            activeColor: AppColors.paletteMedium,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                            onChanged: _isLoading
                                                ? null
                                                : (val) {
                                                    setState(() => _agreedToTerms = val ?? false);
                                                  },
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: _showTermsAndConditionsDialog,
                                            child: const Text.rich(
                                              TextSpan(
                                                text: 'I agree to the ',
                                                style: TextStyle(fontSize: 12, color: AppColors.slate, fontFamily: 'Poppins'),
                                                children: [
                                                  TextSpan(
                                                    text: 'Terms & Conditions',
                                                    style: TextStyle(
                                                      color: AppColors.paletteMedium,
                                                      fontWeight: FontWeight.bold,
                                                      decoration: TextDecoration.underline,
                                                    ),
                                                  ),
                                                  TextSpan(text: ' and Privacy Policy'),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                            // STEP 3: EMAIL VERIFICATION
                            if (_currentStep == 3)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Enter 6-digit verification code sent to:\n${_emailController.text.trim()}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: AppColors.slate, fontSize: 13, height: 1.4, fontFamily: 'Poppins'),
                                  ),
                                  const SizedBox(height: 20),

                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      _buildOtpBoxes(_otpController.text, false, AppColors.darkText, AppColors.slate),
                                      Positioned.fill(
                                        child: Opacity(
                                          opacity: 0.01,
                                          child: TextField(
                                            controller: _otpController,
                                            keyboardType: TextInputType.number,
                                            maxLength: 6,
                                            autofocus: true,
                                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                            decoration: const InputDecoration(
                                              counterText: '',
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                            onChanged: (val) => setState(() {}),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text("Didn't receive code? ", style: TextStyle(color: AppColors.slate, fontSize: 12, fontFamily: 'Poppins')),
                                      GestureDetector(
                                        onTap: (_resendSecondsRemaining > 0 || _isResending) ? null : _resendVerificationOtp,
                                        child: Text(
                                          _resendSecondsRemaining > 0 ? 'Resend in ${_resendSecondsRemaining}s' : 'Resend Code',
                                          style: TextStyle(
                                            color: _resendSecondsRemaining > 0 ? AppColors.slate : AppColors.paletteMedium,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            fontFamily: 'Poppins',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                            const SizedBox(height: 28),

                            // Full Width Action Button
                            SizedBox(
                              height: 56,
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : (_currentStep < 3 ? _nextStep : _verifyAndRegister),
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
                                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                      )
                                    : Text(
                                        widget.isVerificationOnly
                                            ? 'Verify Account'
                                            : (_currentStep < 3 ? 'NEXT' : 'CREATE ACCOUNT'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.0,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Link to Login
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Already have an account? ',
                            style: TextStyle(color: AppColors.slate, fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'Poppins'),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false),
                            child: const Text(
                              'Sign In',
                              style: TextStyle(
                                color: AppColors.paletteMedium,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Poppins',
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedStep(int stepIndex, String title) {
    final isActive = _currentStep == stepIndex;
    final isPassed = _currentStep > stepIndex;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        decoration: BoxDecoration(
          color: isActive ? AppColors.paletteMedium : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.paletteMedium.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.white : (isPassed ? AppColors.paletteNavy : AppColors.slate),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReqItem(String label, bool met, Color textColor, Color subTextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: met ? AppColors.success : subTextColor,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: met ? AppColors.success : subTextColor,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpBoxes(String code, bool isDark, Color textColor, Color subTextColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        const gap = 6.0;
        final calcWidth = (availableWidth - (gap * 5)) / 6;
        final boxWidth = calcWidth.clamp(30.0, 46.0);
        final boxHeight = (boxWidth * 1.16).clamp(38.0, 54.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            final char = index < code.length ? code[index] : '';
            final isFilled = char.isNotEmpty;

            return Padding(
              padding: EdgeInsets.only(right: index < 5 ? gap : 0),
              child: Container(
                width: boxWidth,
                height: boxHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular((boxWidth * 0.28).clamp(8.0, 14.0)),
                  border: Border.all(
                    color: isFilled ? AppColors.paletteMedium : AppColors.borderLight,
                    width: isFilled ? 2 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.paletteMedium.withValues(alpha: isFilled ? 0.15 : 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  char,
                  style: TextStyle(
                    fontSize: (boxWidth * 0.48).clamp(15.0, 22.0),
                    fontWeight: FontWeight.w900,
                    color: AppColors.darkText,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            );
          }),
        );
      },
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
