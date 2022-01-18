DROP TABLE `pool`;

CREATE TABLE `pool` (
  `player_id` int(11) NOT NULL,
  `rated` tinyint(4) NOT NULL DEFAULT 1,
  `entered_pool` timestamp NOT NULL DEFAULT current_timestamp(),
  `last_ping` timestamp NOT NULL DEFAULT '1969-12-31 21:00:00',
  `matched_game` int(11) DEFAULT NULL,
  `in_matching_pool` tinyint(4) NOT NULL DEFAULT 1,
  `open_to_public` tinyint(4) NOT NULL DEFAULT 1,
  `private_game_key` varchar(255) DEFAULT NULL,
  `game_speed` enum('standard','lightning') NOT NULL DEFAULT 'standard',
  `game_type` enum('2way','4way') NOT NULL DEFAULT '2way',
  `challenge_player_id` int(11) DEFAULT NULL,
  `matched_player_id` int(11) DEFAULT NULL,
  `matched_player_2_id` int(11) DEFAULT NULL,
  `matched_player_3_id` int(11) DEFAULT NULL,
  `piece_speed` decimal(4,2) NOT NULL DEFAULT 1.00,
  `piece_recharge` decimal(4,2) NOT NULL DEFAULT 10.00
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
