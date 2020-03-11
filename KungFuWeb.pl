#!/usr/bin/perl
#
use strict; use warnings;
use Mojolicious::Lite;
use Mojolicious::Plugin::Database;
use Mojolicious::Plugin::Authentication;
use UUID::Tiny ':std';
use Data::Dumper;
use JSON::XS;
use Config::Simple;
use HTML::Escape qw/escape_html/;
# via the Digest module (recommended)
use Digest;

use KungFuChess::Game;
use KungFuChess::Player;

use constant {
    ANON_USER => -1,
    AI_USER => -2,
};

my $cfg = new Config::Simple('kungFuChess.cnf');

### current running games
my %games   = ();

### current KungFuChess::Game.pm objects running
my %currentGames = ();

## hash of connections to gameIds 
my %gamesByServerConn = ();

## hash of all connections
my %globalConnections = ();

## hash of all connections
my %globalConnectionsByAuth = ();

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

get '/admin/clear-inactive-games' => sub {
    my $c = shift;
    my $games = app->db()->selectall_arrayref("SELECT game_id from games WHERE status = 'active'");
    foreach my $row (@$games) {
        my $gameId = $row->[0];
        if (! exists($currentGames{$gameId})){
            endGame($gameId, 'server disconnect');
            delete $currentGames{$gameId};
            delete $games{$gameId};
        }
    }
    $c->render('text' => "done");
    return;
};

get '/' => sub {
    my $c = shift;

    my $user = $c->current_user();
    $c->stash('user' => $user);
    my $games = getActiveGames();
    $c->stash('games' => $games);
    $c->render('template' => 'home', format => 'html', handler => 'ep');
};


post '/ajax/createChallenge' => sub {
    my $c = shift;
    my $user = $c->current_user();
    $c->stash('user' => $user);

    my ($gameSpeed, $gameType, $open) = ($c->req->param('gameSpeed'), $c->req->param('gameType'), $c->req->param('open'));

    my $rated = ($gameType eq 'rated' ? 1 : 0);
    app->log->debug( "open, rated: $open, $rated" );

    my $gameId = undef;
    my $uid = undef;
    if ($gameType eq 'practice') {
                  # rematchOfGame, speed, open, rated, whiteId, blackId
        $gameId = createGame(undef, $gameSpeed, 0, $user->{player_id}, $user->{player_id});
    } elsif ($gameType eq 'ai') {
        $gameId = createGame(undef, $gameSpeed, 0, $user->{player_id}, AI_USER);
    } else {
        $uid = createChallenge(($user ? $user->{player_id} : -1), $gameSpeed, ($open ? 1 : 0), $rated);
    }


    my $return = {};
    if ($uid){
        $return->{uid} = $uid;
    }
    if ($gameId){
        $return->{gameId} = $gameId;
    }
    $c->render('json' => $return );
};

post '/ajax/chat' => sub {
    my $c = shift;
    my $user = $c->current_user();

    my $message = $c->req->param('message');
    my %return;
    if ($message =~ m/^\//) {
        if ($message =~ m/^\/msg\s(.+?)\s(.*)/){
            my $screenname = $1;
            my $text = $2;

            my $msg = {
                'c' => 'privatechat',
                'author'    => $user->{screenname},
                'user_id'   => $user->{player_id},
                'message'   => $text
            };
            my $success = screennameBroadcast($msg, $screenname);
            if ($success == -1) {
                $return{'message'} = 'delivery failed, unknown screenname';
            } elsif ($success == 0) {
                $return{'message'} = 'delivery failed, user offline';
            }
        } elsif ($message =~ m#^/invite\s(.*)#) {

        } else {
            $return{'message'} = "Unknown command";
        }
    } else {
        if ($user) {
            my $msg = {
                'c' => 'globalchat',
                'author'    => $user->{screenname},
                'user_id'   => $user->{player_id},
                'message'   => $message
            };

            $msg->{'color'} = $user->getBelt();
            globalBroadcast($msg);
        } else {
            $return{'message'} = "You must be logged in to chat.";
        }
    }

    $c->render('json' => \%return);
};

