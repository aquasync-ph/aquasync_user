import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/user_provider.dart';
import '../services/supabase_service.dart';
import '../widgets/top_banner.dart';
import '../services/tutorial_service.dart';
import 'location_picker_screen.dart';

/// Helper utility for Profile and Change Password Validations
class ProfileValidationUtils {
  static final RegExp _fullNameRegex = RegExp(r"^[a-zA-ZñÑ\s\.\-\']+$");

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

  /// Validate Full Name
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
      return 'Please enter a valid full name (letters, spaces, period, hyphen, apostrophe only).';
    }
    return null;
  }

  /// Validate Phone Number (Strictly 11 digits starting with 09)
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
    return null;
  }

  /// Validate Delivery Address
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
    return null;
  }

  /// Validate Landmark / Notes
  static String? validateLandmark(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final clean = sanitizeInput(raw);
    if (clean.length > 250) {
      return 'Landmark notes must not exceed 250 characters.';
    }
    return null;
  }

  /// Validate New Password Strength
  static String? validateNewPassword(String? raw, String currentPassword) {
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
    if (!RegExp(r'''[!@#$%^&*(),.?\"{}|<>_+\-~`=\\[\\]/\\;']''').hasMatch(raw)) {
      return 'Password must contain a special character.';
    }
    if (raw == currentPassword) {
      return 'New password cannot be the same as current password.';
    }

    final lowerPass = raw.toLowerCase();
    for (var weak in _weakPasswords) {
      if (lowerPass == weak) {
        return 'Password is too weak. Please choose a more secure password.';
      }
    }
    return null;
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _notifyOrders = true;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _pickImage() async {
    HapticFeedback.lightImpact();
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 400,
    );

    if (image != null) {
      setState(() => _isUploading = true);
      try {
        final bytes = await image.readAsBytes();
        if (!mounted) return;
        await Provider.of<UserProvider>(context, listen: false).updateProfilePicture(bytes, image.path);
        if (!mounted) return;
        TopBanner.show(context, 'Profile picture updated successfully!', isError: false);
      } catch (e) {
        if (!mounted) return;
        TopBanner.show(context, 'Failed to update picture: $e', isError: true);
      } finally {
        if (mounted) {
          setState(() => _isUploading = false);
        }
      }
    }
  }

  void _showEditProfilePopup(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final profile = userProvider.profile;
    if (profile == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0);

    String initialAddress = profile.address;
    if (initialAddress == '-') initialAddress = '';
    String initialLandmark = '';
    if (initialAddress.contains('(Landmark: ')) {
      final match = RegExp(r'^(.*?)\s*\(Landmark:\s*(.*?)\)$').firstMatch(initialAddress);
      if (match != null) {
        initialAddress = match.group(1)?.trim() ?? initialAddress;
        initialLandmark = match.group(2)?.trim() ?? '';
      }
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: cardBg,
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: borderColor, width: 1.2),
          ),
          child: _EditProfileDialogContent(
            profile: profile,
            initialAddress: initialAddress,
            initialLandmark: initialLandmark,
            isDark: isDark,
            cardBg: cardBg,
            textColor: textColor,
            subTextColor: subTextColor,
            borderColor: borderColor,
          ),
        );
      },
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: cardBg,
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: borderColor, width: 1.2),
          ),
          child: _ChangePasswordDialogContent(
            isDark: isDark,
            cardBg: cardBg,
            textColor: textColor,
            subTextColor: subTextColor,
            borderColor: borderColor,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final profile = userProvider.profile;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF08101E) : const Color(0xFFF4F9FC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            stretch: true,
            backgroundColor: const Color(0xFF0369A1),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF075985), Color(0xFF0284C7), Color(0xFF0EA5E9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -40,
                    top: -20,
                    child: Icon(Icons.water_drop_rounded, size: 240, color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  Positioned(
                    left: -30,
                    bottom: -30,
                    child: Icon(Icons.waves_rounded, size: 180, color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 50),
                        Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.white,
                                    backgroundImage: (profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty)
                                        ? NetworkImage(profile.avatarUrl!)
                                        : null,
                                    child: (profile?.avatarUrl == null || profile!.avatarUrl!.isEmpty)
                                        ? Text(
                                            (profile?.firstName.isNotEmpty ?? false) ? profile!.firstName[0].toUpperCase() : 'C',
                                            style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: Color(0xFF0284C7)),
                                          )
                                        : null,
                                  ),
                                  if (_isUploading)
                                    const CircularProgressIndicator(color: Color(0xFF0284C7)),
                                ],
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 4,
                              child: GestureDetector(
                                onTap: _isUploading ? null : _pickImage,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: const [
                                      BoxShadow(color: Colors.black26, blurRadius: 6),
                                    ],
                                  ),
                                  child: Icon(_isUploading ? Icons.hourglass_top_rounded : Icons.camera_alt_rounded, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                profile?.fullName ?? 'Aqua Customer',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _showEditProfilePopup(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            profile?.email ?? 'No email address registered',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ACCOUNT SETTINGS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: subTextColor, letterSpacing: 1.2)),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor, width: 1.5),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          _buildPremiumListTile(
                            icon: Icons.person_outline_rounded,
                            iconColor: const Color(0xFF0284C7),
                            title: 'Edit Profile Information',
                            subtitle: 'Name, phone, address & barangay',
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _showEditProfilePopup(context);
                            },
                            textColor: textColor,
                            subTextColor: subTextColor,
                          ),
                          Divider(height: 1, color: borderColor, indent: 64),
                          _buildPremiumListTile(
                            icon: Icons.lock_reset_rounded,
                            iconColor: const Color(0xFFF59E0B),
                            title: 'Change Password',
                            subtitle: 'Update account password securely',
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _showChangePasswordDialog(context);
                            },
                            textColor: textColor,
                            subTextColor: subTextColor,
                          ),
                          Divider(height: 1, color: borderColor, indent: 64),
                          _buildPremiumListTile(
                            icon: Icons.settings_outlined,
                            iconColor: const Color(0xFF8B5CF6),
                            title: 'App Settings & Theme',
                            subtitle: 'Dark mode and language preferences',
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).pushNamed('/settings');
                            },
                            textColor: textColor,
                            subTextColor: subTextColor,
                          ),
                          Divider(height: 1, color: borderColor, indent: 64),
                          _buildPremiumListTile(
                            icon: Icons.help_outline_rounded,
                            iconColor: const Color(0xFF10B981),
                            title: 'App Interactive Tutorial',
                            subtitle: 'Guided walkthrough of buttons & features',
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              TutorialService.instance.startTutorial(force: true);
                            },
                            textColor: textColor,
                            subTextColor: subTextColor,
                          ),
                          Divider(height: 1, color: borderColor, indent: 64),
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            value: _notifyOrders,
                            onChanged: (v) {
                              HapticFeedback.lightImpact();
                              setState(() => _notifyOrders = v);
                            },
                            secondary: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.notifications_active_outlined, color: Color(0xFF10B981), size: 22),
                            ),
                            title: Text('Order Notifications', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                            subtitle: Text('Receive delivery status updates', style: TextStyle(fontSize: 12, color: subTextColor)),
                            activeThumbColor: Colors.white,
                            activeTrackColor: const Color(0xFF10B981),
                            inactiveTrackColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Sign Out Button
                  InkWell(
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      try {
                        await SupabaseService.signOut();
                      } catch (_) {}
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3), width: 1.5),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 22),
                          SizedBox(width: 10),
                          Text(
                            'SIGN OUT',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumListTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color textColor,
    required Color subTextColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: subTextColor)),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: subTextColor.withValues(alpha: 0.5)),
      onTap: onTap,
    );
  }
}

