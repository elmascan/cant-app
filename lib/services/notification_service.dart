import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _db = FirebaseFirestore.instance;

  static Future<void> initialize() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await saveFcmToken();
    _messaging.onTokenRefresh.listen((_) => saveFcmToken());
  }

  static Future<void> saveFcmToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final token = await _messaging.getToken();
    if (token == null) return;
    await _db.collection('profiles').doc(user.uid).set(
      {'fcmToken': token},
      SetOptions(merge: true),
    );
  }

  /// Kullanıcıya ait okunmamış bildirim stream'i
  /// orderBy kaldırıldı — composite index gerektiriyordu.
  /// Sıralama gerekirse çağıran taraf docs üzerinde client-side sort uygular.
  static Stream<QuerySnapshot> unreadStream(String userId) {
    return _db
        .collection('notifications')
        .doc(userId)
        .collection('items')
        .where('read', isEqualTo: false)
        .snapshots();
  }

  static Future<void> markRead(String userId, String notifId) async {
    await _db
        .collection('notifications')
        .doc(userId)
        .collection('items')
        .doc(notifId)
        .update({'read': true});
  }
}
