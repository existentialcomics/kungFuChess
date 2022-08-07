-- MySQL dump 10.13  Distrib 8.0.30, for Linux (x86_64)
--
-- Host: localhost    Database: kungfuchess
-- ------------------------------------------------------
-- Server version	8.0.30-0ubuntu0.20.04.2

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `chat_log`
--

DROP TABLE IF EXISTS `chat_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `chat_log` (
  `chat_log_id` int NOT NULL AUTO_INCREMENT,
  `game_id` int DEFAULT NULL,
  `comment_text` mediumtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `player_id` int DEFAULT NULL,
  `player_color` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `post_time` datetime NOT NULL,
  PRIMARY KEY (`chat_log_id`),
  KEY `game_id` (`game_id`)
) ENGINE=InnoDB AUTO_INCREMENT=50575 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `game_log`
--

DROP TABLE IF EXISTS `game_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `game_log` (
  `game_log_id` int NOT NULL AUTO_INCREMENT,
  `game_id` int NOT NULL,
  `player_id` int NOT NULL,
  `opponent_id` int NOT NULL,
  `opponent_2_id` int DEFAULT NULL,
  `opponent_3_id` int DEFAULT NULL,
  `game_speed` enum('standard','lightning') NOT NULL,
  `game_type` enum('2way','4way') NOT NULL,
  `result` enum('win','draw','loss') NOT NULL,
  `rating_before` int DEFAULT NULL,
  `rating_after` int DEFAULT NULL,
  `rated` tinyint NOT NULL DEFAULT '1',
  `time_ended` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`game_log_id`),
  KEY `player_id_idx` (`player_id`),
  KEY `opponent_id_idx` (`opponent_id`),
  KEY `gameChatIdx` (`game_id`),
  KEY `playerChatIdx` (`player_id`)
) ENGINE=InnoDB AUTO_INCREMENT=118953 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `games`
--

