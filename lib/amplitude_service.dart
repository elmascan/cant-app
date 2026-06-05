import 'package:amplitude_flutter/amplitude.dart';
import 'package:amplitude_flutter/configuration.dart';
import 'package:amplitude_flutter/events/base_event.dart';

class AmplitudeService {
  static final AmplitudeService _instance = AmplitudeService._internal();
  factory AmplitudeService() => _instance;
  AmplitudeService._internal();

  late Amplitude _amplitude;

  Future<void> init() async {
    _amplitude = Amplitude(Configuration(
      apiKey: '9de24929e124481058fdaca16fe3240',
    ));
    await _amplitude.isBuilt;
  }

  // Ekran görüntüleme
  Future<void> logScreenView(String screenName) async {
    await _amplitude.track(BaseEvent(
      'Screen Viewed',
      eventProperties: {'screen_name': screenName},
    ));
  }

  // Kayıt olayı
  Future<void> logSignUp(String method) async {
    await _amplitude.track(BaseEvent(
      'Sign Up',
      eventProperties: {'method': method},
    ));
  }

  // Giriş olayı
  Future<void> logLogin(String method) async {
    await _amplitude.track(BaseEvent(
      'Login',
      eventProperties: {'method': method},
    ));
  }

  // Genel event
  Future<void> logEvent(String eventName, [Map<String, dynamic>? properties]) async {
    await _amplitude.track(BaseEvent(
      eventName,
      eventProperties: properties,
    ));
  }

  // Kullanıcı tanımlama (retention için)
  Future<void> setUserId(String userId) async {
    await _amplitude.setUserId(userId);
  }

  // Çıkış olayı
  Future<void> logLogout() async {
    await _amplitude.track(BaseEvent('Logout'));
    await _amplitude.setUserId(null);
  }
}
