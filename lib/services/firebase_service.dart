import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/event.dart';

class FirebaseService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static FirebaseStorage get _storage => FirebaseStorage.instanceFor(
    bucket: 'gs://sports-community-d6b15.firebasestorage.app',
  );

  // ─── Auth ────────────────────────────────────────────────────────────────

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static Future<UserCredential> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(fullName);
    await _db.collection('profiles').doc(credential.user!.uid).set({
      'full_name': fullName,
      'email': email,
      'created_at': FieldValue.serverTimestamp(),
    });
    return credential;
  }

  static Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  // ─── Events ──────────────────────────────────────────────────────────────

  static Future<List<Event>> getEvents() async {
    final now = Timestamp.now();
    final snapshot = await _db
        .collection('events')
        .where('time', isGreaterThanOrEqualTo: now)
        .orderBy('time', descending: false)
        .get();
    return snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList();
  }

  /// Etkinlik oluşturur ve oluşturulan belge ID'sini döner.
  static Future<String> createEvent(Event event) async {
    final ref = await _db.collection('events').add(event.toFirestore());
    return ref.id;
  }

  /// Etkinlik kapak fotoğrafını Storage'a yükler, URL döner.
  static Future<String> uploadEventCover(String eventId, File file) async {
    try {
      debugPrint('[Storage] uploadEventCover → bucket: ${_storage.bucket}');
      debugPrint('[Storage] file path: ${file.path}, size: ${await file.length()} bytes');
      final ref = _storage.ref().child('events/$eventId/cover.jpg');
      debugPrint('[Storage] ref full path: ${ref.fullPath}');
      final task = await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      debugPrint('[Storage] upload state: ${task.state}');
      final url = await task.ref.getDownloadURL();
      debugPrint('[Storage] download URL: $url');
      return url;
    } on FirebaseException catch (e) {
      debugPrint('[Storage] FirebaseException code=${e.code} message=${e.message} plugin=${e.plugin}');
      rethrow;
    } catch (e, stack) {
      debugPrint('[Storage] Unknown error: $e\n$stack');
      rethrow;
    }
  }

  /// Etkinliğin image_url alanını günceller.
  static Future<void> updateEventImageUrl(String eventId, String imageUrl) async {
    await _db.collection('events').doc(eventId).update({'image_url': imageUrl});
  }

  /// Profil fotoğrafını Storage'a yükler, Firestore'daki photo_url'yi günceller, URL döner.
  static Future<String> uploadProfileAvatar(File file) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('Not signed in');
      debugPrint('[Storage] uploadProfileAvatar → uid: ${user.uid}');
      debugPrint('[Storage] bucket: ${_storage.bucket}');
      debugPrint('[Storage] file path: ${file.path}, size: ${await file.length()} bytes');
      final ref = _storage.ref().child('profiles/${user.uid}/avatar.jpg');
      debugPrint('[Storage] ref full path: ${ref.fullPath}');
      final task = await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      debugPrint('[Storage] upload state: ${task.state}');
      final url = await task.ref.getDownloadURL();
      debugPrint('[Storage] download URL: $url');
      await _db.collection('profiles').doc(user.uid).update({'photo_url': url});
      return url;
    } on FirebaseException catch (e) {
      debugPrint('[Storage] FirebaseException code=${e.code} message=${e.message} plugin=${e.plugin}');
      rethrow;
    } catch (e, stack) {
      debugPrint('[Storage] Unknown error: $e\n$stack');
      rethrow;
    }
  }

  /// Profil dokümanını gerçek zamanlı stream olarak döner.
  static Stream<DocumentSnapshot> streamProfile(String userId) =>
      _db.collection('profiles').doc(userId).snapshots();

  /// Etkinliğe katıl. Kapasite doluysa exception fırlatır.
  static Future<void> joinEvent(String eventId) async {
    final user = currentUser;
    if (user == null) throw Exception('Not signed in');

    await _db.runTransaction((tx) async {
      final ref = _db.collection('events').doc(eventId);
      final snap = await tx.get(ref);
      final data = snap.data() as Map<String, dynamic>;
      final participants = (data['participants'] ?? 0) as int;
      final capacity = data['capacity'] as int?;
      final attendees = List<String>.from(data['attendees'] ?? []);

      if (attendees.contains(user.uid)) throw Exception('Already joined');
      if (capacity != null && participants >= capacity) {
        throw Exception('Event is full');
      }

      tx.update(ref, {
        'participants': FieldValue.increment(1),
        'attendees': FieldValue.arrayUnion([user.uid]),
      });
    });
  }

  /// Etkinlikten ayrıl. Waitlist varsa ilk kişiyi otomatik promote eder.
  static Future<void> leaveEvent(String eventId, String eventTitle) async {
    final user = currentUser;
    if (user == null) throw Exception('Not signed in');

    // Waitlist kontrolü — transaction dışında sorgu
    final waitlistSnap = await _db
        .collection('events')
        .doc(eventId)
        .collection('waitlist')
        .orderBy('joinedAt')
        .limit(1)
        .get();

    await _db.runTransaction((tx) async {
      final eventRef = _db.collection('events').doc(eventId);
      final snap = await tx.get(eventRef);
      final data = snap.data() as Map<String, dynamic>;
      final attendees = List<String>.from(data['attendees'] ?? []);
      final participants = (data['participants'] ?? 0) as int;

      // Kullanıcı zaten ayrılmış mı?
      if (!attendees.contains(user.uid)) {
        throw Exception('You are not registered for this event');
      }

      attendees.remove(user.uid);

      if (waitlistSnap.docs.isEmpty) {
        // Waitlist yok → participants azalt, attendees güncelle
        // 0'ın altına düşmesini engelle
        tx.update(eventRef, {
          'participants': participants > 0 ? FieldValue.increment(-1) : 0,
          'attendees': attendees,
        });
      } else {
        // Waitlist var → slot dolduruluyor, participants değişmez
        final promotedDoc = waitlistSnap.docs.first;
        final promotedUserId = promotedDoc.data()['userId'] as String;

        if (!attendees.contains(promotedUserId)) {
          attendees.add(promotedUserId);
        }

        tx.update(eventRef, {
          'attendees': attendees,
          'waitlistCount': FieldValue.increment(-1),
        });

        // Waitlist'ten çıkar
        tx.delete(promotedDoc.reference);

        // In-app bildirim
        final notifRef = _db
            .collection('notifications')
            .doc(promotedUserId)
            .collection('items')
            .doc();
        tx.set(notifRef, {
          'type': 'waitlist_promoted',
          'eventId': eventId,
          'eventTitle': eventTitle,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  /// Etkinlikten ayrılma nedenini Firestore'a kaydeder.
  static Future<void> saveFeedback({
    required String eventId,
    required String reason,
    String? details,
  }) async {
    final user = currentUser;
    if (user == null) return;
    await _db.collection('event_feedback').add({
      'eventId': eventId,
      'userId': user.uid,
      'reason': reason,
      if (details != null && details.isNotEmpty) 'details': details,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Waitlist ─────────────────────────────────────────────────────────────

  static Future<bool> isOnWaitlist(String eventId) async {
    final user = currentUser;
    if (user == null) return false;
    final doc = await _db
        .collection('events')
        .doc(eventId)
        .collection('waitlist')
        .doc(user.uid)
        .get();
    return doc.exists;
  }

  /// Waitlist'e katıl. Sıra numarasını döner (1 = ilk sıra).
  static Future<int> joinWaitlist(String eventId) async {
    final user = currentUser;
    if (user == null) throw Exception('Not signed in');

    final token = await FirebaseMessaging.instance.getToken();

    await _db
        .collection('events')
        .doc(eventId)
        .collection('waitlist')
        .doc(user.uid)
        .set({
      'userId': user.uid,
      'fcmToken': token ?? '',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('events').doc(eventId).update({
      'waitlistCount': FieldValue.increment(1),
    });

    // Kaçıncı sıraya girdi?
    return await getWaitlistPosition(eventId);
  }

  static Future<void> leaveWaitlist(String eventId) async {
    final user = currentUser;
    if (user == null) return;

    await _db
        .collection('events')
        .doc(eventId)
        .collection('waitlist')
        .doc(user.uid)
        .delete();

    await _db.collection('events').doc(eventId).update({
      'waitlistCount': FieldValue.increment(-1),
    });
  }

  /// Kullanıcının waitlist'teki sırasını döner. -1 = listede değil.
  static Future<int> getWaitlistPosition(String eventId) async {
    final user = currentUser;
    if (user == null) return -1;

    final userDoc = await _db
        .collection('events')
        .doc(eventId)
        .collection('waitlist')
        .doc(user.uid)
        .get();
    if (!userDoc.exists) return -1;

    final joinedAt = userDoc.data()!['joinedAt'] as Timestamp?;
    if (joinedAt == null) return 1; // serverTimestamp henüz yazılmadıysa

    final earlier = await _db
        .collection('events')
        .doc(eventId)
        .collection('waitlist')
        .where('joinedAt', isLessThan: joinedAt)
        .get();
    return earlier.docs.length + 1;
  }

  // ─── Profile ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getProfile(String userId) async {
    final doc = await _db.collection('profiles').doc(userId).get();
    return doc.data();
  }

  /// Kullanıcının katıldığı etkinlik sayısı
  static Future<int> getUserEventCount(String userId) async {
    final result = await _db
        .collection('events')
        .where('attendees', arrayContains: userId)
        .get();
    return result.docs.length;
  }

  // ─── Communities ──────────────────────────────────────────────────────────

  static String _communityId(String sport) =>
      sport.toLowerCase().replaceAll(' ', '_');

  static Stream<QuerySnapshot> streamCommunities() =>
      _db.collection('communities').snapshots();

  static Stream<DocumentSnapshot> streamCommunityDoc(String sport) =>
      _db.collection('communities').doc(_communityId(sport)).snapshots();

  /// Profil bilgilerini (city, bio, sports) günceller ve toplulukları senkronize eder.
  static Future<void> updateProfile({
    required String city,
    required String bio,
    required List<String> sports,
  }) async {
    final user = currentUser;
    if (user == null) return;
    final currentData = await getProfile(user.uid);
    final currentSports =
        List<String>.from(currentData?['sports'] ?? []);

    await _db.collection('profiles').doc(user.uid).update({
      'city': city,
      'bio': bio,
      'sports': sports,
    });

    final toJoin =
        sports.where((s) => !currentSports.contains(s)).toList();
    final toLeave =
        currentSports.where((s) => !sports.contains(s)).toList();
    for (final s in toJoin) {
      await joinCommunity(s);
    }
    for (final s in toLeave) {
      await leaveCommunity(s);
    }
  }

  /// Profildeki sports alanını günceller ve her spor için topluluğa katılır.
  static Future<void> saveSports(List<String> sports) async {
    final user = currentUser;
    if (user == null) return;
    await _db.collection('profiles').doc(user.uid).update({'sports': sports});
    for (final sport in sports) {
      await joinCommunity(sport);
    }
  }

  static Future<void> joinCommunity(String sport) async {
    final user = currentUser;
    if (user == null) throw Exception('Not signed in');
    await _db.collection('communities').doc(_communityId(sport)).set({
      'sport': sport,
      'members': FieldValue.arrayUnion([user.uid]),
      'memberCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  static Future<void> leaveCommunity(String sport) async {
    final user = currentUser;
    if (user == null) return;
    await _db.collection('communities').doc(_communityId(sport)).update({
      'members': FieldValue.arrayRemove([user.uid]),
      'memberCount': FieldValue.increment(-1),
    });
  }

  static Stream<QuerySnapshot> streamMessages(String sport) => _db
      .collection('communities')
      .doc(_communityId(sport))
      .collection('messages')
      .orderBy('createdAt')
      .snapshots();

  static Future<void> sendMessage(String sport, String text) async {
    final user = currentUser;
    if (user == null) throw Exception('Not signed in');
    final profile = await getProfile(user.uid);
    final userName =
        profile?['full_name'] as String? ?? user.displayName ?? 'Unknown';
    await _db
        .collection('communities')
        .doc(_communityId(sport))
        .collection('messages')
        .add({
      'text': text,
      'userId': user.uid,
      'userName': userName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Discover ─────────────────────────────────────────────────────────────

  /// Mevcut kullanıcının daha önce swipe etmediği, aynı sporla ilgilenen
  /// profilleri döner. Maksimum 50 profil.
  static Future<List<Map<String, dynamic>>> getDiscoverProfiles() async {
    final user = currentUser;
    if (user == null) return [];

    // Daha önce swipe edilen kullanıcı ID'leri
    final swipesSnap = await _db
        .collection('swipes')
        .where('swiperId', isEqualTo: user.uid)
        .get();
    final swipedIds = swipesSnap.docs
        .map((d) => d.data()['swipedId'] as String)
        .toSet()
      ..add(user.uid); // kendini de hariç tut

    // Tüm profilleri al (daha büyük veri setlerinde cursor pagination gerekir)
    final profilesSnap = await _db.collection('profiles').limit(100).get();

    final results = <Map<String, dynamic>>[];
    for (final doc in profilesSnap.docs) {
      if (swipedIds.contains(doc.id)) continue;
      final data = doc.data();
      results.add({...data, 'uid': doc.id});
      if (results.length >= 50) break;
    }
    return results;
  }

  /// Bir kullanıcıyı swipe et. liked=true ise karşılıklı beğeni varsa
  /// matches koleksiyonuna kayıt atar ve true döner.
  static Future<bool> swipeUser({
    required String swipedUserId,
    required bool liked,
  }) async {
    final user = currentUser;
    if (user == null) return false;

    final swipeId = '${user.uid}_$swipedUserId';
    await _db.collection('swipes').doc(swipeId).set({
      'swiperId': user.uid,
      'swipedId': swipedUserId,
      'liked': liked,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!liked) return false;

    // Karşı taraf sağa swipe etmiş mi kontrol et
    final reverseDoc = await _db
        .collection('swipes')
        .doc('${swipedUserId}_${user.uid}')
        .get();
    if (!reverseDoc.exists) return false;
    final reverseLiked = reverseDoc.data()?['liked'] as bool? ?? false;
    if (!reverseLiked) return false;

    // Match! — tekrar kayıt yazmamak için kontrol et
    final matchId = [user.uid, swipedUserId]..sort();
    final matchDocId = matchId.join('_');
    final existingMatch = await _db.collection('matches').doc(matchDocId).get();
    if (existingMatch.exists) return true;

    await _db.collection('matches').doc(matchDocId).set({
      'users': matchId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Her iki kullanıcıya in-app match bildirimi yaz
    final myProfile = await getProfile(user.uid);
    final otherProfile = await getProfile(swipedUserId);
    final myName = myProfile?['full_name'] as String? ?? 'Someone';
    final otherName = otherProfile?['full_name'] as String? ?? 'Someone';

    await _db
        .collection('notifications')
        .doc(swipedUserId)
        .collection('items')
        .add({
      'type': 'new_match',
      'matchId': matchDocId,
      'fromName': myName,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _db
        .collection('notifications')
        .doc(user.uid)
        .collection('items')
        .add({
      'type': 'new_match',
      'matchId': matchDocId,
      'fromName': otherName,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return true;
  }

  // ─── Direct Messaging ─────────────────────────────────────────────────────

  /// Mevcut kullanıcının tüm match'lerini stream olarak döner.
  static Stream<QuerySnapshot> streamMatches() {
    final user = currentUser;
    if (user == null) return const Stream.empty();
    return _db
        .collection('matches')
        .where('users', arrayContains: user.uid)
        .snapshots();
  }

  /// Belirli bir match'teki direkt mesajları stream olarak döner.
  static Stream<QuerySnapshot> streamDirectMessages(String matchId) => _db
      .collection('chats')
      .doc(matchId)
      .collection('messages')
      .orderBy('createdAt')
      .snapshots();

  /// Direkt mesaj gönderir; match dokümanına lastMessage yazar ve alıcıya bildirim ekler.
  static Future<void> sendDirectMessage(String matchId, String text) async {
    final user = currentUser;
    if (user == null) throw Exception('Not signed in');

    final profile = await getProfile(user.uid);
    final senderName =
        profile?['full_name'] as String? ?? user.displayName ?? 'Unknown';

    await _db
        .collection('chats')
        .doc(matchId)
        .collection('messages')
        .add({
      'text': text,
      'senderId': user.uid,
      'senderName': senderName,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Match dokümanını lastMessage ile güncelle
    await _db.collection('matches').doc(matchId).update({
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': user.uid,
    });

    // Karşı taraf kullanıcıya bildirim yaz
    final matchDoc = await _db.collection('matches').doc(matchId).get();
    final users = List<String>.from(matchDoc.data()?['users'] ?? []);
    final recipientUid = users.firstWhere(
      (id) => id != user.uid,
      orElse: () => '',
    );
    if (recipientUid.isNotEmpty) {
      await _db
          .collection('notifications')
          .doc(recipientUid)
          .collection('items')
          .add({
        'type': 'new_message',
        'matchId': matchId,
        'fromName': senderName,
        'preview': text.length > 60 ? '${text.substring(0, 60)}…' : text,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
