import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';
import 'swipe_screen.dart';
import 'communities_screen.dart';

class DiscoverTab extends StatelessWidget {
  const DiscoverTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Discover',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Find players or join communities',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 32),

              // Sport Mate card
              _OptionCard(
                emoji: '🤝',
                title: 'Match with your\nSport Mate',
                description:
                    'Swipe right on players who share\nyour sports interests',
                gradientColors: const [Color(0xFF2563EB), Color(0xFF7C3AED)],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SwipeScreen()),
                ),
              ),

              const SizedBox(height: 16),

              // Communities card
              _OptionCard(
                emoji: '🏟️',
                title: 'Communities',
                description:
                    'Join sport communities, chat with\nplayers in your area',
                gradientColors: const [Color(0xFF059669), Color(0xFF0891B2)],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CommunitiesScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _OptionCard({
    required this.emoji,
    required this.title,
    required this.description,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 52)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}
