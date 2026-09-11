import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../core/constants/api_constants.dart';
import '../models/match_model.dart';

class MatchesProvider extends ChangeNotifier {
  final ApiClient apiClient;
  List<MatchModel> _matches = [];
  bool _isLoading = false;
  bool _hasLoaded = false;

  /// Stagione visualizzata. null = quella aperta, la scelta la fa il server.
  /// Resta appiccicata: si sfoglia un archivio senza che aprire il dettaglio
  /// di una partita riporti al presente.
  int? _seasonId;

  List<MatchModel> get matches => _matches;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  int? get seasonId => _seasonId;

  MatchesProvider({required this.apiClient});

  void reset() {
    _matches = [];
    _hasLoaded = false;
    _seasonId = null;
    notifyListeners();
  }

  /// Cambia stagione e ricarica. null torna a quella in corso.
  Future<void> selectSeason(int teamId, int? seasonId) async {
    _seasonId = seasonId;
    await loadMatches(teamId);
  }

  Future<void> loadMatches(int teamId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await apiClient.dio.get(
        ApiConstants.matches(teamId),
        queryParameters: {if (_seasonId != null) 'seasonId': _seasonId},
      );
      if (response.data['success'] == true) {
        _matches = (response.data['data'] as List)
            .map((e) => MatchModel.fromJson(e)).toList();
      }
    } catch (_) {}
    _isLoading = false;
    _hasLoaded = true;
    notifyListeners();
  }

  /// Una partita per id, anche se non e' nella lista caricata (altra stagione,
  /// deep link da notifica prima del caricamento): la aggiunge alla lista.
  Future<MatchModel?> fetchMatch(int teamId, int matchId) async {
    try {
      final response = await apiClient.dio.get(ApiConstants.match(teamId, matchId));
      if (response.data['success'] == true) {
        final match = MatchModel.fromJson(response.data['data'] as Map<String, dynamic>);
        final i = _matches.indexWhere((m) => m.id == match.id);
        if (i >= 0) {
          _matches[i] = match;
        } else {
          _matches.add(match);
        }
        notifyListeners();
        return match;
      }
    } catch (_) {}
    return null;
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
