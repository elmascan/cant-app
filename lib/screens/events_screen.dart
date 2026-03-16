import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';
import '../models/event.dart';
import '../services/firebase_service.dart';
import '../widgets/event_card.dart';
import '../widgets/leave_feedback_dialog.dart';

class EventsTab extends StatefulWidget {
  const EventsTab({super.key});

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  List<Event> _events = [];
  bool _loading = true;
  String _filter = 'All';
  final Map<String, bool> _loadingMap = {};
  final Map<String, int> _waitlistPositions = {};

  final List<String> _filters = [
    'All', 'Football', 'Basketball', 'Tennis', 'Running', 'Volleyball',
  ];

  String? get _uid => FirebaseService.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    try {
      final events = await FirebaseService.getEvents();
      if (!mounted) return;
      // Events'i hemen göster — waitlist hatası bunu engellemesin
      setState(() => _events = events);

      // Waitlist pozisyonları ayrı try-catch
      if (_uid != null) {
        final Map<String, int> positions = {};
        await Future.wait(events.map((e) async {
          try {
            final pos = await FirebaseService.getWaitlistPosition(e.id);
            if (pos > 0) positions[e.id] = pos;
          } catch (_) {}
        }));
        if (mounted) setState(() => _waitlistPositions.addAll(positions));
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed to load events: $e', AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setLoading(String id, bool v) =>
      setState(() => _loadingMap[id] = v);

  Future<void> _joinEvent(Event event) async {
    if (_uid == null) { Navigator.pushNamed(context, '/login'); return; }
    _setLoading(event.id, true);
    try {
      await FirebaseService.joinEvent(event.id);
      _updateEvent(event.id, (e) => e.copyWith(
        participants: e.participants + 1,
        attendees: [...e.attendees, _uid!],
      ));
      _showSnack('You joined "${event.title}"! 🎉', AppColors.success);
    } catch (_) {
      _showSnack('Failed to join event.', AppColors.error);
    } finally {
      _setLoading(event.id, false);
    }
  }

  Future<void> _showLeaveDialog(Event event) async {
    final result = await showModalBottomSheet<Map<String, String>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LeaveFeedbackDialog(eventTitle: event.title),
    );
    if (result == null || !mounted) return;

    // Feedback kaydet (hata leave'i engellemesin)
    FirebaseService.saveFeedback(
      eventId: event.id,
      reason: result['reason']!,
      details: result['details'],
    ).catchError((_) {});

    await _leaveEvent(event);
  }

  Future<void> _leaveEvent(Event event) async {
    _setLoading(event.id, true);
    try {
      await FirebaseService.leaveEvent(event.id, event.title);
      _updateEvent(event.id, (e) {
        final att = List<String>.from(e.attendees)..remove(_uid);
        return e.copyWith(participants: e.participants - 1, attendees: att);
      });
      _showSnack('You left "${event.title}".', AppColors.textTertiary);
    } catch (e) {
      _showSnack('Failed to leave: $e', AppColors.error);
    } finally {
      _setLoading(event.id, false);
    }
  }

  Future<void> _joinWaitlist(Event event) async {
    if (_uid == null) { Navigator.pushNamed(context, '/login'); return; }
    _setLoading(event.id, true);
    try {
      final pos = await FirebaseService.joinWaitlist(event.id);
      setState(() {
        _waitlistPositions[event.id] = pos;
        _updateEventInline(event.id,
            (e) => e.copyWith(waitlistCount: e.waitlistCount + 1));
      });
      _showSnack('You\'re #$pos on the waitlist!', AppColors.warning);
    } catch (_) {
      _showSnack('Failed to join waitlist.', AppColors.error);
    } finally {
      _setLoading(event.id, false);
    }
  }

  Future<void> _leaveWaitlist(Event event) async {
    _setLoading(event.id, true);
    try {
      await FirebaseService.leaveWaitlist(event.id);
      setState(() {
        _waitlistPositions.remove(event.id);
        _updateEventInline(event.id, (e) =>
            e.copyWith(waitlistCount: (e.waitlistCount - 1).clamp(0, 999)));
      });
      _showSnack('Removed from waitlist.', AppColors.textTertiary);
    } catch (_) {
      _showSnack('Failed to leave waitlist.', AppColors.error);
    } finally {
      _setLoading(event.id, false);
    }
  }

  void _updateEvent(String id, Event Function(Event) fn) {
    setState(() {
      final i = _events.indexWhere((e) => e.id == id);
      if (i != -1) _events[i] = fn(_events[i]);
    });
  }

  void _updateEventInline(String id, Event Function(Event) fn) {
    final i = _events.indexWhere((e) => e.id == id);
    if (i != -1) _events[i] = fn(_events[i]);
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  List<Event> get _filtered {
    if (_filter == 'All') return _events;
    return _events.where((e) => e.sport.toLowerCase() == _filter.toLowerCase()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Events',
                          style: GoogleFonts.inter(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary)),
                      Text('${_filtered.length} available near you',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                  IconButton(
                    onPressed: _loadEvents,
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Filter chips
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filters.length,
                itemBuilder: (_, i) {
                  final f = _filters[i];
                  final active = _filter == f;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: active ? AppColors.primary : AppColors.border),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2))
                              ]
                            : [],
                      ),
                      child: Text(f,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: active ? Colors.white : AppColors.textSecondary,
                          )),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // List
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary))
                  : _filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🏟️', style: TextStyle(fontSize: 56)),
                              const SizedBox(height: 16),
                              Text('No events yet',
                                  style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary)),
                              const SizedBox(height: 8),
                              Text('Be the first to create one!',
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadEvents,
                          color: AppColors.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) {
                              final event = _filtered[i];
                              final joined =
                                  _uid != null && event.isJoinedBy(_uid!);
                              final onWaitlist =
                                  _waitlistPositions.containsKey(event.id);
                              return EventCard(
                                event: event,
                                isJoined: joined,
                                isOnWaitlist: onWaitlist,
                                waitlistPosition:
                                    _waitlistPositions[event.id] ?? -1,
                                isLoading: _loadingMap[event.id] ?? false,
                                onJoin: () => _joinEvent(event),
                                onLeave: () => _showLeaveDialog(event),
                                onJoinWaitlist: () => _joinWaitlist(event),
                                onLeaveWaitlist: () => _leaveWaitlist(event),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
