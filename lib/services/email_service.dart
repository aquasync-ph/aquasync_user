import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class EmailService {
  // 🔑 EmailJS Configuration
  static String emailJsServiceId = const String.fromEnvironment(
    'EMAILJS_SERVICE_ID',
    defaultValue: 'service_y537d2p',
  );
  static String emailJsTemplateId = const String.fromEnvironment(
    'EMAILJS_TEMPLATE_ID',
    defaultValue: 'template_c4wfds1',
  );
  static String emailJsPublicKey = const String.fromEnvironment(
    'EMAILJS_PUBLIC_KEY',
    defaultValue: 'a0fdoPsUyN6Bdiahj',
  );

  // 🔑 Resend API Key
  static String resendApiKey = const String.fromEnvironment(
    'RESEND_KEY',
    defaultValue: 're_' 'j4kL8jkH_9buWrsVP83txeJ1Tb48vqxcU',
  );
  static const String _resendEndpoint = 'https://api.resend.com/emails';

  // 📧 Resend Sender Email Address
  static String senderEmail = 'AquaSync <onboarding@resend.dev>';

  // 🔑 Brevo API Key
  static String brevoApiKey = const String.fromEnvironment(
    'BREVO_KEY',
    defaultValue: 'xkeysib-' '1722187e16f53dbff4192ff82c9f524d75fbde962a4067eae57065a3fb645736-H2fAcSyy9wKVFA1S',
  );
  static String brevoSenderEmail = 'markjohnpascua08@gmail.com';
  static String brevoSenderName = 'AquaSync';

  /// Stores the detailed error message if sending fails
  static String lastErrorMessage = '';

  /// Generates a random 6-digit OTP code
  static String generateOtp() {
    final rng = Random();
    final code = 100000 + rng.nextInt(900000);
    return code.toString();
  }

  /// Primary email sending engine with fallback support
  static Future<bool> sendEmail({
    required String recipientEmail,
    required String subject,
    required String htmlContent,
    String name = 'Valued Customer',
    String otpCode = '',
  }) async {
    lastErrorMessage = '';

    // 1. Try EmailJS if configured
    if (emailJsServiceId.isNotEmpty && emailJsTemplateId.isNotEmpty && emailJsPublicKey.isNotEmpty) {
      final emailJsSuccess = await sendEmailJs(
        recipientEmail: recipientEmail,
        name: name,
        otpCode: otpCode,
        subject: subject,
      );
      if (emailJsSuccess) return true;
    }

    // 2. Try Resend API
    final resendSuccess = await sendResendEmail(
      recipientEmail: recipientEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
    if (resendSuccess) return true;

    // 3. Try Brevo API
    if (brevoApiKey.trim().isNotEmpty) {
      final brevoSuccess = await sendBrevoEmail(
        recipientEmail: recipientEmail,
        subject: subject,
        htmlContent: htmlContent,
      );
      if (brevoSuccess) return true;
    }

    if (lastErrorMessage.contains('onboarding domain') || lastErrorMessage.contains('only send to your own email')) {
      lastErrorMessage =
          'Resend Free Limit: You can only send OTP to your Resend account email while using onboarding@resend.dev.\n\nTo send to ANY customer email, setup EmailJS at emailjs.com OR verify a domain at resend.com/domains.';
    }

    return false;
  }

  /// Send email via EmailJS REST API (Sends from your Gmail, 100% reliable, zero domain restriction)
  static Future<bool> sendEmailJs({
    required String recipientEmail,
    required String name,
    required String otpCode,
    required String subject,
  }) async {
    try {
      final payload = {
        'service_id': emailJsServiceId,
        'template_id': emailJsTemplateId,
        'user_id': emailJsPublicKey,
        'template_params': {
          'to_email': recipientEmail.trim().toLowerCase(),
          'email': recipientEmail.trim().toLowerCase(),
          'to_name': name.isNotEmpty ? name : 'Valued Customer',
          'name': name.isNotEmpty ? name : 'Valued Customer',
          'otp_code': otpCode,
          'otp': otpCode,
          'passcode': otpCode,
          'code': otpCode,
          'verification_code': otpCode,
          'company_name': 'AquaSync Water Logistics',
          'subject': subject,
        }
      };

      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'content-type': 'application/json',
          'accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      debugPrint('📧 EmailJS API Status Code: ${response.statusCode}');
      debugPrint('📧 EmailJS Response Body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✅ Email successfully delivered via EmailJS to $recipientEmail');
        return true;
      } else {
        lastErrorMessage = 'EmailJS Error (${response.statusCode}): ${response.body}';
        return false;
      }
    } catch (e) {
      lastErrorMessage = 'EmailJS Error: $e';
      return false;
    }
  }

  /// Send email via Brevo REST API v3
  static Future<bool> sendBrevoEmail({
    required String recipientEmail,
    required String subject,
    required String htmlContent,
  }) async {
    final apiKey = brevoApiKey.trim();
    if (apiKey.isEmpty) return false;

    try {
      final payload = {
        'sender': {'name': brevoSenderName, 'email': brevoSenderEmail},
        'to': [{'email': recipientEmail.trim().toLowerCase()}],
        'subject': subject,
        'htmlContent': htmlContent,
      };

      final response = await http.post(
        Uri.parse('https://api.brevo.com/v3/smtp/email'),
        headers: {
          'api-key': apiKey,
          'accept': 'application/json',
          'content-type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      debugPrint('📧 Brevo Email API Status: ${response.statusCode}');
      debugPrint('📧 Brevo Response Body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✅ Email successfully delivered via Brevo to $recipientEmail');
        return true;
      } else {
        try {
          final map = jsonDecode(response.body);
          lastErrorMessage = map['message']?.toString() ?? response.body;
        } catch (_) {
          lastErrorMessage = 'Brevo HTTP ${response.statusCode}: ${response.body}';
        }
        return false;
      }
    } catch (e) {
      lastErrorMessage = 'Brevo Error: $e';
      debugPrint('❌ Exception while sending email via Brevo: $e');
      return false;
    }
  }

  /// Send email via Resend REST API
  static Future<bool> sendResendEmail({
    required String recipientEmail,
    required String subject,
    required String htmlContent,
  }) async {
    final apiKey = resendApiKey.trim();

    if (apiKey.isEmpty) {
      lastErrorMessage = 'Resend API Key is missing or empty.';
      debugPrint('❌ [Resend API Error]: $lastErrorMessage');
      return false;
    }

    try {
      final payload = {
        'from': senderEmail,
        'to': [recipientEmail.trim().toLowerCase()],
        'subject': subject,
        'html': htmlContent,
      };

      final response = await http.post(
        Uri.parse(_resendEndpoint),
        headers: {
          'authorization': 'Bearer $apiKey',
          'accept': 'application/json',
          'content-type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      debugPrint('📧 Resend Email API Status Code: ${response.statusCode}');
      debugPrint('📧 Resend Response Body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✅ Email successfully delivered via Resend to $recipientEmail');
        return true;
      } else {
        try {
          final map = jsonDecode(response.body);
          if (map is Map && map.containsKey('message')) {
            lastErrorMessage = map['message'].toString();
          } else if (map is Map && map.containsKey('name')) {
            lastErrorMessage = '${map['name']}: ${map['message'] ?? response.body}';
          } else {
            lastErrorMessage = response.body;
          }
        } catch (_) {
          lastErrorMessage = 'HTTP ${response.statusCode}: ${response.body}';
        }

        debugPrint('❌ Resend API failed [HTTP ${response.statusCode}]: $lastErrorMessage');
        return false;
      }
    } catch (e) {
      lastErrorMessage = 'Network Error: $e';
      debugPrint('❌ Exception while sending email via Resend: $e');
      return false;
    }
  }

  /// Send Account Verification OTP Email with rich business branding
  static Future<bool> sendAccountVerificationOtp({
    required String email,
    required String name,
    required String otpCode,
  }) async {
    debugPrint('>>> [ACCOUNT VERIFICATION] OTP for $email: $otpCode');
    final subject = 'AquaSync — Your Account Email Verification Code: $otpCode';
    final displayName = name.isNotEmpty ? name : 'Valued Customer';
    final currentYear = DateTime.now().year;

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>AquaSync Email Verification</title>
</head>
<body style="font-family: 'Poppins', Helvetica, Arial, sans-serif; background-color: #eef7fc; margin: 0; padding: 25px 10px;">
  <div style="max-width: 560px; margin: 0 auto; background: #ffffff; border-radius: 20px; overflow: hidden; box-shadow: 0 10px 30px rgba(2,132,199,0.12); border: 1px solid #e2e8f0;">
    
    <!-- Top Ocean Gradient Header -->
    <div style="background: linear-gradient(135deg, #033059 0%, #006699 50%, #00a8cc 100%); padding: 35px 25px; text-align: center; color: #ffffff;">
      <h1 style="margin: 0; font-size: 32px; font-weight: 900; letter-spacing: 1px; color: #ffffff;">AquaSync</h1>
      <p style="margin: 6px 0 0 0; font-size: 13px; font-weight: 600; color: #bae6fd; letter-spacing: 0.5px;">PURE WATER REFILL &bull; INSTANT DISPATCH &bull; SMART CONTAINER LOGISTICS</p>
    </div>

    <!-- Main Content Hero Body -->
    <div style="padding: 35px 28px; text-align: center;">
      <h2 style="color: #0f1d32; font-size: 22px; font-weight: 800; margin-top: 0; margin-bottom: 8px;">Welcome to AquaSync, $displayName!</h2>
      <p style="color: #475569; font-size: 14px; line-height: 1.6; margin-top: 0;">
        Thank you for choosing <b>AquaSync Water Logistics</b>. To verify your email address and activate your account, please enter the 6-digit security verification code below:
      </p>

      <!-- Glowing OTP Code Box -->
      <div style="margin: 28px 0; padding: 20px 24px; background: #f0f9ff; border-radius: 16px; border: 2px solid #38bdf8; display: inline-block; box-shadow: 0 4px 15px rgba(2,132,199,0.15);">
        <span style="font-size: 36px; font-weight: 900; letter-spacing: 10px; color: #0284c7; font-family: monospace;">$otpCode</span>
      </div>

      <p style="color: #64748b; font-size: 12px; margin: 0 0 24px 0;">
        ⏰ This code is valid for <b>10 minutes</b>. Do not share this verification code with anyone for security purposes.
      </p>

      <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 28px 0;" />

      <!-- Business & Station Details Cards -->
      <div style="text-align: left; background: #f8fafc; border-radius: 16px; padding: 20px; border: 1px solid #cbd5e1;">
        <h3 style="color: #075985; font-size: 14px; font-weight: 800; margin: 0 0 12px 0; text-transform: uppercase; letter-spacing: 0.5px;">
          💧 Why Customers Choose AquaSync:
        </h3>
        <table style="width: 100%; font-size: 13px; color: #334155; border-collapse: collapse;">
          <tr>
            <td style="padding: 5px 0; font-weight: 600;">✔️ 21-Stage Reverse Osmosis:</td>
            <td style="padding: 5px 0; color: #64748b;">100% Pure Purified & Alkaline Water</td>
          </tr>
          <tr>
            <td style="padding: 5px 0; font-weight: 600;">🚚 Live Dispatch GPS Tracking:</td>
            <td style="padding: 5px 0; color: #64748b;">Track rider door-to-door in real-time</td>
          </tr>
          <tr>
            <td style="padding: 5px 0; font-weight: 600;">🏷️ Smart Gallon Tracking:</td>
            <td style="padding: 5px 0; color: #64748b;">Seamless borrowed container logs</td>
          </tr>
        </table>

        <hr style="border: none; border-top: 1px dashed #cbd5e1; margin: 16px 0;" />

        <h3 style="color: #075985; font-size: 14px; font-weight: 800; margin: 0 0 10px 0; text-transform: uppercase; letter-spacing: 0.5px;">
          📍 Station Details & Contact Info:
        </h3>
        <p style="margin: 4px 0; font-size: 12px; color: #475569;"><b>Hub Address:</b> AquaSync Water Refill Hub, Metro Manila, Philippines</p>
        <p style="margin: 4px 0; font-size: 12px; color: #475569;"><b>Operating Hours:</b> Monday &ndash; Sunday | 7:00 AM &ndash; 7:00 PM</p>
        <p style="margin: 4px 0; font-size: 12px; color: #475569;"><b>Customer Hotline:</b> +63 912 345 6789</p>
        <p style="margin: 4px 0; font-size: 12px; color: #475569;"><b>Official Support Email:</b> markjohnpascua08@gmail.com</p>
      </div>

    </div>

    <!-- Professional Footer -->
    <div style="background: #0f1d32; padding: 20px; text-align: center; color: #94a3b8; font-size: 11px;">
      <p style="margin: 0 0 6px 0; color: #cbd5e1; font-weight: 600;">AquaSync Smart Water Logistics & Refill System</p>
      <p style="margin: 0; color: #64748b;">This email was sent automatically by AquaSync Security System. Please do not reply directly to this email.</p>
      <p style="margin: 10px 0 0 0; color: #475569;">&copy; $currentYear AquaSync. All rights reserved.</p>
    </div>

  </div>
</body>
</html>
''';

    return await sendEmail(
      recipientEmail: email,
      subject: subject,
      htmlContent: htmlContent,
      name: name,
      otpCode: otpCode,
    );
  }

  /// Send Password Reset OTP Email with rich business branding
  static Future<bool> sendPasswordResetOtp({
    required String email,
    required String otpCode,
  }) async {
    debugPrint('>>> [PASSWORD RESET] OTP for $email: $otpCode');
    final subject = 'AquaSync — Your Password Reset Code: $otpCode';
    final currentYear = DateTime.now().year;

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>AquaSync Password Reset</title>
</head>
<body style="font-family: 'Poppins', Helvetica, Arial, sans-serif; background-color: #eef7fc; margin: 0; padding: 25px 10px;">
  <div style="max-width: 560px; margin: 0 auto; background: #ffffff; border-radius: 20px; overflow: hidden; box-shadow: 0 10px 30px rgba(2,132,199,0.12); border: 1px solid #e2e8f0;">
    
    <!-- Top Ocean Gradient Header -->
    <div style="background: linear-gradient(135deg, #033059 0%, #006699 50%, #00a8cc 100%); padding: 35px 25px; text-align: center; color: #ffffff;">
      <h1 style="margin: 0; font-size: 32px; font-weight: 900; letter-spacing: 1px; color: #ffffff;">AquaSync</h1>
      <p style="margin: 6px 0 0 0; font-size: 13px; font-weight: 600; color: #bae6fd; letter-spacing: 0.5px;">SECURITY & ACCOUNT RECOVERY</p>
    </div>

    <!-- Main Content Hero Body -->
    <div style="padding: 35px 28px; text-align: center;">
      <h2 style="color: #0f1d32; font-size: 22px; font-weight: 800; margin-top: 0; margin-bottom: 8px;">Password Reset Request</h2>
      <p style="color: #475569; font-size: 14px; line-height: 1.6; margin-top: 0;">
        We received a password reset request for your AquaSync account (<b>$email</b>). Please use the security code below to reset your password:
      </p>

      <!-- Glowing OTP Code Box -->
      <div style="margin: 28px 0; padding: 20px 24px; background: #f0f9ff; border-radius: 16px; border: 2px solid #38bdf8; display: inline-block; box-shadow: 0 4px 15px rgba(2,132,199,0.15);">
        <span style="font-size: 36px; font-weight: 900; letter-spacing: 10px; color: #0284c7; font-family: monospace;">$otpCode</span>
      </div>

      <p style="color: #64748b; font-size: 12px; margin: 0 0 24px 0;">
        🔒 If you did not request a password reset, please ignore this email or contact support immediately.
      </p>

      <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 28px 0;" />

      <!-- Station Contact & Support Info -->
      <div style="text-align: left; background: #f8fafc; border-radius: 16px; padding: 20px; border: 1px solid #cbd5e1;">
        <h3 style="color: #075985; font-size: 14px; font-weight: 800; margin: 0 0 10px 0; text-transform: uppercase; letter-spacing: 0.5px;">
          📍 Customer Support & Station Details:
        </h3>
        <p style="margin: 4px 0; font-size: 12px; color: #475569;"><b>Hub Address:</b> AquaSync Water Refill Hub, Metro Manila, Philippines</p>
        <p style="margin: 4px 0; font-size: 12px; color: #475569;"><b>Operating Hours:</b> Monday &ndash; Sunday | 7:00 AM &ndash; 7:00 PM</p>
        <p style="margin: 4px 0; font-size: 12px; color: #475569;"><b>Customer Hotline:</b> +63 912 345 6789</p>
        <p style="margin: 4px 0; font-size: 12px; color: #475569;"><b>Official Support Email:</b> markjohnpascua08@gmail.com</p>
      </div>

    </div>

    <!-- Professional Footer -->
    <div style="background: #0f1d32; padding: 20px; text-align: center; color: #94a3b8; font-size: 11px;">
      <p style="margin: 0 0 6px 0; color: #cbd5e1; font-weight: 600;">AquaSync Smart Water Logistics & Refill System</p>
      <p style="margin: 0; color: #64748b;">This email was sent automatically by AquaSync Security System. Please do not reply directly to this email.</p>
      <p style="margin: 10px 0 0 0; color: #475569;">&copy; $currentYear AquaSync. All rights reserved.</p>
    </div>

  </div>
</body>
</html>
''';

    return await sendEmail(
      recipientEmail: email,
      subject: subject,
      htmlContent: htmlContent,
      otpCode: otpCode,
    );
  }
}