DROP TABLE IF EXISTS `games`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `games` (
  `game_id` int NOT NULL AUTO_INCREMENT,
  `game_speed` enum('standard','lightning') NOT NULL DEFAULT 'standard',
  `game_type` enum('2way','4way') NOT NULL DEFAULT '2way',
  `time_created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `time_ended` datetime DEFAULT NULL,
  `white_player` int DEFAULT NULL,
  `black_player` int DEFAULT NULL,
  `red_player` int DEFAULT NULL,
  `green_player` int DEFAULT NULL,
  `white_rating` int DEFAULT NULL,
  `black_rating` int DEFAULT NULL,
  `red_rating` int DEFAULT NULL,
  `green_rating` int DEFAULT NULL,
  `result` varchar(80) DEFAULT NULL,
  `score` varchar(40) DEFAULT NULL,
  `status` enum('waiting to begin','active','finished') NOT NULL DEFAULT 'waiting to begin',
  `rated` tinyint DEFAULT '1',
  `white_anon_key` varchar(90) DEFAULT NULL,
  `black_anon_key` varchar(90) DEFAULT NULL,
  `red_anon_key` varchar(90) DEFAULT NULL,
  `green_anon_key` varchar(90) DEFAULT NULL,
  `final_position` text,
  `game_log` mediumtext,
  `ws_server` varchar(255) DEFAULT NULL,
  `server_auth_key` varchar(90) DEFAULT NULL,
  `speed_advantage` varchar(40) DEFAULT NULL,
  `piece_speed` decimal(4,2) NOT NULL DEFAULT '1.00',
  `piece_recharge` decimal(4,2) NOT NULL DEFAULT '1.00',
  `teams` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`game_id`),
  KEY `game_auth_idx` (`server_auth_key`),
  KEY `white_pl_idx` (`white_player`),
  KEY `black_pl_idx` (`black_player`),
  KEY `red_pl_idx` (`red_player`),
  KEY `green_pl_idx` (`green_player`)
) ENGINE=InnoDB AUTO_INCREMENT=75502 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
ALTER DATABASE `kungfuchess` CHARACTER SET latin1 COLLATE latin1_swedish_ci ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb3 */ ;
/*!50003 SET character_set_results = utf8mb3 */ ;
/*!50003 SET collation_connection  = utf8mb3_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `t_games_b_insert` BEFORE INSERT ON `games` FOR EACH ROW begin
    IF(new.game_speed) = 'lightning' THEN 
        set @white_rating := ( SELECT rating_standard FROM players WHERE player_id = new.white_player ); 
        set @black_rating := ( SELECT rating_standard FROM players WHERE player_id = new.black_player ); 
    ELSE
        set @white_rating := ( SELECT rating_standard FROM players WHERE player_id = new.white_player ); 
        set @black_rating := ( SELECT rating_standard FROM players WHERE player_id = new.black_player ); 
    END IF;

    set new.white_rating= @white_rating;
    set new.black_rating= @black_rating;
end */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
ALTER DATABASE `kungfuchess` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ;
ALTER DATABASE `kungfuchess` CHARACTER SET latin1 COLLATE latin1_swedish_ci ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb3 */ ;
/*!50003 SET character_set_results = utf8mb3 */ ;
/*!50003 SET collation_connection  = utf8mb3_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `t_games_b_update` BEFORE UPDATE ON `games` FOR EACH ROW begin
    IF(new.game_speed) = 'lightning' THEN 
        set @white_rating := ( SELECT rating_standard FROM players WHERE player_id = new.white_player ); 
        set @black_rating := ( SELECT rating_standard FROM players WHERE player_id = new.black_player ); 
    ELSE
        set @white_rating := ( SELECT rating_standard FROM players WHERE player_id = new.white_player ); 
        set @black_rating := ( SELECT rating_standard FROM players WHERE player_id = new.black_player ); 
    END IF;
    set new.white_rating= @white_rating;
    set new.black_rating= @black_rating;
end */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
ALTER DATABASE `kungfuchess` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ;

--
-- Table structure for table `player_log`
--

DROP TABLE IF EXISTS `player_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `player_log` (
  `player_log_id` int NOT NULL AUTO_INCREMENT,
  `player_id` int DEFAULT NULL,
  `ip_address` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `action` enum('login success','login attempt') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `time_created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`player_log_id`),
  KEY `player_id` (`player_id`,`action`,`time_created`),
  KEY `ip_address` (`ip_address`,`action`,`time_created`)
) ENGINE=InnoDB AUTO_INCREMENT=26 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `players`
--

DROP TABLE IF EXISTS `players`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `players` (
  `player_id` int NOT NULL AUTO_INCREMENT,
  `screenname` varchar(30) NOT NULL,
  `password` varchar(255) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `rating_standard` int NOT NULL DEFAULT '1600',
  `rating_lightning` int NOT NULL DEFAULT '1600',
  `rating_standard_4way` int NOT NULL DEFAULT '1600',
  `rating_lightning_4way` int NOT NULL DEFAULT '1600',
  `games_played_standard` int NOT NULL DEFAULT '0',
  `games_played_lightning` int NOT NULL DEFAULT '0',
  `games_played_standard_4way` int NOT NULL DEFAULT '0',
  `games_played_lightning_4way` int NOT NULL DEFAULT '0',
  `games_won_standard` int NOT NULL DEFAULT '0',
  `games_won_lightning` int NOT NULL DEFAULT '0',
  `games_won_standard_4way` int NOT NULL DEFAULT '0',
  `games_won_lightning_4way` int NOT NULL DEFAULT '0',
  `games_drawn_standard` int NOT NULL DEFAULT '0',
  `games_drawn_lightning` int NOT NULL DEFAULT '0',
  `games_drawn_standard_4way` int NOT NULL DEFAULT '0',
  `games_drawn_lightning_4way` int NOT NULL DEFAULT '0',
  `games_lost_standard` int NOT NULL DEFAULT '0',
  `games_lost_lightning` int NOT NULL DEFAULT '0',
  `games_lost_standard_4way` int NOT NULL DEFAULT '0',
  `games_lost_lightning_4way` int NOT NULL DEFAULT '0',
  `date_created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_login` timestamp NOT NULL DEFAULT '1970-01-01 05:00:00',
  `last_seen` timestamp NOT NULL DEFAULT '1970-01-01 05:00:00',
  `auth_token` varchar(255) DEFAULT NULL,
  `default_minimum_rating` int DEFAULT '-200',
  `default_maximum_rating` int DEFAULT '200',
  `show_chat` enum('public','players','none') NOT NULL DEFAULT 'public',
  `chat_sounds` tinyint NOT NULL DEFAULT '0',
  `game_sounds` tinyint NOT NULL DEFAULT '1',
  `music_sounds` tinyint NOT NULL DEFAULT '1',
  `ip_address` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`player_id`),
  UNIQUE KEY `screenname` (`screenname`)
) ENGINE=InnoDB AUTO_INCREMENT=4059 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `pool`
--

DROP TABLE IF EXISTS `pool`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `pool` (
  `player_id` int NOT NULL,
  `rated` tinyint NOT NULL DEFAULT '1',
  `entered_pool` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_ping` timestamp NOT NULL DEFAULT '1970-01-01 02:00:00',
  `matched_game` int DEFAULT NULL,
  `in_matching_pool` tinyint NOT NULL DEFAULT '1',
  `open_to_public` tinyint NOT NULL DEFAULT '1',
  `private_game_key` varchar(255) DEFAULT NULL,
  `game_speed` enum('standard','lightning') NOT NULL DEFAULT 'standard',
  `game_type` enum('2way','4way') NOT NULL DEFAULT '2way',
  `challenge_player_id` int DEFAULT NULL,
  `matched_player_id` int DEFAULT NULL,
  `matched_player_2_id` int DEFAULT NULL,
  `matched_player_3_id` int DEFAULT NULL,
  `piece_speed` decimal(4,2) NOT NULL DEFAULT '1.00',
  `piece_recharge` decimal(4,2) NOT NULL DEFAULT '10.00'
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `session`
--

DROP TABLE IF EXISTS `session`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `session` (
  `sid` varchar(40) NOT NULL,
  `data` text,
  `expires` int unsigned NOT NULL,
  PRIMARY KEY (`sid`),
  UNIQUE KEY `sid` (`sid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2022-08-07 16:24:35
