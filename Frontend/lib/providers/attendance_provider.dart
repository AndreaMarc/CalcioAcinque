import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../core/constants/api_constants.dart';
import '../models/attendance_model.dart';

class AttendanceProvider extends ChangeNotifier {
  final ApiClient apiClient;
  List<AttendanceModel> _attendances = [];
  bool _isLoading = false;
  bool _hasLoaded = false;

  List<AttendanceModel> get attendances => _attendances;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;

  AttendanceProvider({required this.apiClient});

  Future<void> loadByMatch(int matchId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await apiClient.dio.get(ApiConstants.matchAttendance(matchId));
      if (response.data['success'] == true) {
        _attendances = (response.data['data'] as List)
            .map((e) => AttendanceModel.fromJson(e)).toList();
      }
    } catch (_) {}
    _isLoading = false;
    _hasLoaded = true;
    notifyListeners();
  }

  Future<bool> updateAttendance(int matchId, int playerId, {
    bool? presente, bool? haGiocato,
    int? minutiGiocati, int? goal, int? assist, int? autogoal,
    int? ammonizioni, int? espulsioni, int? goalSubiti,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (presente != null) data['presente'] = presente;
      if (haGiocato != null) data['haGiocato'] = haGiocato;
      if (minutiGiocati != null) data['minutiGiocati'] = minutiGiocati;
      if (goal != null) data['goal'] = goal;
      if (assist != null) data['assist'] = assist;
      if (autogoal != null) data['autogoal'] = autogoal;
      if (ammonizioni != null) data['ammonizioni'] = ammonizioni;
      if (espulsioni != null) data['espulsioni'] = espulsioni;
      if (goalSubiti != null) data['goalSubiti'] = goalSubiti;
      final response = await apiClient.dio.put(
        ApiConstants.playerAttendance(matchId, playerId), data: data);
      if (response.data['success'] == true) {
        await loadByMatch(matchId);
        return true;
      }
    } catch (_) {}
    return false;
  }
}
