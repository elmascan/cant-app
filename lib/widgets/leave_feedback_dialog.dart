import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';

const _kReasons = [
  'Schedule conflict',
  'Found another event',
  'Too far away',
  'Not interested anymore',
  'Other',
];

/// Kullanıcının etkinlikten ayrılma nedenini soran modal.
/// Navigator.pop ile Map<String, String>? döner:
///   {'reason': '...', 'details': '...'} veya null (iptal).
class LeaveFeedbackDialog extends StatefulWidget {
  final String eventTitle;
  const LeaveFeedbackDialog({super.key, required this.eventTitle});

  @override
  State<LeaveFeedbackDialog> createState() => _LeaveFeedbackDialogState();
}

class _LeaveFeedbackDialogState extends State<LeaveFeedbackDialog> {
  String? _selected;
  final _otherCtrl = TextEditingController();

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_selected == null) return;
    Navigator.pop(context, {
      'reason': _selected!,
      if (_selected == 'Other' && _otherCtrl.text.trim().isNotEmpty)
        'details': _otherCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOther = _selected == 'Other';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Why are you leaving?',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.eventTitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Reason options
              ..._kReasons.map((reason) {
                final selected = _selected == reason;
                return InkWell(
                  onTap: () => setState(() => _selected = reason),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: selected ? 7 : 2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          reason,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: selected
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              // "Other" text field
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: TextField(
                    controller: _otherCtrl,
                    autofocus: true,
                    maxLines: 2,
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Tell us more…',
                      hintStyle:
                          GoogleFonts.inter(color: AppColors.textTertiary),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                ),
                crossFadeState: isOther
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),

              // Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _selected != null ? _confirm : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.border,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(
                          'Leave Event',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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
