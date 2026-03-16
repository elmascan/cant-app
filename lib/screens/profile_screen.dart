import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../constants.dart';
import '../services/firebase_service.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  int _eventCount = 0;
  bool _loading = true;
  String? _photoUrl;
  bool _uploadingPhoto = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseService.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        FirebaseService.getProfile(user.uid),
        FirebaseService.getUserEventCount(user.uid),
      ]);
      if (mounted) {
        setState(() {
          _profile = results[0] as Map<String, dynamic>?;
          _eventCount = results[1] as int;
          _photoUrl = _profile?['photo_url'] as String?;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseService.signOut();
    if (mounted) Navigator.pushReplacementNamed(context, '/welcome');
  }

  void _pickAvatar() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.photo_library_rounded,
                    color: AppColors.primary),
              ),
              title: Text('Choose from Gallery',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _selectAvatar(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.camera_alt_rounded,
                    color: AppColors.primary),
              ),
              title: Text('Take a Photo',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _selectAvatar(ImageSource.camera);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _selectAvatar(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      final url = await FirebaseService.uploadProfileAvatar(File(picked.path));
      if (mounted) setState(() => _photoUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to upload photo: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Widget _buildSportsChips() {
    final sports = _profile?['sports'];
    final List<String> sportList = sports is List
        ? List<String>.from(sports.map((e) => e.toString()))
        : [];

    if (sportList.isEmpty) {
      return Text(
        'No sports selected yet',
        style: GoogleFonts.inter(
            fontSize: 14, color: AppColors.textSecondary),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sportList.map((sport) {
        final emoji = getSportEmoji(sport);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 6),
              Text(sport,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  )),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseService.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('👤', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 20),
                Text('Sign in to view your profile',
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Text('Join the community and track your events',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.textSecondary),
                    textAlign: TextAlign.center),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Sign In',
                        style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final name =
        _profile?['full_name'] ?? user.displayName ?? user.email?.split('@').first ?? 'User';
    final email = user.email ?? '';
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : name[0].toUpperCase();
    final city = _profile?['city'] as String? ?? 'Germany';
    final bio = _profile?['bio'] as String?;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded,
                color: AppColors.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Profile Hero Card ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.07),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Photo + name column
                        Column(
                          children: [
                            GestureDetector(
                              onTap: _uploadingPhoto ? null : _pickAvatar,
                              child: Stack(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.35),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        )
                                      ],
                                    ),
                                    child: _uploadingPhoto
                                        ? const Center(
                                            child: SizedBox(
                                              width: 28,
                                              height: 28,
                                              child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2.5),
                                            ),
                                          )
                                        : _photoUrl != null
                                            ? ClipOval(
                                                child: Image.network(
                                                  _photoUrl!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      Center(
                                                        child: Text(initials,
                                                            style: GoogleFonts.inter(
                                                                fontSize: 28,
                                                                fontWeight:
                                                                    FontWeight.w800,
                                                                color: Colors.white)),
                                                      ),
                                                ),
                                              )
                                            : Center(
                                                child: Text(
                                                  initials,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 28,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: AppColors.surface, width: 2),
                                      ),
                                      child: const Icon(Icons.camera_alt_rounded,
                                          size: 12, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: 90,
                              child: Text(
                                name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(width: 20),

                        // Stats row
                        Expanded(
                          child: Row(
                            children: [
                              // Attended events
                              Expanded(
                                child: _StatBox(
                                  value: _eventCount.toString(),
                                  label: 'Events\nAttended',
                                  sub: '0 no-shows',
                                  subColor: AppColors.textTertiary,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 60,
                                color: AppColors.border,
                                margin: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              // Karma
                              const Expanded(
                                child: _StatBox(
                                  value: '—',
                                  label: 'Karma',
                                  icon: Icons.star_rounded,
                                  iconColor: AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Info section ───────────────────────────────────────────────
                  Text('Account Info',
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        _InfoTile(
                          icon: Icons.person_rounded,
                          label: 'Full Name',
                          value: name,
                        ),
                        const Divider(height: 1, color: AppColors.border, indent: 52),
                        _InfoTile(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: email,
                        ),
                        const Divider(height: 1, color: AppColors.border, indent: 52),
                        _InfoTile(
                          icon: Icons.location_city_rounded,
                          label: 'City',
                          value: city,
                        ),
                        if (bio != null && bio.isNotEmpty) ...[
                          const Divider(height: 1, color: AppColors.border, indent: 52),
                          _InfoTile(
                            icon: Icons.info_outline_rounded,
                            label: 'Bio',
                            value: bio,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── Sports Interests ───────────────────────────────────────────
                  const SizedBox(height: 24),
                  Text('Sports Interests',
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: _buildSportsChips(),
                  ),

                  const SizedBox(height: 16),

                  // ── Edit Profile ───────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final changed = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                EditProfileScreen(profile: _profile),
                          ),
                        );
                        if (changed == true) _load();
                      },
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: Text('Edit Profile',
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

                  const SizedBox(height: 12),

                  // ── Sign Out ───────────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout_rounded,
                          color: AppColors.error, size: 18),
                      label: Text('Sign Out',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(
                            color: AppColors.error, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final String? sub;
  final Color? subColor;
  final IconData? icon;
  final Color? iconColor;

  const _StatBox({
    required this.value,
    required this.label,
    this.sub,
    this.subColor,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 4),
            ],
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            height: 1.3,
          ),
        ),
        if (sub != null) ...[
          const SizedBox(height: 4),
          Text(
            sub!,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: subColor ?? AppColors.textTertiary,
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w600)),
                Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
