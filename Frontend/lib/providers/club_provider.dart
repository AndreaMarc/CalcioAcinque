import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../core/constants/api_constants.dart';
import '../models/club_model.dart';
import '../models/payment_model.dart';
import '../models/season_model.dart';
import '../models/team_format.dart';
import '../models/team_draft.dart' show PlayerPosition, PlayerPositionX;

/// Stato di societa', squadre e anagrafica condivisa.
class ClubProvider extends ChangeNotifier {
  final ApiClient apiClient;

  ClubProvider({required this.apiClient});

  List<ClubModel> _clubs = [];
  List<ClubMember> _members = [];
  List<TeamFormatInfo> _formats = [];
  TeamConfig? _teamConfig;
  List<SeasonModel> _seasons = [];

  int? _selectedClubId;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  List<ClubModel> get clubs => _clubs;
  List<ClubMember> get members => _members;
  TeamConfig? get teamConfig => _teamConfig;

  /// Dalla piu' recente alla piu' vecchia, come le restituisce il server.
  List<SeasonModel> get seasons => _seasons;

  SeasonModel? get stagioneCorrente {
    for (final s in _seasons) {
      if (!s.chiusa) return s;
    }
    return null;
  }
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  /// Catalogo dei formati: se il server non ha risposto si usano i preset locali.
  List<TeamFormatInfo> get formats => _formats.isNotEmpty
      ? _formats
      : TeamFormat.values.map(TeamFormatInfo.local).toList();

  TeamFormatInfo formatInfo(TeamFormat formato) =>
      formats.firstWhere((f) => f.formato == formato,
          orElse: () => TeamFormatInfo.local(formato));

  List<PlayerPosition> positionsFor(TeamFormat formato) {
    final info = formatInfo(formato);
    return info.posizioni.isNotEmpty ? info.posizioni : formato.posizioni;
  }

  ClubModel? get selectedClub {
    if (_clubs.isEmpty) return null;
    if (_selectedClubId == null) return _clubs.first;
    return _clubs.firstWhere((c) => c.id == _selectedClubId, orElse: () => _clubs.first);
  }

  void selectClub(int clubId) {
    _selectedClubId = clubId;
    notifyListeners();
  }

  void reset() {
    _clubs = [];
    _members = [];
    _teamConfig = null;
    _seasons = [];
    _selectedClubId = null;
    _error = null;
    notifyListeners();
  }

  // ------------------------------------------------------------------ letture

