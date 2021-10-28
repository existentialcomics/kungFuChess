alter table games ADD COLUMN server_auth_key varchar(90) DEFAULT NULL;
CREATE INDEX game_auth_idx ON games (server_auth_key(90));
