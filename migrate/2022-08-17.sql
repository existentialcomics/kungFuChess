CREATE TABLE guest_players (
 `screenname` varchar(30) NOT NULL,
 `last_login` timestamp NOT NULL DEFAULT '1969-12-31 21:00:00',
 `last_seen` timestamp NOT NULL DEFAULT '1969-12-31 21:00:00',
 `auth_token` varchar(255) NOT NULL,
  KEY `screen_anon_key` (`screenname`),
  UNIQUE KEY `auth_token_kx` (`auth_token`)
);

DROP TABLE pool;

CREATE TABLE `pool` (
  `player_id` int NOT NULL,
  `player_auth` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `rated` tinyint NOT NULL DEFAULT '1',
  `entered_pool` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_ping` timestamp NOT NULL DEFAULT '1969-12-31 18:00:00',
  `matched_game` int DEFAULT NULL,
  `in_matching_pool` tinyint NOT NULL DEFAULT '1',
  `open_to_public` tinyint NOT NULL DEFAULT '1',
  `private_game_key` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `game_speed` enum('standard','lightning') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'standard',
  `game_type` enum('2way','4way') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '2way',
  `challenge_player_id` int DEFAULT NULL,
  `matched_player_id` int DEFAULT NULL,
  `matched_player_auth` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `piece_speed` decimal(4,2) NOT NULL DEFAULT '1.00',
  `piece_recharge` decimal(4,2) NOT NULL DEFAULT '10.00'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ;


alter table `chat_log` ADD `screenname` varchar(30) NOT NULL AFTER player_id;
DELETE FROM chat_log WHERE player_id < 0;

UPDATE chat_log SET screenname = (SELECT screenname FROM players WHERE players.player_id = chat_log.player_id);
