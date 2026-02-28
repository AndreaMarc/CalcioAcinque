import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../core/storage/secure_storage.dart';
import '../core/constants/api_constants.dart';
import '../models/player_info.dart';
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
  int get playerId => _currentPlayer?.id ?? 0;
  int get teamId => _currentPlayer?.teamId ?? 0;
  String? get error => _error;
  List<TeamMembershipInfo>? get teams => _teams;
  bool get needsTeamSelection => _needsTeamSelection;

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
    int partitePerStagione = 8,
    int gettoniPerGiocatore = 4,
    bool useGettoni = true,
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
          'partitePerStagione': partitePerStagione,
          'gettoniPerGiocatore': gettoniPerGiocatore,
          'useGettoni': useGettoni,
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

  Future<bool> joinTeam({
    required String inviteCode,
    required String nome,
    String? soprannome,
    String? telefono,
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
        final data = response.data['data'];
        if (data is Map<String, dynamic> && data.containsKey('teams') && data['teams'] != null) {
          // User has multiple teams but no team selected yet
          _teams = (data['teams'] as List)
              .map((e) => TeamMembershipInfo.fromJson(e))
              .toList();
          _isAuthenticated = true;
          _needsTeamSelection = true;
          notifyListeners();
          return true;
        }
        _currentPlayer = PlayerInfo.fromJson(data);
        _isAuthenticated = true;
        _needsTeamSelection = false;
        notifyListeners();
        return true;
      }
    } catch (_) {}
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
