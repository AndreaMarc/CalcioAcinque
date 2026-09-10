import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../core/constants/api_constants.dart';
import '../models/dashboard_model.dart';

class DashboardProvider extends ChangeNotifier {
  final ApiClient apiClient;
  DashboardModel? _dashboard;
  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _hasError = false;

  DashboardModel? get dashboard => _dashboard;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  bool get hasError => _hasError;
  bool get useGettoni => _dashboard?.useGettoni ?? true;

  DashboardProvider({required this.apiClient});

  void reset() {
    _dashboard = null;
    _hasLoaded = false;
    _hasError = false;
    notifyListeners();
  }

  Future<void> loadDashboard(int teamId) async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();
    try {
      final response = await apiClient.dio.get(ApiConstants.dashboard(teamId));
      if (response.data['success'] == true) {
        _dashboard = DashboardModel.fromJson(response.data['data']);
      } else {
        _hasError = true;
      }
    } catch (_) {
      _hasError = true;
    }
    _isLoading = false;
    _hasLoaded = true;
    notifyListeners();
  }
}
