import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../services/firebase_service.dart';
import 'direct_chat_screen.dart';

class MatchesTab extends StatelessWidget {
  const MatchesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseService.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Matches',
                      style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('Your sport mates',
                      style: GoogleFonts.inter(
                          fontSize: 14, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseService.streamMatches(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) return _buildEmptyState();
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final data = docs[i].data() as Map<String, dynamic>;
                      final matchId = docs[i].id;
                      final users = List<String>.from(data['users'] ?? []);
                      final otherUid = users.firstWhere(
                        (id) => id != currentUid,
                        orElse: () => '',
                      );
                      return _MatchTile(
                        matchId: matchId,
                        otherUid: otherUid,
                        lastMessage: data['lastMessage'] as String?,
                        lastMessageAt: data['lastMessageAt'] as Timestamp?,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
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
            const Text('🤝', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 20),
            Text('No matches yet',
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'Swipe right on players you\'d like to play with and wait for them to match back.',
              style:
                  GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Match Tile ───────────────────────────────────────────────────────────────

class _MatchTile extends StatelessWidget {
  final String matchId;
  final String otherUid;
  final String? lastMessage;
  final Timestamp? lastMessageAt;

  const _MatchTile({
    required this.matchId,
    required this.otherUid,
    this.lastMessage,
    this.lastMessageAt,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: otherUid.isNotEmpty ? FirebaseService.getProfile(otherUid) : Future.value(null),
      builder: (context, snap) {
        final profile = snap.data;
        final name = profile?['full_name'] as String? ?? 'Player';
        final photoUrl = profile?['photo_url'] as String?;
        final city = profile?['city'] as String? ?? '';
        final sports = (profile?['sports'] as List?)
                ?.map((s) => s.toString())
                .toList() ??
            [];
        final initials = name.trim().isEmpty
            ? '?'
            : name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase();
        final timeStr = lastMessageAt != null
            ? DateFormat('HH:mm').format(lastMessageAt!.toDate())
            : '';

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DirectChatScreen(
                matchId: matchId,
                otherName: name,
                otherPhotoUrl: photoUrl,
              ),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: photoUrl != null
                      ? ClipOval(
                          child: Image.network(photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                    child: Text(initials,
                                        style: GoogleFonts.inter(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white)),
                                  )))
                      : Center(
                          child: Text(initials,
                              style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(name,
                                style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                          ),
                          if (timeStr.isNotEmpty)
                            Text(timeStr,
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.textTertiary)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      if (lastMessage != null)
                        Text(
                          lastMessage!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w400),
                        )
                      else
                        Text(
                          [
                            if (city.isNotEmpty) '📍 $city',
                            if (sports.isNotEmpty)
                              sports.take(2).map((s) => getSportEmoji(s)).join(' '),
                          ].join('  '),
                          style: GoogleFonts.inter(
                              fontSize: 13, color: AppColors.textTertiary),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textTertiary, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
