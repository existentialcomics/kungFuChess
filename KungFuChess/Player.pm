#!/usr/bin/perl
use strict; use warnings;

package KungFuChess::Player;
use JSON::XS;
use UUID::Tiny ':std';
use Data::Dumper;

sub new {
	my $class = shift;

	my $self = {};
	bless( $self, $class );

	if ($self->_init(@_)){
		return $self;
	} else {
		return undef;
	}
}

sub _init {
    my $self = shift;
    my ($data, $dbh) = @_;

    $self->{is_anon} = 0;

    $self->{dbh} = $dbh;

    if (defined($data->{userId})) { 
        return $self->_loadById($data->{userId});
    } elsif (defined($data->{screenname})) { 
        return $self->_loadByScreenname($data->{screenname});
    } elsif (defined($data->{row})) { 
        return $self->_loadByRow($data->{row});
    } elsif (defined($data->{anon})) { 
        return $self->_loadAnonymousUser();
    } elsif (defined($data->{ai})) { 
        return $self->_loadAiUser($data->{auth_token});
    } elsif (defined($data->{auth_token})) { 
        return $self->_loadByAuth($data->{auth_token});
    } else {
        return $self->_loadAnonymousUser();
        #print " player undef\n";
        #return undef;
    }
}

sub getProvisionalFactor {
    my $self = shift;
    my $gameSpeed = shift;
    my $gameType = shift;

    my $gamesPlayed = $self->getGamesPlayed($gameSpeed, $gameType);
    if ($gamesPlayed > 20) {
        return 0;
    }
    return ($gamesPlayed / 20);
}

sub getBelt {
    my $self = shift;
    my $gameSpeed = shift;
    my $gameType  = shift;

    if ($self->{is_anon}) { return 'green'; }

    if (!$gameSpeed) { $gameSpeed = 'standard'; }
    if (!$gameType ) { $gameType  = '2way'; }

    if (! defined( $self->{'rating_' . $gameSpeed})) { 
        return undef;
    }
    my $wayAdd = ($gameType eq '4way' ? '_4way' : '');
    my $rating = $self->{'rating_' . $gameSpeed . $wayAdd};

    # provisional belt
    if ($self->getGamesPlayed($gameSpeed, $gameType) < 20) {
        return 'green';
    }
    return getBeltStatic($rating);
}

### static method that just passes in rating;
sub getBeltStatic {
    my $rating = shift;

    return 'yellow' if ($rating < 1400); 
    return 'orange' if ($rating < 1600); 
    return 'red'    if ($rating < 1800); 
    return 'brown'  if ($rating < 2000); 
    return 'black'  if ($rating < 2200); 
    return 'doubleblack';
}

sub getRating {
    my $self = shift;
    my $gameSpeed = shift;
    my $gameType  = shift;
    if (!$gameSpeed) { $gameSpeed = 'standard'; }
    if (!$gameType ) { $gameType  = '2way'; }

    my $wayAdd = ($gameType eq '4way' ? '_4way' : '');
    return $self->{'rating_' . $gameSpeed . $wayAdd};
}

sub getJsonMsg {
    my $self = shift;

    my $msg = {
        'player_id' => $self->{'player_id'},
        'screenname' => $self->{'screenname'},
        'rating_standard'  => $self->{'rating_standard'},
        'rating_lightning' => $self->{'rating_lightning'},
    };

    return encode_json $msg;
}

sub isAdmin {
    my $self = shift;
    return $self->{screenname} eq 'thebalrog';
}

sub getBestVictory {
    my $self = shift;
    my $gameSpeed = shift;
    my $gameType = shift;

    my @row = $self->{dbh}->selectrow_array(
        "SELECT MAX(rating_before)
            FROM game_log
            WHERE opponent_id = ?
            AND game_speed = ?
            AND game_type = ?
            AND result = 'loss'
            AND rated = 1",
        {},
        $self->{player_id},
        $gameSpeed,
        $gameType ? $gameType : '2way'
    );

    $self->{'best_victory' . $gameSpeed} = $row[0];

    return $self->{'best_victory' . $gameSpeed};
}

sub getWorstDefeat {
    my $self = shift;
    my $gameSpeed = shift;
    my $gameType = shift;

    my @row = $self->{dbh}->selectrow_array(
        "SELECT MIN(rating_before)
            FROM game_log
            WHERE opponent_id = ?
            AND game_speed = ?
            AND game_type = ?
            AND result = 'win'
            AND rated = 1",
        {},
        $self->{player_id},
        $gameSpeed,
        $gameType ? $gameType : '2way'
    );

    $self->{'worst_defeat' . $gameSpeed} = $row[0];

    return $self->{'worst_defeat' . $gameSpeed};
}

sub getHighestRating {
    my $self = shift;
    my $gameSpeed = shift;
    my $gameType = shift;

    my @row = $self->{dbh}->selectrow_array(
        "SELECT MAX(rating_after)
            FROM game_log
            WHERE player_id = ?
            AND game_speed = ?
            AND game_type = ?
            AND rated = 1",
        {},
        $self->{player_id},
        $gameSpeed,
        $gameType ? $gameType : '2way'
    );

    $self->{'highest_rating' . $gameSpeed} = $row[0];

    return $self->{'highest_rating' . $gameSpeed};
}

