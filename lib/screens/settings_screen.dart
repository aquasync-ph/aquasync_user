import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/app_language.dart';
import '../providers/settings_provider.dart';
import '../services/localization_service.dart';
import '../services/tutorial_service.dart';
import '../widgets/top_banner.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF08101E) : const Color(0xFFF4F9FC),
      appBar: AppBar(
        title: Text(
          LocalizationService.translate(context, 'settings', settings.language),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'APP PREFERENCES',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: subTextColor, letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),
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
                    _buildSwitchTile(
                      title: LocalizationService.translate(context, 'dark_mode', settings.language),
                      subtitle: 'Enable dark navy theme interface',
                      icon: Icons.dark_mode_rounded,
                      iconBgColor: const Color(0xFF8B5CF6),
                      value: settings.isDarkMode,
                      onChanged: (val) {
                        HapticFeedback.lightImpact();
                        settings.toggleDarkMode(val);
                      },
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    Divider(height: 1, color: borderColor, indent: 64),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.language_rounded, color: Color(0xFF0284C7), size: 22),
                      ),
                      title: Text(LocalizationService.translate(context, 'language', settings.language), style: TextStyle(fontWeight: FontWeight.w700, color: textColor, fontSize: 15)),
                      subtitle: Text('Change app default language', style: TextStyle(color: subTextColor, fontSize: 12)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<AppLanguage>(
                            value: settings.language,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF0284C7)),
                            dropdownColor: cardBg,
                            style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0284C7), fontSize: 13),
                            onChanged: (AppLanguage? newValue) {
                              if (newValue != null) {
                                HapticFeedback.lightImpact();
                                settings.setLanguage(newValue);
                              }
                            },
                            items: const [
                              DropdownMenuItem(value: AppLanguage.english, child: Text('English')),
                              DropdownMenuItem(value: AppLanguage.tagalog, child: Text('Tagalog')),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: borderColor, indent: 64),
                    _buildSwitchTile(
                      title: 'Push Notifications',
                      subtitle: 'Receive live delivery status alerts',
                      icon: Icons.notifications_active_rounded,
                      iconBgColor: const Color(0xFF10B981),
                      value: settings.pushNotifications,
                      onChanged: (val) {
                        HapticFeedback.lightImpact();
                        settings.togglePushNotifications(val);
                      },
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    Divider(height: 1, color: borderColor, indent: 64),
                    _buildSwitchTile(
                      title: 'In-App Alert Sounds',
                      subtitle: 'Play audio alerts on dispatch updates',
                      icon: Icons.volume_up_rounded,
                      iconBgColor: const Color(0xFFF59E0B),
                      value: settings.soundEnabled,
                      onChanged: (val) {
                        HapticFeedback.lightImpact();
                        settings.toggleSound(val);
                      },
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'SUPPORT & INFORMATION',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: subTextColor, letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),
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
                      icon: Icons.touch_app_rounded,
                      iconColor: const Color(0xFF0284C7),
                      title: 'Interactive App Showcase',
                      subtitle: 'Guided walkthrough of buttons & features',
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        Navigator.of(context).pop();
                        TutorialService.instance.startTutorial(force: true);
                      },
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    Divider(height: 1, color: borderColor, indent: 64),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 22),
                      ),
                      title: Text('App Version', style: TextStyle(fontWeight: FontWeight.w700, color: textColor, fontSize: 15)),
                      subtitle: Text('Current build installed', style: TextStyle(color: subTextColor, fontSize: 12)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('2.4.0-Stable', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ),
                    Divider(height: 1, color: borderColor, indent: 64),
                    _buildPremiumListTile(
                      icon: Icons.privacy_tip_rounded,
                      iconColor: const Color(0xFF6366F1),
                      title: 'Privacy Policy',
                      subtitle: 'Read our data & privacy terms',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        TopBanner.show(context, 'Privacy Policy details will be here soon.', isError: false);
                      },
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBgColor,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color textColor,
    required Color subTextColor,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: textColor, fontSize: 15)),
      subtitle: Text(subtitle, style: TextStyle(color: subTextColor, fontSize: 12)),
      secondary: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconBgColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconBgColor, size: 22),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.white,
      activeTrackColor: iconBgColor,
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

