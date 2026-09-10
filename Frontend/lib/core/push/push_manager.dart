import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Stato del supporto alle notifiche su questo dispositivo.
class PushEnvironment {
  /// Il browser espone service worker e Push API.
  final bool supported;

  /// iPhone/iPad: li' le notifiche web arrivano solo se l'app e' in schermata Home.
  final bool isIOS;

  /// L'app e' stata aperta dall'icona in Home (display-mode standalone).
  final bool isStandalone;

  /// 'granted' | 'denied' | 'default'
  final String permission;

  const PushEnvironment({
    required this.supported,
    required this.isIOS,
    required this.isStandalone,
    required this.permission,
  });

  bool get isGranted => permission == 'granted';
  bool get isDenied => permission == 'denied';

  /// Su iOS senza installazione in Home non ha senso nemmeno chiedere il permesso:
  /// Safari rifiuta la subscription.
  bool get needsHomeScreenInstall => isIOS && !isStandalone;

  bool get canSubscribe => supported && !needsHomeScreenInstall && !isDenied;
}

/// Dati della subscription da mandare al backend.
class PushSubscriptionData {
  final String endpoint;
  final String p256dh;
  final String auth;
  final String descrizione;

  const PushSubscriptionData({
    required this.endpoint,
    required this.p256dh,
    required this.auth,
    required this.descrizione,
  });
}

/// Errore "atteso" del flusso push, con un messaggio mostrabile all'utente.
class PushException implements Exception {
  final String message;
  const PushException(this.message);
  @override
  String toString() => message;
}

/// Ponte verso le API push del browser. Tutto quello che tocca JS sta qui.
class PushManager {
  static const _swScript = 'push-sw.js';

  /// Fotografia dello stato corrente, senza chiedere permessi.
  static PushEnvironment environment() {
    final supported = _hasProperty(web.window, 'PushManager') &&
        _hasProperty(web.window.navigator as JSObject, 'serviceWorker') &&
        _hasProperty(web.window, 'Notification');

    return PushEnvironment(
      supported: supported,
      isIOS: _isIOS(),
      isStandalone: _isStandalone(),
      permission: supported ? web.Notification.permission : 'default',
    );
  }

  /// Chiede il permesso e crea la subscription. Va chiamato da un gesto
  /// dell'utente: iOS e Safari rifiutano la richiesta se arriva da sola.
  static Future<PushSubscriptionData> subscribe(String vapidPublicKey) async {
    final env = environment();

    if (!env.supported) {
      throw const PushException(
          'Questo browser non supporta le notifiche web');
    }
    if (env.needsHomeScreenInstall) {
      throw const PushException(
          'Su iPhone aggiungi prima l\'app alla schermata Home, poi riapri da li');
    }

    final permission = (await web.Notification.requestPermission().toDart).toDart;
    if (permission != 'granted') {
      throw PushException(permission == 'denied'
          ? 'Notifiche bloccate: riattivale dalle impostazioni del browser'
          : 'Permesso per le notifiche non concesso');
    }

    final registration = await _registration();

    // Se esiste gia' una subscription la si riusa: crearne una nuova
    // invaliderebbe quella registrata sul server.
    var subscription = await registration.pushManager.getSubscription().toDart;

    subscription ??= await registration.pushManager
        .subscribe(web.PushSubscriptionOptionsInit(
          userVisibleOnly: true,
          // Safari vuole un BufferSource, non la stringa base64url
          applicationServerKey: _base64UrlDecode(vapidPublicKey).toJS,
        ))
        .toDart;

    return _toData(subscription);
  }

  /// Subscription gia' presente sul dispositivo, se c'e'. Serve a riallineare
  /// il server dopo una reinstallazione, senza richiedere permessi.
  static Future<PushSubscriptionData?> currentSubscription() async {
    final env = environment();
    if (!env.supported || !env.isGranted) return null;

    try {
      final registration = await _registration();
      final subscription = await registration.pushManager.getSubscription().toDart;
      return subscription == null ? null : _toData(subscription);
    } on PushException {
      return null;
    }
  }

