#!/usr/bin/perl
#
use strict; use warnings;
use Mojolicious::Lite;
use Mojolicious::Plugin::Database;
use Mojolicious::Plugin::Authentication;
use UUID::Tiny ':std';
use Data::Dumper;
use ChessPiece;
use ChessGame;
use JSON::XS;
use Config::Simple;
# via the Digest module (recommended)
use Digest;

my $cfg = new Config::Simple('kungFuChess.cnf');

### current running games
my %games   = ();
my %currentGames = ();

app->log->debug('connecting to db...');
app->plugin('database', { 
	dsn      => 'dbi:mysql:dbname=' . $cfg->param('database') .';host=' . $cfg->param('dbhost'),
	username => $cfg->param('dbuser'),
	password => $cfg->param('dbpassword'),
	options  => { 'pg_enable_utf8' => 1, RaiseError => 1 },
	helper   => 'db',
});

app->plugin('DefaultHelpers');

app->plugin('authentication' => {
    'autoload_user' => 1,
    'session_key' => 'kungfuchessapp',
    'load_user' =>
        sub { 
            my ($app, $uid) = @_;
            my @rows = $app->db()->selectall_array('SELECT player_id, screenname, rating FROM players WHERE player_id = ?', {}, $uid);

            foreach my $row (@rows){
                my $user = {
                    'id'         => $row->[0],
                    'screenname' => $row->[1],
                    'rating'     => $row->[2],
                    'auth'       =>  create_uuid_as_string(),
                };
                return $user;
            }
            return 0;

        },
    'validate_user' =>
        sub {
            my ($app, $username, $password, $extradata) = @_;
            print "validating $username, $password, " . encryptPassword($password) . "\n";
            my @rows = $app->db()->selectall_array('SELECT player_id FROM players WHERE screenname = ? AND password = ?', {}, $username, $password);
            print Dumper(@rows);
            if (@rows){
                print "Validated $rows[0]->[0]!\n";
                return $rows[0]->[0];
            }
            return undef;
        },
});

get '/debug/:debugVar' => sub {
    my $c = shift;
    my $debug = Dumper($c->stash('debugVar'));
    $c->render('text' => "$debug");
};

get '/' => sub {
    my $c = shift;

    my $user = $c->current_user();
    $c->stash('user' => $user);
    $c->stash('games' => \%games);
	$c->render('template' => 'home', format => 'html', handler => 'ep');
};

get '/game/:gameId/watch' => sub {
	my $c = shift;
    my $user = $c->current_user();
    $c->stash('user' => $user);
	app->log->debug( "Entering game to watch" );

    my $gameId = $c->stash('gameId');
    my $game = $currentGames{$gameId};
    $game->addPlayer($user);

    print "auth: $user->{auth}\n";
	$c->stash('authId' => $user->{auth});
	$c->stash('timer' => 10);
	$c->stash('autojoin' => 1);
    my ($white, $black) = getPlayers($gameId);

    $c->stash('whitePlayer' => encode_json $white);
    $c->stash('blackPlayer' => encode_json $black);

	$c->render('template' => 'board', format => 'html', handler => 'ep');
	return;
};

### join game
get '/game/:gameId' => sub {
	my $c = shift;
    my $user = $c->current_user();
    $c->stash('user' => $user);
	app->log->debug( "Entering game" );

    my $gameId = $c->stash('gameId');

    my $game = $currentGames{$gameId};
    $game->addPlayer($user);

    print "auth: $user->{auth}\n";
	$c->stash('authId' => $user->{auth});
	$c->stash('timer' => 10);
	$c->stash('autojoin' => 1);
    my ($white, $black) = getPlayers($gameId);

    my $alreadyJoined = 0;
    if (defined($white->{id})){
        if ($white->{id} == $user->{id}){
            $alreadyJoined = 1;
            $c->stash('color', 'white');
            $game->addPlayer($user, 'white');

        }
    }
    if (defined($black->{id})){
        if ($black->{id} == $user->{id}){
            $alreadyJoined = 1;
            $c->stash('color', 'black');
            $game->addPlayer($user, 'black');
        }
    }

    if (!$alreadyJoined){
        if (!defined($white->{id})){
            app->db()->do('UPDATE games SET white_player = ? WHERE game_id = ?', {}, $user->{id}, $gameId);
            $c->stash('color', 'white');
            $game->addPlayer($user, 'white');
        } elsif (!defined($black->{id})){
            app->db()->do('UPDATE games SET black_player = ? WHERE game_id = ?', {}, $user->{id}, $gameId);
            $c->stash('color', 'black');
            $game->addPlayer($user, 'black');
        } else {
            $c->stash('color', 'spectator');
            # full
        }
        ($white, $black) = getPlayers($gameId);
    }

    $c->stash('whitePlayer' => encode_json $white);
    $c->stash('blackPlayer' => encode_json $black);

	$c->render('template' => 'board', format => 'html', handler => 'ep');
	return;
};

