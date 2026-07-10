import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../services/firebase_service.dart';

// ─── Communities List ─────────────────────────────────────────────────────────

class CommunitiesScreen extends StatelessWidget {
  const CommunitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Communities',
          style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseService.streamCommunities(),
        builder: (context, snapshot) {
          // Build a lookup map from Firestore data
          final Map<String, Map<String, dynamic>> firestoreData = {};
          if (snapshot.hasData) {
            for (final doc in snapshot.data!.docs) {
              firestoreData[doc.id] = doc.data() as Map<String, dynamic>;
            }
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: kSports.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final sport = kSports[i];
              final sportName = sport['name']!;
              final emoji = sport['emoji']!;
              final communityId =
                  sportName.toLowerCase().replaceAll(' ', '_');
              final data = firestoreData[communityId];
              final memberCount = (data?['memberCount'] as int?) ?? 0;
              final members =
                  List<String>.from(data?['members'] ?? []);
              final currentUid = FirebaseService.currentUser?.uid ?? '';
              final isMember = members.contains(currentUid);

              return _CommunityCard(
                sportName: sportName,
                emoji: emoji,
                memberCount: memberCount,
                isMember: isMember,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommunityDetailScreen(
                      sportName: sportName,
                      emoji: emoji,
                    ),
                  ),
                ),
                onJoinLeave: () async {
                  if (isMember) {
                    await FirebaseService.leaveCommunity(sportName);
                  } else {
                    await FirebaseService.joinCommunity(sportName);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  final String sportName;
  final String emoji;
  final int memberCount;
  final bool isMember;
  final VoidCallback onTap;
  final VoidCallback onJoinLeave;

  const _CommunityCard({
    required this.sportName,
    required this.emoji,
    required this.memberCount,
    required this.isMember,
    required this.onTap,
    required this.onJoinLeave,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
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
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 28)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sportName,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.people_rounded,
                          size: 14, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        '$memberCount ${memberCount == 1 ? 'member' : 'members'}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onJoinLeave,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isMember ? AppColors.background : AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                  border: isMember
                      ? Border.all(color: AppColors.border)
                      : null,
                ),
                child: Text(
                  isMember ? 'Joined' : 'Join',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isMember
                        ? AppColors.textSecondary
                        : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Community Detail (Chat) ──────────────────────────────────────────────────

class CommunityDetailScreen extends StatefulWidget {
  final String sportName;
  final String emoji;

  const CommunityDetailScreen({
    super.key,
    required this.sportName,
    required this.emoji,
  });

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;
  Set<String> _blockedUids = {};

  String get _currentUid => FirebaseService.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _loadBlocked();
  }

  Future<void> _loadBlocked() async {
    final blocked = await FirebaseService.getBlockedUids();
    if (mounted) setState(() => _blockedUids = blocked);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await FirebaseService.deleteMessage(widget.sportName, messageId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _reportMessage(
      String messageId, String senderUid, String text) async {
    try {
      await FirebaseService.reportMessage(
        sport: widget.sportName,
        messageId: messageId,
        senderUid: senderUid,
        text: text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message reported')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to report: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _blockUser(String uid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block User'),
        content: const Text("You won't see this user's messages anymore."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await FirebaseService.blockUser(uid);
      await _loadBlocked();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User blocked')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to block: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showMessageMenu(BuildContext ctx, String messageId,
      Map<String, dynamic> data, bool isMe) {
    final senderId = data['userId'] as String? ?? '';
    final text = data['text'] as String? ?? '';
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            if (isMe)
              ListTile(
                leading:
                    const Icon(Icons.delete_rounded, color: AppColors.error),
                title: Text('Delete Message',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, color: AppColors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessage(messageId);
                },
              )
            else ...[
              ListTile(
                leading: const Icon(Icons.flag_rounded,
                    color: AppColors.textSecondary),
                title: Text('Report Message',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _reportMessage(messageId, senderId, text);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.block_rounded, color: AppColors.error),
                title: Text('Block User',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, color: AppColors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _blockUser(senderId);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _msgController.clear();
    try {
      await FirebaseService.sendMessage(widget.sportName, text);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(
              widget.sportName,
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          // Show member count from stream
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseService.streamCommunityDoc(widget.sportName),
            builder: (context, snap) {
              final count =
                  (snap.data?.data() as Map?)?['memberCount'] as int? ?? 0;
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    '$count members',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseService.streamMessages(widget.sportName),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary));
                }

                final docs = (snapshot.data?.docs ?? []).where((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final senderId = d['userId'] as String? ?? '';
                  return !_blockedUids.contains(senderId);
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.emoji,
                            style: const TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(
                          'No messages yet',
                          style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Be the first to say hello!',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  );
                }

                _scrollToBottom();

                return ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    final isMe = data['userId'] == _currentUid;
                    return _MessageBubble(
                      data: data,
                      isMe: isMe,
                      onLongPress: () =>
                          _showMessageMenu(context, doc.id, data, isMe),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(top: false, child: _buildInput()),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgController,
              style: GoogleFonts.inter(
                  fontSize: 15, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Say something...',
                hintStyle: GoogleFonts.inter(
                    color: AppColors.textTertiary, fontSize: 15),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _send(),
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: _sending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Message Bubble ───────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isMe;
  final VoidCallback? onLongPress;
  const _MessageBubble(
      {required this.data, required this.isMe, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final text = data['text'] as String? ?? '';
    final userName = data['userName'] as String? ?? 'Unknown';
    final ts = data['createdAt'] as Timestamp?;
    final time = ts != null
        ? DateFormat('HH:mm').format(ts.toDate())
        : '';

    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 3),
              child: Text(
                userName,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary),
              ),
            ),
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                _Avatar(name: userName),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft:
                          Radius.circular(isMe ? 18 : 4),
                      bottomRight:
                          Radius.circular(isMe ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    text,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isMe
                          ? Colors.white
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 8),
                _Avatar(name: 'Me'),
              ],
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
                top: 3,
                left: isMe ? 0 : 40,
                right: isMe ? 40 : 0),
            child: Text(
              time,
              style: GoogleFonts.inter(
                  fontSize: 10, color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase();
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white),
        ),
      ),
    );
  }
}
