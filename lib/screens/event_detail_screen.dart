import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import '../models/event.dart';
import '../services/firebase_service.dart';

class EventDetailScreen extends StatefulWidget {
  final Event event;
  final String? currentUid;
  final bool isJoined;
  final bool isOnWaitlist;
  final int waitlistPosition;

  const EventDetailScreen({
    super.key,
    required this.event,
    this.currentUid,
    this.isJoined = false,
    this.isOnWaitlist = false,
    this.waitlistPosition = -1,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late int _participants;
  late int _waitlistCount;
  late bool _isJoined;
  late bool _isOnWaitlist;
  late int _waitlistPosition;
  bool _loading = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _participants = widget.event.participants;
    _waitlistCount = widget.event.waitlistCount;
    _isJoined = widget.isJoined;
    _isOnWaitlist = widget.isOnWaitlist;
    _waitlistPosition = widget.waitlistPosition;
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _joinEvent() async {
    setState(() => _loading = true);
    try {
      await FirebaseService.joinEvent(widget.event.id);
      setState(() {
        _isJoined = true;
        _participants++;
        _changed = true;
      });
      _snack('Joined! 🎉', AppColors.success);
    } catch (_) {
      _snack('Failed to join.', AppColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _leaveEvent() async {
    setState(() => _loading = true);
    try {
      await FirebaseService.leaveEvent(widget.event.id, widget.event.title);
      setState(() {
        _isJoined = false;
        _participants = (_participants - 1).clamp(0, 9999);
        _changed = true;
      });
      _snack('You left the event.', AppColors.textTertiary);
    } catch (_) {
      _snack('Failed to leave.', AppColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinWaitlist() async {
    setState(() => _loading = true);
    try {
      final pos = await FirebaseService.joinWaitlist(widget.event.id);
      setState(() {
        _isOnWaitlist = true;
        _waitlistPosition = pos;
        _waitlistCount++;
        _changed = true;
      });
      _snack('You\'re #$pos on the waitlist!', AppColors.warning);
    } catch (_) {
      _snack('Failed to join waitlist.', AppColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _leaveWaitlist() async {
    setState(() => _loading = true);
    try {
      await FirebaseService.leaveWaitlist(widget.event.id);
      setState(() {
        _isOnWaitlist = false;
        _waitlistPosition = -1;
        _waitlistCount = (_waitlistCount - 1).clamp(0, 9999);
        _changed = true;
      });
      _snack('Removed from waitlist.', AppColors.textTertiary);
    } catch (_) {
      _snack('Failed to leave waitlist.', AppColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _openMaps() async {
    final name = Uri.encodeComponent(widget.event.location);
    final lat = widget.event.latitude;
    final lng = widget.event.longitude;
    Uri uri;
    if (Platform.isIOS) {
      uri = Uri.parse('https://maps.apple.com/?q=$name');
    } else if (lat != null && lng != null) {
      uri = Uri.parse('geo:$lat,$lng?q=$name');
    } else {
      uri = Uri.parse('https://maps.google.com/?q=$name');
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  bool get _isFull {
    final cap = widget.event.capacity;
    return cap != null && _participants >= cap;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: CustomScrollView(
          slivers: [
            // ── Hero image + AppBar ────────────────────────────────────────
            SliverAppBar(
              expandedHeight: event.imageUrl != null ? 280.0 : 0,
              pinned: true,
              backgroundColor: AppColors.surface,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              leading: Padding(
                padding: const EdgeInsets.all(8),
                child: Material(
                  color: Colors.white.withValues(alpha: 0.92),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.pop(context, _changed),
                    child: const Icon(Icons.arrow_back_ios_rounded,
                        color: AppColors.textPrimary, size: 18),
                  ),
                ),
              ),
              flexibleSpace: event.imageUrl != null
                  ? FlexibleSpaceBar(
                      background: Image.network(
                        event.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            color: AppColors.primaryLight,
                            child: const Center(
                                child: Icon(Icons.broken_image_rounded,
                                    color: AppColors.border, size: 48))),
                      ),
                    )
                  : null,
            ),

            // ── Content ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sport badge + title
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(getSportEmoji(event.sport),
                                style: const TextStyle(fontSize: 28)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.sport.toUpperCase(),
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                    letterSpacing: 1.2),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                event.title,
                                style: GoogleFonts.inter(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                        if (_isJoined)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
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

                    const SizedBox(height: 24),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 20),

                    // Date
                    _InfoRow(
                      icon: Icons.access_time_rounded,
                      text: DateFormat('EEEE, MMMM d, yyyy  •  h:mm a')
                          .format(event.time),
                    ),
                    const SizedBox(height: 14),

                    // Tappable location
                    GestureDetector(
                      onTap: _openMaps,
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_rounded,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              event.location,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.primary,
                              ),
                            ),
                          ),
                          const Icon(Icons.open_in_new_rounded,
                              size: 15, color: AppColors.primary),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Players
                    _InfoRow(
                      icon: Icons.people_rounded,
                      text:
                          '$_participants/${event.capacity ?? '∞'} players${_waitlistCount > 0 ? '  •  $_waitlistCount waiting' : ''}',
                    ),

                    // Capacity bar
                    if (event.capacity != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: event.capacity! > 0
                              ? (_participants / event.capacity!).clamp(0.0, 1.0)
                              : 0,
                          minHeight: 6,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              _isFull ? AppColors.error : AppColors.primary),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Action button
                    SizedBox(width: double.infinity, child: _buildButton()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton() {
    if (_loading) {
      return ElevatedButton(
        onPressed: null,
        style: _btnStyle(AppColors.primary),
        child: const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2)),
      );
    }

    if (_isJoined) {
      return ElevatedButton.icon(
        onPressed: _leaveEvent,
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: Text('Leave Event',
            style:
                GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
        style: _btnStyle(AppColors.textTertiary),
      );
    }

    if (_isOnWaitlist) {
      final pos = _waitlistPosition > 0 ? ' • #$_waitlistPosition' : '';
      return ElevatedButton.icon(
        onPressed: _leaveWaitlist,
        icon: const Icon(Icons.hourglass_top_rounded, size: 18),
        label: Text('On Waitlist$pos',
            style:
                GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
        style: _btnStyle(const Color(0xFFF59E0B)),
      );
    }

    if (_isFull) {
      return ElevatedButton.icon(
        onPressed: widget.currentUid != null ? _joinWaitlist : null,
        icon: const Icon(Icons.playlist_add_rounded, size: 18),
        label: Text('Join Waitlist',
            style:
                GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
        style: _btnStyle(const Color(0xFFF59E0B)),
      );
    }

    if (widget.currentUid == null) {
      return ElevatedButton(
        onPressed: null,
        style: _btnStyle(AppColors.primary.withValues(alpha: 0.5)),
        child: Text('Sign in to Join',
            style:
                GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
      );
    }

    return ElevatedButton(
      onPressed: _joinEvent,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 3,
        shadowColor: AppColors.primary.withValues(alpha: 0.4),
      ),
      child: Text('Join Event',
          style:
              GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
    );
  }

  ButtonStyle _btnStyle(Color color) => ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      );
}

// ─── Info Row ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textTertiary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: GoogleFonts.inter(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}
