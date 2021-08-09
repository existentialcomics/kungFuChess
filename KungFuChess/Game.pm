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
    my ($id, $mode, $speed, $auth, $whiteAnonKey, $blackAnonKey, $isAiGame) = @_;
	$self->{id} = $id;

    if ($speed eq 'standard') {
        $self->{pieceSpeed} = 10;
        $self->{pieceRecharge} = 10;
    } elsif ($speed eq 'lightning') {
        $self->{pieceSpeed} = 2;
        $self->{pieceRecharge} = 2;
    } else {
        warn "unknown game speed $speed\n";
    }
    $self->{speed} = $speed;
    $self->{mode} = $mode;   # 2way or 4way
    $self->{whiteAnonKey} = $whiteAnonKey;
    $self->{blackAnonKey} = $blackAnonKey;
    $self->{redAnonKey} = $whiteAnonKey;
    $self->{greenAnonKey} = $blackAnonKey;

    $self->{playersByAuth} = {};
    $self->{playersConn}   = {};

    $self->{isAiGame} = $isAiGame;
    $self->{readyToPlay}   = 0;
    $self->{auth}          = $auth;
    $self->{serverConn}    = 0;
    $self->{whitePlayer}   = undef;
    $self->{blackPlayer}   = undef;

    $self->{white}->{alive} = 1;
    $self->{black}->{alive} = 1;
    if ($mode eq '4way') {
        $self->{red}->{alive} = 1;
        $self->{green}->{alive} = 1;
    } else {
        $self->{red}->{alive} = 0;
        $self->{green}->{alive} = 0;
    }

    $self->{whiteReady}    = 0;
    $self->{blackReady}    = 0;
    $self->{whiteRematchReady}  = 0;
    $self->{blackRematchPlayer} = 0;
    $self->{white}->{draw} = 0;
    $self->{black}->{draw} = 0;
    $self->{red}->{draw}   = 0;
    $self->{green}->{draw} = 0;

    $self->{gameLog} = [];
    $self->{gameStartTime} = time();

	return 1;
}

### returns false for game is still active
#   otherwise returns the score
sub killPlayer {
    my $self  = shift;
    my $color = shift;
    print "kill player $color\n";
    if ($color eq 'both') {
        $self->{black}->{alive} = 0;
        $self->{white}->{alive} = 0;
        $self->{red}->{alive} = 0;
        $self->{green}->{alive} = 0;
    } else {
        $self->{$color}->{alive} = 0;
    }
    print Dumper($self->{white});
    print Dumper($self->{black});
    print Dumper($self->{green});
    print Dumper($self->{red});

    if ($self->{white}->{alive} + 
        $self->{black}->{alive} + 
        $self->{red}->{alive} + 
        $self->{green}->{alive} <= 1
    ) {
        print "  kill player only one left\n";
        if ($self->{mode} eq '4way') {
            if ($self->{white}->{alive} == 1) {
                return '1-0-0-0';
            } elsif ($self->{black}->{alive} == 1) {
                return '0-1-0-0';
            } elsif ($self->{red}->{alive} == 1) {
                return '0-0-1-0';
            } elsif ($self->{green}->{alive} == 1) {
                return '0-0-0-1';
            } else { ### no one is alive, practice abort?
                return '0-0-0-0';
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
    my $conn = shift;

    delete $self->{playersConn}->{$conn};
}

### returns positive number if all players are ready for how many seconds until game begins
sub playerReady {
    my $self = shift;
    my $msg = shift;

    my $color = $self->authMove($msg);
    if ($color){
        if ($color eq 'white' || $color eq 'both' || $self->{isAiGame}){
            $self->{whiteReady} = time();
        } 
        if($color eq 'black' || $color eq 'both' || $self->{isAiGame}){
            $self->{blackReady} = time();
        }
        if ($self->{whiteReady} && $self->{blackReady}) {
            $self->{readyToPlay} = ($self->{whiteReady} > $self->{blackReady} ? $self->{whiteReady} : $self->{blackReady}) + 3;
            my $msg = {
                'c' => 'gameBegins',
                'seconds' => 3
            };
            $self->serverBroadcast($msg);
            $self->playerBroadcast($msg);
            return 3;
        }
    }
    return 0;
}

### returns positive number if all players pressed draw
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
        if ($self->{mode} eq '4way') {
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
    return $self->{playersByAuth}->{$msg->{auth}}->{color};
}

sub serverBroadcast {
    my $self = shift;
    my $msg = shift;
	$self->{serverConn}->send(encode_json $msg);
}

# no need to save these to the log in interest of space
my %excludeFromLog = (
    'chat' => 1,
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

	foreach my $player (values %{ $self->{playersConn}}){
		$player->send(encode_json $msg);
	}

    if (! $excludeFromLog{$msg->{c}}) {
        push (@{$self->{gameLog}}, 
        {
            'time' => time() - $self->{gameStartTime},
            'msg' => $msg
        });
    }
}

sub addPlayer {
    my $self = shift;
    my ($user, $color) = @_;

    $user->{color} = (defined($color) ? $color : 'none');

    if ($color eq 'white'){
        $self->{whitePlayer} = $user;
    } elsif ($color eq 'black'){
        $self->{blackPlayer} = $user;
    }

    $self->{playersByAuth}->{$user->{auth_token}} = $user;
    $self->playerBroadcast({
        'c' => 'playerjoined',
        'user' => {
            'color' => $user->{color},
            'screenname' => $user->{screenname},
            'rating' => $user->{rating},
            'id' => $user->{id}
        },
    });
}

1;
