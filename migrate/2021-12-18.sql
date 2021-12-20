ALTER TABLE players ADD column chat_sounds tinyint DEFAULT 0 NOT NULL AFTER show_chat;
CREATE INDEX gameChatIdx ON game_log (game_id);
CREATE INDEX playerChatIdx ON game_log (player_id);
