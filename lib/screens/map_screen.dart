import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../models/event.dart';
import '../services/firebase_service.dart';

class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final List<Event> _mappedEvents = [];
  Position? _userPosition;
  bool _loading = true;
  String? _errorMsg;

  // Karlsruhe merkez — kullanıcı konumu yoksa burayı göster
  static const _defaultCenter = LatLng(49.0069, 8.4037);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Future.wait([_getUserLocation(), _loadAndGeocodeEvents()]);
    if (mounted) setState(() => _loading = false);
  }

  // ── Konum ───────────────────────────────────────────────────────────────────

  Future<void> _getUserLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;

      _userPosition = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (_) {}
  }

  // ── Etkinlikleri yükle ve koordinatları belirle ───────────────────────────

  Future<void> _loadAndGeocodeEvents() async {
    try {
      final events = await FirebaseService.getEvents();

      for (final event in events) {
        LatLng? position;

        // Koordinat varsa direkt kullan
        if (event.latitude != null && event.longitude != null) {
          position = LatLng(event.latitude!, event.longitude!);
        } else {
          // Yoksa konum adresini geocode et
          position = await _geocodeAddress(event.location);
        }

        if (position == null) continue;

        final icon = await _emojiMarker(getSportEmoji(event.sport));
        final capacity = event.capacity;
        final snippet = capacity != null
            ? '${event.participants}/$capacity players'
            : '${event.participants} players';

        _mappedEvents.add(event);
        _markers.add(
          Marker(
            markerId: MarkerId(event.id),
            position: position,
            icon: icon,
            anchor: const Offset(0.5, 0.5),
            onTap: () => _showEventSheet(event),
            infoWindow: InfoWindow(
              title: event.title,
              snippet: snippet,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMsg = 'Failed to load events: $e');
    }
  }

  Future<LatLng?> _geocodeAddress(String address) async {
    try {
      final locations = await locationFromAddress('$address, Germany');
      if (locations.isNotEmpty) {
        return LatLng(locations.first.latitude, locations.first.longitude);
      }
    } catch (_) {}
    return null;
  }

  // ── Emoji marker ────────────────────────────────────────────────────────────

  /// Emoji'yi beyaz daireli arka plana çizerek BitmapDescriptor üretir.
  static Future<BitmapDescriptor> _emojiMarker(String emoji) async {
    const size = 96.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Beyaz daire + gölge
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(
        const Offset(size / 2, size / 2 + 3), size / 2 - 4, shadowPaint);

    final bgPaint = Paint()..color = Colors.white;
    canvas.drawCircle(
        const Offset(size / 2, size / 2), size / 2 - 4, bgPaint);

    // Emoji
    final paragraphBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontSize: size * 0.52,
      textAlign: TextAlign.center,
    ))
      ..addText(emoji);
    final paragraph = paragraphBuilder.build()
      ..layout(const ui.ParagraphConstraints(width: size));
    canvas.drawParagraph(
        paragraph, Offset(0, (size - paragraph.height) / 2 - 2));

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  // ── Harita ──────────────────────────────────────────────────────────────────

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_userPosition != null) {
      // moveCamera (instant) prevents briefly showing the default Google Maps position
      _mapController?.moveCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_userPosition!.latitude, _userPosition!.longitude),
          13,
        ),
      );
    }
  }

  void _goToMyLocation() {
    if (_userPosition == null) return;
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(_userPosition!.latitude, _userPosition!.longitude),
        15,
      ),
    );
  }

  LatLng get _initialTarget => _userPosition != null
      ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
      : _defaultCenter;

  // ── Event bottom sheet ───────────────────────────────────────────────────

  void _showEventSheet(Event event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EventSheet(event: event),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _initialTarget,
                    zoom: 13.0,
                  ),
                  markers: _markers,
                  myLocationEnabled: _userPosition != null,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: true,
                  mapToolbarEnabled: false,
                  // PageView ile gesture çakışmasını önler:
                  // haritaya dokunulduğunda tüm gesture'lar haritaya verilir
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                    Factory<EagerGestureRecognizer>(
                        () => EagerGestureRecognizer()),
                  },
                ),

                // ── Header ──────────────────────────────────────────────────
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.map_rounded,
                              color: AppColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Nearby Events',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_mappedEvents.length} events',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Legend ─────────────────────────────────────────────────
                if (_mappedEvents.isEmpty && _errorMsg == null)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.all(32),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🗺️',
                              style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 12),
                          Text('No events found',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              )),
                          const SizedBox(height: 6),
                          Text('Create an event to see it on the map',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),

                // ── My Location button ─────────────────────────────────────
                Positioned(
                  bottom: 160,
                  right: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'map_locate',
                    onPressed: _goToMyLocation,
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.primary,
                    elevation: 4,
                    child: const Icon(Icons.my_location_rounded),
                  ),
                ),
              ],
            ),
    );
  }
}

// ─── Event Bottom Sheet ───────────────────────────────────────────────────────

class _EventSheet extends StatelessWidget {
  final Event event;
  const _EventSheet({required this.event});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
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

          // Sport + Title
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    getSportEmoji(event.sport),
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      event.sport.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 14),

          _InfoRow(
            icon: Icons.access_time_rounded,
            text: DateFormat('EEE, MMM d • h:mm a').format(event.time),
          ),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.location_on_rounded, text: event.location),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.people_rounded,
            text:
                '${event.participants}/${event.capacity ?? '∞'} players',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textTertiary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