get '/ajax/pool/:speed' => sub {
    my $c = shift;

    # TODO gaurd for standard and lightning only

    my $user = $c->current_user();
    enterUpdatePool($user, $c->stash('speed'));
    my $gameId = matchPool($user, $c->stash('speed'));

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

    return $c->render('template' => 'profile', format => 'html', handler => 'ep');
};

get '/matchGame/:uid' => sub {
    my $c = shift;
    my $user = $c->current_user();

    my $gameId = matchGameUid($user, $c->stash('uid'));

    if ($gameId) {
        if ($user) {
            return $c->redirect_to("/game/$gameId");
        } else { 
            ### we have to matchmake based on anonKeys for anonymous users
            my $game = $currentGames{$gameId};
            return $c->redirect_to("/game/$gameId" . "?anon_key=" . $game->{blackAnonKey});
        }
    } else {
        return $c->redirect_to("/");
    }
};

get '/ajax/matchGame/:uid' => sub {
    my $c = shift;
    my $user = $c->current_user();

    my $gameId = matchGameUid($user, $c->stash('uid'));

    if ($gameId) {
        my $json = {};
        $json->{'gameId'} = $gameId;
        if (!$user) {
            my @row = app->db()->selectrow_array('SELECT white_anon_key FROM games WHERE game_id = ?', {}, $gameId);
            if (@row) {
                $json->{'anonKey'} = $row[0];
            }
        }

        $c->render('json' => $json);
    } else {
        $c->render('json' => { 'msg' => "Game Not Found" } );
    }
};

get '/ajax/cancelGame/:uid' => sub {
    my $c = shift;
    my $user = $c->current_user();

    my $result = cancelGameUid($user, $c->stash('uid'));

    $c->render('json' => { 'result' => $result } );
};

get '/openGames' => sub {
    my $c = shift;
    my $user = $c->current_user();
    $c->stash('user' => $user);

    my $uid = $c->req->param('uid');
    my $myGame = getMyOpenGame($user, $uid);

    my $openGames = getOpenGames();
    $c->stash('myGame' => $myGame);
    $c->stash('openGames' => $openGames);
    $c->stash('uid' => $uid);
    return $c->render('template' => 'openGames', format => 'html', handler => 'ep');
};

get '/ajax/openGames' => sub {
    my $c = shift;
    my $user = $c->current_user();
    $c->stash('user' => $user);

    my $uid = $c->req->param('uid');
    my $myGame = getMyOpenGame($user, $uid);

    my $openGames = getOpenGames();
    $c->stash('myGame' => $myGame);
    my @games = @{$openGames};
    my @grep = grep { $_->{player_id} != $myGame->{player_id} } @games;

    $c->stash('openGames' => \@grep);
    $c->stash('uid' => $uid);

    my %return = ();
    if ($myGame->{matched_game} ) {
        $return{'matchedGame'} = $myGame->{matched_game};
        if (!$user) {
            my @row = app->db()->selectrow_array('SELECT black_anon_key FROM games WHERE game_id = ?', {}, $myGame->{matched_game});
            if (@row) {
                $return{'anonKey'} = $row[0];
            }
        }
    }

    $return{'body'} = $c->render_to_string('template' => 'openGames', format => 'html', handler => 'ep');

    $c->render('json' => \%return);
};

