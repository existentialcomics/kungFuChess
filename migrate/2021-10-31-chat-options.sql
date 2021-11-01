alter table players ADD column show_chat ENUM("public", "players", "none") NOT NULL DEFAULT "public";
