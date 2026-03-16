import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  static const _slides = [
    (
      url:
          'https://images.unsplash.com/photo-1575361204480-aadea25e6e68?w=900&q=80',
      quote: '"I\'m always in!"',
    ),
    (
      url:
          'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=900&q=80',
      quote: '"Wanna play today?"',
    ),
    (
      url:
          'https://images.unsplash.com/photo-1522163182402-834f871fd851?w=900&q=80',
      quote: '"Push your limits!"',
    ),
    (
      url:
          'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=900&q=80',
      quote: '"Find your people!"',
    ),
  ];

  int _currentIndex = 0;
  int _previousIndex = 0;
  double _opacity = 1.0;
  Timer? _timer;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _fadeController.value = 1.0;
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _nextSlide());
  }

  void _nextSlide() {
    if (!mounted) return;
    _previousIndex = _currentIndex;
    final next = (_currentIndex + 1) % _slides.length;
    _fadeController.reset();
    setState(() => _currentIndex = next);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentIndex];
    final prevSlide = _slides[_previousIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Previous image (stays while fading in new)
          Image.network(
            prevSlide.url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(color: AppColors.primary),
          ),

          // New image fades in on top
          FadeTransition(
            opacity: _fadeAnim,
            child: Image.network(
              slide.url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: AppColors.primary),
            ),
          ),

          // Dark overlay
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x88000000),
                  Color(0x44000000),
                  Color(0xCC000000),
                ],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),

                  // ── Slide quote ────────────────────────────────────────
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Text(
                      slide.quote,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Dot indicators ─────────────────────────────────────
                  Row(
                    children: List.generate(_slides.length, (i) {
                      final active = i == _currentIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 6),
                        width: active ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 28),

                  // ── Main heading ───────────────────────────────────────
                  Text(
                    'Welcome to CanT',
                    style: GoogleFonts.inter(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Can Train with Your Mate anywhere',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Join local sports and social events and connect with people who share your passion.',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.8),
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Buttons ────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/register'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Get Started',
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/login'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Already have an account? Sign In',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
