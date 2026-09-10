import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../core/push/push_manager.dart';

class NotificationKindPref {
  final String valore;
  final String label;
  final String descrizione;
  final bool attiva;

  const NotificationKindPref({
    required this.valore,
    required this.label,
    required this.descrizione,
    required this.attiva,
  });

  factory NotificationKindPref.fromJson(Map<String, dynamic> json) => NotificationKindPref(
        valore: json['valore'] as String? ?? '',
        label: json['label'] as String? ?? '',
        descrizione: json['descrizione'] as String? ?? '',
        attiva: json['attiva'] as bool? ?? true,
      );
}

/// Stato delle notifiche push: quello che dice il server (chiave VAPID, preferenze)
/// piu' quello che dice il browser (permesso, subscription su questo dispositivo).
class NotificationsProvider extends ChangeNotifier {
  final ApiClient apiClient;

  NotificationsProvider({required this.apiClient});

  PushEnvironment _env = const PushEnvironment(
    supported: false,
    isIOS: false,
    isStandalone: false,
    permission: 'default',
  );

  bool _serverEnabled = false;
  String? _publicKey;
  List<NotificationKindPref> _tipi = const [];
  int _dispositiviRegistrati = 0;
  String? _endpointLocale;
  bool _isLoading = false;
  bool _isBusy = false;
  String? _error;

  PushEnvironment get environment => _env;
  bool get serverEnabled => _serverEnabled;
  List<NotificationKindPref> get tipi => _tipi;
  int get dispositiviRegistrati => _dispositiviRegistrati;
  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;
  String? get error => _error;

  /// Le notifiche sono attive proprio su questo telefono/browser.
  bool get attiveQui => _endpointLocale != null && _env.isGranted;

  /// Si puo' proporre l'attivazione: server configurato, browser compatibile,
  /// e su iOS l'app deve essere gia' in schermata Home.
  bool get puoAttivare => _serverEnabled && _env.canSubscribe;

  void reset() {
    _tipi = const [];
    _dispositiviRegistrati = 0;
    _endpointLocale = null;
    _error = null;
    notifyListeners();
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _env = PushManager.environment();

    try {
      final response = await apiClient.dio.get(ApiConstants.notificationsConfig);
      if (response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        _serverEnabled = data['enabled'] as bool? ?? false;
        _publicKey = data['publicKey'] as String?;
        _dispositiviRegistrati = (data['dispositiviRegistrati'] as num?)?.toInt() ?? 0;
        _tipi = ((data['tipi'] as List?) ?? const [])
            .map((e) => NotificationKindPref.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } on DioException catch (e) {
      _error = _messageOf(e);
    } catch (e) {
      _error = 'Errore imprevisto: $e';
    }

    // La subscription puo' esistere gia' (permesso dato in una sessione precedente)
    final locale = await PushManager.currentSubscription();
    _endpointLocale = locale?.endpoint;

    // Reinstallando la PWA il browser genera un endpoint nuovo: lo si riallinea
    // in silenzio, altrimenti il server continuerebbe a scrivere a un indirizzo morto.
    if (locale != null && _serverEnabled) {
      await _registraSulServer(locale, silenzioso: true);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Chiede il permesso e registra il dispositivo. Da chiamare da un tap.
  Future<bool> enable() async {
    if (_publicKey == null || _publicKey!.isEmpty) {
      _error = 'Il server non ha le chiavi per le notifiche';
      notifyListeners();
      return false;
    }

    _isBusy = true;
    _error = null;
    notifyListeners();

    try {
      final subscription = await PushManager.subscribe(_publicKey!);
      final ok = await _registraSulServer(subscription, silenzioso: false);
      if (ok) {
        _endpointLocale = subscription.endpoint;
        _dispositiviRegistrati = _dispositiviRegistrati + 1;
      }
      _env = PushManager.environment();
      return ok;
    } on PushException catch (e) {
      _error = e.message;
      _env = PushManager.environment();
      return false;
    } catch (e) {
      _error = 'Errore nell attivazione: $e';
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> disable() async {
    _isBusy = true;
    _error = null;
    notifyListeners();

    try {
      final endpoint = await PushManager.unsubscribe() ?? _endpointLocale;
      if (endpoint != null) {
        await apiClient.dio.post(
          ApiConstants.notificationsUnsubscribe,
          data: {'endpoint': endpoint},
        );
      }
      _endpointLocale = null;
      if (_dispositiviRegistrati > 0) _dispositiviRegistrati--;
      return true;
    } on DioException catch (e) {
      _error = _messageOf(e);
      return false;
    } catch (e) {
      _error = 'Errore nella disattivazione: $e';
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> setPreference(String kind, bool enabled) async {
    _error = null;
    try {
      final response = await apiClient.dio.put(
        ApiConstants.notificationsPreferences,
        data: {'kind': kind, 'enabled': enabled},
      );
      if (response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        _tipi = ((data['tipi'] as List?) ?? const [])
            .map((e) => NotificationKindPref.fromJson(e as Map<String, dynamic>))
            .toList();
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      _error = _messageOf(e);
    } catch (e) {
      _error = 'Errore imprevisto: $e';
    }
    notifyListeners();
    return false;
  }

  Future<String?> sendTest() async {
    try {
      final response = await apiClient.dio.post(ApiConstants.notificationsTest);
      return response.data['message'] as String? ?? 'Notifica di prova inviata';
    } on DioException catch (e) {
      _error = _messageOf(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> _registraSulServer(PushSubscriptionData data, {required bool silenzioso}) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.notificationsSubscribe,
        data: {
          'endpoint': data.endpoint,
          'p256dh': data.p256dh,
          'auth': data.auth,
          'descrizione': data.descrizione,
        },
      );
      return response.data['success'] == true;
    } on DioException catch (e) {
      if (!silenzioso) _error = _messageOf(e);
      return false;
    } catch (e) {
      if (!silenzioso) _error = 'Errore imprevisto: $e';
      return false;
    }
  }

  String _messageOf(DioException e) =>
      e.response?.data is Map && (e.response!.data as Map)['message'] != null
          ? (e.response!.data as Map)['message'] as String
          : 'Errore di connessione';
}
