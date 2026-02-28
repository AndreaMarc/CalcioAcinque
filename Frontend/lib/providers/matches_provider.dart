import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../core/constants/api_constants.dart';
import '../models/match_model.dart';

class MatchesProvider extends ChangeNotifier {
  final ApiClient apiClient;
  List<MatchModel> _matches = [];
  bool _isLoading = false;
  bool _hasLoaded = false;

  List<MatchModel> get matches => _matches;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;

  MatchesProvider({required this.apiClient});

  void reset() {
    _matches = [];
    _hasLoaded = false;
    notifyListeners();
  }

  Future<void> loadMatches(int teamId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await apiClient.dio.get(ApiConstants.matches(teamId));
      if (response.data['success'] == true) {
        _matches = (response.data['data'] as List)
            .map((e) => MatchModel.fromJson(e)).toList();
      }
    } catch (_) {}
    _isLoading = false;
    _hasLoaded = true;
    notifyListeners();
  }

  Future<bool> createMatch(int teamId, Map<String, dynamic> data) async {
    try {
      final response = await apiClient.dio.post(ApiConstants.matches(teamId), data: data);
      if (response.data['success'] == true) {
        await loadMatches(teamId);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> updateMatch(int teamId, int matchId, Map<String, dynamic> data) async {
    try {
      final response = await apiClient.dio.put(
        ApiConstants.match(teamId, matchId), data: data);
      if (response.data['success'] == true) {
        await loadMatches(teamId);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> deleteMatch(int teamId, int matchId) async {
    try {
      final response = await apiClient.dio.delete(
        ApiConstants.match(teamId, matchId));
      if (response.data['success'] == true) {
        await loadMatches(teamId);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> updateStato(int teamId, int matchId, String stato) async {
    try {
      final response = await apiClient.dio.put(
        ApiConstants.matchStato(teamId, matchId), data: {'stato': stato});
      if (response.data['success'] == true) {
        await loadMatches(teamId);
        return true;
      }
    } catch (_) {}
    return false;
  }
}
