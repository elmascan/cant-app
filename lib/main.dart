import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'constants.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/events_screen.dart';
import 'screens/create_event_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/matches_screen.dart';
import 'screens/direct_chat_screen.dart';
import 'screens/gdpr_screen.dart';
import 'screens/map_screen.dart';
import 'screens/discover_screen.dart';
import 'services/notification_service.dart';
import 'services/firebase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  runApp(const CanTApp());
}

class CanTApp extends StatefulWidget {
  const CanTApp({super.key});

  @override
  State<CanTApp> createState() => _CanTAppState();
}

class _CanTAppState extends State<CanTApp> {
  // null = henüz kontrol edilmedi
  bool? _gdprAccepted;

  @override
  void initState() {
    super.initState();
    _checkGdpr();
  }

  Future<void> _checkGdpr() async {
    final accepted = await GdprScreen.isAccepted();
    setState(() => _gdprAccepted = accepted);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CanT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      home: _buildHome(),
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const MainShell(),
      },
    );
  }

  Widget _buildHome() {
    // GDPR henüz kontrol edilmedi → splash
    if (_gdprAccepted == null) {
      return const _SplashScreen();
    }

    // GDPR kabul edilmedi → onay ekranı
    if (!_gdprAccepted!) {
      return GdprScreen(
        onAccepted: () => setState(() => _gdprAccepted = true),
      );
    }

    // GDPR kabul edildi → normal auth akışı
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }
        return snapshot.hasData ? const MainShell() : const WelcomeScreen();
      },
    );
  }
}

// SportsApp alias — test dosyası için geriye dönük uyumluluk
typedef SportsApp = CanTApp;

// ─── Splash Screen ────────────────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Icon at top
            Positioned(
              top: 48,
              left: 0,
              right: 0,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/icon/icon.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            // Text + loader at bottom
            Positioned(
              bottom: 48,
              left: 32,
              right: 32,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'CanT',
                    style: GoogleFonts.inter(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Can Train with Your Mate anywhere',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.75),
                      letterSpacing: 0.3,
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

// ─── Nav items ───────────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}

const _kNavItems = [
  _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
  _NavItem(Icons.event_outlined, Icons.event_rounded, 'Events'),
  _NavItem(Icons.handshake_outlined, Icons.handshake_rounded, 'Matches'),
  _NavItem(Icons.map_outlined, Icons.map_rounded, 'Map'),
  _NavItem(Icons.favorite_border_rounded, Icons.favorite_rounded, 'Discover'),
];

// ─── Main Shell ──────────────────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _pageController = PageController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initNotifications() async {
    await NotificationService.initialize();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    NotificationService.unreadStream(uid).listen((snap) {
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (!mounted) return;
        final type = data['type'] as String? ?? '';
        final notifId = doc.id;
        if (type == 'waitlist_promoted') {
          _showBanner(data['eventTitle'] as String? ?? 'an event', notifId, uid);
        } else if (type == 'new_match') {
          _showMatchBanner(
            data['fromName'] as String? ?? 'Someone',
            data['matchId'] as String? ?? '',
            notifId,
            uid,
          );
        } else if (type == 'new_message') {
          _showMessageBanner(
            data['fromName'] as String? ?? 'Someone',
            data['preview'] as String? ?? '',
            data['matchId'] as String? ?? '',
            notifId,
            uid,
          );
        }
      }
    });
  }

  void _showBanner(String title, String notifId, String uid) {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        backgroundColor: AppColors.warning,
        leading: const Icon(Icons.celebration_rounded,
            color: Colors.white, size: 26),
        content: Text(
          'A spot opened in "$title"! You\'ve been added.',
          style: GoogleFonts.inter(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              NotificationService.markRead(uid, notifId);
            },
            child: Text('Got it',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    NotificationService.markRead(uid, notifId);
  }

  void _showMatchBanner(String fromName, String matchId, String notifId, String uid) {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        backgroundColor: AppColors.primary,
        leading: const Icon(Icons.handshake_rounded, color: Colors.white, size: 26),
        content: Text(
          'You have a new Sport Mate! 🎉 $fromName also wants to play.',
          style: GoogleFonts.inter(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              NotificationService.markRead(uid, notifId);
              if (matchId.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DirectChatScreen(
                      matchId: matchId,
                      otherName: fromName,
                      otherPhotoUrl: null,
                    ),
                  ),
                );
              } else {
                _goToTab(2);
              }
            },
            child: Text('View',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              NotificationService.markRead(uid, notifId);
            },
            child: Text('Dismiss',
                style: GoogleFonts.inter(
                    color: Colors.white70, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    NotificationService.markRead(uid, notifId);
  }

  void _showMessageBanner(
      String fromName, String preview, String matchId, String notifId, String uid) {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        backgroundColor: const Color(0xFF059669),
        leading: const Icon(Icons.message_rounded, color: Colors.white, size: 26),
        content: Text(
          '$fromName: $preview',
          style: GoogleFonts.inter(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              NotificationService.markRead(uid, notifId);
              if (matchId.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DirectChatScreen(
                      matchId: matchId,
                      otherName: fromName,
                      otherPhotoUrl: null,
                    ),
                  ),
                );
              } else {
                _goToTab(2);
              }
            },
            child: Text('Reply',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              NotificationService.markRead(uid, notifId);
            },
            child: Text('Dismiss',
                style: GoogleFonts.inter(
                    color: Colors.white70, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    NotificationService.markRead(uid, notifId);
  }

  void _goToTab(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentIndex = index);
  }

  void _openProfile() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: _PersistentTopBar(onOpenProfile: _openProfile),
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                children: [
                  HomeTab(onSeeAll: () => _goToTab(1)),
                  const EventsTab(),
                  const MatchesTab(),
                  const MapTab(),
                  const DiscoverTab(),
                ],
              ),
            ),
          ),
        ],
      ),

      // FAB on Home and Events tabs
      floatingActionButton: _currentIndex <= 1
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CreateEventScreen()));
              },
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: Text('Create Event',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              elevation: 4,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: _goToTab,
      ),
    );
  }
}