sub getLowestRating {
    my $self = shift;
    my $gameSpeed = shift;
    my $gameType = shift;

    my @row = $self->{dbh}->selectrow_array(
        "SELECT MIN(rating_after)
            FROM game_log
            WHERE player_id = ?
            AND game_speed = ?
            AND game_type = ?
            AND rated = 1",
        {},
        $self->{player_id},
        $gameSpeed,
        $gameType ? $gameType : '2way'
    );

    $self->{'lowwest_rating' . $gameSpeed} = $row[0];

    return $self->{'lowwest_rating' . $gameSpeed};
}

sub getGamesDrawn {
    my $self = shift;
    my $gameSpeed = shift;
    my $gameType = shift;

    my @row = $self->{dbh}->selectrow_array(
        "SELECT COUNT(*) as games_won
            FROM game_log
            WHERE player_id = ?
            AND game_speed = ?
            AND game_type = ?
            AND result = 'draw'
            AND rated = 1",
        {},
        $self->{player_id},
        $gameSpeed,
        $gameType ? $gameType : '2way'
    );

    $self->{'games_won_' . $gameSpeed} = $row[0];

    return $self->{'games_won_' . $gameSpeed};
}

sub getGamesLost {
    my $self = shift;
    my $gameSpeed = shift;
    my $gameType = shift;

    my @row = $self->{dbh}->selectrow_array(
        "SELECT COUNT(*) as games_won
            FROM game_log
            WHERE player_id = ?
            AND game_speed = ?
            AND game_type = ?
            AND result = 'loss'
            AND rated = 1",
        {},
        $self->{player_id},
        $gameSpeed,
        $gameType ? $gameType : '2way'
    );

    $self->{'games_won_' . $gameSpeed} = $row[0];

    return $self->{'games_won_' . $gameSpeed};
}

sub getGamesWon {
    my $self = shift;
    my $gameSpeed = shift;
    my $gameType = shift;

    my @row = $self->{dbh}->selectrow_array(
        "SELECT COUNT(*) as games_won
            FROM game_log
            WHERE player_id = ?
            AND game_speed = ?
            AND game_type = ?
            AND result = 'win'
            AND rated = 1",
        {},
        $self->{player_id},
        $gameSpeed,
        $gameType ? $gameType : '2way'
    );

    $self->{'games_won_' . $gameSpeed} = $row[0];

    return $self->{'games_won_' . $gameSpeed};
}

sub getGamesPlayed {
    my $self = shift;
    my $gameSpeed = shift;
    my $gameType = shift;

    my @row = $self->{dbh}->selectrow_array(
        "SELECT COUNT(*) as games_played 
            FROM game_log
            WHERE player_id = ?
            AND game_speed = ?
            AND game_type = ?
            AND rated = 1",
        {},
        $self->{player_id},
        $gameSpeed,
        $gameType ? $gameType : '2way'
    );

    $self->{'games_played_' . $gameSpeed} = $row[0];

    return $self->{'games_played_' . $gameSpeed};
}

sub _loadByRow {
    my $self = shift;
    my $row = shift;
    
    if (! defined($row)) {
        return $self->_loadAnonymousUser();
    }

    my %excludedFields = (
        'password' => 1
    );
    foreach my $key (keys %$row) {
        if (! $excludedFields{$key} ) {
            $self->{$key} = $row->{$key};
        }
    }

    return $self;
}

sub _loadAnonymousUser {
    my $self = shift;

    $self->{player_id} = -1;
    $self->{screenname} = 'anonymous';
    $self->{rating_standard} = 0;
    $self->{rating_lighting} = 0;
    $self->{is_anon} = 1;
    $self->{'auth_token'} = create_uuid_as_string();
}

sub _loadAiUser {
    my $self = shift;
    my $authToken = shift;

    $self->{player_id} = -2;
    $self->{screenname} = 'ai';
    $self->{rating_standard} = 0;
    $self->{rating_lighting} = 0;
    $self->{is_anon} = 1;
    $self->{'auth_token'} = $authToken ? $authToken : create_uuid_as_string();
}

sub _loadById {
    my $self = shift;
    my $userId = shift;

    my $profileRows = $self->{dbh}->selectall_arrayref('
        SELECT *
        FROM players
        WHERE player_id = ?',
        { 'Slice' => {} },
        $userId
    );

    my $row = shift @$profileRows;
    return $self->_loadByRow($row);
}


sub _loadByAuth {
    my $self = shift;
    my $authToken = shift;

    my $profileRows = $self->{dbh}->selectall_arrayref('
        SELECT *
        FROM players
        WHERE auth_token = ?',
        { 'Slice' => {} },
        $authToken
    );

    my $row = shift @$profileRows;
    return $self->_loadByRow($row);
}

### get profile stats
sub _loadByScreenname {
    my $self = shift;
    my $screenname = shift;

    my $profileRows = $self->{dbh}->selectall_arrayref('
        SELECT *
        FROM players
        WHERE screenname = ?',
        { 'Slice' => {} },
        $screenname
    );

    my $row = shift @$profileRows;
    return $self->_loadByRow($row);
}

1;
