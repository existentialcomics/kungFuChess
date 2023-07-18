DROP TABLE IF EXISTS achievement_types;
CREATE TABLE `achievement_types` (
  `achievement_type_id` int NOT NULL AUTO_INCREMENT,
  `image` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `description` TEXT NOT NULL,
  `group_name` varchar(255) NOT NULL,
   PRIMARY KEY (`achievement_type_id`)
  ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS achievements;
CREATE TABLE `achievements` (
  `achievement_id` int NOT NULL AUTO_INCREMENT,
  `achievement_type_id` int NOT NULL,
  `player_id` int NOT NULL,
  `time_created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
   PRIMARY KEY (`achievement_id`),
   UNIQUE KEY `player_achv_uniq` (`achievement_type_id`,`player_id`)
  ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;

insert into achievement_types (image, name, description, group_name) VALUES ('achievements/greenbelt.png', 'Standard Green Belt', 'Create an account', 'belt_std'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/yellowbelt.png', 'Standard Yellow Belt', 'Play 20 rating games in Standard', 'belt_std'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/orangebelt.png', 'Standard Orange Belt', 'Achieve a 1400 rating in Standard', 'belt_std'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/redbelt.png', 'Standard Red Belt', 'Achieve a 1600 rating in Standard', 'belt_std'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/brownbelt.png', 'Standard Brown Belt', 'Achieve a 1800 rating in Standard', 'belt_std'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/blackbelt.png', 'Standard Black Belt', 'Achieve a 2000 rating in Standard', 'belt_std'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/doubleblackbelt.png', 'Standard Double Black Belt', 'Achieve a 2200 rating in Standard', 'belt_std'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/tripleblackbelt.png', 'Standard Triple Black Belt', 'Achieve a 2400 rating in Standard', 'belt_std'); 

insert into achievement_types (image, name, description, group_name) VALUES ('achievements/lightning_yellowbelt.png', 'Lightning Yellow Belt', 'Play 20 rating games in Lightning', 'belt_lit'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/lightning_orangebelt.png', 'Lightning Orange Belt', 'Achieve a 1400 rating in Lightning', 'belt_lit'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/lightning_redbelt.png', 'Lightning Red Belt', 'Achieve a 1600 rating in Lightning', 'belt_lit'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/lightning_brownbelt.png', 'Lightning Brown Belt', 'Achieve a 1800 rating in Lightning', 'belt_lit'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/lightning_blackbelt.png', 'Lightning Black Belt', 'Achieve a 2000 rating in Lightning', 'belt_lit'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/lightning_doubleblackbelt.png', 'Lightning Double Black Belt', 'Achieve a 2200 rating in Lightning', 'belt_lit'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/lightning_tripleblackbelt.png', 'Lightning Triple Black Belt', 'Achieve a 2400 rating in Lightning', 'belt_lit'); 

insert into achievement_types (image, name, description, group_name) VALUES ('achievements/4way_yellowbelt.png', '4way Yellow Belt', 'Play 20 rating games in 4way lightning', 'belt_4way'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/4way_orangebelt.png', '4way Orange Belt', 'Achieve a 1400 rating in 4way Lightning', 'belt_4way'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/4way_redbelt.png', '4way Red Belt', 'Achieve a 1600 rating in 4way Lightning', 'belt_4way'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/4way_brownbelt.png', '4way Brown Belt', 'Achieve a 1800 rating in 4way Lightning', 'belt_4way'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/4way_blackbelt.png', '4way Black Belt', 'Achieve a 2000 rating in 4way Lightning', 'belt_4way'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/4way_doubleblackbelt.png', '4way Double Black Belt', 'Achieve a 2200 rating in 4way Lightning', 'belt_4way'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/4way_tripleblackbelt.png', '4way Triple Black Belt', 'Achieve a 2400 rating in 4way Lightning', 'belt_4way'); 

insert into achievement_types (image, name, description, group_name) VALUES ('achievements/dodge.png', 'Dodge', 'Dodge an attack', 'tactic'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/anticipate.png', 'Anticipate', 'Anticipate an attack', 'tactic'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/diversion.png', 'Diversion', 'Create a diversion', 'tactic'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/combo.png', 'Two Piece Combo', 'Execute a combo attack of two pieces', 'tactic'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/3combo.png', 'Three Piece Combo', 'Execute a combo attack of three pieces', 'tactic'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/4combo.png', 'Four Piece Combo', 'Execute a combo attack of four pieces', 'tactic'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/5combo.png', 'Five Piece Combo', 'Execute a combo attack of five pieces', 'tactic'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/peekaboo.png', 'Peekaboo', 'Execute a peekaboo attack', 'tactic'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/sweep.png', 'Sweep', 'Sweep a piece', 'tactic'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/block.png', 'Block', 'Block an enemy attack', 'tactic'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/feint.png', 'Feint', 'Execute a fient', 'tactic'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/punchthrough.png', 'Punch Through', 'Execute a punch through attack', 'tactic'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/selfkill.png', 'Self Kill', 'Kill your own piece', 'tactic'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/jedi.png', 'Jedi Dodge', 'Execute a jedi dodge', 'tactic'); 

insert into achievement_types (image, name, description, group_name) VALUES ('achievements/ai_std_easy.png', 'AI Standard Easy', 'Beat AI on Standard Easy', 'ai'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/ai_std_medium.png', 'AI Standard Medium', 'Beat AI on Standard Easy', 'ai'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/ai_std_hard.png', 'AI Standard Hard', 'Beat AI on Standard Hard', 'ai'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/ai_std_berserk.png', 'AI Standard Berserk', 'Beat AI on Standard Berserk', 'ai'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/ai_std_crane.png', 'AI Standard Crane', 'Beat AI on Standard Crane', 'ai'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/ai_std_turtle.png', 'AI Standard Turtle', 'Beat AI on Standard Turtle', 'ai'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/ai_std_centipede.png', 'AI Standard Centipede', 'Beat AI on Standard Centipede', 'ai'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/ai_std_dragon.png', 'AI Standard Dragon', 'Beat AI on Standard Dragon', 'ai'); 

insert into achievement_types (image, name, description, group_name) VALUES ('achievements/ai_light_easy.png', 'AI Lightning Easy', 'Beat AI on Lightning Easy', 'ai'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/ai_light_medium.png', 'AI Lightning Medium', 'Beat AI on Lightning Medium', 'ai'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/ai_light_hard.png', 'AI Lightning Hard', 'Beat AI on Lightning Hard', 'ai'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/ai_light_berserk.png', 'AI Lightning Berserk', 'Beat AI on Lightning Beserk', 'ai'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/ai_light_crane.png', 'AI Lightning Crane', 'Beat AI on Lightning Crane', 'ai'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/ai_light_turtle.png', 'AI Lightning Turtle', 'Beat AI on Lightning Turtle', 'ai'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/ai_light_centipede.png', 'AI Lightning Centipede', 'Beat AI on Lightning Centipede', 'ai'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/ai_light_dragon.png', 'AI Lightning Dragon', 'Beat AI on Lightning Dragon', 'ai'); 

insert into achievement_types (image, name, description, group_name) VALUES ('achievements/ai_light_4way_easy.png', 'AI 4way Easy 4way', 'Beat AI on 4way Easy', 'ai'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/ai_light_4way_medium.png', 'AI 4way Medium 4way', 'Beat AI on 4way Medium', 'ai'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/ai_light_4way_hard.png', 'AI 4way Hard 4way', 'Beat AI on 4way Hard', 'ai'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/ai_light_4way_berserk.png', 'AI 4way Berserk 4way', 'Beat AI on 4way Berserk', 'ai'); 

insert into achievement_types (image, name, description, group_name) VALUES ('achievements/masterbelt.png', 'Kung Fu Master', 'Collect all belts', 'master'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/masterTactics.png', 'Tactics Master', 'Perform all tactics', 'master'); 
insert into achievement_types (image, name, description, group_name) VALUES ('achievements/ai_master.png', 'AI Master', 'Beat all AI modes', 'master'); 
