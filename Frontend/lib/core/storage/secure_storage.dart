import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<void> saveAccessToken(String token) async {
    final prefs = await _prefs;
    await prefs.setString('access_token', token);
  }

  Future<String?> getAccessToken() async {
    final prefs = await _prefs;
    return prefs.getString('access_token');
  }

  Future<void> saveRefreshToken(String token) async {
    final prefs = await _prefs;
    await prefs.setString('refresh_token', token);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await _prefs;
    return prefs.getString('refresh_token');
  }

  Future<void> savePlayerData({
    required int playerId,
    required int userId,
    required int teamId,
    required String nome,
    required String ruolo,
  }) async {
    final prefs = await _prefs;
    await prefs.setInt('player_id', playerId);
    await prefs.setInt('user_id', userId);
    await prefs.setInt('team_id', teamId);
    await prefs.setString('player_nome', nome);
    await prefs.setString('player_ruolo', ruolo);
  }

  Future<int?> getPlayerId() async {
    final prefs = await _prefs;
    return prefs.getInt('player_id');
  }

  Future<int?> getTeamId() async {
    final prefs = await _prefs;
    return prefs.getInt('team_id');
  }

  Future<String?> getRuolo() async {
    final prefs = await _prefs;
    return prefs.getString('player_ruolo');
  }

  Future<void> saveLastTeamId(int teamId) async {
    final prefs = await _prefs;
    await prefs.setInt('last_team_id', teamId);
  }

  Future<int?> getLastTeamId() async {
    final prefs = await _prefs;
    return prefs.getInt('last_team_id');
  }

  Future<void> clearAll() async {
    final prefs = await _prefs;
    await prefs.clear();
  }
}
