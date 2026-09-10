import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../core/constants/api_constants.dart';
import '../models/team_draft.dart';
import '../models/team_format.dart';

class TeamDraftProvider extends ChangeNotifier {
  final ApiClient apiClient;

  List<TeamDraft> _drafts = [];
  int? _currentDraftId;
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;
  String _signature = '';

  List<TeamDraft> get drafts => _drafts;
  TeamDraft? get currentDraft =>
      _currentDraftId == null ? null : _drafts.where((d) => d.id == _currentDraftId).firstOrNull;
  int? get currentDraftId => _currentDraftId;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get error => _error;

  TeamDraftProvider({required this.apiClient});

  void reset() {
    _drafts = [];
    _currentDraftId = null;
    _hasLoaded = false;
    _error = null;
    _signature = '';
    notifyListeners();
  }

  String _signatureOf(List<TeamDraft> drafts) => drafts
      .map((d) =>
          '${d.id}:${d.updatedAt.toIso8601String()}:${d.candidates.length}:${d.collaborators.length}')
      .join('|');

  /// Refresh in background (senza spinner) per il sync live tra collaboratori.
  /// Aggiorna lo stato solo se qualcosa è effettivamente cambiato (dedup via firma),
  /// così non interrompe scroll/interazioni quando non serve.
  Future<void> refreshSilently() async {
    try {
      final response = await apiClient.dio.get(ApiConstants.drafts);
      if (response.data['success'] != true) return;
      final fresh = ((response.data['data'] as List?) ?? [])
          .map((e) => TeamDraft.fromJson(e as Map<String, dynamic>))
          .toList();
      final sig = _signatureOf(fresh);
      if (sig == _signature) return; // niente di nuovo
      _signature = sig;
      _drafts = fresh;
      if (_currentDraftId != null && !_drafts.any((d) => d.id == _currentDraftId)) {
        // il draft corrente è stato lanciato/eliminato dall'owner
        _currentDraftId = _drafts.isNotEmpty ? _drafts.first.id : null;
      }
      notifyListeners();
    } catch (_) {}
  }

  void selectDraft(int draftId) {
    _currentDraftId = draftId;
    notifyListeners();
  }

  Future<void> loadDrafts({int? preferredId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await apiClient.dio.get(ApiConstants.drafts);
      if (response.data['success'] == true) {
        _drafts = ((response.data['data'] as List?) ?? [])
            .map((e) => TeamDraft.fromJson(e as Map<String, dynamic>))
            .toList();
        _signature = _signatureOf(_drafts);
        if (preferredId != null && _drafts.any((d) => d.id == preferredId)) {
          _currentDraftId = preferredId;
        } else if (_currentDraftId == null || !_drafts.any((d) => d.id == _currentDraftId)) {
          _currentDraftId = _drafts.isNotEmpty ? _drafts.first.id : null;
        }
      }
    } on DioException catch (e) {
      _error = e.response?.data?['message'] ?? 'Errore di connessione';
    } catch (e) {
      _error = 'Errore: $e';
    }
    _isLoading = false;
    _hasLoaded = true;
    notifyListeners();
  }

  Future<TeamDraft?> createDraft({
    required String nomeTeam,
    required TeamFormat formato,
    required int partitePerStagione,
    required int gettoniPerGiocatore,
    required bool useGettoni,
  }) async {
    _error = null;
    try {
      final response = await apiClient.dio.post(ApiConstants.drafts, data: {
        'nomeTeam': nomeTeam,
        'formato': formato.apiValue,
        'partitePerStagione': partitePerStagione,
        'gettoniPerGiocatore': gettoniPerGiocatore,
        'useGettoni': useGettoni,
      });
      if (response.data['success'] == true) {
        final created = TeamDraft.fromJson(response.data['data'] as Map<String, dynamic>);
        await loadDrafts(preferredId: created.id);
        return created;
      }
    } on DioException catch (e) {
      _error = e.response?.data?['message'] ?? 'Errore di connessione';
    } catch (e) {
      _error = 'Errore: $e';
    }
    notifyListeners();
    return null;
  }