get '/create' => sub {
	my $c = shift;
    my $user = $c->current_user();
    $c->stash('user' => $user);

	my $auth   = create_uuid_as_string();

    my $sth = $c->db()->prepare("INSERT INTO games (game_id) VALUES (NULL)");
    $sth->execute();

    my $gameId = $sth->{mysql_insertid};

	$games{$gameId} = {
		'players' => {},
		'serverConn' => '',
		'auth'       => $auth,
        'begun'      => 0,
	};

    $currentGames{$gameId} = ChessGame->new(
        $gameId,
        $auth
    );

	# spin up game server, wait for it to send authjoin
	app->log->debug( "starting game client $gameId, $auth" );
	# spin up game server, wait for it to send authjoin
	app->log->debug('/usr/bin/perl /home/corey/kungfuchess/kungFuChessGame.pl ' . $gameId . ' ' . $auth . ' > /home/corey/game.log 2>/home/corey/errors.log &');
	system('/usr/bin/perl /home/corey/kungfuchess/kungFuChessGame.pl ' . $gameId . ' ' . $auth . ' > /home/corey/game.log 2>/home/corey/errors.log &');

	$c = $c->redirect_to("/game/$gameId");
};

get '/register' => sub {
    my $c = shift;
	$c->render('template' => 'register', format => 'html', handler => 'ep');
};