class _EditProfileDialogContent extends StatefulWidget {
  final UserProfile profile;
  final String initialAddress;
  final String initialLandmark;
  final bool isDark;
  final Color cardBg;
  final Color textColor;
  final Color subTextColor;
  final Color borderColor;

  const _EditProfileDialogContent({
    required this.profile,
    required this.initialAddress,
    required this.initialLandmark,
    required this.isDark,
    required this.cardBg,
    required this.textColor,
    required this.subTextColor,
    required this.borderColor,
  });

  @override
  State<_EditProfileDialogContent> createState() => __EditProfileDialogContentState();
}

class __EditProfileDialogContentState extends State<_EditProfileDialogContent> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _landmarkController;

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
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.profile.fullName);

    String rawPhone = widget.profile.phone;
    if (rawPhone.startsWith('+63')) {
      rawPhone = '0${rawPhone.substring(3)}';
    }
    _phoneController = TextEditingController(text: rawPhone);

    _addressController = TextEditingController(text: widget.initialAddress);
    _landmarkController = TextEditingController(text: widget.initialLandmark);
    _selectedLatitude = widget.profile.latitude;
    _selectedLongitude = widget.profile.longitude;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _landmarkController.dispose();
    super.dispose();
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
      TopBanner.show(context, 'Delivery address pinned: ${result.address}', isError: false);
    }
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    if (_selectedBarangay == 'Select Barangay' || _selectedBarangay.isEmpty) {
      TopBanner.show(context, 'Please select a valid barangay.', isError: true);
      return;
    }

    final fullName = ProfileValidationUtils.sanitizeInput(_fullNameController.text);
    final rawPhone = ProfileValidationUtils.sanitizeInput(_phoneController.text);
    final phoneE164 = '+63${rawPhone.substring(1)}';
    final address = ProfileValidationUtils.sanitizeInput(_addressController.text);
    final landmark = ProfileValidationUtils.sanitizeInput(_landmarkController.text);

    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    try {
      final user = SupabaseService.currentUser;
      if (user == null) throw Exception('Not authenticated');

      // Duplicate phone check if phone was modified
      if (phoneE164 != widget.profile.phone) {
        final phoneCheck = await SupabaseService.client
            .from('profiles')
            .select('id')
            .or('phone.eq.$rawPhone,phone.eq.$phoneE164')
            .neq('id', user.id)
            .maybeSingle();

        if (phoneCheck != null) {
          if (!mounted) return;
          setState(() => _isSaving = false);
          TopBanner.show(context, 'This phone number is already registered to another account.', isError: true);
          return;
        }
      }

      final fullAddress = landmark.isNotEmpty
          ? '$address, $_selectedBarangay (Landmark: $landmark)'
          : '$address, $_selectedBarangay';

      final updates = <String, dynamic>{
        'full_name': fullName,
        'phone': phoneE164,
        'address': fullAddress,
      };

      if (_selectedLatitude != null) updates['latitude'] = _selectedLatitude;
      if (_selectedLongitude != null) updates['longitude'] = _selectedLongitude;

      await SupabaseService.updateProfile(userId: user.id, updates: updates);

      if (!mounted) return;
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final p = widget.profile;

      final nameParts = fullName.split(' ');
      final fName = nameParts.first;
      final lName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      userProvider.setProfile(UserProfile(
        id: p.id,
        firstName: fName,
        lastName: lName,
        email: p.email,
        phone: phoneE164,
        address: fullAddress,
        role: p.role,
        avatarUrl: p.avatarUrl,
        latitude: _selectedLatitude ?? p.latitude,
        longitude: _selectedLongitude ?? p.longitude,
      ));

      Navigator.pop(context);
      TopBanner.show(context, 'Profile information updated successfully!', isError: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      TopBanner.show(context, 'Failed to update profile: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit Profile Information',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: widget.textColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: widget.subTextColor),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Full Name Field
              TextFormField(
                controller: _fullNameController,
                enabled: !_isSaving,
                maxLength: 100,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'[\r\n\t]')),
                ],
                style: TextStyle(color: widget.textColor, fontWeight: FontWeight.bold, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  counterText: '',
                  prefixIcon: Icon(Icons.person_rounded, color: Color(0xFF0284C7)),
                ),
                validator: ProfileValidationUtils.validateFullName,
              ),
              const SizedBox(height: 12),

              // Phone Number
              TextFormField(
                controller: _phoneController,
                enabled: !_isSaving,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                style: TextStyle(color: widget.textColor, fontWeight: FontWeight.bold, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Phone Number (09XXXXXXXXX) *',
                  counterText: '',
                  prefixIcon: Icon(Icons.phone_android_rounded, color: Color(0xFF0284C7)),
                ),
                validator: ProfileValidationUtils.validatePhone,
              ),
              const SizedBox(height: 12),

              // Complete Delivery Address
              TextFormField(
                controller: _addressController,
                enabled: !_isSaving,
                maxLength: 200,
                maxLines: 2,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'[\r\n\t]')),
                ],
                style: TextStyle(color: widget.textColor, fontWeight: FontWeight.bold, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Default Delivery Street Address *',
                  counterText: '',
                  prefixIcon: Icon(Icons.location_on_rounded, color: Color(0xFF0284C7)),
                ),
                validator: ProfileValidationUtils.validateAddress,
              ),
              const SizedBox(height: 12),

              // Barangay Dropdown
              DropdownButtonFormField<String>(
                value: _selectedBarangay,
                decoration: InputDecoration(
                  labelText: 'Barangay *',
                  prefixIcon: const Icon(Icons.map_outlined, color: Color(0xFF0284C7)),
                  filled: true,
                  fillColor: widget.cardBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: widget.borderColor, width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.8),
                  ),
                ),
                items: _barangayList.map((bg) {
                  return DropdownMenuItem<String>(
                    value: bg,
                    child: Text(
                      bg,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: bg == 'Select Barangay' ? FontWeight.normal : FontWeight.bold,
                        color: bg == 'Select Barangay' ? widget.subTextColor : widget.textColor,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: _isSaving
                    ? null
                    : (val) {
                        if (val != null) setState(() => _selectedBarangay = val);
                      },
                validator: (val) {
                  if (val == null || val == 'Select Barangay' || val.trim().isEmpty) {
                    return 'Please select a valid barangay.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Landmark / Delivery Notes (Optional)
              TextFormField(
                controller: _landmarkController,
                enabled: !_isSaving,
                maxLength: 250,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'[\r\n\t]')),
                ],
                style: TextStyle(color: widget.textColor, fontWeight: FontWeight.bold, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Landmark / Delivery Notes (Optional)',
                  counterText: '',
                  prefixIcon: Icon(Icons.business_rounded, color: Color(0xFF0284C7)),
                ),
                validator: ProfileValidationUtils.validateLandmark,
              ),
              const SizedBox(height: 14),

              // Pin Location on Map Button
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _pickLocationOnMap,
                icon: Icon(
                  _selectedLatitude != null ? Icons.check_circle_rounded : Icons.my_location_rounded,
                  color: _selectedLatitude != null ? const Color(0xFF10B981) : const Color(0xFF0284C7),
                  size: 18,
                ),
                label: Text(
                  _selectedLatitude != null ? 'CHANGE PIN LOCATION ON MAP' : 'PIN EXACT LOCATION ON MAP',
                  style: TextStyle(
                    color: _selectedLatitude != null ? const Color(0xFF10B981) : const Color(0xFF0284C7),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  side: BorderSide(
                    color: _selectedLatitude != null ? const Color(0xFF10B981) : const Color(0xFF0284C7),
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Save Changes Button
              InkWell(
                onTap: _isSaving ? null : _saveChanges,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'SAVE CHANGES',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 0.5,
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

class _ChangePasswordDialogContent extends StatefulWidget {
  final bool isDark;
  final Color cardBg;
  final Color textColor;
  final Color subTextColor;
  final Color borderColor;

  const _ChangePasswordDialogContent({
    required this.isDark,
    required this.cardBg,
    required this.textColor,
    required this.subTextColor,
    required this.borderColor,
  });

  @override
  State<_ChangePasswordDialogContent> createState() => __ChangePasswordDialogContentState();
}

class __ChangePasswordDialogContentState extends State<_ChangePasswordDialogContent> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final currentPass = _currentPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (confirmPass != newPass) {
      TopBanner.show(context, 'Confirm password does not match new password.', isError: true);
      return;
    }

    final user = SupabaseService.currentUser;
    if (user == null || user.email == null) {
      TopBanner.show(context, 'Session expired. Please log in again.', isError: true);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    try {
      // Step 1: Verify current password by attempting re-authentication
      try {
        await SupabaseService.signInWithPassword(
          email: user.email!,
          password: currentPass,
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        TopBanner.show(context, 'Current password is incorrect. Please re-check.', isError: true);
        return;
      }

      // Step 2: Update password in Supabase Auth
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPass),
      );

      if (!mounted) return;
      Navigator.pop(context); // Close dialog
      TopBanner.show(context, 'Password changed successfully!', isError: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      TopBanner.show(context, 'Failed to change password: ${e.toString().replaceAll('Exception: ', '')}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(22),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Change Password',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: widget.textColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: widget.subTextColor),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Current Password
              TextFormField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrent,
                enabled: !_isSaving,
                maxLength: 64,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'[\r\n\t]')),
                ],
                style: TextStyle(color: widget.textColor, fontWeight: FontWeight.bold, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Current Password *',
                  counterText: '',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF0284C7)),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: widget.subTextColor),
                    onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Current password is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // New Password
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNew,
                enabled: !_isSaving,
                maxLength: 64,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'[\r\n\t]')),
                ],
                style: TextStyle(color: widget.textColor, fontWeight: FontWeight.bold, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'New Password *',
                  counterText: '',
                  prefixIcon: const Icon(Icons.lock_reset_rounded, color: Color(0xFF0284C7)),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: widget.subTextColor),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                validator: (v) => ProfileValidationUtils.validateNewPassword(v, _currentPasswordController.text),
              ),
              const SizedBox(height: 14),

              // Confirm New Password
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                enabled: !_isSaving,
                maxLength: 64,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'[\r\n\t]')),
                ],
                style: TextStyle(color: widget.textColor, fontWeight: FontWeight.bold, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Confirm New Password *',
                  counterText: '',
                  prefixIcon: const Icon(Icons.lock_clock_outlined, color: Color(0xFF0284C7)),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: widget.subTextColor),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please confirm your new password.';
                  if (v != _newPasswordController.text) return 'Passwords do not match.';
                  return null;
                },
              ),
              const SizedBox(height: 22),

              // Action Button
              SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text(
                          'CHANGE PASSWORD',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
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
