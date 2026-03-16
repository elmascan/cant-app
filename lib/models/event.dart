import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  final String id;
  final String sport;
  final String title;
  final String location;
  final DateTime time;
  final int participants;
  final int? capacity;
  final String? createdBy;
  final double? latitude;
  final double? longitude;
  final List<String> attendees;
  final int waitlistCount;
  final String? imageUrl;

  Event({
    required this.id,
    required this.sport,
    required this.title,
    required this.location,
    required this.time,
    required this.participants,
    this.capacity,
    this.createdBy,
    this.latitude,
    this.longitude,
    this.attendees = const [],
    this.waitlistCount = 0,
    this.imageUrl,
  });

  factory Event.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Event(
      id: doc.id,
      sport: data['sport'] ?? '',
      title: data['title'] ?? '',
      location: data['location'] ?? '',
      time: (data['time'] as Timestamp).toDate(),
      participants: data['participants'] ?? 0,
      capacity: data['capacity'],
      createdBy: data['created_by'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      attendees: List<String>.from(data['attendees'] ?? []),
      waitlistCount: data['waitlistCount'] ?? 0,
      imageUrl: data['image_url'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'sport': sport,
      'title': title,
      'location': location,
      'time': Timestamp.fromDate(time),
      'participants': participants,
      'capacity': capacity,
      'created_by': createdBy,
      'latitude': latitude,
      'longitude': longitude,
      'attendees': attendees,
      'waitlistCount': 0,
      if (imageUrl != null) 'image_url': imageUrl,
      'created_at': FieldValue.serverTimestamp(),
    };
  }

  Event copyWith({
    int? participants,
    List<String>? attendees,
    int? waitlistCount,
    String? imageUrl,
  }) {
    return Event(
      id: id,
      sport: sport,
      title: title,
      location: location,
      time: time,
      participants: participants ?? this.participants,
      capacity: capacity,
      createdBy: createdBy,
      latitude: latitude,
      longitude: longitude,
      attendees: attendees ?? this.attendees,
      waitlistCount: waitlistCount ?? this.waitlistCount,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  bool get isFull => capacity != null && participants >= capacity!;
  bool isJoinedBy(String userId) => attendees.contains(userId);
}
