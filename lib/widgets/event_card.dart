import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../constants.dart';

class EventCard extends StatelessWidget {
  final Event event;

  final VoidCallback? onJoin;
  final VoidCallback? onLeave;
  final VoidCallback? onJoinWaitlist;
  final VoidCallback? onLeaveWaitlist;

  final bool isJoined;
  final bool isOnWaitlist;
  final int waitlistPosition; // -1 = bilinmiyor
  final bool isLoading;

  const EventCard({
    super.key,
    required this.event,
    this.onJoin,
    this.onLeave,
    this.onJoinWaitlist,
    this.onLeaveWaitlist,
    this.isJoined = false,
    this.isOnWaitlist = false,
    this.waitlistPosition = -1,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event photo
          if (event.imageUrl != null)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                event.imageUrl!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        height: 160,
                        color: AppColors.primaryLight,
                        child: const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary, strokeWidth: 2)),
                      ),
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık
                Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(14)),
                  child: Center(
                      child: Text(getSportEmoji(event.sport),
                          style: const TextStyle(fontSize: 26))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.title,
                          style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text(event.sport.toUpperCase(),
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              letterSpacing: 1.2)),
                    ],
                  ),
                ),
                if (isJoined)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Joined',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success)),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Detaylar
            _DetailRow(
                icon: Icons.access_time_rounded,
                text: DateFormat('EEE, MMM d • h:mm a').format(event.time)),
            const SizedBox(height: 8),
            _DetailRow(icon: Icons.location_on_rounded, text: event.location),
            const SizedBox(height: 8),
            _DetailRow(
              icon: Icons.people_rounded,
              text:
                  '${event.participants}/${event.capacity ?? '∞'} players${event.waitlistCount > 0 ? '  •  ${event.waitlistCount} waiting' : ''}',
            ),

            if (event.capacity != null) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: event.participants / event.capacity!,
                  minHeight: 5,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      event.isFull ? AppColors.error : AppColors.primary),
                ),
              ),
            ],

            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: _buildButton()),
          ],
        ),
      ),
        ],
      ),
    );
  }

  Widget _buildButton() {
    if (isLoading) {
      return ElevatedButton(
        onPressed: null,
        style: _style(AppColors.primary),
        child: const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2)),
      );
    }

    // Katılmış → ayrıl
    if (isJoined) {
      return ElevatedButton.icon(
        onPressed: onLeave,
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: Text('Leave Event',
            style:
                GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
        style: _style(AppColors.textTertiary),
      );
    }

    // Etkinlik dolu + bekliyor → waitlist'ten çık
    if (isOnWaitlist) {
      final pos = waitlistPosition > 0 ? ' • #$waitlistPosition in line' : '';
      return ElevatedButton.icon(
        onPressed: onLeaveWaitlist,
        icon: const Icon(Icons.hourglass_top_rounded, size: 18),
        label: Text('Waitlist$pos',
            style:
                GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
        style: _style(const Color(0xFFF59E0B)),
      );
    }

    // Etkinlik dolu → waitlist'e katıl
    if (event.isFull) {
      return ElevatedButton.icon(
        onPressed: onJoinWaitlist,
        icon: const Icon(Icons.playlist_add_rounded, size: 18),
        label: Text('Join Waitlist',
            style:
                GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
        style: _style(const Color(0xFFF59E0B)),
      );
    }

    // Normal katılma
    return ElevatedButton(
      onPressed: onJoin,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
        shadowColor: AppColors.primary.withOpacity(0.4),
      ),
      child: Text('Join Event',
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
    );
  }

  ButtonStyle _style(Color color) => ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _DetailRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: AppColors.textTertiary),
      const SizedBox(width: 10),
      Expanded(
          child: Text(text,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500))),
    ]);
  }
}