  /// Disdice la subscription sul dispositivo. Ritorna l'endpoint che era attivo,
  /// cosi' il chiamante puo' cancellarlo anche sul server.
  static Future<String?> unsubscribe() async {
    final env = environment();
    if (!env.supported) return null;

    try {
      final registration = await _registration();
      final subscription = await registration.pushManager.getSubscription().toDart;
      if (subscription == null) return null;

      final endpoint = subscription.endpoint;
      await subscription.unsubscribe().toDart;
      return endpoint;
    } on PushException {
      return null;
    }
  }

  // ---------------------------------------------------------------- interni

  static Future<web.ServiceWorkerRegistration> _registration() async {
    final container = web.window.navigator.serviceWorker;

    // `ready` resta appeso all'infinito se nessun worker e' registrato: se
    // index.html non ha fatto in tempo, lo si registra qui.
    // Senza argomenti getRegistration cerca quella che copre la pagina corrente.
    final existing = await container.getRegistration().toDart;
    if (existing == null) {
      try {
        await container.register(_swScript.toJS).toDart;
      } catch (e) {
        throw PushException('Service worker non registrato: $e');
      }
    }

    return container.ready.toDart;
  }

  static PushSubscriptionData _toData(web.PushSubscription subscription) {
    final p256dh = subscription.getKey('p256dh');
    final auth = subscription.getKey('auth');

    if (p256dh == null || auth == null) {
      throw const PushException('Il browser non ha fornito le chiavi di cifratura');
    }

    return PushSubscriptionData(
      endpoint: subscription.endpoint,
      p256dh: _base64UrlEncode(p256dh.toDart.asUint8List()),
      auth: _base64UrlEncode(auth.toDart.asUint8List()),
      descrizione: _deviceLabel(),
    );
  }

  static bool _hasProperty(JSObject target, String name) {
    try {
      return target.has(name);
    } catch (_) {
      return false;
    }
  }

  static bool _isIOS() {
    final ua = web.window.navigator.userAgent;
    if (RegExp(r'iPhone|iPad|iPod').hasMatch(ua)) return true;
    // iPadOS si presenta come Macintosh: lo si riconosce dal touch
    return ua.contains('Macintosh') && web.window.navigator.maxTouchPoints > 1;
  }

  static bool _isStandalone() {
    try {
      if (web.window.matchMedia('(display-mode: standalone)').matches) return true;
    } catch (_) {
      // matchMedia puo' non esistere in contesti particolari
    }
    // Safari su iOS usa ancora navigator.standalone, non tipizzato in package:web
    try {
      final value = (web.window.navigator as JSObject).getProperty('standalone'.toJS);
      return value != null && (value as JSBoolean).toDart;
    } catch (_) {
      return false;
    }
  }

  static String _deviceLabel() {
    final ua = web.window.navigator.userAgent;
    final piattaforma = _isIOS()
        ? 'iPhone'
        : ua.contains('Android')
            ? 'Android'
            : ua.contains('Macintosh')
                ? 'Mac'
                : ua.contains('Windows')
                    ? 'Windows'
                    : 'Browser';
    final browser = ua.contains('CriOS') || ua.contains('Chrome')
        ? 'Chrome'
        : ua.contains('Firefox')
            ? 'Firefox'
            : ua.contains('Safari')
                ? 'Safari'
                : '';
    return browser.isEmpty ? piattaforma : '$piattaforma · $browser';
  }

  static Uint8List _base64UrlDecode(String input) {
    var normalized = input.replaceAll('-', '+').replaceAll('_', '/');
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }
    return base64Decode(normalized);
  }

  static String _base64UrlEncode(Uint8List bytes) => base64Encode(bytes)
      .replaceAll('+', '-')
      .replaceAll('/', '_')
      .replaceAll('=', '');
}
