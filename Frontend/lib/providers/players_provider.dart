import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../core/constants/api_constants.dart';
import '../models/player_model.dart';

class PlayersProvider extends ChangeNotifier {
  final ApiClient apiClient;
  List<PlayerModel> _players = [];
  bool _isLoading = false;
  bool _hasLoaded = false;

  List<PlayerModel> get players => _players;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;

  PlayersProvider({required this.apiClient});

  void reset() {
    _players = [];
    _hasLoaded = false;
    notifyListeners();
  }

  Future<void> loadPlayers(int teamId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await apiClient.dio.get(ApiConstants.players(teamId));
      if (response.data['success'] == true) {
        _players = (response.data['data'] as List)
            .map((e) => PlayerModel.fromJson(e)).toList();
      }
    } catch (_) {}
    _isLoading = false;
    _hasLoaded = true;
    notifyListeners();
  }

  Future<bool> createPlayer(int teamId, Map<String, dynamic> data) async {
    try {
      final response = await apiClient.dio.post(ApiConstants.players(teamId), data: data);
      if (response.data['success'] == true) {
        await loadPlayers(teamId);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> updatePlayer(int teamId, int playerId, Map<String, dynamic> data) async {
    try {
      final response = await apiClient.dio.put(
        ApiConstants.player(teamId, playerId),
        data: data,
      );
      if (response.data['success'] == true) {
        await loadPlayers(teamId);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> deletePlayer(int teamId, int playerId) async {
    try {
      final response = await apiClient.dio.delete(
        ApiConstants.player(teamId, playerId),
      );
      if (response.data['success'] == true) {
        await loadPlayers(teamId);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> resetPassword(int teamId, int playerId, String newPassword) async {
    try {
      final response = await apiClient.dio.put(
        ApiConstants.playerResetPassword(teamId, playerId),
        data: {'newPassword': newPassword},
      );
      if (response.data['success'] == true) {
        return true;
      }
    } catch (_) {}
    return false;
  }
}
