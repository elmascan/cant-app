import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../services/firebase_service.dart';

class DirectChatScreen extends StatefulWidget {
  final String matchId;
  final String otherName;
  final String? otherPhotoUrl;

  const DirectChatScreen({
    super.key,
    required this.matchId,
    required this.otherName,
    this.otherPhotoUrl,
  });

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  String get _currentUid => FirebaseService.currentUser?.uid ?? '';

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

  Future<void> _send() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _msgController.clear();
    try {
      await FirebaseService.sendDirectMessage(widget.matchId, text);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to send: $e')));
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
    final initials = widget.otherName.trim().isEmpty
        ? '?'
        : widget.otherName
            .trim()
            .split(' ')
            .map((w) => w[0])
            .take(2)
            .join()
            .toUpperCase();

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
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
              child: widget.otherPhotoUrl != null
                  ? ClipOval(
                      child: Image.network(widget.otherPhotoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                                child: Text(initials,
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white)),
                              )))
                  : Center(
                      child: Text(initials,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ),
            ),
            const SizedBox(width: 10),
            Text(widget.otherName,
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ],
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseService.streamDirectMessages(widget.matchId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary));
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🤝', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text('You matched!',
                            style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text('Say hello to ${widget.otherName}!',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textSecondary)),
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
                    final data = docs[i].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == _currentUid;
                    return _DmBubble(
                      data: data,
                      isMe: isMe,
                      otherInitials: initials,
                      otherPhotoUrl: widget.otherPhotoUrl,
                    );
                  },
                );
              },
            ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 12),
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
              style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Message ${widget.otherName}…',
                hintStyle: GoogleFonts.inter(
                    color: AppColors.textTertiary, fontSize: 15),
                filled: true,
                fillColor: AppColors.background,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  color: AppColors.primary, shape: BoxShape.circle),
              child: _sending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── DM Bubble ────────────────────────────────────────────────────────────────

class _DmBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isMe;
  final String otherInitials;
  final String? otherPhotoUrl;

  const _DmBubble({
    required this.data,
    required this.isMe,
    required this.otherInitials,
    this.otherPhotoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final text = data['text'] as String? ?? '';
    final ts = data['createdAt'] as Timestamp?;
    final time = ts != null ? DateFormat('HH:mm').format(ts.toDate()) : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
              child: otherPhotoUrl != null
                  ? ClipOval(
                      child: Image.network(otherPhotoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                                child: Text(otherInitials,
                                    style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                              )))
                  : Center(
                      child: Text(otherInitials,
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(text,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: isMe ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      )),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(time,
                      style: GoogleFonts.inter(
                          fontSize: 10, color: AppColors.textTertiary)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