get '/ajax/activeGames' => sub {
    my $c = shift;
    my $user = $c->current_user();
    $c->stash('user' => $user);

    my $games = getActiveGames();
    $c->stash('games' => $games);

    my %return = ();
    $return{'body'} = $c->render_to_string('template' => 'activeGames', format => 'html', handler => 'ep');

    $c->render('json' => \%return);
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
        $user = new KungFuChess::Player( { 'anon' => 1 });
    }
    $c->stash('user' => $user);
    app->log->debug("---- Entering game ----" );
    my $gameId = $c->stash('gameId');

    my $color = 'watch';

    my ($white, $black) = getPlayers($gameId);
    $c->stash('whitePlayer' => $white);
    $c->stash('blackPlayer' => $black);
    $c->stash('authId' => $user->{auth_token});
    $c->stash('anonKey' => $c->param('anonKey'));

    my $game = ($currentGames{$gameId} ? $currentGames{$gameId} : undef);
    my $gameRow = app->db()->selectrow_hashref('SELECT * FROM games WHERE game_id = ?', { 'Slice' => {} }, $gameId);

    $c->stash('positionGameMsgs' => $gameRow->{final_position});
    $c->stash('gameLog'          => $gameRow->{game_log});
    $c->stash('gameStatus'       => $gameRow->{status});
    my ($timerSpeed, $timerRecharge) = getPieceSpeed($gameRow->{game_speed});
    $c->stash('timerSpeed'    => $timerSpeed);
    $c->stash('timerRecharge' => $timerRecharge);

    if (defined($white->{player_id})){
        my $matchedKey = 1;
        if ($white->{player_id} == -1) {
            my @row = app->db()->selectrow_array('SELECT white_anon_key FROM games WHERE game_id = ?', {}, $gameId);
            if (@row) {
                $matchedKey = ($row[0] eq $c->param('anonKey'));
            }
        }
        if ($white->{player_id} == $user->{player_id} && $matchedKey){
            app->log->debug(" User is the white player $white->{player_id} vs $user->{player_id}" );
            $color = 'white';
        }
    }
    if (defined($black->{player_id})){
        my $matchedKey = 1;
        if ($black->{player_id} == -1) {
            my @row = app->db()->selectrow_array('SELECT black_anon_key FROM games WHERE game_id = ?', {}, $gameId);
            if (@row) {
                $matchedKey = ($row[0] eq $c->param('anonKey'));
            }
        }
        if ($black->{player_id} == $user->{player_id} && $matchedKey){
            app->log->debug(" User is the black player $black->{player_id} vs $user->{player_id}" );
            $color = ($color eq 'white' ? 'both' : 'black');
        }
    }
    if ($color ne 'watch' && $game) {
        $game->addPlayer($user, $color);
    }
    $c->stash('color', $color);

    $c->render('template' => 'board', format => 'html', handler => 'ep');
    return;
};

get '/createGame' => sub {
    my $c = shift;
    my $user = $c->current_user();
    $c->stash('user' => $user);

    $c->render('template' => 'createGame', format => 'html', handler => 'ep');
};

sub getPieceSpeed {
    my $speed = shift;
    my $pieceSpeed = 10;
    my $pieceRecharge = 10;

    if ($speed eq 'standard') {
        $pieceSpeed = 10;
        $pieceRecharge = 10;
    } elsif ($speed eq 'lightning') {
        $pieceSpeed = 2;
        $pieceRecharge = 2;
    } else {
        warn "unknown speed $speed\n";
    }
    return ($pieceSpeed, $pieceRecharge);
}

sub getAnonymousUser {
    my $anonUser = {
        'player_id'  => -1,
        'screenname' => 'anonymous',
        'rating'     => undef,
        'auth'       => create_uuid_as_string(),
    };
    return $anonUser;
}