// ─── Persistent Top Bar ──────────────────────────────────────────────────────

class _PersistentTopBar extends StatelessWidget {
  final VoidCallback onOpenProfile;
  const _PersistentTopBar({required this.onOpenProfile});

  String get _firstName {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';
    final name = user.displayName ?? user.email?.split('@').first ?? '';
    return name.split(' ').first;
  }

  String get _initials {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '?';
    final name =
        user.displayName ?? user.email?.split('@').first ?? '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 10),
      child: Row(
        children: [
          Text('CanT',
              style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary)),
          const Spacer(),
          if (user != null)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .doc(user.uid)
                  .collection('items')
                  .where('read', isEqualTo: false)
                  .snapshots(),
              builder: (context, snap) {
                final count = snap.data?.docs.length ?? 0;
                return GestureDetector(
                  onTap: () => showModalBottomSheet(
                    context: context,
                    backgroundColor: AppColors.surface,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (_) => _NotificationPanel(uid: user.uid),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          count > 0
                              ? Icons.notifications_rounded
                              : Icons.notifications_outlined,
                          color: count > 0
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          size: 22,
                        ),
                        if (count > 0)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle),
                              child: Center(
                                child: Text(
                                  count > 9 ? '9+' : '$count',
                                  style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          GestureDetector(
            onTap: onOpenProfile,
            child: Row(
              children: [
                if (_firstName.isNotEmpty) ...[
                  Text(_firstName,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(width: 8),
                ],
                StreamBuilder<DocumentSnapshot>(
                  stream: user != null
                      ? FirebaseService.streamProfile(user.uid)
                      : const Stream.empty(),
                  builder: (context, snap) {
                    final data = snap.hasData
                        ? snap.data!.data() as Map<String, dynamic>?
                        : null;
                    final photoUrl = data?['photo_url'] as String?;
                    return Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ],
                      ),
                      child: photoUrl != null
                          ? ClipOval(
                              child: Image.network(
                                photoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(_initials,
                                      style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white)),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(_initials,
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                            ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Notification Panel ──────────────────────────────────────────────────────

class _NotificationPanel extends StatelessWidget {
  final String uid;
  const _NotificationPanel({required this.uid});

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _markAllRead() async {
    final snap = await FirebaseFirestore.instance
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .where('read', isEqualTo: false)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Notifications',
                          style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary)),
                      const Spacer(),
                      TextButton(
                        onPressed: _markAllRead,
                        child: Text('Mark all read',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notifications')
                    .doc(uid)
                    .collection('items')
                    .limit(30)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary));
                  }
                  final docs = [...(snap.data?.docs ?? [])];
                  docs.sort((a, b) {
                    final aTs =
                        (a.data() as Map)['createdAt'] as Timestamp?;
                    final bTs =
                        (b.data() as Map)['createdAt'] as Timestamp?;
                    if (aTs == null && bTs == null) return 0;
                    if (aTs == null) return 1;
                    if (bTs == null) return -1;
                    return bTs.compareTo(aTs);
                  });
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🔔',
                              style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text('No notifications yet',
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final data =
                          docs[i].data() as Map<String, dynamic>;
                      final type = data['type'] as String? ?? '';
                      final read = data['read'] as bool? ?? true;
                      final ts = data['createdAt'] as Timestamp?;

                      IconData icon;
                      Color iconColor;
                      String title;

                      switch (type) {
                        case 'new_match':
                          icon = Icons.handshake_rounded;
                          iconColor = AppColors.primary;
                          title =
                              '${data['fromName'] ?? 'Someone'} matched with you! 🎉';
                          break;
                        case 'new_message':
                          icon = Icons.message_rounded;
                          iconColor = const Color(0xFF059669);
                          title =
                              '${data['fromName'] ?? 'Someone'}: ${data['preview'] ?? ''}';
                          break;
                        case 'waitlist_promoted':
                          icon = Icons.celebration_rounded;
                          iconColor = AppColors.warning;
                          title =
                              'You got a spot in "${data['eventTitle'] ?? 'an event'}"!';
                          break;
                        default:
                          icon = Icons.notifications_rounded;
                          iconColor = AppColors.textSecondary;
                          title = 'New notification';
                      }

                      return InkWell(
                        onTap: () {
                          if (!read) {
                            NotificationService.markRead(uid, docs[i].id);
                          }
                          if ((type == 'new_match' ||
                                  type == 'new_message') &&
                              data['matchId'] != null) {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DirectChatScreen(
                                  matchId: data['matchId'] as String,
                                  otherName:
                                      data['fromName'] as String? ??
                                          'Player',
                                  otherPhotoUrl: null,
                                ),
                              ),
                            );
                          }
                        },
                        child: Container(
                          color: read
                              ? null
                              : AppColors.primary.withValues(alpha: 0.05),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: iconColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(icon,
                                    color: iconColor, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: read
                                            ? FontWeight.w500
                                            : FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (ts != null)
                                      Text(_timeAgo(ts),
                                          style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color:
                                                  AppColors.textTertiary)),
                                  ],
                                ),
                              ),
                              if (!read)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Custom Bottom Nav ────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_kNavItems.length, (i) {
              final item = _kNavItems[i];
              final active = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: Icon(
                          active ? item.activeIcon : item.icon,
                          key: ValueKey(active),
                          size: 22,
                          color: active
                              ? AppColors.primary
                              : AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w500,
                          color: active
                              ? AppColors.primary
                              : AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: active ? 4 : 0,
                        height: active ? 4 : 0,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
