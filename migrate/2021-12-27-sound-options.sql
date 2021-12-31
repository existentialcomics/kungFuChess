ALTER TABLE players ADD column game_sounds tinyint DEFAULT 1 NOT NULL AFTER chat_sounds;
ALTER TABLE players ADD column music_sounds tinyint DEFAULT 1 NOT NULL AFTER game_sounds;
