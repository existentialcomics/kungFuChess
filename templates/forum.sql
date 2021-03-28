DROP TABLE IF EXISTS `forum_post`;
CREATE TABLE `forum_post` (
  `forum_post_id` int(11) NOT NULL AUTO_INCREMENT,
  `category` enum('chess','feedback', 'off-topic') NOT NULL,
  `post_title` varchar(255) NOT NULL,
  `post_text` TEXT NOT NULL,
  `player_id` int(11) NOT NULL,
  `post_time` datetime NOT NULL,
  PRIMARY KEY (`forum_post_id`)
);

CREATE TABLE `forum_comment` (
  `forum_comment_id` int(11) NOT NULL AUTO_INCREMENT,
  `forum_post_id` int(11) NOT NULL,
  `comment_text` TEXT NOT NULL,
  `player_id` int(11) NOT NULL,
  `post_time` datetime NOT NULL,
  PRIMARY KEY (`forum_comment_id`)
);

CREATE TABLE `chat_log` (
  `chat_log_id` int(11) NOT NULL AUTO_INCREMENT,
  `game_id` int(11) DEFAULT NULL,
  `comment_text` TEXT NOT NULL,
  `player_id` int(11) NOT NULL,
  `post_time` datetime NOT NULL,
  PRIMARY KEY (`chat_log_id`)
);
