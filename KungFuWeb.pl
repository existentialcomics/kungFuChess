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
use HTML::Escape qw/escape_html/;
# via the Digest module (recommended)
use Digest;

use KungFuChess::Player;

my $cfg = new Config::Simple('kungFuChess.cnf');

### current running games
my %games   = ();

### current ChessGame.pm objects running
my %currentGames = ();

## hash of connections to gameIds 
my %gamesByServerConn = ();

## hash of all connections
my %globalConnections = ();

## hash of game id by connections and which players are in
my %playerGamesByServerConn = ();

app->log->debug('connecting to db...');
app->plugin('database', { 
    dsn      => 'dbi:mysql:dbname=' . $cfg->param('database') .';host=' . $cfg->param('dbhost'),
    username => $cfg->param('dbuser'),
    password => $cfg->param('dbpassword'),
    options  => {
        'pg_enable_utf8' => 1,
        'RaiseError' => 1
    },
    helper   => 'db',
});

app->plugin('DefaultHelpers');

app->plugin('authentication' => {
    'autoload_user' => 1,
    'session_key' => 'kungfuchessapp',
    'load_user' =>
        sub { 
            my ($app, $uid) = @_;
            my @rows = $app->db()->selectall_array('SELECT player_id, screenname, rating_standard, rating_lightning, auth_token FROM players WHERE player_id = ?', {}, $uid);

            foreach my $row (@rows){
                my $user = {
                    'id'         => $row->[0],
                    'screenname' => $row->[1],
                    'rating_standard' => $row->[2],
                    'rating_lightning' => $row->[3],
                    'auth'       => $row->[4],
                };
                app->db()->do('UPDATE players SET last_seen = NOW() WHERE player_id = ?', {}, $user->{'id'});
                my $player = new KungFuChess::Player(
                    {  'userId' => $user->{id} },
                    app->db()
                );
                return $player;
            }
            return undef;
        },
    'validate_user' =>
        sub {
            my ($app, $username, $password, $extradata) = @_;
            my @rows = $app->db()->selectall_array('SELECT player_id FROM players WHERE screenname = ? AND password = ?', {}, $username, $password);
            if (@rows){
                my $id = $rows[0]->[0];
                my $auth = create_uuid_as_string();
                app->db()->do('UPDATE players SET last_login = NOW(), last_seen = NOW(), auth_token = ? WHERE player_id = ?', {}, $auth, $id);
                app->log->debug("updated auth in db to: $auth");
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
    my $games = getActiveGames();
    $c->stash('games' => $games);
    $c->render('template' => 'home', format => 'html', handler => 'ep');
};

get '/ajax/games' => sub {
    my $c = shift;

    my $games = getActiveGames();
    $c->render('json' => $games);
};

post '/ajax/chat' => sub {
    my $c = shift;
    my $user = $c->current_user();

    my $msg = {
        'c' => 'globalchat',
        'author'    => $user->{screenname},
        'user_id'   => $user->{player_id},
        'message'   => $c->req->param('message')
    };

    globalBroadcast($msg);

    $c->render('json' => {});
};

get '/ajax/pool' => sub {
    my $c = shift;

    my $user = $c->current_user();
    enterPool($user);
    my $gameId = matchPool($user, 'standard');

    my $json = {};

    if ($gameId) {
        $json->{'gameId'} = $gameId;
    }

    $c->render('json' => $json);
};


get '/about' => sub {
    my $c = shift;
    my $user = $c->current_user();
    $c->stash('user' => $user);

    $c->render('template' => 'about', format => 'html', handler => 'ep');
};

get '/profile/:screenname' => sub {
    my $c = shift;
    my $user = $c->current_user();
    $c->stash('user' => $user);

    my $data = { 'screenname' => $c->stash('screenname') };
    my $player = new KungFuChess::Player($data, app->db());

    $c->stash('player' => $player);

    $c->render('template' => 'profile', format => 'html', handler => 'ep');
};

get '/games' => sub {
    my $c = shift;
    my $user = $c->current_user();
    $c->stash('user' => $user);

    my $games = getActiveGames();
    $c->stash('games' => $games);
    $c->render('template' => 'games', format => 'html', handler => 'ep');
};

get '/activePlayers' => sub {
    my $c = shift;
    my $user = $c->current_user();
    $c->stash('user' => $user);

    my $ratingType = ($c->req->param('ratingType') ? $c->req->param('ratingType') : 'standard');

    my $players = getActivePlayers();
    $c->stash('players' => $players);
    $c->stash('ratingType' => $ratingType);
    $c->render('template' => 'players', format => 'html', handler => 'ep');
};

### join game
get '/game/:gameId' => sub {
    my $c = shift;
    my $user = $c->current_user();
    if (!$user) {
        $user = getAnonymousUser();
    }
    $c->stash('user' => $user);
    app->log->debug("---- Entering game ----" );

    my $gameId = $c->stash('gameId');
    my $game = $currentGames{$gameId};
    if (!$game){
        $c->render('template' => 'gameEnded', format => 'html', handler => 'ep');
        return;
    }

    $c->stash('authId' => $user->{auth_token});
    $c->stash('timer' => 10);
    $c->stash('gameBegan' => $game->{readyToPlay});
    my ($white, $black) = getPlayers($gameId);

    my $alreadyJoined = 0;
    if (defined($white->{player_id})){
        if ($white->{player_id} == $user->{player_id}){
            app->log->debug(" User is the white player " );
            $alreadyJoined = 1;
            $c->stash('color', 'white');
            $game->addPlayer($user, 'white');

        }
    }
    if (defined($black->{player_id})){
        if ($black->{player_id} == $user->{player_id}){
            app->log->debug(" User is the black player " );
            $alreadyJoined = 1;
            $c->stash('color', 'black');
            $game->addPlayer($user, 'black');
        }
    }

    #### we aren't join games right now as I figure out the pool, to join you must use pool
    #### another process is needed probably to set the player ids. anon players will be
    #### preset to -1 -1, and games wont get inserted until there is a match

    ### if it is an anonymous user we never count them as "already joined" since there can be two anonymous users
    ### this means anon users can't resume games if they look away from the screen really
    ### in theory we could compare the auth string here to see the difference though
    #if ($user->{player_id} == -1){
        #$alreadyJoined = 0;
    #}

    #if (!$alreadyJoined){
        #if (!defined($white->{player_id})){
            #app->db()->do('UPDATE games SET white_player = ? WHERE game_id = ?', {}, $user->{player_id}, $gameId);
            #$c->stash('color', 'white');
            #$game->addPlayer($user, 'white');
        #} elsif (!defined($black->{player_id})){
            #app->db()->do('UPDATE games SET black_player = ? WHERE game_id = ?', {}, $user->{player_id}, $gameId);
            #$c->stash('color', 'black');
            #$game->addPlayer($user, 'black');
        #} else {
            #$c->stash('color', 'spectator');
            ## full
        #}
        #($white, $black) = getPlayers($gameId);
    #}

    $c->stash('whitePlayer' => $white);
    $c->stash('blackPlayer' => $black);

    $c->render('template' => 'board', format => 'html', handler => 'ep');
    return;
};

post '/createGame' => sub {
    my $c = shift;
    my $user = $c->current_user();
    $c->stash('user' => $user);

    my ($open, $rated) = ($c->req->param('open'), $c->req->param('rated'));

    app->log->debug( "open, rated: $open, $rated" );

    my $gameId = createGame(undef, "stanard", ($open ? 1 : 0), ($rated ? 1 : 0));

    $c = $c->redirect_to("/game/$gameId");
};

get '/createGame' => sub {
    my $c = shift;
    my $user = $c->current_user();
    $c->stash('user' => $user);

    $c->render('template' => 'createGame', format => 'html', handler => 'ep');
};


sub getAnonymousUser {
    my $anonUser = {
        'id'         => -1,
        'screenname' => 'anonymous',
        'rating'     => undef,
        'auth'       => create_uuid_as_string(),
    };
    return $anonUser;
}

sub createGame {
    my ($rematchOfGame, $speed, $open, $rated, $white, $black) = @_;

    if ($rematchOfGame) {
        my @row = app->db()->selectrow_array("SELECT game_speed, white_player, black_player, rated, open_to_public FROM games
            WHERE game_id = ?", {}, $rematchOfGame->{id});
        ($speed, $white, $black, $rated, $open) = @row;
    }

    my $auth = create_uuid_as_string();

    my $sth = app->db()->prepare("INSERT INTO games (game_id, game_speed, white_player, black_player, rated, open_to_public)
        VALUES (NULL, ?, ?, ?, ?, ?)");
    $sth->execute($speed, $white, $black, $rated, $open);

    my $gameId = $sth->{mysql_insertid};

    $games{$gameId} = {
        'players' => {},
        'serverConn' => '',
        'auth'       => $auth,
        'begun'      => 0,
    };

    $currentGames{$gameId} = ChessGame->new(
        $gameId,
        $speed,
        $auth
    );

    # spin up game server, wait for it to send authjoin
    app->log->debug( "starting game client $gameId, $auth" );
    # spin up game server, wait for it to send authjoin
    app->log->debug('/usr/bin/perl /home/corey/kungfuchess/kungFuChessGame.pl ' . $gameId . ' ' . $auth . ' > /home/corey/game.log 2>/home/corey/errors.log &');
    system('/usr/bin/perl /home/corey/kungfuchess/kungFuChessGame.pl ' . $gameId . ' ' . $auth . ' > /home/corey/game.log 2>/home/corey/errors.log &');

    return $gameId;
}

get '/register' => sub {
    my $c = shift;
    $c->render('template' => 'register', format => 'html', handler => 'ep');
};

post '/register' => sub {
    my $c = shift;
    my ($u, $p) = ($c->req->param('username'), $c->req->param('password'));
    $c->db()->do('INSERT INTO players (screenname, password)
            VALUES (?, ?)', {}, $u, encryptPassword($p));

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
    if ($c->authenticate($u, encryptPassword($p))){
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
    my $connId = sprintf "%s", $self->tx;
    $self->inactivity_timeout(300);

    $globalConnections{$connId} = $self;

    $self->on(finish => sub {
        ## delete player
        app->log->debug("connection closed for $connId");
        if (exists $gamesByServerConn{$connId}){
            my $gameId = $gamesByServerConn{$connId};
            endGame($gameId, 'server disconnect');
            #delete $currentGames{$gameId};
            delete $gamesByServerConn{$connId};
            app->log->debug("game connection closed $connId");
        } elsif (exists $playerGamesByServerConn{$connId}){
            my $gameId = $playerGamesByServerConn{$connId};
            my $game = $currentGames{$gameId};
            if (!$game){
                app->log->debug("game $gameId not found for $connId");
            } else {
                $game->removeConnection($connId);
                delete $playerGamesByServerConn{$connId};
                app->log->debug("game connection closed $connId");
            }
        } else {
            app->log->debug("conneciton $connId closing, but not found!");
        }
        delete $globalConnections{$connId};
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
            $game->addConnection($connId, $self);
            $playerGamesByServerConn{$connId} = $msg->{gameId};

            $self->send(encode_json $ret);

            $game->serverBroadcast($msg);
            app->log->debug('player joined');
        } elsif ($msg->{'c'} eq 'chat'){
            my $player = getPlayerByAuth($msg->{auth});
            $msg->{'message'} = escape_html($msg->{'message'});
            $msg->{'author'}  = escape_html( ($player ? $player->{screenname} : "anonymous") );

            app->log->debug("chat msg recieved");
            $game->playerBroadcast($msg);
        } elsif ($msg->{'c'} eq 'readyToRematch'){
            my $return = $game->playerRematchReady($msg);

        } elsif ($msg->{'c'} eq 'readyToBegin'){
            my $return = $game->playerReady($msg);
            app->log->debug("ready to begin msg");
            if ($return > 0){
            }
        } elsif ($msg->{'c'} eq 'serverping'){

        } elsif ($msg->{'c'} eq 'ping'){

        } elsif ($msg->{'c'} eq 'move'){
            app->log->debug('moving, ready to auth');
            return 0 if (!$game->gameBegan());
            my $color = $game->authMove($msg);

            return 0 if (!$color);

            $msg->{color} = $color;

            # pass the move request to the server
            # TODO pass the player's color to the server
            $game->serverBroadcast($msg);
        } elsif ($msg->{'c'} eq 'authmove'){
            if (! gameauth($msg) ){ return 0; }

            # pass the move request to the server
            $msg->{'c'} = 'move';
            $game->playerBroadcast($msg);
        } elsif ($msg->{'c'} eq 'spawn'){
            if (! gameauth($msg) ){ return 0; }

            #print "broadcast spawn...\n";
            $game->playerBroadcast($msg);
        } elsif ($msg->{'c'} eq 'revokeDraw'){
            if (! gameauth($msg) ){ return 0; }
            my $color = $game->authMove($msg);
            return 0 if (!$color);

            $game->playerRevokeDraw($msg);

            $game->playerBroadcast($msg);
        } elsif ($msg->{'c'} eq 'requestDraw'){
            if (! gameauth($msg) ){ return 0; }
            my $color = $game->authMove($msg);
            return 0 if (!$color);

            my $drawConfirmed = $game->playerDraw($msg);
            if ($drawConfirmed) {
                endGame($msg->{gameId}, 'draw');

                my $drawnMsg = {
                    'c' => 'gameDrawn'
                };

                $game->playerBroadcast($drawnMsg);
                $game->serverBroadcast($drawnMsg);
            } else {
                $game->playerBroadcast($msg);
            }

        } elsif ($msg->{'c'} eq 'resign'){
            if (! gameauth($msg) ){ return 0; }
            my $color = $game->authMove($msg);

            return 0 if (!$color);

            $msg->{'color'} = $color;
            $game->playerBroadcast($msg);
            $game->serverBroadcast($msg);

            my $result = '';
            if ($color eq 'black'){
                $result = 'white wins';
            } elsif ($color eq 'white'){
                $result = 'black wins';
            }
            endGame($msg->{gameId}, $result);
        } elsif ($msg->{'c'} eq 'playerlost'){
            if (! gameauth($msg) ){ return 0; }
            $game->playerBroadcast($msg);

            my $result = '';
            if ($msg->{color} eq 'black'){
                $result = 'white wins';
            } elsif ($msg->{color} eq 'white'){
                $result = 'black wins';
            }
            endGame($msg->{gameId}, $result);
        } elsif ($msg->{'c'} eq 'authkill'){
            if (! gameauth($msg) ){ return 0; }

            $msg->{'c'} = 'kill';
            $game->playerBroadcast($msg);
        } elsif ($msg->{'c'} eq 'rematch'){
            if (! gameauth($msg) ){ return 0; }

            my $rematchConfirmed = $game->playerRematch($msg);
            if ($rematchConfirmed) {
                my $gameId = createGame($game);
                my $newGameMsg = {
                    'c' => 'newgame',
                    'gameId' => $gameId
                };
                $game->playerBroadcast($newGameMsg);
            }
        } elsif ($msg->{'c'} eq 'promote'){
            if (! gameauth($msg) ){ return 0; }

            $game->playerBroadcast($msg);
        } elsif ($msg->{'c'} eq 'authjoin'){
            if (! gameauth($msg) ){ return 0; }

            $game->setServerConnection($self->tx);
            $gamesByServerConn{$connId} = $game->{id};
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

sub globalBroadcast {
    my $msg = shift;

    foreach my $conn (values %globalConnections) {
        $conn->send(encode_json $msg);
    }
}

sub serverBroadcast {
    my ($gameId, $msg) = @_;
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
    my $resultColor  = shift;

    app()->log->debug("updating ratings for $gameId, $resultColor");

    my $result = '';
    if ($resultColor eq 'white wins') {
        $result = 1;
    } elsif ($resultColor eq 'black wins') {
        $result = 0;
    } elsif ($resultColor eq 'draw') {
        $result = 0.5;
    } else {
        return (undef, undef);
    }

    my ($white, $black) = getPlayers($gameId);

    # k variable controls change rate
    my $k = 32;

    my $ratingColumn = "rating_standard";
    
    # transformed rating (on a normal curve)
    my $r1 = 10 ** ($white->{$ratingColumn} / 400);
    my $r2 = 10 ** ($black->{$ratingColumn} / 400);

    # expected score
    my $e1 = $r1 / ($r1 + $r2);
    my $e2 = $r2 / ($r1 + $r2);

    $white->{$ratingColumn} = $white->{$ratingColumn} + $k * ($result - $e1);
    $black->{$ratingColumn} = $black->{$ratingColumn} + $k * ((1 - $result) - $e2);
    savePlayer($white, $result, 'standard');
    savePlayer($black, 1 - $result, 'standard');

    return ($white, $black);
}

sub endGame {
    my $gameId = shift;
    my $result = shift;

    app->log->debug('ending game: ' . $gameId . ' to ' . $result);

    my @gameRow = app->db()->selectrow_array("SELECT status FROM games WHERE game_id = ?", {}, $gameId);

    if (! @gameRow ) {
        app->debug("  game doesn't exist so it cannot be ended!! $gameId");
        return 0;
    }
    if ($gameRow[0] ne 'active') {
        app->log->debug("  $gameId already ended ($gameRow[0])");
        return 0;
    }

    ### set result
    app->db()->do(
        'UPDATE games SET `status` = "finished", result = ?, time_ended = NOW() WHERE game_id = ?',
        {},
        $result,
        $gameId,
    );

    my ($whiteStart, $blackStart) = getPlayers($gameId);
    my ($whiteEnd, $blackEnd) = updateRatings($gameId, $result);

    if ($result eq 'white wins' || $result eq 'black wins' || $result eq 'draw') {
        ### write to game log for both players
        if ($whiteStart->{player_id}) {
            app->db()->do('INSERT INTO game_log
                (game_id, player_id, opponent_id, game_type, result, rating_before, rating_after, opponent_rating_before, opponent_rating_after, rated)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {},
                $gameId,
                $whiteStart->{player_id},
                $blackStart->{player_id},
                'standard',
                ($result eq 'draw' ? 'draw' : ($result eq 'white wins' ? 'win' : 'loss') ),
                $whiteStart->{rating_standard},
                $whiteEnd->{rating_standard},
                $blackStart->{rating_standard},
                $blackEnd->{rating_standard},
                1
            );
        }

        if ($blackStart->{player_id}) {
            app->db()->do('INSERT INTO game_log
                (game_id, player_id, opponent_id, game_type, result, rating_before, rating_after, opponent_rating_before, opponent_rating_after, rated)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {},
                $gameId,
                $blackStart->{player_id},
                $whiteStart->{player_id},
                'standard',
                ($result eq 'draw' ? 'draw' : ($result eq 'white wins' ? 'loss' : 'win') ),
                $blackStart->{rating_standard},
                $blackEnd->{rating_standard},
                $whiteStart->{rating_standard},
                $whiteEnd->{rating_standard},
                1
            );
        }
    }


    # TODO delete games by connection and anything else.
    # if the connection is still active send the server 
    # a msg to shut down.
    delete $games{$gameId};
    return 1;
}

sub getPlayers {
    my $gameId = shift;

    my $ratingColumn = 'rating_standard';

    my @rows = qw(screenname id rating);
    my @white = app->db()->selectrow_array('SELECT
        IF(white_player = -1, "anonymous", screenname) as screenname,
        IF(white_player = -1, -1, player_id) as player_id,
        ' . $ratingColumn . ' as rating
            FROM games g
            LEFT JOIN players p
            ON g.white_player = p.player_id WHERE game_id = ?', {}, $gameId);
    my @black = app->db()->selectrow_array('SELECT
        IF(black_player = -1, "anonymous", screenname) as screenname,
        IF(black_player = -1, -1, player_id) as player_id,
        ' . $ratingColumn . ' as rating
            FROM games g
            LEFT JOIN players p
            ON g.black_player = p.player_id WHERE game_id = ?', {}, $gameId);

    my @row = app->db()->selectrow_array('SELECT white_player, black_player FROM games WHERE game_id = ?', {}, $gameId);

    my $white = new KungFuChess::Player( { 'userId' => $row[0] }, app->db() );
    my $black = new KungFuChess::Player( { 'userId' => $row[1] }, app->db() );

    return ($white, $black);
}

sub getActiveGames {
    my ($ratedOnly, $minRating, $maxRating) = @_;
    my $ratingCol = 'rating_standard';
    my @rows = qw(game_id time_created white_id white_rating white_screenname black_id black_rating black_screenname);
    my $games = app->db()->selectall_arrayref('
        SELECT 
            g.game_id,
            g.time_created,
            w.player_id,
            w.'.$ratingCol.',
            w.screenname,
            b.player_id,
            b.'.$ratingCol.',
            b.screenname
        FROM games g
        LEFT JOIN players w ON g.white_player = w.player_id
        LEFT JOIN players b ON g.black_player = b.player_id
        WHERE status = "active"
    ');

    my @gameHashes = ();
    foreach my $game (@{$games}) {
        my %gameH = ();
        my $id = $game->[0];
        # not in the pool
        if (!$currentGames{$id}){
            endGame($id, 'server disconnect');
        }

        @gameH{@rows} = @{$game};
        push @gameHashes, \%gameH;
    }

    return \@gameHashes;
}

sub getActivePlayers {
    my $playerRows = app->db()->selectall_arrayref('
        SELECT *
        FROM players
        WHERE last_seen > NOW() - INTERVAL 10 SECOND',
        { 'Slice' => {} }
    );

    my @players = ();

    foreach my $row (@$playerRows) {
        my $data = {
            'row' => $row
        };
        my $player = new KungFuChess::Player($data, app->db());
        if ($player) {
            push @players, $player;
        }
    }

    return \@players;
}

sub getPlayerByAuth {
    my $auth = shift;

    app->log->debug('getPlayerByAuth: ' . $auth);
    my @rows = qw(screenname id);
    my $sql = 'SELECT screenname, player_id FROM players WHERE auth_token = "'. $auth . '"';
    app->log->debug($sql);
    my @playerRow = app->db()->selectrow_array(
        #'SELECT screenname, player_id, rating, is_provisional FROM players WHERE auth_token = ?',
        $sql,
        {}
        #$auth
    );
    if (!@playerRow){ return undef; }
    my %player;
    @player{@rows} = @playerRow;

    return \%player;
}

sub getPlayerById {
    my $playerId = shift;

    my @rows = qw(screenname id rating_standard rating_lightning games_played_standard games_played_lightning);
    my @playerRow = app->db()->selectrow_array(
        'SELECT screenname, player_id, rating_standard, rating_lightning, games_played_standard, games_played_lightning
        FROM players player_id = ?',
        {},
        $playerId
    );

    if (!@playerRow){ return undef; }
    my %player;
    @player{@rows} = @playerRow;

    return \%player;
}

sub savePlayer {
    my $player = shift;
    my $result = shift;
    my $gameType = shift;

    my $sth = app->db()->prepare('UPDATE players SET rating_standard = ?, rating_lightning = ? WHERE player_id = ?' );
    $sth->execute($player->{rating_standard}, $player->{rating_lightning}, $player->{player_id});

    if (defined($result) && ($gameType eq 'standard' || $gameType eq 'lightning') ) {
        my $resultColumn = '';
        my $playedColumn = "games_played_$gameType";

        if ($result == 1) {
            $resultColumn = "games_won_$gameType";
        } elsif ($result == 0.5) {
            $resultColumn = "games_drawn_$gameType";
        } elsif ($result == 0) {
            $resultColumn = "games_lost_$gameType";
        } else {
            app->log->debug("UNKNOWN result! $result");
        }
        if ($resultColumn ne '') {
            my $sthResult = app->db()->prepare("UPDATE players SET $playedColumn = $playedColumn + 1, $resultColumn = $resultColumn + 1 WHERE player_id = ?" );
        }
    }
}

sub getOpenGames {
    my @poolRows = app->db()->selectall_arrayref('
        SELECT p.player_id, p.rated, p.private_game_key, p.game_speed, py.rating_standard, py.rating_lightning, py.screenname
        FROM pool p LEFT JOIN players py ON p.player_id = py.player_id
            WHERE in_matching_pool = 0
            AND open_to_public = 1
            AND last_ping > NOW() - INTERVAL 3 SECOND',
        { 'Slice' => 1 }
    );

    return @poolRows;

}

sub enterPool {
    my $player = shift;

    if (! $player) { 
        return 0;
    }
    if (! $player->{player_id}) {
        return 0;
    }

    my $sth = app->db()->prepare('INSERT INTO pool (player_id, game_speed, rated, last_ping) VALUES (?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE game_speed = ?, rated = ?, last_ping = NOW()
    ');
    $sth->execute($player->{'player_id'}, 'standard', 1, 'standard', 1);
}

sub matchPool {
    my $player = shift;
    my $ratingType = shift;

    if (!$ratingType) { $ratingType = 'standard'; }

    my $ratingColumn = 'rating_' . $ratingType;
    my @poolRow = app->db()->selectrow_array('SELECT player_id, matched_game FROM pool WHERE player_id = ?', {}, $player->{'player_id'});

    if (!@poolRow) {
        enterPool($player);
    } else {
        my ($player_id, $matched_game) = @poolRow;
        if ($matched_game) {
            my @gameRow = app->db()->selectrow_array('SELECT status, white_player, black_player FROM games WHERE game_id = ?', {}, $matched_game);
            
            my ($gameStatus, $blackPlayer, $whitePlayer) = @gameRow;
            if ($gameStatus eq 'active' && ($blackPlayer == $player->{'player_id'} || $whitePlayer == $player->{'player_id'}) ) {
                print "returning $matched_game\n";
                return $matched_game;
            } else {
                app->db()->do("UPDATE pool SET matched_game = NULL WHERE player_id = ?", {}, $player->{'player_id'});
            }
        }
    }

    my @playerMatchedRow = app->db()->selectrow_array(
        'SELECT p.player_id FROM pool p
            LEFT JOIN players pl ON p.player_id = pl.player_id
            WHERE p.player_id != ?
            AND in_matching_pool = 1
            AND private_game_key IS NULL
            AND game_speed = "' . $ratingType . '"
            AND last_ping > NOW() - INTERVAL 3 SECOND
            ORDER BY abs(? - ' . $ratingColumn . ') limit 1',
        {},
        $player->{'player_id'}, $player->{'rating'}
    );

    if (@playerMatchedRow) {
        my $playerMatchedId = $playerMatchedRow[0];
                  # rematchOfGame, speed, open, rated, whiteId, blackId
        my $gameId = createGame(undef, $ratingType, 1, 1, $player->{'player_id'}, $playerMatchedId);

        app->db()->do('UPDATE pool SET matched_game = ? WHERE player_id IN (?, ?)', {}, $gameId, $player->{'player_id'}, $playerMatchedId);

        return $gameId;
    }

    return undef;
}

app->start;
