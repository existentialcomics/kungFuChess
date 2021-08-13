#!/usr/bin/perl
#
use strict; use warnings;
use Mojolicious::Lite;
use Mojolicious::Plugin::Database;
use Mojolicious::Plugin::Authentication;
use Mojolicious::Validator;
use Mojolicious::Validator::Validation;
use Mojolicious::Plugin::CSRFProtect;
use UUID::Tiny ':std';
use Data::Dumper;
use JSON::XS;
use Config::Simple;
use HTML::Escape qw/escape_html/;
# via the Digest module (recommended)
use Digest;

use Cwd qw( abs_path );
use File::Basename qw( dirname );
use lib dirname(abs_path($0));

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
my %gameConnections = ();

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
app->plugin('CSRFProtect');

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
clearInactiveGames();

get '/admin/clear-inactive-games' => sub {
    my $c = shift;
    clearInactiveGames();
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


#####################################
###
###
post '/ajax/createChallenge' => sub {
    my $c = shift;
    my $user = $c->current_user();
    $c->stash('user' => $user);
    #   standard/light , 2way/4way , unrated/ai/etc, open to public
    my ($gameSpeed, $gamePlayerType, $gameType, $open) =
        ($c->req->param('gameSpeed'), $c->req->param('gamePlayersType'), $c->req->param('gameType'), $c->req->param('open'));

    my $rated = ($gameType eq 'rated' ? 1 : 0);
    app->log->debug( "open, rated: $open, $rated" );

    my $gameId = undef;
    my $uid = undef;
    if ($gameType eq 'practice') {
                  # speed, type, open, rated, whiteId, blackId
        $gameId = createGame($gamePlayerType, $gameSpeed, 0, ($user ? $user->{player_id} : ANON_USER), ($user ? $user->{player_id} : -1), ($user ? $user->{player_id} : ANON_USER), ($user ? $user->{player_id} : -1));
        if (! $user) {
            app->db()->do("UPDATE games SET black_anon_key = white_anon_key WHERE game_id = ?", {}, $gameId);
        }
    } elsif ($gameType eq 'ai') {
        $gameId = createGame($gamePlayerType, $gameSpeed, 0, ($user ? $user->{player_id} : ANON_USER), AI_USER);
    } else {
        $uid = createChallenge(($user ? $user->{player_id} : -1), $gameSpeed, ($open ? 1 : 0), $rated, undef);
    }

    my $return = {};
    if ($uid){
        $return->{uid} = $uid;
    }
    if ($gameId){
        $return->{gameId} = $gameId;
        if (! $user) {
            my $row = app->db()->selectrow_arrayref("SELECT white_anon_key FROM games WHERE game_id = ?", {}, $gameId);
            $return->{anonKey} = $row->[0];
        }
    }
    $c->render('json' => $return );
};

#####################################
###
###
get '/ajax/rematch' => sub {
    my $c = shift;
    my $user = $c->current_user();
    $c->stash('user' => $user);

    my ($origGameId) = ($c->req->param('gameId'));

    my $gameRow = app->db()->selectrow_hashref('SELECT * FROM games WHERE game_id = ?', { 'Slice' => {} }, $origGameId);

    my $myId = undef;
    my $challengeId = undef;
    if ($gameRow->{white_player} eq $user->{player_id}) {
        $myId        = $gameRow->{white_player};
        $challengeId = $gameRow->{black_player};
    } elsif ($gameRow->{black_player} eq $user->{player_id}) {
        $myId        = $gameRow->{black_player};
        $challengeId = $gameRow->{white_player};
    } else {
        ### abort 403
    }

    app->log->debug("myId: $myId, chalId: $challengeId");

    my $gameId = undef;
    my $uid = undef;
    if ($gameRow->{white_player} eq $gameRow->{black_player}) {
                  # speed, open, rated, whiteId, blackId
        $gameId = createGame($gameRow->{game_type}, $gameRow->{game_speed}, 0, $gameRow->{white_player}, $gameRow->{black_player});
        if (! $user) {
            app->db()->do("UPDATE games SET black_anon_key = white_anon_key WHERE game_id = ?", {}, $gameId);
        }
    } elsif ($challengeId eq AI_USER) {
        $gameId = createGame($gameRow->{game_type}, $gameRow->{game_speed}, 0, $myId, AI_USER);
    } else { ### rematch with another player
        my $existingRematch = app->db()->selectrow_hashref(
            'SELECT * FROM pool
            WHERE player_id = ?
            AND challenge_player_id = ?
            AND rated = ?
            AND game_speed = ?', { },
            $challengeId,
            $myId,
            $gameRow->{rated},
            $gameRow->{game_speed}
        );

        my $myRematchAccepted = app->db()->selectrow_hashref(
            'SELECT * FROM pool
            WHERE player_id = ?
            AND challenge_player_id = ?
            AND rated = ?
            AND game_speed = ?
            AND matched_game IS NOT NULL
            ', { },
            $myId,
            $challengeId,
            $gameRow->{rated},
            $gameRow->{game_speed}
        );

        if ($existingRematch) {
            $gameId = createGame($gameRow->{game_type}, $gameRow->{game_speed}, 0, $challengeId, $myId);
            app->db()->do('
                UPDATE pool
                SET matched_game = ?
                WHERE player_id = ?
                AND challenge_player_id = ?
                AND rated = ?
                AND game_speed = ?', { },
                $gameId,
                $challengeId,
                $myId,
                $gameRow->{rated},
                $gameRow->{game_speed}
            );
        } elsif ($myRematchAccepted) {
            $gameId = $myRematchAccepted->{matched_game};
        } else {
            $uid = createChallenge($myId, $gameRow->{game_speed}, 0, $gameRow->{rated}, $challengeId);
        }
    }

    my $return = {};
    if ($uid){
        $return->{uid} = $uid;
    }
    if ($gameId){
        $return->{gameId} = $gameId;
        if (! $user) {
            my $row = app->db()->selectrow_arrayref("SELECT white_anon_key FROM games WHERE game_id = ?", {}, $gameId);
            $return->{anonKey} = $row->[0];
        }
    }
    $c->render('json' => $return );
};

#####################################
###
###
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

#####################################
###
###
get '/ajax/pool/:speed/:type' => sub {
    my $c = shift;

    # TODO gaurd for standard and lightning, 2way and 4way only

    my $user = $c->current_user();
    enterUpdatePool(
        $user,
        { 
            'gameSpeed' => $c->stash('speed'),
            'gameType'  => $c->stash('type')
        }
    );
    my $gameId = matchPool($user, $c->stash('speed'), $c->stash('type'));

    my $json = {};

    if ($gameId) {
        $json->{'gameId'} = $gameId;
    }

    $c->render('json' => $json);
};

#####################################
###
###
get '/about' => sub {
    my $c = shift;
    my $user = $c->current_user();
    $c->stash('user' => $user);

    $c->render('template' => 'about', format => 'html', handler => 'ep');
};

get '/forums' => sub {
    my $c = shift;
    my $user = $c->current_user();
    $c->stash('user' => $user);

    $c->render('template' => 'forums', format => 'html', handler => 'ep');
};

get '/forums/:topic' => sub {
    my $c = shift;
    my $user = $c->current_user();
    $c->stash('user' => $user);
    my $page = $c->req->param('page');
    my $limit = 5;
    if ($page) {
        $page =~ s/[^\d]//;
        if ($page eq '') { $page = 1; }
    } else {
        $page = 1;
    }
    my $offset = ($page - 1) * $limit;

    my $posts = app->db()->selectall_arrayref(
        "SELECT forum_post.*, players.*, forum_post.post_text as preview,
        count(forum_comment.forum_comment_id) as comment_count FROM forum_post
            LEFT JOIN players ON forum_post.player_id = players.player_id 
            INNER JOIN forum_comment ON forum_post.forum_post_id = forum_comment.forum_post_id
            WHERE category = ?
            GROUP BY forum_comment.forum_comment_id
            LIMIT $limit OFFSET $offset
            ",
        { 'Slice' => {} },
        topicToCategory($c->stash('topic'))
    );
    my $max = app->db()->selectrow_arrayref('SELECT COUNT(*) FROM forum_post WHERE category = ?'
        ,
        {},
        topicToCategory($c->stash('topic'))
    );

    my $maxPage = $max->[0] / $limit;
    $c->stash('page' => $page);

    foreach my $post (@$posts) {
        $post->{player} = new KungFuChess::Player({ row => $post }, app->db());
    }
    $c->stash('posts' => $posts);

    $c->render('template' => 'forumsTopic', format => 'html', handler => 'ep');
};

sub topicToCategory {
    my $topic = shift;
    if ($topic eq 'kungfuchess') { return 'chess'; }
    #if ($_ eq 'feedback') { return 'feedback'; }
    #if ($_ eq 'off-topic') { return 'off-topic'; }
    return $topic;
}

### create a forum post
post '/forums/:topic' => sub {
    my $c = shift;
    my $user = $c->current_user();
    $c->stash('user' => $user);
    my $topic   = $c->stash('topic');
    my $subject = $c->req->param('subject');
    my $text    = $c->req->param('body');

    my $sth = app->db()->prepare('INSERT INTO forum_post (category, post_title, post_text, player_id, post_time) VALUES (?, ?, ?, ?, NOW())', {}); 

    $sth->execute(
        topicToCategory($c->stash('topic')),
        $subject,
        $text,
        $user->{player_id}
    );
    
    my $id = $sth->{mysql_insertid};

    $c->redirect_to("/forums/$topic/$id");
};

### create a forum post form
get '/forums/:topic/post' => sub {
    my $c = shift;
    my $user = $c->current_user();
    $c->stash('user' => $user);
    $c->render('template' => 'forumsForm', format => 'html', handler => 'ep');
};

get '/forums/:topic/:postId' => sub {
    my $c = shift;
    my $user = $c->current_user();
    $c->stash('user' => $user);

    my $post = app()->db->selectrow_hashref('SELECT * FROM forum_post LEFT JOIN players ON forum_post.player_id = players.player_id WHERE forum_post_id = ?', {}, $c->stash('postId'));
    $post->{player} = new KungFuChess::Player({ row => $post }, app->db());
    $c->stash('post' => $post);


    my $comments = app()->db->selectall_arrayref(
        'SELECT * FROM forum_comment LEFT JOIN players ON forum_comment.player_id = players.player_id WHERE forum_post_id = ?',
        { 'Slice' => {} },
        $c->stash('postId')
    );
    foreach my $comment (@$comments) {
        $comment->{player} = new KungFuChess::Player({ row => $comment }, app->db());
    }
    $c->stash('comments' => $comments);

    $c->render('template' => 'forumPost', format => 'html', handler => 'ep');
};

### create a comment
post '/forums/:topic/:postId' => sub {
    my $c = shift;
    my $user = $c->current_user();
    $c->stash('user' => $user);
    my $postId = $c->stash('postId');
    my $commentText  = $c->req->param('comment');
    my $topic  = $c->stash('topic');

    my $sth = app->db()->prepare('INSERT INTO forum_comment (forum_post_id, comment_text, player_id, post_time) VALUES (?, ?, ?, NOW())', {}); 

    $sth->execute(
        $postId,
        $commentText,
        $user->{player_id}
    );

    $c->redirect_to('/forums/' . $topic . '/' . $postId);
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

    my ($white, $black, $red, $green) = getPlayers($gameId);
    $c->stash('whitePlayer' => $white);
    $c->stash('blackPlayer' => $black);
    $c->stash('redPlayer'   => $red);
    $c->stash('greenPlayer' => $green);
    $c->stash('authId' => $user->{auth_token});
    $c->stash('anonKey' => $c->param('anonKey'));

    my $game = ($currentGames{$gameId} ? $currentGames{$gameId} : undef);
    my $gameRow = app->db()->selectrow_hashref('SELECT * FROM games WHERE game_id = ?', { 'Slice' => {} }, $gameId);

    $c->stash('positionGameMsgs' => $gameRow->{final_position});
    $c->stash('gameLog'          => $gameRow->{game_log});
    $c->stash('chatLog'          => ($game ? encode_json($game->{chatLog}) : undef));
    $c->stash('gameStatus'       => $gameRow->{status});
    my ($timerSpeed, $timerRecharge) = getPieceSpeed($gameRow->{game_speed});
    $c->stash('gameSpeed'     => $gameRow->{game_speed});
    $c->stash('gameType'      => $gameRow->{game_type});
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
    if (defined($red->{player_id})){
        my $matchedKey = 1;
        if ($red->{player_id} == -1) {
            my @row = app->db()->selectrow_array('SELECT red_anon_key FROM games WHERE game_id = ?', {}, $gameId);
            if (@row) {
                $matchedKey = ($row[0] eq $c->param('anonKey'));
            }
        }
        if ($red->{player_id} == $user->{player_id} && $matchedKey){
            app->log->debug(" User is the red player $red->{player_id} vs $user->{player_id}" );
            $color = ($color eq 'both' ? 'both' : 'red');
        }
    }
    if (defined($green->{player_id})){
        my $matchedKey = 1;
        if ($green->{player_id} == -1) {
            my @row = app->db()->selectrow_array('SELECT green_anon_key FROM games WHERE game_id = ?', {}, $gameId);
            if (@row) {
                $matchedKey = ($row[0] eq $c->param('anonKey'));
            }
        }
        if ($green->{player_id} == $user->{player_id} && $matchedKey){
            app->log->debug(" User is the green player $green->{player_id} vs $user->{player_id}" );
            $color = ($color eq 'both' ? 'both' : 'green');
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
    my ($mode, $speed, $rated, $white, $black, $red, $green) = @_;
    app->log->debug("creating game with $mode, $speed, $rated, $white, $black, $red, $green\n");

    my $whiteUid = ($white == ANON_USER || $black == AI_USER ? create_uuid_as_string() : undef);
    my $blackUid = ($black == ANON_USER || $black == AI_USER ? create_uuid_as_string() : undef);
    my $redUid   = undef;
    my $greenUid = undef;
    if ($mode eq '4way') {
        $redUid   = ($white == ANON_USER ? create_uuid_as_string() : undef);
        $greenUid = ($black == ANON_USER ? create_uuid_as_string() : undef);
    }

    my $auth = create_uuid_as_string();

    my $sth = app->db()->prepare("INSERT INTO games (game_id, game_speed, game_type, white_player, black_player, red_player, green_player, rated, white_anon_key, black_anon_key, red_anon_key, green_anon_key)
        VALUES (NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
    $sth->execute($speed, $mode, $white, $black, $red, $green, $rated, $whiteUid, $blackUid, $redUid, $greenUid);

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
        $mode,
        $speed,
        $auth,
        $whiteUid,
        $blackUid,
        $isAiGame
    );

    # spin up game server, wait for it to send authjoin
    app->log->debug( "starting game client $gameId, $auth" );
    # spin up game server, wait for it to send authjoin
    my $cmd = sprintf('/usr/bin/perl ./kungFuChessGame%s.pl %s %s %s %s >%s  2>%s &',
        $mode,
        $gameId,
        $auth,
        $speed,
        0,       # ai
        '/var/log/kungfuchess/game.log',
        '/var/log/kungfuchess/error.log'
    );
    app->log->debug($cmd);
    system($cmd);

    if ($isAiGame) {
        my $aiUser = new KungFuChess::Player(
            { 'ai' => 1, 'auth_token' => $blackUid }
        );
        my $cmdAi = sprintf('/usr/bin/perl ./kungFuChessGame%sAi.pl %s %s %s %s >%s  2>%s &',
            $mode,
            $gameId,
            $blackUid,
            $speed,
            1,       # ai
            '/var/log/kungfuchess/game-ai.log',
            '/var/log/kungfuchess/error-ai.log'
        );
        app->log->debug($cmdAi);
        system($cmdAi);
        $currentGames{$gameId}->addPlayer($aiUser, 'black');
    }

    return $gameId;
}

get '/register' => sub {
    my $c = shift;
    my $user = $c->current_user();
    $c->stash('user' => $user);
    $c->render('template' => 'register', format => 'html', handler => 'ep');
};

post '/register' => sub {
    my $c = shift;
    my $user = $c->current_user();
    $c->stash('user' => $user);

    my ($u, $p) = ($c->req->param('username'), $c->req->param('password'));

    my $existing = app->db()->selectall_arrayref('SELECT * FROM players WHERE screenname = ?', {}, $u);
    if (@$existing) {
        $c->stash('error' => 'Username ' . $u . ' already exists!');
        return $c->render('template' => 'register', format => 'html', handler => 'ep');
    }
    $c->db()->do('INSERT INTO players (screenname, password, rating_standard, rating_lightning)
            VALUES (?, ?, 1400, 1400)', {}, $u, encryptPassword($p));

    if ($c->authenticate($u, encryptPassword($p))){
        my $user = $c->current_user();
        $c->stash('user' => $user);
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
                delete $gameConnections{$gameId};
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
        } elsif ($msg->{'c'} eq 'chat') {
            my $player = new KungFuChess::Player({auth_token => $msg->{auth}}, app->db());
            print "chat msg:\n";
            print Dumper($msg);
            print "----\n";
            $msg->{'message'} = escape_html($msg->{'message'});
            $msg->{'author'}  = escape_html( ($player ? $player->{screenname} : "anonymous") );

            $msg->{'color'} = $player->getBelt();
            app->log->debug("chat msg recieved");
            foreach my $conn (values %{$gameConnections{$gameId}}) {
                $conn->send(encode_json($msg));
            }
        }

        #app->log->debug('message about to be game checked ' . $msg->{c});
        #### below are the in game only msgs
        return 0 if (! $msg->{gameId} );
        my $game = $currentGames{$msg->{gameId}};
        return 0 if (! $game);
        #app->log->debug('message game checked ' . $msg->{c});

        if ($msg->{'c'} eq 'join'){
            $game->addConnection($connId, $self);
            $gameConnections{$gameId}->{$connId} = $self;
            $playerGamesByServerConn{$connId} = $msg->{gameId};

            if ($game->serverReady()) {
                my $ret = {
                    'c' => 'joined',
                };
                $self->send(encode_json $ret);
                $game->serverBroadcast($msg);
                app->log->debug('player joined');
            } else {
                my $retNotReady = {
                    'c' => 'notready',
                };
                $self->send(encode_json $retNotReady);
                $game->serverBroadcast($msg);
            }
        } elsif ($msg->{'c'} eq 'chat'){
            my $player = new KungFuChess::Player({auth_token => $msg->{auth}}, app->db());

            if ($msg->{'message'} =~ m/^\/(\S+)(?:\s(.*))?/) {
                my $command = $1;
                my $args    = $2;
                if ($command eq 'switch') {
                    print "command switch\n";
                    my $color = $game->authMove($msg);
                    my ($colorSrc, $colorDst) = split(' ', $args);
                    print "colors: $colorSrc $colorDst vs $color\n";
                    if ($colorSrc eq $color) {
                        if ($colorDst eq 'white' || $colorDst eq 'black') {
                            my @players1 = app()->db->selectrow_array("SELECT ${colorSrc}_player, status FROM games WHERE game_id = ? limit 1", {}, $game->{id});
                            my @players2 = app()->db->selectrow_array("SELECT ${colorDst}_player, status FROM games WHERE game_id = ? limit 1", {}, $game->{id});
                            if ($players1[1] eq 'waiting to begin') {
                                app()->db->do("UPDATE games SET ${colorSrc}_player = ? WHERE game_id = ? limit 1", {}, $players2[0], $game->{id});
                                app()->db->do("UPDATE games SET ${colorDst}_player = ? WHERE game_id = ? limit 1", {}, $players1[0], $game->{id});
                                my $commandMsg = {
                                    'c' => 'refresh'
                                };
                                $game->playerBroadcast($commandMsg);
                            } else {
                                my $sysMsg = {
                                    'c'   => 'systemMsg', 
                                    'msg' => 'Cannot switch once game has begun'
                                };
                                $game->playerBroadcast($sysMsg);
                            }
                        }
                    } else {
                        my $commandMsg = {
                            'c' => 'systemMsg',
                            'msg' => 'you can only change your own color'
                        };
                        $game->playerBroadcast($commandMsg);
                    }
                } else {
                    my $commandMsg = {
                        'c' => 'systemMsg',
                        'msg' => 'unknown command.'
                    };
                    $game->playerBroadcast($commandMsg);
                }
            } else {
            }
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
            app->log->debug('game has begun');

            app->log->debug($msg->{auth});
            my $color = $game->authMove($msg);
            app->log->debug("moving $color");

            return 0 if (!$color);

            app->log->debug('move authed for ' . $color);
            $msg->{color} = $color;

            # pass the move request to the server
            # TODO pass the player's color to the server
            $game->serverBroadcast($msg);
        } elsif ($msg->{'c'} eq 'authunsuspend'){
            if (! gameauth($msg) ){ return 0; }
            # pass the move request to the server
            $msg->{'c'} = 'unsuspend';
            $game->playerBroadcast($msg);
        } elsif ($msg->{'c'} eq 'authsuspend'){
            if (! gameauth($msg) ){ return 0; }
            # pass the move request to the server
            $msg->{'c'} = 'suspend';
            $game->playerBroadcast($msg);
        } elsif ($msg->{'c'} eq 'authmovestep'){
            if (! gameauth($msg) ){ return 0; }
            # pass the move request to the server
            $msg->{'c'} = 'move';
            $game->playerBroadcast($msg);
        } elsif ($msg->{'c'} eq 'authstop'){
            if (! gameauth($msg) ){ return 0; }
            # pass the move request to the server
            $msg->{'c'} = 'stop';
            $game->playerBroadcast($msg);
        } elsif ($msg->{'c'} eq 'authmove'){ # for animation only
            if (! gameauth($msg) ){ return 0; }

            # tell the players to animate the pieces
            $msg->{'c'} = 'moveAnimate';
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
        } elsif ($msg->{'c'} eq 'requestDraw'){
            my $color = $game->authMove($msg);
            return 0 if (!$color);

            my $drawConfirmed = $game->playerDraw($msg);
            if ($drawConfirmed) {
                endGame($msg->{gameId}, 'draw');

                my $drawnMsg = {
                    'c' => 'requestDraw'
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

            endGame($msg->{gameId}, 'aborted');
        } elsif ($msg->{'c'} eq 'resign'){
            my $color = $game->authMove($msg);
            return 0 if (!$color);

            $msg->{'color'} = $color;
            $game->playerBroadcast($msg);
            $game->serverBroadcast($msg);

            my $score = $game->killPlayer($color);
            print "resign player $color: $score\n";
            if ($score) {
                endGame($msg->{gameId}, 'resigned', $score);
            }
        } elsif ($msg->{'c'} eq 'playerlost'){
            if (! gameauth($msg) ){ return 0; }
            print "\n\nPLAYERLOST \n\n";
            $game->playerBroadcast($msg);

            my $score = $game->killPlayer($msg->{color});
            print "kill player $msg->{color} $score\n";
            if ($score) {
                endGame($msg->{gameId}, 'king killed', $score);
            }
        } elsif ($msg->{'c'} eq 'authkill'){
            if (! gameauth($msg) ){ return 0; }

            $msg->{'c'} = 'kill';
            $game->playerBroadcast($msg);
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

    ### score must exist and look something like 1-0, 0.5-0.5, 1-0-0-0, etc
    if (!$score || $score !~ m/^[01\.-]+$/) {
        app()->log->debug("invalid score.");
        return;
    }
    my ($result, $bresult, $cresult, $dresult) = split('-', $score);

    my ($white, $black, $red, $green) = getPlayers($gameId);

    # k variable controls change rate
    my $k = 32;

    my $ratingColumn = 'rating_standard';
    if ($gameSpeed eq 'standard' || $gameSpeed eq 'lightning') {
        $ratingColumn = "rating_$gameSpeed";
    } else {
        app()->log->debug("invalid speed: $gameSpeed.");
        return;
    }
    
    if ($cresult) { ### was a 4way game
        # transformed rating (on a normal curve)
        my $r1 = 10 ** ($white->{$ratingColumn} / 400);
        my $r2 = 10 ** ($black->{$ratingColumn} / 400);
        my $r3 = 10 ** ($red->{$ratingColumn} / 400);
        my $r4 = 10 ** ($green->{$ratingColumn} / 400);

        # expected score -------- divide second part by two again??
        my $e1 = $r1 / ($r1 + $r2 + $r3 + $r4);
        my $e2 = $r2 / ($r1 + $r2 + $r3 + $r4);
        my $e3 = $r3 / ($r1 + $r2 + $r3 + $r4);
        my $e4 = $r4 / ($r1 + $r2 + $r3 + $r4);

        my $whiteProv = $white->getProvisionalFactor();
        my $blackProv = $black->getProvisionalFactor();
        my $redProv   = $black->getProvisionalFactor();
        my $greenProv = $black->getProvisionalFactor();

        #### TODO adjust results based on all four results i.e. 0-0-0.5-0.5 vs all draws
        $white->{$ratingColumn} = $white->{$ratingColumn} + $k * ($result - $e1);
        $black->{$ratingColumn} = $black->{$ratingColumn} + $k * ($bresult - $e2);
        $red->{$ratingColumn}   = $red->{$ratingColumn}   + $k * ($cresult - $e3);
        $green->{$ratingColumn} = $green->{$ratingColumn} + $k * ($dresult - $e4);
        savePlayer($white, $result,  $gameSpeed);
        savePlayer($black, $bresult, $gameSpeed);
        savePlayer($red  , $cresult, $gameSpeed);
        savePlayer($green, $cresult, $gameSpeed);
    } else {
        # transformed rating (on a normal curve)
        my $r1 = 10 ** ($white->{$ratingColumn} / 400);
        my $r2 = 10 ** ($black->{$ratingColumn} / 400);

        # expected score
        my $e1 = $r1 / ($r1 + $r2);
        my $e2 = $r2 / ($r1 + $r2);

        my $whiteProv = $white->getProvisionalFactor();
        my $blackProv = $black->getProvisionalFactor();

        $white->{$ratingColumn} = $white->{$ratingColumn} + $k * ($result - $e1);
        $black->{$ratingColumn} = $black->{$ratingColumn} + $k * ($bresult - $e2);
        savePlayer($white, $result,  $gameSpeed);
        savePlayer($black, $bresult, $gameSpeed);
    }

    return ($white, $black);
}

sub endGame {
    my $gameId = shift;
    my $result = shift;
    my $score = shift;

    app->log->debug('ending game: ' . $gameId . ' to ' . $result);

    my @gameRow = app->db()->selectrow_array("SELECT status, game_speed, game_type, rated FROM games WHERE game_id = ?", {}, $gameId);

    if (! @gameRow ) {
        app->debug("  game doesn't exist so it cannot be ended!! $gameId");
        return 0;
    }

    my ($status, $gameSpeed, $gameType, $rated) = @gameRow;

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

    print "result: $result\n";
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

    my ($whiteEnd, $blackEnd) = ($whiteStart, $blackStart);
    if ($rated) {
        ($whiteEnd, $blackEnd) = updateRatings($gameId, $gameSpeed, $score);   
    }

    print "updating game log....$score\n";
    if ($score && $score =~ m/^[01\.-]+$/) {
        print " updating now\n";
        ### write to game log for both players
        if ($whiteStart->{player_id}) {
            app->db()->do('INSERT INTO game_log
                (game_id, player_id, opponent_id, game_speed, game_type, result, rating_before, rating_after, rated)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {},
                $gameId,
                $whiteStart->{player_id},
                $blackStart->{player_id},
                $gameSpeed,
                $gameType,
                ($result eq 'draw' ? 'draw' : ($result eq '1-0' ? 'win' : 'loss') ),
                $whiteStart->{"rating_$gameSpeed"},
                $whiteEnd->{"rating_$gameSpeed"},
                $rated
            );
        }

        if ($blackStart->{player_id}) {
            app->db()->do('INSERT INTO game_log
                (game_id, player_id, opponent_id, game_speed, game_type, result, rating_before, rating_after, rated)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {},
                $gameId,
                $blackStart->{player_id},
                $whiteStart->{player_id},
                $gameSpeed,
                $gameType,
                ($result eq 'draw' ? 'draw' : ($result eq '1-0' ? 'loss' : 'win') ),
                $blackStart->{"rating_$gameSpeed"},
                $blackEnd->{"rating_$gameSpeed"},
                1
            );
        }
    }


    my $game = $currentGames{$gameId};
    if ($game) {
        my $msg = {
            'c' => 'gameOver',
            'result' => $result,
            'score' => $score
        };
        $game->playerBroadcast($msg);
        $game->serverBroadcast($msg);
    }
    delete $currentGames{$gameId};
    delete $games{$gameId};
    return 1;
}

sub getPlayers {
    my $gameId = shift;

    my @row = app->db()->selectrow_array('SELECT white_player, black_player, red_player, green_player FROM games WHERE game_id = ?', {}, $gameId);

    ### if their id is undef we get a guest player
    my $white = new KungFuChess::Player( { 'userId' => $row[0] }, app->db() );
    my $black = new KungFuChess::Player( { 'userId' => $row[1] }, app->db() );
    my $red = new KungFuChess::Player(   { 'userId' => $row[2] }, app->db() );
    my $green = new KungFuChess::Player( { 'userId' => $row[3] }, app->db() );

    return ($white, $black, $red, $green);
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

sub clearInactiveGames {
    my $games = app->db()->selectall_arrayref("SELECT game_id from games WHERE status = 'active'");
    foreach my $row (@$games) {
        my $gameId = $row->[0];
        if (! exists($currentGames{$gameId})){
            endGame($gameId, 'clear inactive');
        }
    }
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
    my $gameSpeed = shift;
    my $gameType = shift;

    app->log->debug("saving player rating $player->{player_id} $player->{rating_standard}, $player->{rating_lightning}");
    my $sth = app->db()->prepare('UPDATE players SET rating_standard = ?, rating_lightning = ?, rating_standard_4way = ?, rating_lightning_4way = ? WHERE player_id = ?' );
    $sth->execute($player->{rating_standard}, $player->{rating_lightning}, $player->{rating_standard_4way}, $player->{rating_lightning_4way}, $player->{player_id});

    if (defined($result) && ($gameSpeed eq 'standard' || $gameSpeed eq 'lightning') ) {
        my $resultColumn = '';
        my $playedColumn = "games_played_$gameSpeed";
        my $fourWay = ($gameType eq '4way' ? '_4way' : '');

        if ($result == 1) {
            $resultColumn = "games_won_$gameSpeed" . $fourWay;
        } elsif ($result == 0.5) {
            $resultColumn = "games_drawn_$gameSpeed" . $fourWay;
        } elsif ($result == 0) {
            $resultColumn = "games_lost_$gameSpeed" . $fourWay;
        } else {
            app->log->debug("UNKNOWN result! $result");
        }
        if ($resultColumn ne '') {
            app->log->debug("saving player $playedColumn $resultColumn $player->{player_id}");
            my $sthResult = app->db()->prepare("UPDATE players SET $playedColumn = $playedColumn + 1, $resultColumn = $resultColumn + 1 WHERE player_id = ?");
            $sthResult->execute($player->{player_id});
        }
    }
}

sub getMyOpenGame {
    my $user = shift;
    my $uid = shift;

    my $playerId = ($user ? $user->{player_id} : -1);

    ### TODO if not anon user delete other games
    my $myGame = app->db()->selectrow_hashref('
        SELECT p.matched_game, p.player_id, p.rated, p.private_game_key, p.game_speed, p.open_to_public,
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
    my $options = shift;

    if (! $player) { 
        return 0;
    }
    if (! $player->{player_id}) {
        return 0;
    }

    my $gameSpeed       = (exists($options->{gameSpeed}) ? $options->{gameSpeed} : 1);
    my $rated           = (exists($options->{rated}) ? $options->{rated} : 1);
    my $privateKey      = (exists($options->{privateKey}) ? $options->{privateKey} : undef);
    my $challengePlayer = (exists($options->{challengePlayerId}) ? $options->{challengePlayerId} : 1);

    my $sth = app->db()->prepare('INSERT INTO pool (player_id, game_speed, rated, last_ping) VALUES (?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE game_speed = ?, rated = ?, last_ping = NOW(), in_matching_pool = 1, private_game_key = NULL, open_to_public = 1
    ');
    $sth->execute(
        $player->{'player_id'},
        $gameSpeed,
        $rated,
        ### updates
        $gameSpeed,
        $rated
    );
}

sub createChallenge {
    my ($playerId, $gameSpeed, $open, $rated, $challengePlayer) = @_;

    app->db()->do("DELETE FROM pool WHERE player_id = ?", {}, $playerId);

    my $sth = app->db()->prepare('INSERT INTO pool
        (player_id, game_speed, open_to_public, rated, private_game_key, in_matching_pool, last_ping, challenge_player_id)
        VALUES (?, ?, ?, ?, ?, 0, NOW(), ?)');

    my $uuid = create_uuid_as_string();
    $sth->execute($playerId, $gameSpeed, $open, $rated, $uuid, $challengePlayer);

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
                  # speed, open, rated, whiteId, blackId
        my $gameId = createGame($poolRow->{game_type}, $poolRow->{game_speed}, $poolRow->{rated}, $playerId, $poolRow->{player_id});

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
    my $gameType  = shift;

    if (!$gameSpeed) { $gameSpeed = 'standard'; }

    my $ratingColumn = 'rating_' . $gameSpeed;
    my @gameMatch = app->db()->selectrow_array(
        'SELECT player_id, matched_game FROM pool WHERE player_id = ? AND in_matching_pool = 1 AND game_speed = ?', {}, $player->{'player_id'}, $gameSpeed);

    if (@gameMatch) {
        my ($player_id, $matched_game) = @gameMatch;
        if ($matched_game) {
            my @gameRow = app->db()->selectrow_array(
                'SELECT status, white_player, black_player, green_player, red_player FROM games WHERE game_id = ?',
                {},
                $matched_game
            );
            
            my ($gameStatus, $blackPlayer, $whitePlayer, $greenPlayer, $redPlayer) = @gameRow;
            print "\nmatched game $matched_game: $gameStatus, $blackPlayer, $whitePlayer, $greenPlayer, $redPlayer\n\n";
            if ($gameStatus eq 'waiting to begin' &&
                ($blackPlayer == $player->{'player_id'}
                    || $whitePlayer == $player->{'player_id'}
                    || $redPlayer == $player->{'player_id'}
                    || $greenPlayer == $player->{'player_id'}
                )
            ) {
                print "returning $matched_game\n";
                return $matched_game;
            } else { ### the matched game is over or obsolete
                app->db()->do("UPDATE pool SET matched_game = NULL WHERE player_id = ?", {}, $player->{'player_id'});
            }
        }
    }

    ### now we try to find if any player matched them.
    my $needed = $gameType eq '4way' ? 3 : 1;
    my $matchSql = 
        'SELECT p.player_id FROM pool p
            LEFT JOIN players pl ON p.player_id = pl.player_id
            WHERE p.player_id != ?
            AND in_matching_pool = 1
            AND game_speed = ?
            AND last_ping > NOW() - INTERVAL 3 SECOND
            ORDER BY abs(? - ' . $ratingColumn . ') LIMIT ' . $needed;
    my $playerMatchedRow = app->db()->selectall_arrayref(
        $matchSql,
        {},
        $player->{'player_id'}, $gameSpeed, $player->{$ratingColumn}
    );

    if ($#{$playerMatchedRow} + 1 >= $needed) {
        print "found match!\n";
        my $playerMatchedId = $playerMatchedRow->[0][0];
        my $playerMatchedId2 = ($gameType eq '4way' ? $playerMatchedRow->[1][0] : undef);
        my $playerMatchedId3 = ($gameType eq '4way' ? $playerMatchedRow->[2][0] : undef);
                  # speed, rated, whiteId, blackId, redId, greenId
        my $gameId = createGame($gameType, $gameSpeed, 1, $player->{'player_id'}, $playerMatchedId, $playerMatchedId2, $playerMatchedId3);

        if ($gameType eq '4way') {
            app->db()->do('UPDATE pool SET matched_game = ? WHERE player_id IN (?, ?, ?, ?)', {}, $gameId, $player->{'player_id'}, $playerMatchedId, $playerMatchedId2, $playerMatchedId3);
        } else {
            app->db()->do('UPDATE pool SET matched_game = ? WHERE player_id IN (?, ?)', {}, $gameId, $player->{'player_id'}, $playerMatchedId);
        }

        return $gameId;
    }

    return undef;
}

app->start;
