import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';

class EmailService {
  static const String _apiKey =
      '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';
  static const String _endpoint = 'https://api.brevo.com/v3/smtp/email';
  static const String _senderName = 'AquaSync Water Refill';
  static const String _senderEmail = 'purcalovely02@gmail.com';

  /// Generates a random 6-digit OTP code
  static String generateOtp() {
    final rng = Random();
    final code = 100000 + rng.nextInt(900000);
    return code.toString();
  }

  /// Send email via Brevo REST API
  static Future<bool> sendBrevoEmail({
    required String recipientEmail,
    required String recipientName,
    required String subject,
    required String htmlContent,
  }) async {
    final sendersToTry = [
      {'name': _senderName, 'email': _senderEmail},
      {'name': _senderName, 'email': 'no-reply@aquasync.com'},
    ];

    for (final sender in sendersToTry) {
      try {
        final client = HttpClient();
        final request = await client.postUrl(Uri.parse(_endpoint));

        request.headers.set('accept', 'application/json');
        request.headers.set('api-key', _apiKey);
        request.headers.set('content-type', 'application/json');

        final payload = {
          'sender': sender,
          'to': [
            {
              'email': recipientEmail,
              'name': recipientName.isNotEmpty ? recipientName : 'AquaSync Customer',
            }
          ],
          'subject': subject,
          'htmlContent': htmlContent,
        };

        request.add(utf8.encode(jsonEncode(payload)));

        final response = await request.close();
        final responseBody = await response.transform(utf8.decoder).join();
        client.close();

        debugPrint('Brevo Email API Status: ${response.statusCode}');
        debugPrint('Brevo Response: $responseBody');

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return true;
        }
      } catch (e) {
        debugPrint('Error sending email via Brevo: $e');
      }
    }
    return false;
  }

  /// Send Account Verification OTP Email with rich business branding
  static Future<bool> sendAccountVerificationOtp({
    required String email,
    required String name,
    required String otpCode,
  }) async {
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
        <p style="margin: 4px 0; font-size: 12px; color: #475569;"><b>Official Support Email:</b> purcalovely02@gmail.com</p>
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

    return await sendBrevoEmail(
      recipientEmail: email,
      recipientName: name,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Send Password Reset OTP Email with rich business branding
  static Future<bool> sendPasswordResetOtp({
    required String email,
    required String otpCode,
  }) async {
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
        <p style="margin: 4px 0; font-size: 12px; color: #475569;"><b>Official Support Email:</b> purcalovely02@gmail.com</p>
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

    return await sendBrevoEmail(
      recipientEmail: email,
      recipientName: 'AquaSync Member',
      subject: subject,
      htmlContent: htmlContent,
    );
  }
}
