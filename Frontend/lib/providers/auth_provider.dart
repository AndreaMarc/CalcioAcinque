import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../core/storage/secure_storage.dart';
import '../core/constants/api_constants.dart';
import '../models/player_info.dart';
import '../models/team_format.dart';
import '../models/team_membership_info.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient apiClient;
  final SecureStorageService storage;

  PlayerInfo? _currentPlayer;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _error;
  List<TeamMembershipInfo>? _teams;
  bool _needsTeamSelection = false;

  PlayerInfo? get currentPlayer => _currentPlayer;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  bool get isAdmin => _currentPlayer?.isAdmin ?? false;
  bool get isMister => _currentPlayer?.isMister ?? false;
  bool get isCassiere => _currentPlayer?.isCassiere ?? false;

  // Nei gate della UI si usano questi e non isAdmin: dicono cosa puoi fare,
  // non chi sei, e il backend applica le stesse politiche (vedi Ruoli.cs).
  bool get puoGestireSquadra => _currentPlayer?.puoGestireSquadra ?? false;
  bool get puoGestireCampo => _currentPlayer?.puoGestireCampo ?? false;
  bool get puoGestireSoldi => _currentPlayer?.puoGestireSoldi ?? false;
  bool get puoGestireGettoni => _currentPlayer?.puoGestireGettoni ?? false;
  int get playerId => _currentPlayer?.id ?? 0;
  int get teamId => _currentPlayer?.teamId ?? 0;
  String? get error => _error;
  List<TeamMembershipInfo>? get teams => _teams;
  bool get needsTeamSelection => _needsTeamSelection;

  /// Membership del team attivo: da qui la UI legge formato e societa'.
  TeamMembershipInfo? get currentMembership {
    final id = teamId;
    if (id == 0) return null;
    for (final t in _teams ?? const <TeamMembershipInfo>[]) {
      if (t.teamId == id) return t;
    }
    return null;
  }

  int? get currentClubId => currentMembership?.clubId;

  AuthProvider({required this.apiClient, required this.storage});

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await apiClient.dio.post(ApiConstants.login, data: {
        'email': email,
        'password': password,
      });

      if (response.data['success'] == true) {
        final data = response.data['data'];
        await storage.saveAccessToken(data['accessToken']);
        await storage.saveRefreshToken(data['refreshToken']);

        if (data['player'] != null) {
          // Single team - backward compatible
          _currentPlayer = PlayerInfo.fromJson(data['player']);
          await storage.savePlayerData(
            playerId: _currentPlayer!.id,
            userId: _currentPlayer!.userId,
            teamId: _currentPlayer!.teamId,
            nome: _currentPlayer!.nome,
            ruolo: _currentPlayer!.ruolo,
          );
          await storage.saveLastTeamId(_currentPlayer!.teamId);
          _isAuthenticated = true;
          _needsTeamSelection = false;
        } else if (data['teams'] != null) {
          // Multiple teams - need selection
          _teams = (data['teams'] as List)
              .map((e) => TeamMembershipInfo.fromJson(e))
              .toList();
          _isAuthenticated = true;
          _needsTeamSelection = true;
        }

        _isLoading = false;
        notifyListeners();
        return true;
      }
      _error = response.data['message'] ?? 'Errore di login';
    } on DioException catch (e) {
      _error = e.response?.data?['message'] ?? 'Errore di connessione';
    } catch (e) {
      _error = 'Errore imprevisto: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> selectTeam(int teamId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await apiClient.dio.post(
        ApiConstants.selectTeam,
        data: {'teamId': teamId},
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        await storage.saveAccessToken(data['accessToken']);
        await storage.saveRefreshToken(data['refreshToken']);
        _currentPlayer = PlayerInfo.fromJson(data['player']);
        await storage.savePlayerData(
          playerId: _currentPlayer!.id,
          userId: _currentPlayer!.userId,
          teamId: _currentPlayer!.teamId,
          nome: _currentPlayer!.nome,
          ruolo: _currentPlayer!.ruolo,
        );
        await storage.saveLastTeamId(_currentPlayer!.teamId);
        _needsTeamSelection = false;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _error = response.data['message'] ?? 'Errore nella selezione del team';
    } on DioException catch (e) {
      _error = e.response?.data?['message'] ?? 'Errore di connessione';
    } catch (e) {
      _error = 'Errore imprevisto: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> switchTeam(int teamId) async {
    final success = await selectTeam(teamId);
    return success;
  }

  Future<void> loadMyTeams() async {
    try {
      final response = await apiClient.dio.get(ApiConstants.myTeams);
      if (response.data['success'] == true) {
        _teams = (response.data['data'] as List)
            .map((e) => TeamMembershipInfo.fromJson(e))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> createTeam({
    required String nomeTeam,
    required String nomeGiocatore,
    String? soprannome,
    TeamFormat formato = TeamFormat.calcioA5,
    int? clubId,
    String? nomeSocieta,
    int partitePerStagione = 8,
    int gettoniPerGiocatore = 4,
    bool useGettoni = true,
    double quotaIscrizione = 0,
    double quotaTesseramento = 0,
    double costoPartita = 0,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await apiClient.dio.post(
        ApiConstants.createTeam,
        data: {
          'nomeTeam': nomeTeam,
          'nomeGiocatore': nomeGiocatore,
          if (soprannome != null && soprannome.isNotEmpty) 'soprannome': soprannome,
          'formato': formato.apiValue,
          if (clubId != null) 'clubId': clubId,
          if (nomeSocieta != null && nomeSocieta.isNotEmpty) 'nomeSocieta': nomeSocieta,
          'partitePerStagione': partitePerStagione,
          'gettoniPerGiocatore': gettoniPerGiocatore,
          'useGettoni': useGettoni,
          'quotaIscrizione': quotaIscrizione,
          'quotaTesseramento': quotaTesseramento,
          'costoPartita': costoPartita,
        },
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        await storage.saveAccessToken(data['accessToken']);
        await storage.saveRefreshToken(data['refreshToken']);
        _currentPlayer = PlayerInfo.fromJson(data['player']);
        await storage.savePlayerData(
          playerId: _currentPlayer!.id,
          userId: _currentPlayer!.userId,
          teamId: _currentPlayer!.teamId,
          nome: _currentPlayer!.nome,
          ruolo: _currentPlayer!.ruolo,
        );
        await storage.saveLastTeamId(_currentPlayer!.teamId);
        _needsTeamSelection = false;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _error = response.data['message'] ?? 'Errore nella creazione del team';
    } on DioException catch (e) {
      _error = e.response?.data?['message'] ?? 'Errore di connessione';
    } catch (e) {
      _error = 'Errore imprevisto: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> launchTeamFromDraft({
    required int draftId,
    String? nomeGiocatore,
    String? soprannome,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await apiClient.dio.post(
        ApiConstants.draftLaunch(draftId),
        data: {
          if (nomeGiocatore != null && nomeGiocatore.isNotEmpty) 'nomeGiocatore': nomeGiocatore,
          if (soprannome != null && soprannome.isNotEmpty) 'soprannome': soprannome,
        },
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        await storage.saveAccessToken(data['accessToken']);
        await storage.saveRefreshToken(data['refreshToken']);
        _currentPlayer = PlayerInfo.fromJson(data['player']);
        await storage.savePlayerData(
          playerId: _currentPlayer!.id,
          userId: _currentPlayer!.userId,
          teamId: _currentPlayer!.teamId,
          nome: _currentPlayer!.nome,
          ruolo: _currentPlayer!.ruolo,
        );
        await storage.saveLastTeamId(_currentPlayer!.teamId);
        _needsTeamSelection = false;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _error = response.data['message'] ?? 'Errore nel lancio della squadra';
    } on DioException catch (e) {
      _error = e.response?.data?['message'] ?? 'Errore di connessione';
    } catch (e) {
      _error = 'Errore imprevisto: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<Map<String, dynamic>?> getJoinInfo(String code) async {
    try {
      final response = await apiClient.dio.get(ApiConstants.joinInfo(code));
      if (response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> joinTeam({
    required String inviteCode,
    required String nome,
    String? soprannome,
    String? telefono,
    int? pendingPlayerId,
    int? teamId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await apiClient.dio.post(
        ApiConstants.joinTeam,
        data: {
          'inviteCode': inviteCode,
          'nome': nome,
          if (soprannome != null && soprannome.isNotEmpty) 'soprannome': soprannome,
          if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
          if (pendingPlayerId != null) 'pendingPlayerId': pendingPlayerId,
          // Serve solo con un codice societa' che ha piu' di una squadra
          if (teamId != null) 'teamId': teamId,
        },
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        await storage.saveAccessToken(data['accessToken']);
        await storage.saveRefreshToken(data['refreshToken']);
        _currentPlayer = PlayerInfo.fromJson(data['player']);
        await storage.savePlayerData(
          playerId: _currentPlayer!.id,
          userId: _currentPlayer!.userId,
          teamId: _currentPlayer!.teamId,
          nome: _currentPlayer!.nome,
          ruolo: _currentPlayer!.ruolo,
        );
        await storage.saveLastTeamId(_currentPlayer!.teamId);
        _needsTeamSelection = false;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _error = response.data['message'] ?? 'Errore nell\'unirsi al team';
    } on DioException catch (e) {
      _error = e.response?.data?['message'] ?? 'Errore di connessione';
    } catch (e) {
      _error = 'Errore imprevisto: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<String?> getInviteCode() async {
    try {
      final response = await apiClient.dio.get(ApiConstants.inviteCode);
      if (response.data['success'] == true) {
        return response.data['data']['inviteCode'] as String?;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> tryAutoLogin() async {
    final token = await storage.getAccessToken();
    if (token == null) return false;

    try {
      final response = await apiClient.dio.get(ApiConstants.me);
      if (response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        final playerJson = data['player'];
        final teamsJson = data['teams'] as List?;

        _teams = teamsJson != null
            ? teamsJson.map((e) => TeamMembershipInfo.fromJson(e)).toList()
            : null;
        _isAuthenticated = true;

        if (playerJson != null && (teamsJson == null || teamsJson.length <= 1)) {
          // Singolo team o nessun team alternativo → entra direttamente
          _currentPlayer = PlayerInfo.fromJson(playerJson);
          _needsTeamSelection = false;
        } else {
          // Nessun team OR multipli team → manda a /select-team
          _currentPlayer = null;
          _needsTeamSelection = true;
        }
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> signup(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await apiClient.dio.post(ApiConstants.signup, data: {
        'email': email,
        'password': password,
      });

      if (response.data['success'] == true) {
        final data = response.data['data'];
        await storage.saveAccessToken(data['accessToken']);
        await storage.saveRefreshToken(data['refreshToken']);
        _currentPlayer = null;
        _teams = [];
        _isAuthenticated = true;
        _needsTeamSelection = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _error = response.data['message'] ?? 'Errore nella registrazione';
    } on DioException catch (e) {
      _error = e.response?.data?['message'] ?? 'Errore di connessione';
    } catch (e) {
      _error = 'Errore imprevisto: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> updateMyProfile({String? nome, String? soprannome, String? telefono}) async {
    if (_currentPlayer == null) return false;
    try {
      final response = await apiClient.dio.put(
        ApiConstants.myProfile(_currentPlayer!.teamId),
        data: {
          if (nome != null) 'nome': nome,
          if (soprannome != null) 'soprannome': soprannome,
          if (telefono != null) 'telefono': telefono,
        },
      );
      if (response.data['success'] == true) {
        _currentPlayer = _currentPlayer!.copyWith(
          nome: nome,
          soprannome: soprannome,
          telefono: telefono,
        );
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> logout() async {
    await storage.clearAll();
    _currentPlayer = null;
    _isAuthenticated = false;
    _needsTeamSelection = false;
    _teams = null;
    _error = null;
    notifyListeners();
  }
}
