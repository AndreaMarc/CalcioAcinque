-- Migration: MultiTenantSupport
-- Drop unique index on UserId (requires dropping FK first in MySQL)
START TRANSACTION;

-- Check if MultiTenantSupport migration already applied
SET @migrationExists = (SELECT COUNT(*) FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260217141847_MultiTenantSupport');

-- Only apply if not already done
SET @sql1 = IF(@migrationExists = 0, 'ALTER TABLE `players` DROP FOREIGN KEY `FK_players_users_UserId`', 'SELECT 1');
PREPARE stmt FROM @sql1;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql2 = IF(@migrationExists = 0, 'ALTER TABLE `players` DROP INDEX `IX_players_UserId`', 'SELECT 1');
PREPARE stmt FROM @sql2;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql3 = IF(@migrationExists = 0, 'ALTER TABLE `players` ADD INDEX `IX_players_UserId` (`UserId`)', 'SELECT 1');
PREPARE stmt FROM @sql3;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql4 = IF(@migrationExists = 0, 'ALTER TABLE `players` ADD CONSTRAINT `FK_players_users_UserId` FOREIGN KEY (`UserId`) REFERENCES `users` (`Id`) ON DELETE CASCADE', 'SELECT 1');
PREPARE stmt FROM @sql4;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql5 = IF(@migrationExists = 0, 'ALTER TABLE `teams` ADD COLUMN `InviteCode` varchar(20) CHARACTER SET utf8mb4 NULL', 'SELECT 1');
PREPARE stmt FROM @sql5;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql6 = IF(@migrationExists = 0, 'INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`) VALUES (''20260217141847_MultiTenantSupport'', ''8.0.0'')', 'SELECT 1');
PREPARE stmt FROM @sql6;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

COMMIT;

-- Migration: AddMatchTitolo
START TRANSACTION;

SET @migrationExists2 = (SELECT COUNT(*) FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260217145049_AddMatchTitolo');

SET @sql7 = IF(@migrationExists2 = 0, 'ALTER TABLE `matches` ADD COLUMN `Titolo` varchar(255) CHARACTER SET utf8mb4 NULL', 'SELECT 1');
PREPARE stmt FROM @sql7;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql8 = IF(@migrationExists2 = 0, 'INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`) VALUES (''20260217145049_AddMatchTitolo'', ''8.0.0'')', 'SELECT 1');
PREPARE stmt FROM @sql8;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

COMMIT;