  Future<void> loadFormats() async {
    if (_formats.isNotEmpty) return;
    try {
      final response = await apiClient.dio.get(ApiConstants.teamFormats);
      if (response.data['success'] == true) {
        _formats = (response.data['data'] as List)
            .map((e) => TeamFormatInfo.fromJson(e as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (_) {
      // I preset locali coprono il caso peggiore, non serve segnalare l'errore
    }
  }

  Future<void> loadClubs({int? preferClubId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await apiClient.dio.get(ApiConstants.clubs);
      if (response.data['success'] == true) {
        _clubs = (response.data['data'] as List)
            .map((e) => ClubModel.fromJson(e as Map<String, dynamic>))
            .toList();
        if (preferClubId != null && _clubs.any((c) => c.id == preferClubId)) {
          _selectedClubId = preferClubId;
        }
        _selectedClubId ??= _clubs.isNotEmpty ? _clubs.first.id : null;
      } else {
        _error = response.data['message'] as String?;
      }
    } on DioException catch (e) {
      _error = _messageOf(e);
    } catch (e) {
      _error = 'Errore imprevisto: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMembers(int clubId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await apiClient.dio.get(ApiConstants.clubMembers(clubId));
      if (response.data['success'] == true) {
        _members = (response.data['data'] as List)
            .map((e) => ClubMember.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        _error = response.data['message'] as String?;
      }
    } on DioException catch (e) {
      _error = _messageOf(e);
    } catch (e) {
      _error = 'Errore imprevisto: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<TeamConfig?> loadTeamConfig(int teamId) async {
    try {
      final response = await apiClient.dio.get(ApiConstants.team(teamId));
      if (response.data['success'] == true) {
        _teamConfig = TeamConfig.fromJson(response.data['data'] as Map<String, dynamic>);
        notifyListeners();
        return _teamConfig;
      }
    } on DioException catch (e) {
      _error = _messageOf(e);
      notifyListeners();
    } catch (_) {}
    return null;
  }

  /// Le stagioni della squadra. Il server ne crea una se la squadra non ne ha
  /// ancora, quindi la lista non torna mai vuota per una squadra esistente.
  Future<List<SeasonModel>> loadSeasons(int teamId) async {
    try {
      final response = await apiClient.dio.get(ApiConstants.seasons(teamId));
      if (response.data['success'] == true) {
        _seasons = (response.data['data'] as List)
            .map((e) => SeasonModel.fromJson(e as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } on DioException catch (e) {
      _error = _messageOf(e);
      notifyListeners();
    } catch (_) {}
    return _seasons;
  }

  Future<String?> loadInviteCode(int clubId) async {
    try {
      final response = await apiClient.dio.get(ApiConstants.clubInviteCode(clubId));
      if (response.data['success'] == true) {
        return response.data['data']['inviteCode'] as String?;
      }
    } catch (_) {}
    return null;
  }

  // ------------------------------------------------------------------ scritture

  Future<bool> createClub(String nome) => _mutate(() async {
        final response = await apiClient.dio.post(ApiConstants.clubs, data: {'nome': nome});
        if (response.data['success'] != true) return response.data['message'] as String?;
        final club = ClubModel.fromJson(response.data['data'] as Map<String, dynamic>);
        _clubs = [..._clubs, club];
        _selectedClubId = club.id;
        return null;
      });

  /// Aggiorna nome e/o dati di pagamento della societa.
  /// Stringa vuota su un campo pagamento = cancellalo; null = lascialo com e.
  Future<bool> updateClub(
    int clubId, {
    String? nome,
    String? paypalLink,
    String? iban,
    String? intestatarioIban,
  }) =>
      _mutate(() async {
        final response = await apiClient.dio.put(ApiConstants.club(clubId), data: {
          if (nome != null) 'nome': nome,
          if (paypalLink != null) 'paypalLink': paypalLink,
          if (iban != null) 'iban': iban,
          if (intestatarioIban != null) 'intestatarioIban': intestatarioIban,
        });
        if (response.data['success'] != true) return response.data['message'] as String?;
        await _refreshClub(clubId);
        return null;
      });

  /// Aggiunge una squadra alla societa'. E' la via per avere l'a5 e l'a7 insieme.
  Future<bool> createTeam({
    required int clubId,
    required String nome,
    required TeamFormat formato,
    int partitePerStagione = 8,
    bool useGettoni = true,
    int gettoniPerGiocatore = 4,
    double quotaIscrizione = 0,
    double quotaTesseramento = 0,
    double costoPartita = 0,
    bool iscriviMi = true,
  }) =>
      _mutate(() async {
        final response = await apiClient.dio.post(
          ApiConstants.clubTeams(clubId),
          data: {
            'nome': nome,
            'formato': formato.apiValue,
            'partitePerStagione': partitePerStagione,
            'useGettoni': useGettoni,
            'gettoniPerGiocatore': gettoniPerGiocatore,
            'quotaIscrizione': quotaIscrizione,
            'quotaTesseramento': quotaTesseramento,
            'costoPartita': costoPartita,
            'iscriviMi': iscriviMi,
          },
        );
        if (response.data['success'] != true) return response.data['message'] as String?;
        await _refreshClub(clubId);
        return null;
      });

  /// Aggiorna regole e costi di una squadra (`PUT /api/teams/{teamId}`).
  Future<bool> updateTeamConfig({
    required int teamId,
    String? nome,
    TeamFormat? formato,
    int? partitePerStagione,
    bool? useGettoni,
    int? gettoniPerGiocatore,
    int? giocatoriInCampo,
    int? maxConvocati,
    int? minutiPerTempo,
    int? numeroTempi,
    double? quotaIscrizione,
    double? quotaTesseramento,
    double? costoPartita,
    RegimePagamento? regimePagamentoDefault,
    DestinatariQuota? applicaIscrizioneA,
    DestinatariQuota? applicaTesseramentoA,
    int? minutiMinimiPerAddebito,
    int? orePromemoriaPartita,
    String? paypalLink,
    String? iban,
    String? intestatarioIban,
    String? logoBase64,
  }) =>
      _mutate(() async {
        final response = await apiClient.dio.put(
          ApiConstants.team(teamId),
          data: {
            if (nome != null) 'nome': nome,
            if (formato != null) 'formato': formato.apiValue,
            if (partitePerStagione != null) 'partitePerStagione': partitePerStagione,
            if (useGettoni != null) 'useGettoni': useGettoni,
            if (gettoniPerGiocatore != null) 'gettoniPerGiocatore': gettoniPerGiocatore,
            if (giocatoriInCampo != null) 'giocatoriInCampo': giocatoriInCampo,
            // 0 significa "nessun limite": il backend lo traduce in null
            if (maxConvocati != null) 'maxConvocati': maxConvocati,
            if (minutiPerTempo != null) 'minutiPerTempo': minutiPerTempo,
            if (numeroTempi != null) 'numeroTempi': numeroTempi,
            if (quotaIscrizione != null) 'quotaIscrizione': quotaIscrizione,
            if (quotaTesseramento != null) 'quotaTesseramento': quotaTesseramento,
            if (costoPartita != null) 'costoPartita': costoPartita,
            if (regimePagamentoDefault != null)
              'regimePagamentoDefault': regimePagamentoDefault.apiValue,
            if (applicaIscrizioneA != null) 'applicaIscrizioneA': applicaIscrizioneA.apiValue,
            if (applicaTesseramentoA != null)
              'applicaTesseramentoA': applicaTesseramentoA.apiValue,
            if (minutiMinimiPerAddebito != null)
              'minutiMinimiPerAddebito': minutiMinimiPerAddebito,
            if (orePromemoriaPartita != null)
              'orePromemoriaPartita': orePromemoriaPartita,
            // Stringa vuota = azzera l override e torna ai dati della societa
            if (paypalLink != null) 'paypalLink': paypalLink,
            if (iban != null) 'iban': iban,
            if (intestatarioIban != null) 'intestatarioIban': intestatarioIban,
            // Stringa vuota = rimuovi il logo
            if (logoBase64 != null) 'logoBase64': logoBase64,
          },
        );
        if (response.data['success'] != true) return response.data['message'] as String?;
        _teamConfig = TeamConfig.fromJson(response.data['data'] as Map<String, dynamic>);
        return null;
      });

  Future<bool> upsertMember({
    required int clubId,
    int? memberId,
    required String nome,
    String? soprannome,
    String? telefono,
    DateTime? dataNascita,
    String? note,
    String? email,
    String? password,
  }) =>
      _mutate(() async {
        final data = {
          'nome': nome,
          if (soprannome != null && soprannome.isNotEmpty) 'soprannome': soprannome,
          if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
          if (dataNascita != null) 'dataNascita': dataNascita.toIso8601String(),
          if (note != null && note.isNotEmpty) 'note': note,
          if (email != null && email.isNotEmpty) 'email': email,
          if (password != null && password.isNotEmpty) 'password': password,
        };
        final response = memberId == null
            ? await apiClient.dio.post(ApiConstants.clubMembers(clubId), data: data)
            : await apiClient.dio.put(ApiConstants.clubMember(clubId, memberId), data: data);
        if (response.data['success'] != true) return response.data['message'] as String?;
        _replaceMember(ClubMember.fromJson(response.data['data'] as Map<String, dynamic>));
        return null;
      });

  Future<bool> deleteMember(int clubId, int memberId) => _mutate(() async {
        final response = await apiClient.dio.delete(ApiConstants.clubMember(clubId, memberId));
        if (response.data['success'] != true) return response.data['message'] as String?;
        _members = _members.where((m) => m.id != memberId).toList();
        return null;
      });

  /// Iscrive una persona dell'anagrafica a una squadra: e' l'azione che rende
  /// un giocatore "comune" alle due squadre della societa'.
  Future<bool> enrollMember({
    required int clubId,
    required int memberId,
    required int teamId,
    String ruolo = 'User',
    PlayerPosition? posizione,
    int? numeroMaglia,
  }) =>
      _mutate(() async {
        final response = await apiClient.dio.post(
          ApiConstants.clubMemberEnroll(clubId, memberId),
          data: {
            'teamId': teamId,
            'ruolo': ruolo,
            if (posizione != null) 'posizione': posizione.apiValue,
            if (numeroMaglia != null) 'numeroMaglia': numeroMaglia,
          },
        );
        if (response.data['success'] != true) return response.data['message'] as String?;
        _replaceMember(ClubMember.fromJson(response.data['data'] as Map<String, dynamic>));
        await _refreshClub(clubId);
        return null;
      });

  Future<bool> unenrollMember({
    required int clubId,
    required int memberId,
    required int teamId,
  }) =>
      _mutate(() async {
        final response =
            await apiClient.dio.delete(ApiConstants.clubMemberUnenroll(clubId, memberId, teamId));
        if (response.data['success'] != true) return response.data['message'] as String?;
        _replaceMember(ClubMember.fromJson(response.data['data'] as Map<String, dynamic>));
        await _refreshClub(clubId);
        return null;
      });

  // ------------------------------------------------------------------ interni

  /// Esegue una scrittura gestendo loading/errore in un solo posto.
  /// L'azione ritorna null se e' andata bene, o il messaggio d'errore.
  /// Chiude la stagione corrente e apre la successiva. Con arretrati aperti il
  /// server rifiuta: si ripresenta la stessa chiamata con [ignoraArretrati].
  /// Ritorna null in caso di errore, con il motivo in [error].
  Future<CloseSeasonResult?> closeSeason({
    required int teamId,
    String? nomeNuovaStagione,
    String? note,
    bool ignoraArretrati = false,
  }) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final response = await apiClient.dio.post(
        ApiConstants.closeSeason(teamId),
        data: {
          if (nomeNuovaStagione != null && nomeNuovaStagione.isNotEmpty)
            'nomeNuovaStagione': nomeNuovaStagione,
          if (note != null && note.isNotEmpty) 'note': note,
          'ignoraArretrati': ignoraArretrati,
        },
      );
      _isSaving = false;

      if (response.data['success'] != true) {
        _error = response.data['message'] as String?;
        notifyListeners();
        return null;
      }

      final result =
          CloseSeasonResult.fromJson(response.data['data'] as Map<String, dynamic>);
      // I contatori dei giocatori sono cambiati per tutti: chi legge la rosa
      // o la dashboard deve ricaricare, qui basta rinfrescare le stagioni.
      await loadSeasons(teamId);
      notifyListeners();
      return result;
    } on DioException catch (e) {
      _error = _messageOf(e);
    } catch (e) {
      _error = 'Errore imprevisto: $e';
    }

    _isSaving = false;
    notifyListeners();
    return null;
  }

  Future<bool> _mutate(Future<String?> Function() action) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final message = await action();
      _isSaving = false;
      if (message != null) {
        _error = message;
        notifyListeners();
        return false;
      }
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = _messageOf(e);
    } catch (e) {
      _error = 'Errore imprevisto: $e';
    }

    _isSaving = false;
    notifyListeners();
    return false;
  }

  Future<void> _refreshClub(int clubId) async {
    final response = await apiClient.dio.get(ApiConstants.club(clubId));
    if (response.data['success'] != true) return;
    final updated = ClubModel.fromJson(response.data['data'] as Map<String, dynamic>);
    final index = _clubs.indexWhere((c) => c.id == clubId);
    if (index >= 0) {
      _clubs = [..._clubs]..[index] = updated;
    } else {
      _clubs = [..._clubs, updated];
    }
  }

  void _replaceMember(ClubMember member) {
    final index = _members.indexWhere((m) => m.id == member.id);
    if (index >= 0) {
      _members = [..._members]..[index] = member;
    } else {
      _members = [..._members, member]..sort((a, b) => a.nome.compareTo(b.nome));
    }
  }

  String _messageOf(DioException e) =>
      e.response?.data is Map && (e.response!.data as Map)['message'] != null
          ? (e.response!.data as Map)['message'] as String
          : 'Errore di connessione';
}
