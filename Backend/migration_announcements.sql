CREATE TABLE IF NOT EXISTS `__EFMigrationsHistory` (
    `MigrationId` varchar(150) CHARACTER SET utf8mb4 NOT NULL,
    `ProductVersion` varchar(32) CHARACTER SET utf8mb4 NOT NULL,
    CONSTRAINT `PK___EFMigrationsHistory` PRIMARY KEY (`MigrationId`)
) CHARACTER SET=utf8mb4;

START TRANSACTION;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211152618_InitialCreate') THEN

    ALTER DATABASE CHARACTER SET utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211152618_InitialCreate') THEN

    CREATE TABLE `teams` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `Nome` varchar(100) CHARACTER SET utf8mb4 NOT NULL,
        `PartitePerStagione` int NOT NULL,
        `GettoniPerGiocatore` int NOT NULL,
        `CreatedAt` datetime(6) NOT NULL,
        CONSTRAINT `PK_teams` PRIMARY KEY (`Id`)
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211152618_InitialCreate') THEN

    CREATE TABLE `users` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `Email` varchar(255) CHARACTER SET utf8mb4 NOT NULL,
        `PasswordHash` varchar(255) CHARACTER SET utf8mb4 NOT NULL,
        `IsActive` tinyint(1) NOT NULL,
        `LastLoginAt` datetime(6) NULL,
        `CreatedAt` datetime(6) NOT NULL,
        `UpdatedAt` datetime(6) NOT NULL,
        CONSTRAINT `PK_users` PRIMARY KEY (`Id`)
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211152618_InitialCreate') THEN

    CREATE TABLE `matches` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `TeamId` int NOT NULL,
        `Data` datetime(6) NOT NULL,
        `Ora` time(6) NOT NULL,
        `Luogo` varchar(255) CHARACTER SET utf8mb4 NULL,
        `NumeroGiornata` int NOT NULL,
        `Stato` longtext CHARACTER SET utf8mb4 NOT NULL,
        `Note` varchar(500) CHARACTER SET utf8mb4 NULL,
        `CreatedAt` datetime(6) NOT NULL,
        CONSTRAINT `PK_matches` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_matches_teams_TeamId` FOREIGN KEY (`TeamId`) REFERENCES `teams` (`Id`) ON DELETE CASCADE
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211152618_InitialCreate') THEN

    CREATE TABLE `players` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `TeamId` int NOT NULL,
        `UserId` int NOT NULL,
        `Nome` varchar(100) CHARACTER SET utf8mb4 NOT NULL,
        `Soprannome` varchar(100) CHARACTER SET utf8mb4 NULL,
        `Telefono` varchar(20) CHARACTER SET utf8mb4 NULL,
        `Ruolo` longtext CHARACTER SET utf8mb4 NOT NULL,
        `GettoniTotali` int NOT NULL,
        `GettoniConsumati` int NOT NULL,
        `IscrizionePagata` tinyint(1) NOT NULL,
        `TesseramentoPagato` tinyint(1) NOT NULL,
        `CreatedAt` datetime(6) NOT NULL,
        CONSTRAINT `PK_players` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_players_teams_TeamId` FOREIGN KEY (`TeamId`) REFERENCES `teams` (`Id`) ON DELETE CASCADE,
        CONSTRAINT `FK_players_users_UserId` FOREIGN KEY (`UserId`) REFERENCES `users` (`Id`) ON DELETE CASCADE
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211152618_InitialCreate') THEN

    CREATE TABLE `refresh_tokens` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `UserId` int NOT NULL,
        `Token` varchar(500) CHARACTER SET utf8mb4 NOT NULL,
        `ExpiresAt` datetime(6) NOT NULL,
        `CreatedAt` datetime(6) NOT NULL,
        `RevokedAt` datetime(6) NULL,
        CONSTRAINT `PK_refresh_tokens` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_refresh_tokens_users_UserId` FOREIGN KEY (`UserId`) REFERENCES `users` (`Id`) ON DELETE CASCADE
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211152618_InitialCreate') THEN

    CREATE TABLE `convocations` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `MatchId` int NOT NULL,
        `PlayerId` int NOT NULL,
        `StatoRisposta` longtext CHARACTER SET utf8mb4 NOT NULL,
        `DataConvocazione` datetime(6) NOT NULL,
        `DataRisposta` datetime(6) NULL,
        `NotificaInviata` tinyint(1) NOT NULL,
        CONSTRAINT `PK_convocations` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_convocations_matches_MatchId` FOREIGN KEY (`MatchId`) REFERENCES `matches` (`Id`) ON DELETE CASCADE,
        CONSTRAINT `FK_convocations_players_PlayerId` FOREIGN KEY (`PlayerId`) REFERENCES `players` (`Id`) ON DELETE CASCADE
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211152618_InitialCreate') THEN

    CREATE TABLE `match_attendance` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `MatchId` int NOT NULL,
        `PlayerId` int NOT NULL,
        `Convocato` tinyint(1) NOT NULL,
        `Presente` tinyint(1) NOT NULL,
        `HaGiocato` tinyint(1) NOT NULL,
        `GettoneConsumato` tinyint(1) NOT NULL,
        CONSTRAINT `PK_match_attendance` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_match_attendance_matches_MatchId` FOREIGN KEY (`MatchId`) REFERENCES `matches` (`Id`) ON DELETE CASCADE,
        CONSTRAINT `FK_match_attendance_players_PlayerId` FOREIGN KEY (`PlayerId`) REFERENCES `players` (`Id`) ON DELETE CASCADE
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211152618_InitialCreate') THEN

    CREATE TABLE `player_payments` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `PlayerId` int NOT NULL,
        `Descrizione` varchar(255) CHARACTER SET utf8mb4 NOT NULL,
        `Importo` decimal(10,2) NOT NULL,
        `DataPagamento` datetime(6) NOT NULL,
        `Pagato` tinyint(1) NOT NULL,
        `AdminId` int NOT NULL,
        `Note` varchar(500) CHARACTER SET utf8mb4 NULL,
        `CreatedAt` datetime(6) NOT NULL,
        CONSTRAINT `PK_player_payments` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_player_payments_players_AdminId` FOREIGN KEY (`AdminId`) REFERENCES `players` (`Id`) ON DELETE RESTRICT,
        CONSTRAINT `FK_player_payments_players_PlayerId` FOREIGN KEY (`PlayerId`) REFERENCES `players` (`Id`) ON DELETE CASCADE
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211152618_InitialCreate') THEN

    CREATE TABLE `token_transactions` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `PlayerId` int NOT NULL,
        `MatchId` int NULL,
        `Tipo` longtext CHARACTER SET utf8mb4 NOT NULL,
        `Motivazione` varchar(500) CHARACTER SET utf8mb4 NOT NULL,
        `Quantita` int NOT NULL,
        `AdminId` int NOT NULL,
        `Timestamp` datetime(6) NOT NULL,
        CONSTRAINT `PK_token_transactions` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_token_transactions_matches_MatchId` FOREIGN KEY (`MatchId`) REFERENCES `matches` (`Id`) ON DELETE SET NULL,
        CONSTRAINT `FK_token_transactions_players_AdminId` FOREIGN KEY (`AdminId`) REFERENCES `players` (`Id`) ON DELETE RESTRICT,
        CONSTRAINT `FK_token_transactions_players_PlayerId` FOREIGN KEY (`PlayerId`) REFERENCES `players` (`Id`) ON DELETE CASCADE
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211152618_InitialCreate') THEN

    CREATE UNIQUE INDEX `IX_convocations_MatchId_PlayerId` ON `convocations` (`MatchId`, `PlayerId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211152618_InitialCreate') THEN

    CREATE INDEX `IX_convocations_PlayerId` ON `convocations` (`PlayerId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211152618_InitialCreate') THEN

    CREATE UNIQUE INDEX `IX_match_attendance_MatchId_PlayerId` ON `match_attendance` (`MatchId`, `PlayerId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211152618_InitialCreate') THEN

    CREATE INDEX `IX_match_attendance_PlayerId` ON `match_attendance` (`PlayerId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211152618_InitialCreate') THEN

    CREATE INDEX `IX_matches_TeamId_Data` ON `matches` (`TeamId`, `Data`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211152618_InitialCreate') THEN

    CREATE INDEX `IX_matches_TeamId_NumeroGiornata` ON `matches` (`TeamId`, `NumeroGiornata`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211152618_InitialCreate') THEN

    CREATE INDEX `IX_player_payments_AdminId` ON `player_payments` (`AdminId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211152618_InitialCreate') THEN

    CREATE INDEX `IX_player_payments_PlayerId` ON `player_payments` (`PlayerId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211152618_InitialCreate') THEN

    CREATE UNIQUE INDEX `IX_players_TeamId_UserId` ON `players` (`TeamId`, `UserId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211152618_InitialCreate') THEN

    CREATE UNIQUE INDEX `IX_players_UserId` ON `players` (`UserId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211152618_InitialCreate') THEN

    CREATE UNIQUE INDEX `IX_refresh_tokens_Token` ON `refresh_tokens` (`Token`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211152618_InitialCreate') THEN

    CREATE INDEX `IX_refresh_tokens_UserId` ON `refresh_tokens` (`UserId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211152618_InitialCreate') THEN

    CREATE INDEX `IX_token_transactions_AdminId` ON `token_transactions` (`AdminId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211152618_InitialCreate') THEN

    CREATE INDEX `IX_token_transactions_MatchId` ON `token_transactions` (`MatchId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211152618_InitialCreate') THEN

    CREATE INDEX `IX_token_transactions_PlayerId_Timestamp` ON `token_transactions` (`PlayerId`, `Timestamp`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211152618_InitialCreate') THEN

    CREATE UNIQUE INDEX `IX_users_Email` ON `users` (`Email`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211152618_InitialCreate') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20260211152618_InitialCreate', '8.0.0');

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

COMMIT;

START TRANSACTION;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211162954_AddPlayerAvailability') THEN

    CREATE TABLE `player_availabilities` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `MatchId` int NOT NULL,
        `PlayerId` int NOT NULL,
        `Disponibile` tinyint(1) NOT NULL,
        `Note` varchar(255) CHARACTER SET utf8mb4 NULL,
        `CreatedAt` datetime(6) NOT NULL,
        `UpdatedAt` datetime(6) NOT NULL,
        CONSTRAINT `PK_player_availabilities` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_player_availabilities_matches_MatchId` FOREIGN KEY (`MatchId`) REFERENCES `matches` (`Id`) ON DELETE CASCADE,
        CONSTRAINT `FK_player_availabilities_players_PlayerId` FOREIGN KEY (`PlayerId`) REFERENCES `players` (`Id`) ON DELETE CASCADE
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211162954_AddPlayerAvailability') THEN

    CREATE UNIQUE INDEX `IX_player_availabilities_MatchId_PlayerId` ON `player_availabilities` (`MatchId`, `PlayerId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211162954_AddPlayerAvailability') THEN

    CREATE INDEX `IX_player_availabilities_PlayerId` ON `player_availabilities` (`PlayerId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211162954_AddPlayerAvailability') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20260211162954_AddPlayerAvailability', '8.0.0');

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

COMMIT;

START TRANSACTION;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211170837_AddPlayerMatchStats') THEN

    ALTER TABLE `match_attendance` ADD `Ammonizioni` int NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211170837_AddPlayerMatchStats') THEN

    ALTER TABLE `match_attendance` ADD `Assist` int NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211170837_AddPlayerMatchStats') THEN

    ALTER TABLE `match_attendance` ADD `Autogoal` int NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211170837_AddPlayerMatchStats') THEN

    ALTER TABLE `match_attendance` ADD `Espulsioni` int NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211170837_AddPlayerMatchStats') THEN

    ALTER TABLE `match_attendance` ADD `Goal` int NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211170837_AddPlayerMatchStats') THEN

    ALTER TABLE `match_attendance` ADD `GoalSubiti` int NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211170837_AddPlayerMatchStats') THEN

    ALTER TABLE `match_attendance` ADD `MinutiGiocati` int NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260211170837_AddPlayerMatchStats') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20260211170837_AddPlayerMatchStats', '8.0.0');

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

COMMIT;

START TRANSACTION;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260212092421_AddAnnouncements') THEN

    CREATE TABLE `announcements` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `TeamId` int NOT NULL,
        `AuthorId` int NOT NULL,
        `Titolo` varchar(200) CHARACTER SET utf8mb4 NOT NULL,
        `Contenuto` varchar(2000) CHARACTER SET utf8mb4 NOT NULL,
        `Importante` tinyint(1) NOT NULL,
        `CreatedAt` datetime(6) NOT NULL,
        CONSTRAINT `PK_announcements` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_announcements_players_AuthorId` FOREIGN KEY (`AuthorId`) REFERENCES `players` (`Id`) ON DELETE RESTRICT,
        CONSTRAINT `FK_announcements_teams_TeamId` FOREIGN KEY (`TeamId`) REFERENCES `teams` (`Id`) ON DELETE CASCADE
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260212092421_AddAnnouncements') THEN

    CREATE TABLE `announcement_reads` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `AnnouncementId` int NOT NULL,
        `PlayerId` int NOT NULL,
        `ReadAt` datetime(6) NOT NULL,
        CONSTRAINT `PK_announcement_reads` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_announcement_reads_announcements_AnnouncementId` FOREIGN KEY (`AnnouncementId`) REFERENCES `announcements` (`Id`) ON DELETE CASCADE,
        CONSTRAINT `FK_announcement_reads_players_PlayerId` FOREIGN KEY (`PlayerId`) REFERENCES `players` (`Id`) ON DELETE CASCADE
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260212092421_AddAnnouncements') THEN

    CREATE UNIQUE INDEX `IX_announcement_reads_AnnouncementId_PlayerId` ON `announcement_reads` (`AnnouncementId`, `PlayerId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260212092421_AddAnnouncements') THEN

    CREATE INDEX `IX_announcement_reads_PlayerId` ON `announcement_reads` (`PlayerId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260212092421_AddAnnouncements') THEN

    CREATE INDEX `IX_announcements_AuthorId` ON `announcements` (`AuthorId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260212092421_AddAnnouncements') THEN

    CREATE INDEX `IX_announcements_TeamId_CreatedAt` ON `announcements` (`TeamId`, `CreatedAt`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260212092421_AddAnnouncements') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20260212092421_AddAnnouncements', '8.0.0');

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

COMMIT;

