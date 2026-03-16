import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';
import '../services/firebase_service.dart';

class SportSelectionScreen extends StatefulWidget {
  const SportSelectionScreen({super.key});

  @override
  State<SportSelectionScreen> createState() => _SportSelectionScreenState();
}

class _SportSelectionScreenState extends State<SportSelectionScreen> {
  final Set<String> _selected = {};
  bool _saving = false;

  Future<void> _confirm() async {
    if (_selected.isEmpty) return;
    setState(() => _saving = true);
    try {
      await FirebaseService.saveSports(_selected.toList());
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
        setState(() => _saving = false);
      }
    }
  }

  void _skip() => Navigator.pushReplacementNamed(context, '/home');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🏅', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 16),
                    Text(
                      'Which sports\ninterest you?',
                      style: GoogleFonts.inter(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select all that apply — we\'ll use this to match\nyou with players and communities.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: kSports.map((sport) {
                        final name = sport['name']!;
                        final emoji = sport['emoji']!;
                        final isSelected = _selected.contains(name);
                        return _SportTile(
                          name: name,
                          emoji: emoji,
                          selected: isSelected,
                          onTap: () => setState(() {
                            if (isSelected) {
                              _selected.remove(name);
                            } else {
                              _selected.add(name);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    if (_selected.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_selected.length} sport${_selected.length > 1 ? 's' : ''} selected',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Bottom buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_selected.isEmpty || _saving) ? null : _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.border,
                        disabledForegroundColor: AppColors.textTertiary,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 3,
                        shadowColor: AppColors.primary.withValues(alpha: 0.4),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(
                              'Continue',
                              style: GoogleFonts.inter(
                                  fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _saving ? null : _skip,
                    child: Text(
                      'Skip for now',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SportTile extends StatelessWidget {
  final String name;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  const _SportTile({
    required this.name,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(
              name,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 16),
            ],
          ],
        ),
      ),
    );
  }
}
