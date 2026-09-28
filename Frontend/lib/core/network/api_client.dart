import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

class ApiClient {
  late final Dio dio;
  final SecureStorageService storage;
  Future<bool>? _refreshing;

  /// Invocato quando la sessione è realmente scaduta (refresh fallito):
  /// l'app deve fare logout e tornare al login. Impostato da main.dart.
  Future<void> Function()? onSessionExpired;

  /// Invocato per gli errori che non sono "colpa" della richiesta: rete
  /// assente, timeout, 5xx. I provider spesso ingoiano l'errore e mostrano
  /// una lista vuota: almeno un avviso globale l'utente lo deve vedere.
  void Function(String message)? onNetworkError;

  static String describeNetworkError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Il server non risponde: controlla la connessione e riprova';
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return 'Sei senza rete o il server non è raggiungibile';
      default:
        return 'Il server ha avuto un problema: riprova tra poco';
    }
  }

  static bool _isAuthEndpoint(String path) =>
      path.contains('/auth/login') ||
      path.contains('/auth/signup') ||
      path.contains('/auth/refresh');

  ApiClient({required this.storage}) {
    dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        // Non gestire i 401 degli endpoint di auth (credenziali errate, non sessione scaduta)
        if (error.response?.statusCode == 401 &&
            !_isAuthEndpoint(error.requestOptions.path)) {
          final refreshed = await _tryRefreshToken();
          if (refreshed) {
            final token = await storage.getAccessToken();
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            final response = await dio.fetch(error.requestOptions);
            return handler.resolve(response);
          }
          // Refresh fallito → sessione scaduta: logout + redirect al login
          await onSessionExpired?.call();
        }
        // 403: il ruolo sta nel token, e un token emesso prima di una promozione
        // (es. a admin) dice ancora quello vecchio, mentre l'app mostra gia' i
        // tasti nuovi. Un token rinnovato porta il ruolo attuale: si riprova una
        // volta sola. Se resta 403 il permesso manca davvero.
        if (error.response?.statusCode == 403 &&
            !_isAuthEndpoint(error.requestOptions.path) &&
            error.requestOptions.extra['retry403'] != true) {
          if (await _tryRefreshToken()) {
            final token = await storage.getAccessToken();
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            error.requestOptions.extra['retry403'] = true;
            try {
              return handler.resolve(await dio.fetch(error.requestOptions));
            } on DioException catch (e) {
              return handler.next(e);
            }
          }
        }
        final status = error.response?.statusCode;
        if (status == null || status >= 500) {
          onNetworkError?.call(describeNetworkError(error));
        }
        handler.next(error);
      },
    ));
  }

  Future<bool> _tryRefreshToken() {
    // Single-flight: se un refresh è già in corso, attende quello invece di
    // avviarne un secondo (che fallirebbe perché il refresh token viene ruotato).
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    try {
      final refreshToken = await storage.getRefreshToken();
      if (refreshToken == null) return false;

      final teamId = await storage.getTeamId();
      final Map<String, dynamic> refreshData = {'refreshToken': refreshToken};
      if (teamId != null) {
        refreshData['teamId'] = teamId;
      }

      final response = await Dio(BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        headers: {'Content-Type': 'application/json'},
      )).post(ApiConstants.refreshToken, data: refreshData);

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        await storage.saveAccessToken(data['accessToken']);
        await storage.saveRefreshToken(data['refreshToken']);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
