/// Ruolo di una persona in UNA squadra. Rispecchia `UserRole` del backend
/// (`Backend/Models/Enums/UserRole.cs`); le politiche di accesso vere stanno
/// la', qui ci sono solo le etichette e i permessi che guidano la UI.
enum Ruolo { admin, mister, cassiere, giocatore }

extension RuoloX on Ruolo {
  String get apiValue {
    switch (this) {
      case Ruolo.admin:
        return 'Admin';
      case Ruolo.mister:
        return 'Mister';
      case Ruolo.cassiere:
        return 'Cassiere';
      case Ruolo.giocatore:
        return 'User';
    }
  }

  String get label {
    switch (this) {
      case Ruolo.admin:
        return 'Amministratore';
      case Ruolo.mister:
        return 'Mister';
      case Ruolo.cassiere:
        return 'Cassiere';
      case Ruolo.giocatore:
        return 'Giocatore';
    }
  }

  String get descrizione {
    switch (this) {
      case Ruolo.admin:
        return 'Rosa, partite e cassa: puo fare tutto';
      case Ruolo.mister:
        return 'Partite, convocazioni e presenze. Non vede i pagamenti';
      case Ruolo.cassiere:
        return 'Quote, incassi e solleciti. Non gestisce le partite';
      case Ruolo.giocatore:
        return 'Vede il suo e risponde alle convocazioni';
    }
  }

  /// Sigla per il pallino sulla maglia. null per chi non ha incarichi:
  /// un distintivo su tutta la rosa non distinguerebbe nessuno.
  String? get badge {
    switch (this) {
      case Ruolo.admin:
        return 'CAP';
      case Ruolo.mister:
        return 'MIS';
      case Ruolo.cassiere:
        return 'CAS';
      case Ruolo.giocatore:
        return null;
    }
  }

  bool get puoGestireSquadra => this == Ruolo.admin;
  bool get puoGestireCampo => this == Ruolo.admin || this == Ruolo.mister;
  bool get puoGestireSoldi => this == Ruolo.admin || this == Ruolo.cassiere;

  static Ruolo fromApi(String? value) {
    switch (value) {
      case 'Admin':
        return Ruolo.admin;
      case 'Mister':
        return Ruolo.mister;
      case 'Cassiere':
        return Ruolo.cassiere;
      default:
        return Ruolo.giocatore;
    }
  }
}

/// Etichetta leggibile a partire dalla stringa che arriva dall'API.
String labelRuolo(String? apiValue) => RuoloX.fromApi(apiValue).label;

/// Sigla da mostrare sulla maglia, o null per un giocatore senza incarichi.
String? badgeRuolo(String? apiValue) => RuoloX.fromApi(apiValue).badge;
