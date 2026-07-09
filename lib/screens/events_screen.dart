import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';
import '../models/event.dart';
import '../services/firebase_service.dart';
import '../amplitude_service.dart';
import '../widgets/event_card.dart';
import '../widgets/leave_feedback_dialog.dart';
import 'create_event_screen.dart';
import 'event_detail_screen.dart';

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
    AmplitudeService().logScreenView('Events');
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    try {
      final events = await FirebaseService.getEvents();
      if (!mounted) return;
      setState(() => _events = events);

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
      if (mounted) _showSnack('Failed to load events: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setLoading(String id, bool v) => setState(() => _loadingMap[id] = v);

  Future<void> _joinEvent(Event event) async {
    if (_uid == null) { Navigator.pushNamed(context, '/login'); return; }
    _setLoading(event.id, true);
    try {
      await FirebaseService.joinEvent(event.id);
      AmplitudeService().logEvent('Event Joined', {
        'event_id': event.id,
        'event_title': event.title,
        'sport': event.sport,
      });
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
      AmplitudeService().logEvent('Event Left', {
        'event_id': event.id,
        'event_title': event.title,
        'sport': event.sport,
      });
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

  Future<void> _editEvent(Event event) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CreateEventScreen(editEvent: event)),
    );
    if (updated == true) _loadEvents();
  }

  Future<void> _deleteEvent(Event event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text(
            'Are you sure you want to delete "${event.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _setLoading(event.id, true);
    try {
      await FirebaseService.deleteEvent(event.id);
      setState(() => _events.removeWhere((e) => e.id == event.id));
      _showSnack('"${event.title}" deleted.', AppColors.textTertiary);
    } catch (e) {
      _showSnack('Failed to delete: $e', AppColors.error);
    } finally {
      _setLoading(event.id, false);
    }
  }

  Future<void> _openDetail(Event event) async {
    final joined = _uid != null && event.isJoinedBy(_uid!);
    final onWaitlist = _waitlistPositions.containsKey(event.id);
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(
          event: event,
          currentUid: _uid,
          isJoined: joined,
          isOnWaitlist: onWaitlist,
          waitlistPosition: _waitlistPositions[event.id] ?? -1,
        ),
      ),
    );
    if (changed == true) _loadEvents();
  }

  List<Event> get _filtered {
    if (_filter == 'All') return _events;
    return _events
        .where((e) => e.sport.toLowerCase() == _filter.toLowerCase())
        .toList();
  }

  List<Event> get _myEvents =>
      _events.where((e) => e.createdBy == _uid).toList();

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
                    Text('Events',
                        style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    IconButton(
                      onPressed: _loadEvents,
                      icon: const Icon(Icons.refresh_rounded,
                          color: AppColors.primary),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primaryLight,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Tab bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TabBar(
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicator: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    padding: const EdgeInsets.all(4),
                    dividerColor: Colors.transparent,
                    labelStyle: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w500),
                    tabs: const [
                      Tab(text: 'All Events'),
                      Tab(text: 'My Events'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Tab content
              Expanded(
                child: TabBarView(
                  children: [
                    _AllEventsView(
                      loading: _loading,
                      events: _filtered,
                      filters: _filters,
                      activeFilter: _filter,
                      onRefresh: _loadEvents,
                      onFilterChanged: (f) {
                        setState(() => _filter = f);
                        AmplitudeService().logEvent(
                            'Events Filter Changed', {'filter': f});
                      },
                      uid: _uid,
                      loadingMap: _loadingMap,
                      waitlistPositions: _waitlistPositions,
                      onJoin: _joinEvent,
                      onLeave: _showLeaveDialog,
                      onJoinWaitlist: _joinWaitlist,
                      onLeaveWaitlist: _leaveWaitlist,
                      onEdit: _editEvent,
                      onDelete: _deleteEvent,
                      onTap: _openDetail,
                    ),
                    _MyEventsView(
                      loading: _loading,
                      events: _myEvents,
                      uid: _uid,
                      loadingMap: _loadingMap,
                      waitlistPositions: _waitlistPositions,
                      onJoin: _joinEvent,
                      onLeave: _showLeaveDialog,
                      onJoinWaitlist: _joinWaitlist,
                      onLeaveWaitlist: _leaveWaitlist,
                      onEdit: _editEvent,
                      onDelete: _deleteEvent,
                      onTap: _openDetail,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── All Events Tab ─────────────────────────────────────────────────────────────

class _AllEventsView extends StatelessWidget {
  final bool loading;
  final List<Event> events;
  final List<String> filters;
  final String activeFilter;
  final void Function(String) onFilterChanged;
  final String? uid;
  final Map<String, bool> loadingMap;
  final Map<String, int> waitlistPositions;
  final Future<void> Function() onRefresh;
  final Future<void> Function(Event) onJoin;
  final Future<void> Function(Event) onLeave;
  final Future<void> Function(Event) onJoinWaitlist;
  final Future<void> Function(Event) onLeaveWaitlist;
  final Future<void> Function(Event) onEdit;
  final Future<void> Function(Event) onDelete;
  final Future<void> Function(Event) onTap;

  const _AllEventsView({
    required this.loading,
    required this.events,
    required this.filters,
    required this.activeFilter,
    required this.onFilterChanged,
    required this.uid,
    required this.loadingMap,
    required this.waitlistPositions,
    required this.onRefresh,
    required this.onJoin,
    required this.onLeave,
    required this.onJoinWaitlist,
    required this.onLeaveWaitlist,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sport filter chips
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filters.length,
            itemBuilder: (_, i) {
              final f = filters[i];
              final active = activeFilter == f;
              return GestureDetector(
                onTap: () => onFilterChanged(f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color:
                            active ? AppColors.primary : AppColors.border),
                    boxShadow: active
                        ? [
                            BoxShadow(
                                color:
                                    AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2))
                          ]
                        : [],
                  ),
                  child: Text(f,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? Colors.white
                            : AppColors.textSecondary,
                      )),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('${events.length} available near you',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textSecondary)),
        ),
        const SizedBox(height: 8),

        // List
        Expanded(child: _buildList(context)),
      ],
    );
  }

  Widget _buildList(BuildContext context) {
    if (loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (events.isEmpty) {
      return Center(
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
                    fontSize: 14, color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        itemCount: events.length,
        itemBuilder: (_, i) => _buildCard(events[i]),
      ),
    );
  }

  Widget _buildCard(Event event) {
    final joined = uid != null && event.isJoinedBy(uid!);
    final onWaitlist = waitlistPositions.containsKey(event.id);
    return EventCard(
      event: event,
      currentUid: uid,
      isJoined: joined,
      isOnWaitlist: onWaitlist,
      waitlistPosition: waitlistPositions[event.id] ?? -1,
      isLoading: loadingMap[event.id] ?? false,
      onTap: () => onTap(event),
      onJoin: () => onJoin(event),
      onLeave: () => onLeave(event),
      onJoinWaitlist: () => onJoinWaitlist(event),
      onLeaveWaitlist: () => onLeaveWaitlist(event),
      onEdit: () => onEdit(event),
      onDelete: () => onDelete(event),
    );
  }
}

// ── My Events Tab ──────────────────────────────────────────────────────────────

class _MyEventsView extends StatelessWidget {
  final bool loading;
  final List<Event> events;
  final String? uid;
  final Map<String, bool> loadingMap;
  final Map<String, int> waitlistPositions;
  final Future<void> Function(Event) onJoin;
  final Future<void> Function(Event) onLeave;
  final Future<void> Function(Event) onJoinWaitlist;
  final Future<void> Function(Event) onLeaveWaitlist;
  final Future<void> Function(Event) onEdit;
  final Future<void> Function(Event) onDelete;
  final Future<void> Function(Event) onTap;

  const _MyEventsView({
    required this.loading,
    required this.events,
    required this.uid,
    required this.loadingMap,
    required this.waitlistPositions,
    required this.onJoin,
    required this.onLeave,
    required this.onJoinWaitlist,
    required this.onLeaveWaitlist,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔐', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text('Sign in to see your events',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ],
        ),
      );
    }

    if (loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📋', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text("You haven't created any events yet",
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Tap + to create your first event!',
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      itemCount: events.length,
      itemBuilder: (_, i) {
        final event = events[i];
        final joined = uid != null && event.isJoinedBy(uid!);
        final onWaitlist = waitlistPositions.containsKey(event.id);
        return EventCard(
          event: event,
          currentUid: uid,
          isJoined: joined,
          isOnWaitlist: onWaitlist,
          waitlistPosition: waitlistPositions[event.id] ?? -1,
          isLoading: loadingMap[event.id] ?? false,
          onTap: () => onTap(event),
          onJoin: () => onJoin(event),
          onLeave: () => onLeave(event),
          onJoinWaitlist: () => onJoinWaitlist(event),
          onLeaveWaitlist: () => onLeaveWaitlist(event),
          onEdit: () => onEdit(event),
          onDelete: () => onDelete(event),
        );
      },
    );
  }
}
