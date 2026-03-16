import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';
import '../services/firebase_service.dart';

const _kCities = [
  'Berlin', 'Hamburg', 'München', 'Köln', 'Frankfurt',
  'Stuttgart', 'Düsseldorf', 'Leipzig', 'Dortmund', 'Karlsruhe',
  'Mannheim', 'Bonn', 'Münster', 'Augsburg', 'Nürnberg',
];

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late String _city;
  late TextEditingController _bioController;
  late Set<String> _selectedSports;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _city = widget.profile?['city'] as String? ?? 'Berlin';
    _bioController = TextEditingController(
        text: widget.profile?['bio'] as String? ?? '');
    final sports = widget.profile?['sports'];
    if (sports is List) {
      _selectedSports = Set<String>.from(sports.map((e) => e.toString()));
    } else {
      _selectedSports = {};
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  void _showCityPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text('Select City',
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: _kCities.map((city) {
                final selected = city == _city;
                return ListTile(
                  title: Text(city,
                      style: GoogleFonts.inter(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      )),
                  trailing: selected
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.primary)
                      : null,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    setState(() => _city = city);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirebaseService.updateProfile(
        city: _city,
        bio: _bioController.text.trim(),
        sports: _selectedSports.toList(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Edit Profile',
            style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text('Save',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── City ──────────────────────────────────────────────────
            Text('City',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _showCityPicker,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_city_rounded,
                        size: 20, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_city,
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 20, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Bio ────────────────────────────────────────────────────
            Text('Bio',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: TextField(
                controller: _bioController,
                maxLength: 150,
                maxLines: 3,
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Tell others about yourself...',
                  hintStyle: GoogleFonts.inter(
                      fontSize: 14, color: AppColors.textTertiary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  counterStyle: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.textTertiary),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Sports ─────────────────────────────────────────────────
            Text('Sports Interests',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kSports.map((sport) {
                  final name = sport['name']!;
                  final emoji = sport['emoji']!;
                  final selected = _selectedSports.contains(name);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (selected) {
                          _selectedSports.remove(name);
                        } else {
                          _selectedSports.add(name);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(emoji,
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(name,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              )),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 32),

            // ── Save Button ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(_saving ? 'Saving...' : 'Save Changes',
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
