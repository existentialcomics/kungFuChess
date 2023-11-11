package KungFuChess::Game;
use strict;
use warnings;
use Time::HiRes qw(time);
use JSON::XS;
use Data::Dumper;

### this is a representation of the game states only, it doesn't know about any of the pieces, that is handled by GameServer.pm
### possible this could go away and it could all be done in mysql

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
    my $row = shift;
    $self->{id} = $row->{game_id};

    $self->{game_type} = $row->{game_type};   # 2way or 4way
    $self->{teams} = $row->{teams};

    $self->{playersByAuth} = {};
    $self->{playersConn}   = {};

    $self->{watchers} = [];

    $self->{readyToPlay}   = 0;
    $self->{auth}          = $row->{server_auth_key};
    $self->{serverConn}    = 0;

    $self->{white}->{alive} = 1;
    $self->{black}->{alive} = 1;
    if ($row->{game_type} eq '4way') {
        $self->{red}->{alive} = 1;
        $self->{green}->{alive} = 1;
    } else {
        $self->{red}->{alive} = 0;
        $self->{green}->{alive} = 0;
    }

    $self->{bothReady}    = 0;
    $self->{whiteReady}    = 0;
    $self->{blackReady}    = 0;
    $self->{redReady}      = 0;
    $self->{greenReady}    = 0;

    $self->{white}->{draw} = 0;
    $self->{black}->{draw} = 0;
    $self->{red}->{draw}   = 0;
    $self->{green}->{draw} = 0;

    $self->{white}->{isAi} = $row->{white_player} < 0;
    $self->{black}->{isAi} = $row->{black_player} < 0;
    $self->{red}->{isAi}   = $row->{red_player} < 0;
    $self->{green}->{isAi} = $row->{green_player} < 0;

    $self->{gameLog} = [];
    $self->{chatLog} = [];
    $self->{gameStartTime} = time();

    return 1;
}

sub isAlive {
    my $self  = shift;
    my $color = shift;
    if ($color eq 'both') {
        return 1;
    }
    return $self->{$color}->{alive};
}

sub setTeams {
    my $self  = shift;
    my $teams = shift;

    $self->{teams} = $teams;
}

# returns true if no human players remain
sub onlyAiLeft {
    my $self = shift;
    return ( 
        ($self->{white}->{alive} == 0 || $self->{white}->{isAi} == 1) &&
        ($self->{black}->{alive} == 0 || $self->{black}->{isAi} == 1) &&
        ($self->{red}->{alive} == 0 || $self->{red}->{isAi} == 1) &&
        ($self->{green}->{alive} == 0 || $self->{green}->{isAi} == 1)
    );
}

