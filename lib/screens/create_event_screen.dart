import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/event.dart';
import '../services/firebase_service.dart';

const _kMapsApiKey = 'AIzaSyCxPo38pP6_mVeBPL_KiaqQmypXWw7-RTE';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _locationFocus = FocusNode();

  String _selectedSport = 'Football';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 18, minute: 0);
  File? _pickedImage;
  bool _uploadingImage = false;
  bool _loading = false;

  // Places Autocomplete
  List<Map<String, dynamic>> _suggestions = [];
  bool _loadingSuggestions = false;
  bool _showSuggestions = false;
  double? _selectedLat;
  double? _selectedLng;
  Timer? _debounce;

  final _picker = ImagePicker();

  // ── Places API ─────────────────────────────────────────────────────────────

  void _onLocationChanged(String value) {
    // Kullanıcı manuel yazıyorsa koordinatı sıfırla
    setState(() {
      _selectedLat = null;
      _selectedLng = null;
    });

    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchPlaces(value);
    });
  }

  Future<void> _searchPlaces(String query) async {
    if (!mounted) return;
    setState(() => _loadingSuggestions = true);
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&key=$_kMapsApiKey'
        '&components=country:de'
        '&language=de'
        '&types=geocode|establishment',
      );
      final response = await http.get(uri);
      if (!mounted) return;
      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['status'] == 'OK') {
        setState(() {
          _suggestions =
              List<Map<String, dynamic>>.from(data['predictions'] ?? []);
          _showSuggestions = _suggestions.isNotEmpty;
        });
      } else {
        setState(() {
          _suggestions = [];
          _showSuggestions = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _showSuggestions = false);
    } finally {
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  Future<void> _selectPlace(Map<String, dynamic> prediction) async {
    final placeId = prediction['place_id'] as String;
    final description = prediction['description'] as String;

    // Önce metni doldur, öneri listesini kapat
    _locationCtrl.text = description;
    setState(() {
      _showSuggestions = false;
      _suggestions = [];
      _loadingSuggestions = true;
    });
    _locationFocus.unfocus();

    // Place Details → lat/lng al
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&fields=geometry'
        '&key=$_kMapsApiKey',
      );
      final response = await http.get(uri);
      if (!mounted) return;
      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['status'] == 'OK') {
        final loc =
            data['result']['geometry']['location'] as Map<String, dynamic>;
        setState(() {
          _selectedLat = (loc['lat'] as num).toDouble();
          _selectedLng = (loc['lng'] as num).toDouble();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingSuggestions = false);
  }

  // ── Image ──────────────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.photo_library_rounded,
                    color: AppColors.primary),
              ),
              title: Text('Choose from Gallery',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _selectImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.camera_alt_rounded,
                    color: AppColors.primary),
              ),
              title: Text('Take a Photo',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _selectImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _selectImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _pickedImage = File(picked.path));
  }

  // ── Date / Time ────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty || _locationCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please fill in all required fields.'),
          backgroundColor: AppColors.error));
      return;
    }
    setState(() => _loading = true);
    try {
      final dt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      final event = Event(
        id: '',
        sport: _selectedSport,
        title: _titleCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        time: dt,
        participants: 0,
        capacity: int.tryParse(_capacityCtrl.text),
        createdBy: FirebaseService.currentUser?.uid,
        latitude: _selectedLat,
        longitude: _selectedLng,
      );
      final eventId = await FirebaseService.createEvent(event);

      if (_pickedImage != null) {
        setState(() => _uploadingImage = true);
        final imageUrl = await FirebaseService.uploadEventCover(eventId, _pickedImage!);
        await FirebaseService.updateEventImageUrl(eventId, imageUrl);
        setState(() => _uploadingImage = false);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Event created! 🎉'),
            backgroundColor: AppColors.success));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to create event: $e'),
            backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() {
        _loading = false;
        _uploadingImage = false;
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Create Event',
            style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () {
          // Dışarı tıklayınca öneri listesini kapat
          setState(() => _showSuggestions = false);
          _locationFocus.unfocus();
          FocusScope.of(context).unfocus();
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Event Image ────────────────────────────────────────
                _sectionLabel('Event Photo (optional)'),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _loading ? null : _pickImage,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 180,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _pickedImage != null
                            ? AppColors.primary
                            : AppColors.border,
                        width: _pickedImage != null ? 2 : 1,
                      ),
                    ),
                    child: _pickedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(_pickedImage!, fit: BoxFit.cover),
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: _pickImage,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black
                                            .withValues(alpha: 0.65),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.edit_rounded,
                                              size: 14,
                                              color: Colors.white),
                                          const SizedBox(width: 4),
                                          Text('Change',
                                              style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: Colors.white,
                                                  fontWeight:
                                                      FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: const BoxDecoration(
                                    color: AppColors.primaryLight,
                                    shape: BoxShape.circle),
                                child: const Icon(
                                    Icons.add_photo_alternate_rounded,
                                    size: 26,
                                    color: AppColors.primary),
                              ),
                              const SizedBox(height: 10),
                              Text('Pick an Image',
                                  style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary)),
                              const SizedBox(height: 4),
                              Text('Gallery or Camera',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.textTertiary)),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Sport ──────────────────────────────────────────────
                _sectionLabel('Sport'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kSports.map((s) {
                    final active = _selectedSport == s['name'];
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedSport = s['name']!),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.primary
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: active
                                  ? AppColors.primary
                                  : AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(s['emoji']!,
                                style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 6),
                            Text(s['name']!,
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: active
                                        ? Colors.white
                                        : AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // ── Title ──────────────────────────────────────────────
                _sectionLabel('Event Title *'),
                const SizedBox(height: 10),
                _buildField(
                    controller: _titleCtrl,
                    hint: 'e.g. Sunday Football in the Park',
                    icon: Icons.sports_rounded),

                const SizedBox(height: 20),

                // ── Location with Autocomplete ─────────────────────────
                _sectionLabel('Location *'),
                const SizedBox(height: 10),
                _buildLocationField(),

                const SizedBox(height: 20),

                // ── Date & Time ────────────────────────────────────────
                _sectionLabel('Date & Time'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: _infoTile(
                            icon: Icons.calendar_today_rounded,
                            text:
                                DateFormat('EEE, MMM d').format(_selectedDate)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickTime,
                        child: _infoTile(
                            icon: Icons.access_time_rounded,
                            text: _selectedTime.format(context)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Capacity ───────────────────────────────────────────
                _sectionLabel('Max Players (optional)'),
                const SizedBox(height: 10),
                _buildField(
                    controller: _capacityCtrl,
                    hint: 'e.g. 10',
                    icon: Icons.people_rounded,
                    keyboardType: TextInputType.number),

                const SizedBox(height: 36),

                // ── Submit ─────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 3,
                      shadowColor: AppColors.primary.withValues(alpha: 0.4),
                    ),
                    child: _loading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2)),
                              if (_uploadingImage) ...[
                                const SizedBox(width: 12),
                                Text('Uploading photo…',
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: Colors.white70)),
                              ]
                            ],
                          )
                        : Text('Create Event',
                            style: GoogleFonts.inter(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Location field with suggestions ────────────────────────────────────────

  Widget _buildLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text field
        TextField(
          controller: _locationCtrl,
          focusNode: _locationFocus,
          enabled: !_loading,
          onChanged: _onLocationChanged,
          style:
              GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'e.g. Stadtpark Karlsruhe',
            hintStyle: GoogleFonts.inter(color: AppColors.textTertiary),
            prefixIcon: const Icon(Icons.location_on_rounded,
                color: AppColors.textTertiary, size: 20),
            suffixIcon: _loadingSuggestions
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary)),
                  )
                : _selectedLat != null
                    ? const Icon(Icons.check_circle_rounded,
                        color: AppColors.success, size: 20)
                    : null,
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 2)),
          ),
        ),

        // Suggestions dropdown
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                children: _suggestions.take(5).toList().asMap().entries.map((e) {
                  final idx = e.key;
                  final pred = e.value;
                  final main =
                      pred['structured_formatting']?['main_text'] as String? ??
                          pred['description'] as String;
                  final secondary =
                      pred['structured_formatting']?['secondary_text']
                          as String?;
                  final isLast =
                      idx == (_suggestions.length - 1).clamp(0, 4);

                  return Column(
                    children: [
                      InkWell(
                        onTap: () => _selectPlace(pred),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.location_on_rounded,
                                    color: AppColors.primary, size: 16),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      main,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (secondary != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        secondary,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: AppColors.textTertiary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!isLast)
                        const Divider(
                            height: 1,
                            color: AppColors.border,
                            indent: 58,
                            endIndent: 14),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(text,
      style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary));

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: !_loading,
      style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: AppColors.textTertiary),
        prefixIcon: Icon(icon, color: AppColors.textTertiary, size: 20),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 2)),
      ),
    );
  }

  Widget _infoTile({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(text,
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      ]),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _capacityCtrl.dispose();
    _locationFocus.dispose();
    super.dispose();
  }
}
