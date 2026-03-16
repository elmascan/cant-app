import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';
import '../services/firebase_service.dart';

class SwipeScreen extends StatefulWidget {
  const SwipeScreen({super.key});

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen>
    with SingleTickerProviderStateMixin {
  final CardSwiperController _swiperController = CardSwiperController();

  List<Map<String, dynamic>> _profiles = [];
  bool _loading = true;
  bool _showMatch = false;
  String _matchName = '';
  String _matchEmoji = '';

  late AnimationController _matchAnimController;
  late Animation<double> _matchScaleAnim;
  late Animation<double> _matchFadeAnim;

  @override
  void initState() {
    super.initState();
    _matchAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _matchScaleAnim =
        CurvedAnimation(parent: _matchAnimController, curve: Curves.elasticOut);
    _matchFadeAnim =
        CurvedAnimation(parent: _matchAnimController, curve: Curves.easeIn);
    _loadProfiles();
  }

  @override
  void dispose() {
    _swiperController.dispose();
    _matchAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    final profiles = await FirebaseService.getDiscoverProfiles();
    if (mounted) setState(() { _profiles = profiles; _loading = false; });
  }

  Future<bool> _onSwipe(
    int previousIndex,
    int? currentIndex,
    CardSwiperDirection direction,
  ) async {
    if (previousIndex >= _profiles.length) return true;
    final profile = _profiles[previousIndex];
    final swipedUserId = profile['uid'] as String;

    if (direction == CardSwiperDirection.right) {
      final isMatch = await FirebaseService.swipeUser(
        swipedUserId: swipedUserId,
        liked: true,
      );
      if (isMatch && mounted) {
        _triggerMatchAnimation(
          profile['full_name'] as String? ?? 'Someone',
          (profile['sports'] as List?)?.isNotEmpty == true
              ? getSportEmoji((profile['sports'] as List).first as String)
              : '🏃',
        );
      }
    } else if (direction == CardSwiperDirection.left) {
      await FirebaseService.swipeUser(swipedUserId: swipedUserId, liked: false);
    }
    return true;
  }

  void _triggerMatchAnimation(String name, String emoji) {
    setState(() { _showMatch = true; _matchName = name; _matchEmoji = emoji; });
    _matchAnimController.forward(from: 0);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _matchAnimController.reverse().then((_) {
          if (mounted) setState(() => _showMatch = false);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Find Sport Mate',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : _profiles.isEmpty
                  ? _buildEmptyState()
                  : Column(
                      children: [
                        const SizedBox(height: 12),
                        Expanded(
                          child: CardSwiper(
                            controller: _swiperController,
                            cardsCount: _profiles.length,
                            onSwipe: _onSwipe,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 8),
                            numberOfCardsDisplayed:
                                math.min(3, _profiles.length),
                            backCardOffset: const Offset(0, 24),
                            scale: 0.92,
                            cardBuilder: (context, index, hPct, vPct) {
                              return _ProfileCard(
                                profile: _profiles[index],
                                swipeProgress: hPct.toDouble(),
                              );
                            },
                          ),
                        ),
                        _buildActionButtons(),
                        const SizedBox(height: 16),
                      ],
                    ),
          if (_showMatch) _buildMatchOverlay(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            icon: Icons.close_rounded,
            color: AppColors.error,
            size: 56,
            onTap: () => _swiperController.swipe(CardSwiperDirection.left),
          ),
          _ActionButton(
            icon: Icons.sports_rounded,
            color: AppColors.primary,
            size: 56,
            onTap: () => _swiperController.swipe(CardSwiperDirection.right),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏃', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 20),
            Text('No players found',
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'Update your sports interests in your profile to find playmates.',
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchOverlay() {
    return FadeTransition(
      opacity: _matchFadeAnim,
      child: Container(
        color: Colors.black.withValues(alpha: 0.75),
        child: Center(
          child: ScaleTransition(
            scale: _matchScaleAnim,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 40,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_matchEmoji, style: const TextStyle(fontSize: 56)),
                  const SizedBox(height: 12),
                  Text("It's a Match! 🎉",
                      style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(
                    'You and $_matchName both want to play!',
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () {
                      _matchAnimController.reverse().then((_) {
                        if (mounted) setState(() => _showMatch = false);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 12),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(40)),
                      child: Text('Keep Swiping',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
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
}

// ─── Profile Card ─────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  final double swipeProgress;
  const _ProfileCard({required this.profile, required this.swipeProgress});

  @override
  Widget build(BuildContext context) {
    final name = profile['full_name'] as String? ?? 'Unknown';
    final city = profile['city'] as String? ?? '';
    final sports =
        (profile['sports'] as List?)?.map((s) => s.toString()).toList() ?? [];
    final photoUrl = profile['photo_url'] as String?;
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase();

    Color? tintColor;
    double tintOpacity = 0;
    if (swipeProgress > 0) {
      tintColor = AppColors.success;
      tintOpacity = (swipeProgress.abs() / 100).clamp(0.0, 0.6);
    } else if (swipeProgress < 0) {
      tintColor = AppColors.error;
      tintOpacity = (swipeProgress.abs() / 100).clamp(0.0, 0.6);
    }

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      photoUrl != null
                          ? Image.network(photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _avatarFallback(initials))
                          : _avatarFallback(initials),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.5)
                              ],
                              stops: const [0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: GoogleFonts.inter(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                            if (city.isNotEmpty)
                              Row(children: [
                                const Icon(Icons.location_on_rounded,
                                    color: Colors.white70, size: 14),
                                const SizedBox(width: 4),
                                Text(city,
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w500)),
                              ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Plays',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textTertiary,
                                letterSpacing: 1.0)),
                        const SizedBox(height: 8),
                        if (sports.isEmpty)
                          Text('No sports listed',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.textSecondary))
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: sports
                                .map((s) => _SportChip(sport: s))
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (tintColor != null && tintOpacity > 0)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: tintColor.withValues(alpha: tintOpacity),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        if (swipeProgress > 15)
          Positioned(
              top: 24,
              left: 20,
              child: _SwipeBadge(label: 'PLAY', color: AppColors.success)),
        if (swipeProgress < -15)
          Positioned(
              top: 24,
              right: 20,
              child: _SwipeBadge(label: 'PASS', color: AppColors.error)),
      ],
    );
  }

  Widget _avatarFallback(String initials) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(initials,
            style: GoogleFonts.inter(
                fontSize: 64,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.9))),
      ),
    );
  }
}

class _SportChip extends StatelessWidget {
  final String sport;
  const _SportChip({required this.sport});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(20)),
      child: Text('${getSportEmoji(sport)} $sport',
          style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary)),
    );
  }
}

class _SwipeBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SwipeBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
          border: Border.all(color: color, width: 3),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 2)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.icon,
      required this.color,
      required this.size,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 16,
                spreadRadius: 2)
          ],
        ),
        child: Icon(icon, color: color, size: size * 0.44),
      ),
    );
  }
}
