ALTER TABLE `guest_players` ADD INDEX `guest_last_seen_idx` (`last_seen`);
ALTER TABLE `players` ADD INDEX `players_last_seen_idx` (`last_seen`);
ALTER TABLE `pool` ADD INDEX `pool_last_ping_idx` (`last_ping`);

ALTER TABLE guest_players DROP COLUMN last_login;
ALTER TABLE guest_players ADD COLUMN `date_created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP;