sub createGame {
    my ($rematchOfGame, $speed, $rated, $white, $black) = @_;

    my $whiteUid = ($white == -1 ? create_uuid_as_string() : undef);
    my $blackUid = ($black == -1 ? create_uuid_as_string() : undef);

    if ($rematchOfGame) {
        my @row = app->db()->selectrow_array("SELECT game_speed, white_player, black_player, rated, white_anon_key, black_anon_key FROM games
            WHERE game_id = ?", {}, $rematchOfGame->{id});
        ($speed, $white, $black, $rated, $whiteUid, $blackUid) = @row;
    }

    my $auth = create_uuid_as_string();

    my $sth = app->db()->prepare("INSERT INTO games (game_id, game_speed, white_player, black_player, rated, white_anon_key, black_anon_key)
        VALUES (NULL, ?, ?, ?, ?, ?, ?)");
    $sth->execute($speed, $white, $black, $rated, $whiteUid, $blackUid);

    my $gameId = $sth->{mysql_insertid};

    $games{$gameId} = {
        'players' => {},
        'serverConn' => '',
        'auth'       => $auth,
        'begun'      => 0,
    };

    my $isAiGame =  ($black == AI_USER ? 1 : 0);

    $currentGames{$gameId} = KungFuChess::Game->new(
        $gameId,
        $speed,
        $auth,
        $whiteUid,
        $blackUid,
        $isAiGame
    );

    # spin up game server, wait for it to send authjoin
    app->log->debug( "starting game client $gameId, $auth" );
    # spin up game server, wait for it to send authjoin
    app->log->debug('/usr/bin/perl /home/corey/kungfuchess/kungFuChessGame.pl ' . $gameId . ' ' . $auth . ' ' . $speed . ' > /home/corey/game.log 2>/home/corey/errors.log &');
    system('/usr/bin/perl /home/corey/kungfuchess/kungFuChessGame.pl ' . $gameId . ' ' . $auth . ' ' . $speed . ' ' . $isAiGame . ' > /home/corey/game.log 2>/home/corey/errors.log &');

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
            if ($gameId) {
                endGame($gameId, 'server disconnect');
                delete $currentGames{$gameId};
                delete $games{$gameId};
                delete $gamesByServerConn{$connId};
                app->log->debug("game connection closed $connId");
            }
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

        if ($msg->{'c'} eq 'main_ping'){
            ### this is the global ping, not during the game
            if ($msg->{userAuthToken}) {
                $globalConnectionsByAuth{$msg->{userAuthToken}} = $self;
                app->db()->do('UPDATE players SET last_seen = NOW() WHERE auth_token = ?', {}, $msg->{userAuthToken});
            }
        }

        #### below are the in game only msgs
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

            $msg->{'color'} = $player->getBelt();
            app->log->debug("chat msg recieved");
            $game->playerBroadcast($msg);
        } elsif ($msg->{'c'} eq 'readyToRematch'){
            my $return = $game->playerRematchReady($msg);

        } elsif ($msg->{'c'} eq 'readyToBegin'){
            my $return = $game->playerReady($msg);
            app->log->debug("ready to begin msg");
            if ($return > 0){
                app->db()->do('UPDATE games SET status = "active" WHERE game_id = ?', {}, $game->{id});
            }
        } elsif ($msg->{'c'} eq 'serverping'){

        } elsif ($msg->{'c'} eq 'ping'){
            my $color = $game->authMove($msg);
            if ($color) {
                $msg->{'c'} = 'pong';
                $msg->{'color'} = $color;
                $game->playerBroadcast($msg);
            };
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

            $game->playerBroadcast($msg);
        } elsif ($msg->{'c'} eq 'revokeDraw'){
            if (! gameauth($msg) ){ return 0; }
            my $color = $game->authMove($msg);
            return 0 if (!$color);

            $game->playerRevokeDraw($msg);

            $game->playerBroadcast($msg);
        } elsif ($msg->{'c'} eq 'forceDraw'){
            if (! gameauth($msg) ){ return 0; }
            endGame($msg->{gameId}, 'draw');

            my $drawnMsg = {
                'c' => 'gameDrawn'
            };

            $game->playerBroadcast($drawnMsg);
            $game->serverBroadcast($drawnMsg);
        } elsif ($msg->{'c'} eq 'requestDraw'){
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
                $game->serverBroadcast($msg);
            }
        } elsif ($msg->{'c'} eq 'abort'){
            my $color = $game->authMove($msg);
            return 0 if (!$color);
            return 0 if ($game->gameBegan());

            $game->playerBroadcast($msg);
            $game->serverBroadcast($msg);
            endGame($msg->{gameId}, 'aborted');
        } elsif ($msg->{'c'} eq 'resign'){
            my $color = $game->authMove($msg);
            return 0 if (!$color);

            $msg->{'color'} = $color;
            $game->playerBroadcast($msg);
            $game->serverBroadcast($msg);

            my $result = '';
            if ($color eq 'black'){
                $result = 'black resigns';
            } elsif ($color eq 'white'){
                $result = 'white resigns';
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
        } elsif ($msg->{'c'} eq 'gamePositionMsgs'){
            print "game positions updating...\n";
            if (! gameauth($msg) ){ return 0; }
            updateFinalGamePosition($game->{id}, $msg->{msgs});
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
    return 0 if (! ($msg->{gameId} && $msg->{auth}));                          # no game / auth tokens
    return 0 if ($games{$msg->{gameId}}->{auth} ne $msg->{auth});              # incorrect server auth

    return 1;
}

sub updateFinalGamePosition {
    my $gameId = shift;
    my $msgs = shift;

    print "gameid, msgs: $gameId, $msgs\n";

    app->db()->do('UPDATE games SET final_position = ? WHERE game_id = ?',
        {},
        $msgs,
        $gameId
    );
}

sub screennameBroadcast {
    my $msg = shift;
    my $screenname = shift;
    my @userRow = app->db()->selectrow_array('SELECT player_id, auth_token FROM players WHERE screenname = ?', {}, $screenname);
    if (! @userRow) { return -1; }
    print " user row found\n";
    if (! $globalConnectionsByAuth{ $userRow[1] }) { return 0; }
    print " connection found found\n";

    my $connection = $globalConnectionsByAuth{ $userRow[1] };
    $connection->send(encode_json $msg);
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
    my $gameSpeed = shift;
    my $score  = shift;

    app()->log->debug("updating ratings for $gameId, " . ($score ? 'score' : '(no score)'));

    if (!$score || $score !~ m/\d-\d/) {
        app()->log->debug("invalid score.");
        return;
    }
    my ($result, $bresult) = split('-', $score);

    my ($white, $black) = getPlayers($gameId);

    # k variable controls change rate
    my $k = 32;

    my $ratingColumn = "rating_$gameSpeed";
    
    # transformed rating (on a normal curve)
    my $r1 = 10 ** ($white->{$ratingColumn} / 400);
    my $r2 = 10 ** ($black->{$ratingColumn} / 400);

    # expected score
    my $e1 = $r1 / ($r1 + $r2);
    my $e2 = $r2 / ($r1 + $r2);

    $white->{$ratingColumn} = $white->{$ratingColumn} + $k * ($result - $e1);
    $black->{$ratingColumn} = $black->{$ratingColumn} + $k * ((1 - $result) - $e2);
    savePlayer($white, $result, $gameSpeed);
    savePlayer($black, 1 - $result, $gameSpeed);

    return ($white, $black);
}

sub endGame {
    my $gameId = shift;
    my $result = shift;

    my $score = undef;

    if ($result eq 'black wins' || $result eq 'win resigns') {
        $score = '0-1';
    } elsif ($result eq 'white wins' || $result eq 'black resigns') {
        $score = '1-0';
    } elsif ($result eq 'draw' || $result eq 'forced draw') {
        $score = '0.5-0.5';
    }

    app->log->debug('ending game: ' . $gameId . ' to ' . $result);

    my @gameRow = app->db()->selectrow_array("SELECT status, game_speed, rated FROM games WHERE game_id = ?", {}, $gameId);

    if (! @gameRow ) {
        app->debug("  game doesn't exist so it cannot be ended!! $gameId");
        return 0;
    }

    my ($status, $gameSpeed, $rated) = @gameRow;

    app->db()->do("DELETE FROM pool WHERE matched_game = ?", {}, $gameId);

        if ($status eq 'finished') {
        app->log->debug("  $gameId already ended ($status)");
        return 0;
    }

    my $gameLog = "";
    if (exists($currentGames{$gameId})) {
        my $game = $currentGames{$gameId};
        $gameLog = encode_json($game->{gameLog});
    }

    ### set result
    app->db()->do(
        'UPDATE games SET `status` = "finished", result = ?, score = ?, time_ended = NOW(), game_log = ? WHERE game_id = ?',
        {},
        $result,
        $score,
        $gameLog,
        $gameId,
    );

    my ($whiteStart, $blackStart) = getPlayers($gameId);

    my ($whiteEnd, $blackEnd) =($whiteStart, $blackStart);
    if ($rated) {
        ($whiteEnd, $blackEnd) = updateRatings($gameId, $gameSpeed, $score);   
    }

    if ($result eq 'white wins' || $result eq 'black wins' || $result eq 'draw') {
        ### write to game log for both players
        if ($whiteStart->{player_id}) {
            app->db()->do('INSERT INTO game_log
                (game_id, player_id, opponent_id, game_type, result, rating_before, rating_after, opponent_rating_before, opponent_rating_after, rated)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {},
                $gameId,
                $whiteStart->{player_id},
                $blackStart->{player_id},
                $gameSpeed,
                ($result eq 'draw' ? 'draw' : ($result eq 'white wins' ? 'win' : 'loss') ),
                $whiteStart->{"rating_$gameSpeed"},
                $whiteEnd->{"rating_$gameSpeed"},
                $blackStart->{"rating_$gameSpeed"},
                $blackEnd->{"rating_$gameSpeed"},
                $rated
            );
        }

        if ($blackStart->{player_id}) {
            app->db()->do('INSERT INTO game_log
                (game_id, player_id, opponent_id, game_type, result, rating_before, rating_after, opponent_rating_before, opponent_rating_after, rated)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {},
                $gameId,
                $blackStart->{player_id},
                $whiteStart->{player_id},
                $gameSpeed,
                ($result eq 'draw' ? 'draw' : ($result eq 'white wins' ? 'loss' : 'win') ),
                $blackStart->{"rating_$gameSpeed"},
                $blackEnd->{"rating_$gameSpeed"},
                $whiteStart->{"rating_$gameSpeed"},
                $whiteEnd->{"rating_$gameSpeed"},
                1
            );
        }
    }


    # TODO delete games by connection and anything else.
    # if the connection is still active send the server 
    # a msg to shut down.
    #delete $games{$gameId}; ## we still need it to get positions etc
    return 1;
}

sub getPlayers {
    my $gameId = shift;

    ### TODO rating column can be delete?
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
    my ($ratedOnly, $gameSpeed) = @_;
    my $additionalWhere = "";
    if ($gameSpeed && ($gameSpeed eq 'standard' || $gameSpeed eq 'lightning')) {
        $additionalWhere = "WHERE game_speed = $gameSpeed";
    }
    my @rows = qw(game_id time_created white_id white_rating white_screenname black_id black_rating black_screenname);
    my $games = app->db()->selectall_arrayref('
        SELECT 
            g.game_id,
            g.rated,
            g.game_speed,
            g.time_created,
            w.player_id as white_player_id,
            IF (g.game_speed = "standard", w.rating_standard, w.rating_lightning) as white_rating,
            w.screenname as white_screenname,
            b.player_id as black_player_id,
            IF (g.game_speed = "standard", b.rating_standard, b.rating_lightning) as black_rating,
            b.screenname as black_screenname
        FROM games g
        LEFT JOIN players w ON g.white_player = w.player_id
        LEFT JOIN players b ON g.black_player = b.player_id
        WHERE status = "active"
        ' . $additionalWhere . '
        ORDER BY white_rating + black_rating
    ',
        { 'Slice' => {} }
    );

    return $games;
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

sub getMyOpenGame {
    my $user = shift;
    my $uid = shift;

    my $playerId = ($user ? $user->{player_id} : -1);

    ### TODO if not anon user delete other games
    my $myGame = app->db()->selectrow_hashref('
        SELECT p.matched_game, p.player_id, p.rated, p.private_game_key, p.game_speed,
               py.rating_standard, py.rating_lightning, py.screenname, p.in_matching_pool
        FROM pool p LEFT JOIN players py ON p.player_id = py.player_id
            WHERE p.player_id = ?
            AND p.private_game_key = ?
        ',
        { 'Slice' => {} },
        $playerId,
        $uid
    );

    if ($myGame) {
        app->db()->do( 'UPDATE pool SET last_ping = NOW()
                WHERE player_id = ?
                AND private_game_key = ?',
            {},
            $playerId,
            $uid
        );
    }

    return $myGame;
}

sub getOpenGames {
    my $poolRows = app->db()->selectall_arrayref('
        SELECT p.player_id, p.rated, p.private_game_key, p.game_speed, py.rating_standard, py.rating_lightning, py.screenname
        FROM pool p LEFT JOIN players py ON p.player_id = py.player_id
            WHERE in_matching_pool = 0
            AND last_ping > NOW() - INTERVAL 4 SECOND
            AND open_to_public = 1
        ',
        { 'Slice' => {} }
    );

    return $poolRows;
}

### entering the pool WILL destroy any open games you have, you cannot do both
sub enterUpdatePool {
    my $player = shift;
    my $gameSpeed = shift;

    if (! $player) { 
        return 0;
    }
    if (! $player->{player_id}) {
        return 0;
    }

    my $sth = app->db()->prepare('INSERT INTO pool (player_id, game_speed, rated, last_ping) VALUES (?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE game_speed = ?, rated = ?, last_ping = NOW(), in_matching_pool = 1, private_game_key = NULL, open_to_public = 1
    ');
    $sth->execute($player->{'player_id'}, $gameSpeed, 1, $gameSpeed, 1);
}

sub createChallenge {
    my ($playerId, $gameSpeed, $open, $rated) = @_;

    app->db()->do("DELETE FROM pool WHERE player_id = ?", {}, $playerId);

    my $sth = app->db()->prepare('INSERT INTO pool
        (player_id, game_speed, open_to_public, rated, private_game_key, in_matching_pool, last_ping)
        VALUES (?, ?, ?, ?, ?, 0, NOW())');

    my $uuid = create_uuid_as_string();
    $sth->execute($playerId, $gameSpeed, $open, $rated, $uuid);

    return $uuid;
}

sub matchGameUid {
    my $player = shift;
    my $uid = shift;

    my $playerId = ($player ? $player->{player_id} : -1);

    my $poolRow = app->db()->selectrow_hashref('SELECT * FROM pool WHERE private_game_key = ?',
        { 'Slice' => {} },
        $uid
    );

    if (! $poolRow ) {
        return undef;
    } else {
        if ($poolRow->{rated} && $playerId == -1) {
            return undef;
        }
                  # rematchOfGame, speed, open, rated, whiteId, blackId
        my $gameId = createGame(undef, $poolRow->{game_speed}, $poolRow->{rated}, $playerId, $poolRow->{player_id});

        app->db()->do('UPDATE pool SET matched_game = ? WHERE private_game_key = ?', {}, $gameId, $uid);
        return $gameId;
    }
}

sub cancelGameUid {
    my $player = shift;
    my $uid = shift;

    my $playerId = ($player ? $player->{player_id} : -1);

    app->db()->do('DELETE FROM pool WHERE player_id = ? AND private_game_key = ?', {}, $playerId, $uid);

    return 1;
}

sub matchPool {
    my $player = shift;
    my $gameSpeed = shift;

    if (!$gameSpeed) { $gameSpeed = 'standard'; }

    my $ratingColumn = 'rating_' . $gameSpeed;
    my @gameMatch = app->db()->selectrow_array(
        'SELECT player_id, matched_game FROM pool WHERE player_id = ? AND in_matching_pool = 1 AND game_speed = ?', {}, $player->{'player_id'}, $gameSpeed);

    if (@gameMatch) {
        my ($player_id, $matched_game) = @gameMatch;
        if ($matched_game) {
            my @gameRow = app->db()->selectrow_array(
                'SELECT status, white_player, black_player FROM games WHERE game_id = ?',
                {},
                $matched_game
            );
            
            my ($gameStatus, $blackPlayer, $whitePlayer) = @gameRow;
            print "\nmatched game $matched_game: $gameStatus, $blackPlayer, $whitePlayer\n\n";
            if ($gameStatus eq 'waiting to begin' && ($blackPlayer == $player->{'player_id'} || $whitePlayer == $player->{'player_id'}) ) {
                print "returning $matched_game\n";
                return $matched_game;
            } else { ### the matched game is over or obsolete
                app->db()->do("UPDATE pool SET matched_game = NULL WHERE player_id = ?", {}, $player->{'player_id'});
            }
        }
    }

    ### now we try to find if any player matched them.
    my $matchSql = 
        'SELECT p.player_id FROM pool p
            LEFT JOIN players pl ON p.player_id = pl.player_id
            WHERE p.player_id != ?
            AND in_matching_pool = 1
            AND game_speed = ?
            AND last_ping > NOW() - INTERVAL 3 SECOND
            ORDER BY abs(? - ' . $ratingColumn . ') limit 1';
    my @playerMatchedRow = app->db()->selectrow_array(
        $matchSql,
        {},
        $player->{'player_id'}, $gameSpeed, $player->{$ratingColumn}
    );

    if (@playerMatchedRow) {
        my $playerMatchedId = $playerMatchedRow[0];
                  # rematchOfGame, speed, rated, whiteId, blackId
        my $gameId = createGame(undef, $gameSpeed, 1, $player->{'player_id'}, $playerMatchedId);

        app->db()->do('UPDATE pool SET matched_game = ? WHERE player_id IN (?, ?)', {}, $gameId, $player->{'player_id'}, $playerMatchedId);

        return $gameId;
    }

    return undef;
}

app->start;
