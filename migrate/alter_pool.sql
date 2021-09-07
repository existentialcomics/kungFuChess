ALTER TABLE pool
  DROP INDEX `player_id`;
alter table pool ADD COLUMN average_rating int(11) DEFAULT 1400;
