class ApiConstants {
  static const String baseUrl = 'https://incampo-api.studiorocket.it';
  static const String login = '/api/auth/login';
  static const String signup = '/api/auth/signup';
  static const String register = '/api/auth/register';
  static const String refreshToken = '/api/auth/refresh';
  static const String me = '/api/auth/me';
  static const String selectTeam = '/api/auth/select-team';
  static const String myTeams = '/api/auth/teams';
  static const String createTeam = '/api/auth/create-team';
  static const String joinTeam = '/api/auth/join-team';
  static const String inviteCode = '/api/auth/invite-code';
  static String joinInfo(String code) => '/api/auth/join-info/$code';
  static String pendingPlayers(int teamId) => '/api/teams/$teamId/pending-players';
  static String pendingPlayer(int teamId, int id) => '/api/teams/$teamId/pending-players/$id';

  static String team(int teamId) => '/api/teams/$teamId';
  static String players(int teamId) => '/api/teams/$teamId/players';
  static String player(int teamId, int playerId) => '/api/teams/$teamId/players/$playerId';
  static String matches(int teamId) => '/api/teams/$teamId/matches';
  static String match(int teamId, int matchId) => '/api/teams/$teamId/matches/$matchId';
  static String matchStato(int teamId, int matchId) => '/api/teams/$teamId/matches/$matchId/stato';
  static String matchConvocations(int matchId) => '/api/matches/$matchId/convocations';
  static String respondConvocation(int convocationId) => '/api/convocations/$convocationId/respond';
  static String pendingConvocations(int playerId) => '/api/players/$playerId/convocations/pending';
  static String matchAttendance(int matchId) => '/api/matches/$matchId/attendance';
  static String playerAttendance(int matchId, int playerId) => '/api/matches/$matchId/attendance/$playerId';
  static String teamTokens(int teamId) => '/api/teams/$teamId/tokens';
  static String playerTokens(int playerId) => '/api/players/$playerId/tokens';
  static String teamPayments(int teamId) => '/api/teams/$teamId/payments';
  static String playerPayments(int playerId) => '/api/players/$playerId/payments';
  static String payment(int paymentId) => '/api/payments/$paymentId';
  static String dashboard(int teamId) => '/api/teams/$teamId/dashboard';
  static String matchAvailability(int matchId) => '/api/matches/$matchId/availability';
  static String nextAvailability(int teamId) => '/api/teams/$teamId/next-availability';
  static String teamStats(int teamId) => '/api/teams/$teamId/stats';
  static String playerStats(int playerId) => '/api/players/$playerId/stats';
  static String calendarIcs(int teamId) => '/api/teams/$teamId/matches/calendar.ics';
  static String announcements(int teamId) => '/api/teams/$teamId/announcements';
  static String announcement(int teamId, int id) => '/api/teams/$teamId/announcements/$id';
  static String announcementAcknowledge(int teamId, int id) => '/api/teams/$teamId/announcements/$id/acknowledge';
  static String playerResetPassword(int teamId, int playerId) => '/api/teams/$teamId/players/$playerId/reset-password';
  static String myProfile(int teamId) => '/api/teams/$teamId/players/me';

  static String generatePayments(int teamId) => '/api/teams/$teamId/payments/generate';
  static String remindPayments(int teamId) => '/api/teams/$teamId/payments/remind';
  static String declarePayment(int paymentId) => '/api/payments/$paymentId/declare';

  // Incasso di una singola partita (il teamId lo prende dal token, non dal path)
  static String matchPaymentsPreview(int matchId) => '/api/matches/$matchId/payments/preview';
  static String matchPayments(int matchId) => '/api/matches/$matchId/payments';

  // Notifiche push: sono per utente, quindi niente teamId nel path
  // (TeamAuthorizationMiddleware intercetta le route con {teamId})
  static const String notificationsConfig = '/api/notifications/config';
  static const String notificationsSubscribe = '/api/notifications/subscriptions';
  static const String notificationsUnsubscribe = '/api/notifications/subscriptions/remove';
  static const String notificationsPreferences = '/api/notifications/preferences';
  static const String notificationsTest = '/api/notifications/test';

  // Stagioni (per squadra: si aprono e chiudono separatamente)
  static String seasons(int teamId) => '/api/teams/$teamId/seasons';
  static String closeSeason(int teamId) => '/api/teams/$teamId/seasons/close';

  // Societa' (raggruppa piu' squadre con anagrafica condivisa)
  static const String clubs = '/api/clubs';
  static const String teamFormats = '/api/clubs/formats';
  static String club(int clubId) => '/api/clubs/$clubId';
  static String clubInviteCode(int clubId) => '/api/clubs/$clubId/invite-code';
  static String clubTeams(int clubId) => '/api/clubs/$clubId/teams';
  static String clubMembers(int clubId) => '/api/clubs/$clubId/members';
  static String clubMember(int clubId, int memberId) => '/api/clubs/$clubId/members/$memberId';
  static String clubMemberEnroll(int clubId, int memberId) =>
      '/api/clubs/$clubId/members/$memberId/enroll';
  static String clubMemberUnenroll(int clubId, int memberId, int teamId) =>
      '/api/clubs/$clubId/members/$memberId/enroll/$teamId';

  // Draft squadra (configuratore pre-creazione)
  static const String drafts = '/api/drafts';
  static String draft(int id) => '/api/drafts/$id';
  static String draftCandidates(int id) => '/api/drafts/$id/candidates';
  static String draftCandidate(int draftId, int candidateId) =>
      '/api/drafts/$draftId/candidates/$candidateId';
  static String draftCandidateFriends(int draftId, int candidateId) =>
      '/api/drafts/$draftId/candidates/$candidateId/friends';
  static String draftLaunch(int id) => '/api/drafts/$id/launch';
  static String draftShare(String code) => '/api/drafts/share/$code';
  static String draftShareJoin(String code) => '/api/drafts/share/$code/join';
}
