import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../core/constants/api_constants.dart';
import '../models/convocation_model.dart';

class ConvocationsProvider extends ChangeNotifier {
  final ApiClient apiClient;
  List<ConvocationModel> _convocations = [];
  List<ConvocationModel> _pending = [];
  bool _isLoading = false;
  bool _hasLoaded = false;

  List<ConvocationModel> get convocations => _convocations;
  List<ConvocationModel> get pending => _pending;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;

  ConvocationsProvider({required this.apiClient});

  Future<void> loadByMatch(int matchId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await apiClient.dio.get(ApiConstants.matchConvocations(matchId));
      if (response.data['success'] == true) {
        _convocations = (response.data['data'] as List)
            .map((e) => ConvocationModel.fromJson(e)).toList();
      }
    } catch (_) {}
    _isLoading = false;
    _hasLoaded = true;
    notifyListeners();
  }

  Future<void> loadPending(int playerId) async {
    try {
      final response = await apiClient.dio.get(ApiConstants.pendingConvocations(playerId));
      if (response.data['success'] == true) {
        _pending = (response.data['data'] as List)
            .map((e) => ConvocationModel.fromJson(e)).toList();
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<bool> sendConvocations(int matchId, List<int> playerIds) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.matchConvocations(matchId),
        data: {'playerIds': playerIds},
      );
      if (response.data['success'] == true) {
        await loadByMatch(matchId);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> respond(int convocationId, String risposta) async {
    try {
      final response = await apiClient.dio.put(
        ApiConstants.respondConvocation(convocationId),
        data: {'risposta': risposta},
      );
      return response.data['success'] == true;
    } catch (_) {}
    return false;
  }
}
