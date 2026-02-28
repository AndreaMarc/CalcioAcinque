import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../core/constants/api_constants.dart';
import '../models/token_transaction_model.dart';

class TokensProvider extends ChangeNotifier {
  final ApiClient apiClient;
  List<TokenTransactionModel> _transactions = [];
  bool _isLoading = false;

  List<TokenTransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;

  TokensProvider({required this.apiClient});

  Future<void> loadPlayerTokens(int playerId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await apiClient.dio.get(ApiConstants.playerTokens(playerId));
      if (response.data['success'] == true) {
        _transactions = (response.data['data'] as List)
            .map((e) => TokenTransactionModel.fromJson(e)).toList();
      }
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> manualAdjust(int playerId, int quantita, String motivazione) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.playerTokens(playerId),
        data: {'quantita': quantita, 'motivazione': motivazione},
      );
      if (response.data['success'] == true) {
        await loadPlayerTokens(playerId);
        return true;
      }
    } catch (_) {}
    return false;
  }
}