### returns false for game is still active
#   otherwise returns the score
sub killPlayer {
    my $self  = shift;
    my $color = shift;
    if ($color eq 'both') {
        $self->{black}->{alive} = 0;
        $self->{white}->{alive} = 0;
        $self->{red}->{alive}   = 0;
        $self->{green}->{alive} = 0;
    } else {
        $self->{$color}->{alive} = 0;
    }

    if ($self->{teams}) {
        my ($whiteTeam, $blackTeam, $redTeam, $greenTeam) = split("-", $self->{teams});
        my %teamsRemaining = ();
        if ($self->{white}->{alive} == 1) {
            $teamsRemaining{$whiteTeam}++
        }
        if ($self->{black}->{alive} == 1) {
            $teamsRemaining{$blackTeam}++
        }
        if ($self->{red}->{alive} == 1) {
            $teamsRemaining{$redTeam}++
        }
        if ($self->{green}->{alive} == 1) {
            $teamsRemaining{$greenTeam}++
        }
        if (keys %teamsRemaining == 1) {
            if ($self->{white}->{alive} == 1) {
                return
                    ($whiteTeam eq $whiteTeam ? '1' : '0') . '-' .
                    ($whiteTeam eq $blackTeam ? '1' : '0') . '-' .
                    ($whiteTeam eq $redTeam   ? '1' : '0') . '-' .
                    ($whiteTeam eq $greenTeam ? '1' : '0');
            } elsif ($self->{black}->{alive} == 1) {
                return
                    ($blackTeam eq $whiteTeam ? '1' : '0') . '-' .
                    ($blackTeam eq $blackTeam ? '1' : '0') . '-' .
                    ($blackTeam eq $redTeam   ? '1' : '0') . '-' .
                    ($blackTeam eq $greenTeam ? '1' : '0');
            } elsif ($self->{red}->{alive} == 1) {
                return
                    ($redTeam eq $whiteTeam ? '1' : '0') . '-' .
                    ($redTeam eq $blackTeam ? '1' : '0') . '-' .
                    ($redTeam eq $redTeam   ? '1' : '0') . '-' .
                    ($redTeam eq $greenTeam ? '1' : '0');
            } elsif ($self->{green}->{alive} == 1) {
                return
                    ($greenTeam eq $whiteTeam ? '1' : '0') . '-' .
                    ($greenTeam eq $blackTeam ? '1' : '0') . '-' .
                    ($greenTeam eq $redTeam   ? '1' : '0') . '-' .
                    ($greenTeam eq $greenTeam ? '1' : '0');
            }

            ### none are alive? shouldn't ever happen
            return 0;
        } else {
            return 0;
        } 
    }

    if ($self->{white}->{alive} + 
        $self->{black}->{alive} + 
        $self->{red}->{alive} + 
        $self->{green}->{alive} <= 1
    ) {
        if ($self->{game_type} eq '4way') {
            if ($self->{white}->{alive} == 1) {
                return '1-0-0-0';
            } elsif ($self->{black}->{alive} == 1) {
                return '0-1-0-0';
            } elsif ($self->{red}->{alive} == 1) {
                return '0-0-1-0';
            } elsif ($self->{green}->{alive} == 1) {
                return '0-0-0-1';
            } else { ### no one is alive, practice abort?
                return '0-1-2-3';
            }
        } else {
            if ($self->{white}->{alive} == 1) {
                return '1-0';
            } elsif ($self->{black}->{alive} == 1) {
                return '0-1';
            } else { ### no one is alive, practice abort?
                return '0-0';
            }
        }
        ### shouldn't get here
    }
    return 0;
}

sub setServerConnection {
    my $self = shift;
    my $conn = shift;

    $self->{serverConn} = $conn;
}

sub serverReady {
    my $self = shift;
    return $self->{serverConn};
}

sub addConnection {
    my $self = shift;
    my ($connId, $conn) = @_;

    $self->{playersConn}->{$connId} = $conn;
}

sub removeConnection {
    my $self = shift;
    my $connId = shift;

    delete $self->{playersConn}->{$connId};
}

### returns positive number if all players are ready for how many seconds until game begins
sub playerReady {
    my $self = shift;
    my $msg = shift;

    my $color = $self->authMove($msg);
    if ($self->{readyToPlay} > 0) {
        return 0;
    }
    if ($color){
        my $readyMsg = {
            'c' => 'playerReady',
            'color' => $color
        };
        if ($self->{"${color}Ready"} == 0) {
            $self->playerBroadcast($readyMsg);
        }
        if ($color eq 'white' || $color eq 'both'){
            $self->{whiteReady} = time();
        } 
        if($color eq 'black' || $color eq 'both'){
            $self->{blackReady} = time();
        }
        if($color eq 'red'   || $color eq 'both'){
            $self->{redReady} = time();
        }
        if($color eq 'green'   || $color eq 'both'){
            $self->{greenReady} = time();
        }
        if (
            (($self->{redReady} && $self->{greenReady}) || ($self->{game_type} ne '4way'))
            && ($self->{whiteReady} && $self->{blackReady})
        ) {
            $self->{readyToPlay} = time + 3;
            my $msg = {
                'c' => 'gameBegins',
                'seconds' => 3,
                'teams' => $self->{teams},
            };
            $self->serverBroadcast($msg);
            $self->playerBroadcast($msg);
            return 3;
        }
    }
    return 0;
}

sub clearDraws {
    my $self = shift;

    $self->{white}->{draw} = 0;
    $self->{black}->{draw} = 0;
    $self->{red}->{draw}   = 0;
    $self->{green}->{draw} = 0;
}

