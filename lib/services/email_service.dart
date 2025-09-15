// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class EmailService {
  // EmailJS credentials (keep for fallback)
  static const String _serviceId = 'service_iuouffm';
  static const String _templateId = 'template_8060k7e';
  static const String _publicKey = 'LU5nqmNiQgb_vus3a';
  static const String _privateKey = 'nFG6evuU6LXSRyttdPpY4';

  /// Generates a 5-digit verification PIN
  static String generateVerificationPin() {
    final random = Random();
    return (10000 + random.nextInt(90000)).toString();
  }

  /// Sends password reset PIN via EmailJS with CORS headers
  static Future<bool> sendPasswordResetPin({
    required String email,
    required String pin,
    required String userName,
  }) async {
    try {
      // Try EmailJS first with proper headers
      final success = await _sendViaEmailJS(email, pin, userName);
      if (success) return true;

      // Fallback to Firebase Cloud Function
      return await _sendViaFirebaseFunction(email, pin, userName);
    } catch (e) {
      print('Error sending password reset PIN: $e');
      return false;
    }
  }

  /// Send via EmailJS with mobile-friendly headers
  static Future<bool> _sendViaEmailJS(String email, String pin, String userName) async {
    try {
      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      
      final templateParams = {
        'to_email': email,
        'to_name': userName,
        'verification_pin': pin,
        'app_name': 'VeggieConnect',
        'expiry_minutes': '15',
      };

      final requestBody = {
        'service_id': _serviceId,
        'template_id': _templateId,
        'user_id': _publicKey,
        'accessToken': _privateKey,
        'template_params': templateParams,
      };
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Origin': 'https://veggieconnect.app', // Add your domain
          'Referer': 'https://veggieconnect.app',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        print('✅ EmailJS: Password reset PIN sent successfully to $email');
        return true;
      } else {
        print('❌ EmailJS failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ EmailJS error: $e');
      return false;
    }
  }

  /// Fallback: Send via Firebase Cloud Function
  static Future<bool> _sendViaFirebaseFunction(String email, String pin, String userName) async {
    try {
      // Store email request in Firestore for Cloud Function to process
      await FirebaseFirestore.instance.collection('email_queue').add({
        'type': 'password_reset',
        'to_email': email,
        'to_name': userName,
        'verification_pin': pin,
        'app_name': 'VeggieConnect',
        'expiry_minutes': '15',
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
      });

      print('✅ Fallback: Email queued for processing');
      return true;
    } catch (e) {
      print('❌ Fallback error: $e');
      return false;
    }
  }

  /// Alternative: Direct SMTP implementation (most reliable)
  static Future<bool> sendPasswordResetPinDirect({
    required String email,
    required String pin,
    required String userName,
  }) async {
    try {
      // Use a reliable email service API (SendGrid, Mailgun, etc.)
      final url = Uri.parse('https://api.sendgrid.v3/mail/send');
      
      final emailContent = {
        'personalizations': [
          {
            'to': [{'email': email, 'name': userName}],
            'subject': 'VeggieConnect - Reset Your Password'
          }
        ],
        'from': {'email': 'noreply@veggieconnect.app', 'name': 'VeggieConnect'},
        'content': [
          {
            'type': 'text/html',
            'value': _generateEmailHTML(userName, pin)
          }
        ]
      };

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer YOUR_SENDGRID_API_KEY',
          'Content-Type': 'application/json',
        },
        body: json.encode(emailContent),
      );

      if (response.statusCode == 202) {
        print('✅ SendGrid: Email sent successfully');
        return true;
      } else {
        print('❌ SendGrid failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ SendGrid error: $e');
      return false;
    }
  }

  /// Generate HTML email content
  static String _generateEmailHTML(String userName, String pin) {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5; }
            .container { max-width: 600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
            .header { text-align: center; margin-bottom: 30px; }
            .logo { color: #4CAF50; font-size: 28px; font-weight: bold; margin-bottom: 10px; }
            .pin-box { background-color: #f8f9fa; border: 2px solid #4CAF50; border-radius: 10px; padding: 20px; text-align: center; margin: 20px 0; }
            .pin { font-size: 32px; font-weight: bold; color: #4CAF50; letter-spacing: 8px; margin: 10px 0; }
            .warning { background-color: #fff3cd; border: 1px solid #ffeaa7; border-radius: 5px; padding: 15px; margin: 20px 0; }
            .footer { text-align: center; margin-top: 30px; color: #666; font-size: 12px; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <div class="logo">VeggieConnect</div>
                <h2>Password Reset Request</h2>
            </div>
            
            <p>Hello $userName,</p>
            
            <p>You have requested a password reset for your VeggieConnect account. To proceed, please use the verification PIN below:</p>
            
            <div class="pin-box">
                <p><strong>Your Verification PIN:</strong></p>
                <div class="pin">$pin</div>
            </div>
            
            <div class="warning">
                <p><strong>⚠️ Important Security Information:</strong></p>
                <ul>
                    <li>This PIN will expire in 15 minutes</li>
                    <li>Do not share this PIN with anyone</li>
                    <li>If you didn't request this password reset, please ignore this email</li>
                    <li>VeggieConnect will never contact you about this email or ask for login codes</li>
                </ul>
            </div>
            
            <p>If you didn't make this request, you can safely ignore this email. Your account remains secure.</p>
            
            <p>Best regards,<br>The VeggieConnect Team</p>
            
            <div class="footer">
                <p>This is an automated message. Please do not reply to this email.</p>
                <p>© 2024 VeggieConnect. All rights reserved.</p>
            </div>
        </div>
    </body>
    </html>
    ''';
  }

  /// Sends welcome email (optional - for new user registration)
  static Future<bool> sendWelcomeEmail({
    required String email,
    required String userName,
  }) async {
    try {
      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Origin': 'https://veggieconnect.app',
          'Referer': 'https://veggieconnect.app',
        },
        body: json.encode({
          'service_id': _serviceId,
          'template_id': 'template_welcome',
          'user_id': _publicKey,
          'accessToken': _privateKey,
          'template_params': {
            'to_email': email,
            'to_name': userName,
            'app_name': 'VeggieConnect',
          },
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error sending welcome email: $e');
      return false;
    }
  }
}