  Future<bool> updateDraft({
    required int draftId,
    required String nomeTeam,
    required TeamFormat formato,
    required int partitePerStagione,
    required int gettoniPerGiocatore,
    required bool useGettoni,
  }) async {
    _error = null;
    try {
      final response = await apiClient.dio.put(ApiConstants.draft(draftId), data: {
        'nomeTeam': nomeTeam,
        'formato': formato.apiValue,
        'partitePerStagione': partitePerStagione,
        'gettoniPerGiocatore': gettoniPerGiocatore,
        'useGettoni': useGettoni,
      });
      if (response.data['success'] == true) {
        await loadDrafts(preferredId: draftId);
        return true;
      }
    } on DioException catch (e) {
      _error = e.response?.data?['message'] ?? 'Errore di connessione';
    } catch (e) {
      _error = 'Errore: $e';
    }
    notifyListeners();
    return false;
  }

  Future<bool> deleteDraft(int draftId) async {
    try {
      final response = await apiClient.dio.delete(ApiConstants.draft(draftId));
      if (response.data['success'] == true) {
        await loadDrafts();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> addCandidate(
    int draftId, {
    required String nome,
    String? soprannome,
    PlayerPosition? posizione,
    required DraftStatus stato,
    required int bravura,
    required int affidabilita,
    required bool tesserato,
    String? note,
  }) async {
    _error = null;
    try {
      final response = await apiClient.dio.post(ApiConstants.draftCandidates(draftId), data: {
        'nome': nome,
        if (soprannome != null && soprannome.isNotEmpty) 'soprannome': soprannome,
        if (posizione != null) 'posizione': posizione.apiValue,
        'stato': stato.apiValue,
        'bravura': bravura,
        'affidabilita': affidabilita,
        'tesserato': tesserato,
        if (note != null && note.isNotEmpty) 'note': note,
      });
      if (response.data['success'] == true) {
        await loadDrafts(preferredId: draftId);
        return true;
      }
    } on DioException catch (e) {
      _error = e.response?.data?['message'] ?? 'Errore di connessione';
    } catch (e) {
      _error = 'Errore: $e';
    }
    notifyListeners();
    return false;
  }

  Future<bool> updateCandidate(
    int draftId,
    int candidateId, {
    required String nome,
    String? soprannome,
    PlayerPosition? posizione,
    required DraftStatus stato,
    required int bravura,
    required int affidabilita,
    required bool tesserato,
    String? note,
  }) async {
    _error = null;
    try {
      final response = await apiClient.dio.put(
        ApiConstants.draftCandidate(draftId, candidateId),
        data: {
          'nome': nome,
          if (soprannome != null && soprannome.isNotEmpty) 'soprannome': soprannome,
          if (posizione != null) 'posizione': posizione.apiValue,
          'stato': stato.apiValue,
          'bravura': bravura,
          'affidabilita': affidabilita,
          'tesserato': tesserato,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );
      if (response.data['success'] == true) {
        await loadDrafts(preferredId: draftId);
        return true;
      }
    } on DioException catch (e) {
      _error = e.response?.data?['message'] ?? 'Errore di connessione';
    } catch (e) {
      _error = 'Errore: $e';
    }
    notifyListeners();
    return false;
  }

  Future<bool> addFriends(int draftId, int candidateId, int count) async {
    _error = null;
    try {
      final response = await apiClient.dio.post(
        ApiConstants.draftCandidateFriends(draftId, candidateId),
        data: {'count': count},
      );
      if (response.data['success'] == true) {
        await loadDrafts(preferredId: draftId);
        return true;
      }
    } on DioException catch (e) {
      _error = e.response?.data?['message'] ?? 'Errore di connessione';
    } catch (e) {
      _error = 'Errore: $e';
    }
    notifyListeners();
    return false;
  }

  Future<bool> removeCandidate(int draftId, int candidateId) async {
    try {
      final response = await apiClient.dio.delete(
        ApiConstants.draftCandidate(draftId, candidateId),
      );
      if (response.data['success'] == true) {
        await loadDrafts(preferredId: draftId);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<TeamDraft?> joinByShareCode(String code) async {
    _error = null;
    try {
      final response = await apiClient.dio.post(ApiConstants.draftShareJoin(code));
      if (response.data['success'] == true) {
        final joined = TeamDraft.fromJson(response.data['data'] as Map<String, dynamic>);
        await loadDrafts(preferredId: joined.id);
        return joined;
      }
    } on DioException catch (e) {
      _error = e.response?.data?['message'] ?? 'Errore di connessione';
    } catch (e) {
      _error = 'Errore: $e';
    }
    notifyListeners();
    return null;
  }

  Future<Map<String, dynamic>?> previewByShareCode(String code) async {
    try {
      final response = await apiClient.dio.get(ApiConstants.draftShare(code));
      if (response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}
