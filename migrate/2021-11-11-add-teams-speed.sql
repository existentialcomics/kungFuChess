alter table games add column piece_speed DECIMAL(4, 2) DEFAULT 1 NOT NULL;
alter table games add column piece_recharge DECIMAL(4, 2) DEFAULT 1 NOT NULL;
alter table games add column teams varchar(20) DEFAULT NULL;

update players SET games_played_standard_4way = games_won_standard_4way + games_lost_standard_4way + games_drawn_standard_4way;
update players SET games_played_lightning_4way = games_won_lightning_4way + games_lost_lightning_4way + games_drawn_lightning_4way;
update players SET rating_standard_4way = rating_standard, rating_lightning_4way = rating_lightning;
