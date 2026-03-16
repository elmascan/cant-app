import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';
import '../models/event.dart';
import '../services/firebase_service.dart';
import '../widgets/event_card.dart';
import '../widgets/leave_feedback_dialog.dart';

// German cities for location picker
const _kCities = [
  'Berlin', 'Hamburg', 'München', 'Köln', 'Frankfurt',
  'Stuttgart', 'Düsseldorf', 'Leipzig', 'Dortmund', 'Karlsruhe',
  'Mannheim', 'Bonn', 'Münster', 'Augsburg', 'Nürnberg',
];

class HomeTab extends StatefulWidget {
  /// Callback to switch to Events tab (index 1 in PageView)
  final VoidCallback onSeeAll;

  const HomeTab({
    super.key,
    required this.onSeeAll,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  List<Event> _events = [];
  bool _loading = true;
  String _city = 'Berlin';
  final Map<String, bool> _loadingMap = {};
  final Map<String, int> _waitlistPositions = {};

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
      // Events'i hemen göster
      setState(() => _events = events);

      // Waitlist pozisyonları ayrı — hata events'i engellemesin
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
      _showSnack('Failed.', AppColors.error);
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
      _showSnack('Failed.', AppColors.error);
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
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? AppColors.primary : AppColors.textPrimary,
                      )),
                  trailing: selected
                      ? const Icon(Icons.check_rounded, color: AppColors.primary)
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

  // Quick sport category pills data
  static const _categories = [
    {'emoji': '⚽', 'label': 'Football'},
    {'emoji': '🏀', 'label': 'Basketball'},
    {'emoji': '🎾', 'label': 'Tennis'},
    {'emoji': '🏃', 'label': 'Running'},
    {'emoji': '🏐', 'label': 'Volleyball'},
    {'emoji': '🚴', 'label': 'Cycling'},
  ];

  @override
  Widget build(BuildContext context) {
    // Home'da ilk 3 etkinliği göster
    final preview = _events.take(3).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadEvents,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
              // ── Top Bar + Location ────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      _IconBtn(
                        icon: Icons.chat_bubble_outline_rounded,
                        onTap: () {},
                      ),
                      const SizedBox(width: 8),
                      _IconBtn(
                        icon: Icons.calendar_today_outlined,
                        onTap: () {},
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _showCityPicker,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 16, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(_city,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                )),
                            const SizedBox(width: 2),
                            const Icon(Icons.keyboard_arrow_down_rounded,
                                size: 18, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Greeting ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Find your game,',
                        style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        'join the community 🏆',
                        style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Category pills ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                      child: Text(
                        'Browse by sport',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 72,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _categories.length,
                        itemBuilder: (_, i) {
                          final cat = _categories[i];
                          return GestureDetector(
                            onTap: widget.onSeeAll,
                            child: Container(
                              width: 80,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(cat['emoji']!,
                                      style: const TextStyle(fontSize: 26)),
                                  const SizedBox(height: 4),
                                  Text(
                                    cat['label']!,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // ── Upcoming Events header ────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Upcoming Events',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onSeeAll,
                        child: Text(
                          'See all',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Events list ───────────────────────────────────────────
              // Loading: sadece events bölümünde spinner (üst kısım görünür kalır)
              if (_loading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),
                )
              else if (_events.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                    child: Column(
                      children: [
                        const Text('🏟️', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text('No events yet',
                            style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: widget.onSeeAll,
                          child: Text('Create the first one →',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final event = preview[i];
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
                      childCount: preview.length,
                    ),
                  ),
                ),

              // "See all" button at bottom if more events exist
              if (!_loading && _events.length > 3)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: OutlinedButton(
                      onPressed: widget.onSeeAll,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'View all ${_events.length} events',
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary),
                      ),
                    ),
                  ),
                ),

              // ── FAQ ───────────────────────────────────────────────────
              const _FaqSection(),
            ],
          ),
        ),
    );
  }
}

// ─── FAQ Section ─────────────────────────────────────────────────────────────

const _kFaqs = [
  (
    q: 'What is CanT?',
    a:
        'CanT is a community platform that connects sports enthusiasts in Germany. Find local events, join games, and meet people who share your passion for sport.',
  ),
  (
    q: 'How do I join an event?',
    a:
        'Browse the Events tab, find an event that suits you, and tap "Join Event". If the event is full, you can join the waitlist and you\'ll be notified when a spot opens up.',
  ),
  (
    q: 'How do I create an event?',
    a:
        'Tap the "Create Event" button on the Home or Events screen. Fill in the sport, location, date/time, and capacity. Your event will be visible to everyone immediately.',
  ),
  (
    q: 'Is it free?',
    a:
        'Yes! CanT is completely free to use. Creating and joining events costs nothing. We may introduce optional premium features in the future.',
  ),
  (
    q: 'How do I find events near me?',
    a:
        'Tap the city name at the top of the Home screen to change your location. Events are listed with their location so you can easily find nearby games.',
  ),
];

class _FaqSection extends StatelessWidget {
  const _FaqSection();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Text('💬', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  'Frequently Asked Questions',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // FAQ items
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: List.generate(_kFaqs.length, (i) {
                  final faq = _kFaqs[i];
                  final isLast = i == _kFaqs.length - 1;
                  return Column(
                    children: [
                      Theme(
                        data: ThemeData(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          childrenPadding: const EdgeInsets.fromLTRB(
                              16, 0, 16, 14),
                          expandedCrossAxisAlignment:
                              CrossAxisAlignment.start,
                          iconColor: AppColors.primary,
                          collapsedIconColor: AppColors.textTertiary,
                          title: Text(
                            faq.q,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          children: [
                            Text(
                              faq.a,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.55,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        const Divider(
                            height: 1,
                            color: AppColors.border,
                            indent: 16,
                            endIndent: 16),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Icon Button ──────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 20, color: AppColors.textSecondary),
      ),
    );
  }
}
