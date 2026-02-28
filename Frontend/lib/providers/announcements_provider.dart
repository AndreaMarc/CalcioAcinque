import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../core/constants/api_constants.dart';
import '../models/announcement_model.dart';

class AnnouncementsProvider extends ChangeNotifier {
  final ApiClient apiClient;
  List<AnnouncementModel> _announcements = [];
  bool _isLoading = false;
  bool _hasLoaded = false;

  List<AnnouncementModel> get announcements => _announcements;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;

  int get unreadCount => _announcements.where((a) => !a.hoPresaVisione).length;

  AnnouncementsProvider({required this.apiClient});

  void reset() {
    _announcements = [];
    _hasLoaded = false;
    notifyListeners();
  }

  Future<void> loadAnnouncements(int teamId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await apiClient.dio.get(ApiConstants.announcements(teamId));
      if (response.data['success'] == true) {
        _announcements = (response.data['data'] as List)
            .map((e) => AnnouncementModel.fromJson(e))
            .toList();
      }
    } catch (_) {}
    _isLoading = false;
    _hasLoaded = true;
    notifyListeners();
  }

  Future<AnnouncementModel?> getDetail(int teamId, int announcementId) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.announcement(teamId, announcementId),
      );
      if (response.data['success'] == true) {
        return AnnouncementModel.fromJson(response.data['data']);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> create(int teamId, {
    required String titolo,
    required String contenuto,
    bool importante = false,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.announcements(teamId),
        data: {
          'titolo': titolo,
          'contenuto': contenuto,
          'importante': importante,
        },
      );
      if (response.data['success'] == true) {
        await loadAnnouncements(teamId);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> delete(int teamId, int announcementId) async {
    try {
      final response = await apiClient.dio.delete(
        ApiConstants.announcement(teamId, announcementId),
      );
      if (response.data['success'] == true) {
        await loadAnnouncements(teamId);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> acknowledge(int teamId, int announcementId) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.announcementAcknowledge(teamId, announcementId),
      );
      if (response.data['success'] == true) {
        await loadAnnouncements(teamId);
        return true;
      }
    } catch (_) {}
    return false;
  }
}
