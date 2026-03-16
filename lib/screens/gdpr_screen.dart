import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

const _kGdprKey = 'gdpr_accepted';

class GdprScreen extends StatelessWidget {
  final VoidCallback onAccepted;

  const GdprScreen({super.key, required this.onAccepted});

  static Future<bool> isAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kGdprKey) ?? false;
  }

  static Future<void> accept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kGdprKey, true);
  }

  void _accept(BuildContext context) async {
    await GdprScreen.accept();
    onAccepted();
  }

  void _learnMore(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, controller) => _PrivacyContent(scrollController: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Logo / Icon
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🏆', style: TextStyle(fontSize: 42)),
                ),
              ),
              const SizedBox(height: 28),

              Text(
                'Welcome to CanT',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Before you start, please review how we handle your data.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 36),

              // Data points
              _DataPoint(
                icon: Icons.person_outline_rounded,
                title: 'Account data',
                desc: 'Name and email to create your profile.',
              ),
              const SizedBox(height: 16),
              _DataPoint(
                icon: Icons.event_outlined,
                title: 'Activity data',
                desc: 'Events you create or join within the app.',
              ),
              const SizedBox(height: 16),
              _DataPoint(
                icon: Icons.location_on_outlined,
                title: 'Location (optional)',
                desc: 'Used only to show nearby events.',
              ),
              const SizedBox(height: 16),
              _DataPoint(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                desc: 'Waitlist updates and event reminders.',
              ),

              const Spacer(flex: 3),

              // GDPR text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                        height: 1.5),
                    children: [
                      const TextSpan(
                          text:
                              'By continuing, you agree to our '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => _learnMore(context),
                      ),
                      const TextSpan(
                          text:
                              ' and the processing of your personal data in accordance with GDPR.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Accept button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _accept(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    shadowColor: AppColors.primary.withValues(alpha: 0.4),
                  ),
                  child: Text(
                    'Accept & Continue',
                    style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Learn more
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => _learnMore(context),
                  child: Text(
                    'Learn More',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _DataPoint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _DataPoint(
      {required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(desc,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrivacyContent extends StatelessWidget {
  final ScrollController scrollController;

  const _PrivacyContent({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Text('Privacy Policy',
            style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text('Last updated: March 2026',
            style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.textTertiary)),
        const SizedBox(height: 20),
        _section('Data We Collect',
            'We collect your name, email address, and activity data (events created and joined) to provide the CanT service. Location data is optional and only used to show nearby events.'),
        _section('How We Use Your Data',
            'Your data is used to operate the app, personalize your experience, and send event-related notifications. We do not sell your personal data to third parties.'),
        _section('Data Storage',
            'Your data is stored securely on Google Firebase servers located in the European Union. We comply with GDPR requirements for data storage and processing.'),
        _section('Your Rights',
            'Under GDPR, you have the right to access, correct, or delete your personal data at any time. You can also withdraw your consent. To exercise these rights, contact us through the app.'),
        _section('Cookies & Analytics',
            'We use Firebase Analytics to understand how users interact with the app. This data is anonymized and used only to improve the service.'),
        _section('Contact',
            'For privacy-related questions, contact us at privacy@playmate.app'),
      ],
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text(body,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.55)),
        ],
      ),
    );
  }
}