post '/register' => sub {
    my $c = shift;
    my ($u, $p) = ($c->req->param('username'), $c->req->param('password'));
    print "registering $u\n";
    $c->db()->do('INSERT INTO players (screenname, password, rating, is_provisional)
            VALUES (?, ?, ? ,?)', {}, $u, encryptPassword($p), 1600, 1);
    if ($c->authenticate($u, $p)){
        print "authed $u!\n";
    } else {
        print "error $u!\n";
    }
	$c->redirect_to("/");
};

get '/logout' => sub {
    my $c = shift;

    $c->logout();

	$c->redirect_to("/");
};

get '/login' => sub {
    my $c = shift;
    my $user = $c->current_user();
    $c->stash('user' => $user);


	$c->render('template' => 'login', format => 'html', handler => 'ep');
};

post '/login' => sub {
    my $c = shift;


    my ($u, $p) = ($c->req->param('username'), $c->req->param('password'));
    print "login $u, $p\n";
    if ($c->authenticate($u, encryptPassword($p))){
        print "authed $u!\n";
        my $user = $c->current_user();
        $c->stash('user' => $user);
	    $c->redirect_to("/");
    }
    $c->stash('error' => 'Invalid username or password');
    my $user = $c->current_user();
    $c->stash('user' => $user);
	$c->render('template' => 'login', format => 'html', handler => 'ep');
};

websocket '/ws' => sub {
	my $self = shift;

	app->log->debug(sprintf 'Client connected: %s', $self->tx);
	my $id = sprintf "%s", $self->tx;
	$self->inactivity_timeout(300);

	$self->on(finish => sub {
		## delete player
		app->log->debug("connection closed for $id");
	});

	my $gameId = "";

	$self->on(message => sub {
		my ($self, $msg) = @_;
		eval {
			$msg = decode_json($msg);
		} or do {
			print "bad JSON: $msg\n";
			return 0;
		};

        #app->log->debug("msg recieved c: $msg->{'c'}");

        return 0 if (! $msg->{gameId} );
        my $game = $currentGames{$msg->{gameId}};
        return 0 if (! $game);

		if ($msg->{'c'} eq 'join'){

			my $ret = {
				'c' => 'joined',
			};
            $game->addConnection($id, $self);

			$self->send(encode_json $ret);

			$game->serverBroadcast($msg);
			app->log->debug('player joined');
		} elsif ($msg->{'c'} eq 'chat'){
            app->log->debug("chat msg recieved");
            $game->playerBroadcast($msg);
		} elsif ($msg->{'c'} eq 'ping'){

		} elsif ($msg->{'c'} eq 'move'){
            app->log->debug('moving, ready to auth');
            my $color = $game->authMove($msg);
            return 0 if (!$color);

            $msg->{color} = $color;
            

			# pass the move request to the server
			# TODO pass the player's color to the server
			$game->serverBroadcast($msg);
		} elsif ($msg->{'c'} eq 'authmove'){
            print "AUTHMOVE\n";
            if (! gameauth($msg) ){ return 0; }

			# pass the move request to the server
			$msg->{'c'} = 'move';
			$game->playerBroadcast($msg);
		} elsif ($msg->{'c'} eq 'spawn'){
            if (! gameauth($msg) ){ return 0; }

			print "broadcast spawn...\n";
			$game->playerBroadcast($msg);

		} elsif ($msg->{'c'} eq 'playerlost'){
            if (! gameauth($msg) ){ return 0; }
			$game->playerBroadcast($msg);
            # end game here
            updateRatings($msg->{gameId}, $msg->{color});
		} elsif ($msg->{'c'} eq 'authkill'){
            if (! gameauth($msg) ){ return 0; }

			$msg->{'c'} = 'kill';
			$game->playerBroadcast($msg);
		} elsif ($msg->{'c'} eq 'promote'){
            if (! gameauth($msg) ){ return 0; }

			$game->playerBroadcast($msg);
		} elsif ($msg->{'c'} eq 'authjoin'){
            if (! gameauth($msg) ){ return 0; }

            $game->setServerConnection($self->tx);
		} else {
			print "bad message: $msg\n";
			print Dumper($msg);
		}
	});
};

# auth from the game server
sub gameauth {
    my $msg = shift;
    return 1;
    return 0 if (! ($msg->{gameId} && $msg->{auth}));                          # no game / auth tokens
    return 0 if ($games{$msg->{gameId}}->{auth} ne $msg->{auth});              # incorrect server auth

    return 1;
}

sub playerBroadcast {
	my ($gameId, $msg) = @_;
	print "player broadcast $gameId\n";
	delete $msg->{auth};
	foreach my $player (values %{ $games{$gameId}->{players}}){
		print "broadcasting to player $msg->{c}\n";
		$player->{conn}->send(encode_json $msg);
	}
}

sub serverBroadcast {
	my ($gameId, $msg) = @_;
	print "server broadcast for gameId: $gameId\n";
    print Dumper($msg);
	$games{$gameId}->{serverConn}->send(encode_json $msg);
}

sub encryptPassword {
    my $password = shift;

    my $bcrypt = Digest->new('Bcrypt');

    # $cost is an integer between 1 and 31
    $bcrypt->cost(10);

    # $salt must be exactly 16 octets long
    #              1234567890123456
    $bcrypt->salt('kungfuchessABCCB');

    $bcrypt->add($password);

    return $bcrypt->b64digest();
}

# result 1 = white wins, 0 = black wins, .5 = draw
sub updateRatings {
    my $gameId = shift;
    my $loser  = shift;

    my $result = ($loser eq 'black' ? 1 : 0);

    my ($white, $black) = getPlayers($gameId);

    # k variable controls change rate
    my $k = 32;
    
    # transformed rating (on a normal curve)
    my $r1 = 10 ** ($white->{rating} / 400);
    my $r2 = 10 ** ($black->{rating} / 400);

    # expected score
    my $e1 = $r1 / ($r1 + $r2);
    my $e2 = $r2 / ($r1 + $r2);

    $white->{rating} = $white->{rating} + $k * ($result - $e1);
    $black->{rating} = $black->{rating} + $k * ((1 - $result) - $e2);
    savePlayer($white);
    savePlayer($black);
}

sub getPlayers {
    my $gameId = shift;

    my @rows = qw(screenname id rating is_provisional);
    my @white = app->db()->selectrow_array('SELECT screenname, player_id, rating, is_provisional FROM games g LEFT JOIN players p ON g.white_player = p.player_id WHERE game_id = ?', {}, $gameId);
    my @black = app->db()->selectrow_array('SELECT screenname, player_id, rating, is_provisional FROM games g LEFT JOIN players p ON g.black_player = p.player_id WHERE game_id = ?', {}, $gameId);
    my %white;
    @white{@rows} = @white;

    my %black;
    @black{@rows} = @black;

    print "get players:\n";
    print Dumper(%white);
    print Dumper(%black);

    return (\%white, \%black);
}

sub getPlayerById {
    my $playerId = shift;

    my @rows = qw(screenname id rating is_provisional);
    my @playerRow = app->db()->selectrow_array('SELECT screenname, player_id, rating, is_provisional FROM players player_id = ?', {}, $playerId);
    my %player;
    @player{@rows} = @playerRow;

    return \%player;
}

sub savePlayer {
    my $player = shift;

    my $sth = app->db()->prepare('UPDATE players SET rating = ?, is_provisional = ? WHERE player_id = ?' );
    $sth->execute($player->{rating}, $player->{provisional}, $player->{id});
}

app->start;