### revokes a draw
sub playerRevokeDraw {
    my $self = shift;
    my $msg = shift;

    my $color = $self->authMove($msg);
    if ($color){
        if ($color eq 'white'){
            $self->{white}->{draw} = 0;
        } elsif($color eq 'black'){
            $self->{black}->{draw} = 0;
        } elsif($color eq 'red'){
            $self->{red}->{draw} = 0;
        } elsif($color eq 'green'){
            $self->{green}->{draw} = 0;
        }
    }
    return 0;
}

### returns positive number if all players pressed draw
sub playerDraw {
    my $self = shift;
    my $msg = shift;

    my $color = $self->authMove($msg);
    if ($color){
        if ($color eq 'white' || $color eq 'both'){
            $self->{white}->{draw} = time();
        } elsif($color eq 'black' || $color eq 'both'){
            $self->{black}->{draw} = time();
        } elsif($color eq 'red' || $color eq 'both'){
            $self->{red}->{draw} = time();
        } elsif($color eq 'green' || $color eq 'both'){
            $self->{green}->{draw} = time();
        }
        if ($self->{game_type} eq '4way') {
            if (   $self->{white}->{draw}
                && $self->{black}->{draw}
                && $self->{red}->{draw}
                && $self->{green}->{draw}
            ) {
                return 
                    ($self->{white}->{alive} ? '0.5' : '0') . '-' .
                    ($self->{black}->{alive} ? '0.5' : '0') . '-' .
                    ($self->{red}->{alive}   ? '0.5' : '0') . '-' .
                    ($self->{green}->{alive} ? '0.5' : '0');
            }

        } else {
            if ($self->{white}->{draw} && $self->{black}->{draw}) {
                return '0.5-0.5';
            }
        }
    }
    return 0;
}

sub gameBegan {
    my $self = shift;
    return ($self->{readyToPlay} != 0 && $self->{readyToPlay} < time());
}

# returns which color the player is authed to move
sub authMove {
    my $self = shift;
    my $msg = shift;

    return 0 if (! defined($msg->{auth}));
    return 0 if (! defined($self->{playersByAuth}->{$msg->{auth}}));
    return $self->{playersByAuth}->{$msg->{auth}};
}

sub serverBroadcast {
    my $self = shift;
    my $msg = shift;
    $self->{serverConn}->send(encode_json $msg);
}

# no need to save these to the log in interest of space
my %excludeFromLog = (
    'switch' => 1,
    'chat' => 1,
    'gamechat' => 1,
    'globalchat' => 1,
    'refresh' => 1,
    'serverping' => 1,
    'readyToRematch' => 1,
    'readyToBegin' => 1,
    'ping' => 1,
    'pong' => 1,
    'serverping' => 1,
    'playerjoined' => 1,
    'requestDraw' => 1,
    'revokeDraw' => 1,
);

sub playerBroadcast {
    my $self = shift;
    my $msg = shift;

    delete $msg->{auth};
    my $msgConnId = $msg->{connId};
    delete $msg->{connId};

    foreach my $connId (keys %{ $self->{playersConn}}) {
        my $conn = $self->{playersConn}->{$connId};
        eval {
            if (! defined($msgConnId) || ($msgConnId eq $connId)) {
                if ($conn) {
                    $conn->send(encode_json $msg);
                }
            }
        };
    }

    if ($msg->{c} eq 'chat') {
        push (@{$self->{chatLog}},
        {
            'time' => time(),
            'msg' => $msg
        });
    }
    if (! $excludeFromLog{$msg->{c}}) {
        push (@{$self->{gameLog}}, 
        {
            'time' => time() - $self->{gameStartTime},
            'msg' => $msg
        });
    }
}

sub resetRecording() {
    my $self = shift;
    $self->{gameLog} = [];
}

sub addWatcher {
    my $self = shift;
    my $user = shift;
    push @{$self->{watchers}}, $user;
    $self->playerBroadcast(
        {
            'c' => 'watcherAdded',
            'screenname' => $user->{screenname}
        }
    );
}

sub getWatchers {
    my $self = shift;

    return @{$self->{watchers}};
}

sub addPlayer {
    my $self = shift;
    my ($auth, $color, $player) = @_;

    $self->playerBroadcast(
        {
            'c' => 'playerAdded',
            'color' => $color,
            'player' => $player ? $player->getJsonMsg() : '{}'
        }
    );
    $self->{playersByAuth}->{$auth} = $color;
}

1;
