delimiter //
drop trigger if exists t_games_b_insert //

create trigger t_games_b_insert before insert on games
for each row begin
    IF(new.game_speed) = 'lightning' THEN 
        set @white_rating := ( SELECT rating_standard FROM players WHERE player_id = new.white_player ); 
        set @black_rating := ( SELECT rating_standard FROM players WHERE player_id = new.black_player ); 
    ELSE
        set @white_rating := ( SELECT rating_standard FROM players WHERE player_id = new.white_player ); 
        set @black_rating := ( SELECT rating_standard FROM players WHERE player_id = new.black_player ); 
    END IF;

    set new.white_rating= @white_rating;
    set new.black_rating= @black_rating;
end;
//
drop trigger if exists t_games_b_update //

create trigger t_games_b_update before update on games
for each row begin
    IF(new.game_speed) = 'lightning' THEN 
        set @white_rating := ( SELECT rating_standard FROM players WHERE player_id = new.white_player ); 
        set @black_rating := ( SELECT rating_standard FROM players WHERE player_id = new.black_player ); 
    ELSE
        set @white_rating := ( SELECT rating_standard FROM players WHERE player_id = new.white_player ); 
        set @black_rating := ( SELECT rating_standard FROM players WHERE player_id = new.black_player ); 
    END IF;
    set new.white_rating= @white_rating;
    set new.black_rating= @black_rating;
end;
//

delimiter ;
