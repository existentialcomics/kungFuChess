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

app->hook(before_routes => sub {
    my $c = shift;
    $c->stash('title' => "KungFuChess");
    $c->stash('wsDomain'     => $cfg->param('ws_domain'));
    $c->stash('wsDomainMain' => $cfg->param('ws_domain_main'));
    $c->stash('wsProtocol'   => $cfg->param('ws_protocol'));
});

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
                # TODO load by row, it does the query twice
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
    my $activeTab = $c->req->param('activeTab') ? $c->req->param('activeTab') : 'pool';
    my $currentGameUid = $c->req->param('uid') ? $c->req->param('uid') : '';
    $c->stash('activeTab' => $activeTab);
    $c->stash('currentGameUid' => $currentGameUid);
    my $chatLog = app->db()->selectall_arrayref(
        "SELECT chat_log.*, chat_log.player_color as color, UNIX_TIMESTAMP() - UNIX_TIMESTAMP(post_time) as unix_seconds_back, p.screenname FROM chat_log
            LEFT JOIN players p ON chat_log.player_id = p.player_id
            WHERE game_id IS NULL
            ORDER BY chat_log_id
            DESC limit 100",
        { 'Slice' => {} }
    );
    unshift(@{$chatLog},{
        'post_time' => time,
        'game_id' => undef,
        'player_id' => 1,
        'comment_text' => 'Welcome to KungFuChess (currently in beta). Enter the matching pools or start a game to play. Click the "about" tab to see more about the game, or "learn" to learn special tactics. WARNING: sweep rules have changed, you know sweep any piece that moved after you, even if it has fully stopped. Premove was also added.',
        'screenname' => 'SYSTEM',
        'color' => 'red',
        'text_color' => '#666666',
        'chat_log_id' => 1
    });
    my $chatLogString = ($chatLog ? encode_json \@{$chatLog} : '[]');
    ### hacky but not sure how to do it proper. Because it is a javascript string
    #   we must double escape "
    #$chatLogString =~ s/\\"/\\\\"/g;
    $c->stash('chatLog' => $chatLogString);

    $c->render('template' => 'home', format => 'html', handler => 'ep');
};

get '/learn' => sub {
    my $c = shift;

    my $user = $c->current_user();
    $c->stash('user' => $user);

    $c->render('template' => 'learn', format => 'html', handler => 'ep');
};

get '/tactics/beginner/dodge' => sub {
    my $c = shift;

    my $user = $c->current_user();
    $c->stash('user' => $user);

    $c->stash('video' => '/dodge.webm');
    $c->stash('name' => 'Dodge');
    $c->stash('description' => 'One of the key features of KungFu Chess is the ability to dodge incoming attacks. Especially on slower games, it is very dangers to attack pieces that are not in their recharge state, especially from long range. This makes is so pieces that are recharging are often the only pieces vulnerable to attack, so be very careful not to move into vulnerable positions, and if there is an attack on a strong pieces, always be ready to quickly dodge it.');

    $c->render('template' => 'tactic', format => 'html', handler => 'ep');
};

get '/tactics/beginner/anticipate' => sub {
    my $c = shift;

    my $user = $c->current_user();
    $c->stash('user' => $user);

    $c->stash('video' => '/anticipate.webm');
    $c->stash('name' => 'Anticipate');
    $c->stash('description' => 'When you see a piece moving, it is very important to try to work out which spot your opponent is attempting to land on, so you can potentially set up an attack on that spot before they reach it, allowing you to capture the piece before it is able to move again. In the video, you can see the bishap making long move to g4. However, white anticipates this, particually once they move into the f5 square, which is already guarded. This allows white to move a pawn forward to attack the expected square. Against a skilled opponent, you should not only consider squares guarded that are attacked by pawns, but also squares that are potentially attacked by pawns that are ready to move.');

    $c->render('template' => 'tactic', format => 'html', handler => 'ep');
};

get '/tactics/beginner/cutoff' => sub {
    my $c = shift;

    my $user = $c->current_user();
    $c->stash('user' => $user);

    $c->stash('video' => '/cutoff.webm');
    $c->stash('name' => 'Cutoff');
    $c->stash('description' => 'Think you are safely guarding a piece just because you are attacking the square it is on? This isn\'t chess, so think again. A key aspect of Kung Fu Chess is that you are often guarding pieces that don\'t seemed guarded, such as with the "anticipate" tactic, but you are also not guarding pieces that do seemed guarded. For example, it is quite easy to take a piece while simulaneously cutting off the pieces guarding it. Always be aware of what pieces can move into your path.');

    $c->render('template' => 'tactic', format => 'html', handler => 'ep');
};

get '/tactics/beginner/diversion' => sub {
    my $c = shift;

    my $user = $c->current_user();
    $c->stash('user' => $user);

    $c->stash('video' => '/diversion.webm');
    $c->stash('name' => 'Diversion');
    $c->stash('description' => 'Always remember that this is a real time game, and your opponent has to not only in theory protect his pieces, but he actually has to react in time to make the moves. Just because you can dodge a piece, doesn\'t mean you will. In this case white creates a diversion on the other side of the board, drawing black\'s attention (and his physical mouse cursor) to the king side, all the while assassinating the exposed king with his knight.');

    $c->render('template' => 'tactic', format => 'html', handler => 'ep');
};

get '/tactics/advanced/combo' => sub {
    my $c = shift;

    my $user = $c->current_user();
    $c->stash('user' => $user);

    $c->stash('video' => '/combo.webm');
    $c->stash('name' => 'Combo');
    $c->stash('description' => 'This is the most core tactic of Kung Fu Chess. Pieces aren\'t guarded if you can simply take the piece and the piece guarding it at once. Take out entire pawn structures at once or protecting piece to move while you take another piece. The possiblities are endless when combination tactics are properly mastered, and combo moves are what really drives advanced play.');

    $c->render('template' => 'tactic', format => 'html', handler => 'ep');
};

get '/tactics/advanced/peekaboo' => sub {
    my $c = shift;

    my $user = $c->current_user();
    $c->stash('user' => $user);

    $c->stash('video' => '/peekaboo.webm');
    $c->stash('name' => 'Combo');
    $c->stash('description' => 'This deceptive tactic makes use of the fact that are you allowed to move to spaces that would be illegal in regular chess play. For example, just because a piece is sitting inbetween you and a square, doesn\'t mean you can\'t attempt to move there. After all, since the game takes place in real time, who is to say if the piece will still be obstructing you by the time you reach it? This allows you to disguise your moves for powerful discovered attacks. You can even move through enemy pieces, anticipating that they will move them before you reach the spot, for truly unexpected play.');

    $c->render('template' => 'tactic', format => 'html', handler => 'ep');
};

get '/tactics/advanced/block' => sub {
    my $c = shift;

    my $user = $c->current_user();
    $c->stash('user' => $user);

    $c->stash('video' => '/block.webm');
    $c->stash('name' => 'Block');
    $c->stash('description' => 'Similarly to the peekaboo tactic and anticipate tactics, this takes advantage of knowing where your opponent is moving, and the fact that you can alter the board before they arrive. In this case we don\'t simply guard or dodge from the spot, we move and sacrifice one of our own pieces into their path to stop them in their tracks.');

    $c->render('template' => 'tactic', format => 'html', handler => 'ep');
};

get '/tactics/expert/sweep' => sub {
    my $c = shift;

    my $user = $c->current_user();
    $c->stash('user' => $user);

    $c->stash('video' => '/sweep.webm');
    $c->stash('name' => 'Sweep');
    $c->stash('description' => 'The most dangerous and feared tactic in Kung Fu Chess: the sweep. Only experts can execute this move with any consistency, as it requires anticipating where your opponent is going to move before they even move their piece. If you move before them, sweeping through their path, you will kill them mid move. When two pieces collide, the piece that moved first kills the other piece, so you must set up the sweep very carefully, and make sure not to move too late or you will be the one getting killed.');

    $c->render('template' => 'tactic', format => 'html', handler => 'ep');
};

get '/tactics/expert/feint' => sub {
    my $c = shift;

    my $user = $c->current_user();
    $c->stash('user' => $user);

    $c->stash('video' => '/feint.webm');
    $c->stash('name' => 'Feint');
    $c->stash('description' => 'This bold and daring strategy uses your opponent\'s skill against him, by moving towards a very good spot and then not landing there! In the video, white has a chance to exchange a knight for a rook by attacking the black knight and rook at the same time. He will lose his bishop, assuming black dodges it and takes, but will get the rook. However, since he knows his opponent will see this and have ample time to dodge, so he moves instead to the unguarded space in front of it, saving his bishop. Risky, because if black does not dodge, he would lose the queen!');

    $c->render('template' => 'tactic', format => 'html', handler => 'ep');
};

get '/tactics/expert/selfkill' => sub {
    my $c = shift;

    my $user = $c->current_user();
    $c->stash('user' => $user);

    $c->stash('video' => '/selfKill.webm');
    $c->stash('name' => 'Self Kill');
    $c->stash('description' => 'As was discussed in other tactics, such as the block and peekabo, since we don\'t know what the state of the board will be when we begin a move, you are allowed to make normally illegal moves. For knights in particular, this means you can move anywhere, even on top of your own pieces. If you don\'t move your piece away in time, you will kill it. However, in rare circumstances, this can be used to your advantage. As you can see in the video, the white king is trapped, and the black bishop is quickly coming in for the kill. White however can kill their own pawn, clearing a desperate escape route for the king.');

    $c->render('template' => 'tactic', format => 'html', handler => 'ep');
};

#####################################
###
###
post '/ajax/createChallenge' => sub {
    my $c = shift;
    my $user = $c->current_user();
    $c->stash('user' => $user);
    #   standard/light , 2way/4way , unrated/ai/etc, open to public
    my ($gameSpeed, $gameType, $gameMode, $open) =
        ($c->req->param('gameSpeed'),
         $c->req->param('gamePlayersType'),
         $c->req->param('gameMode'),
         $c->req->param('open'));

    my $rated = ($gameMode eq 'rated' ? 1 : 0);
    app->log->debug( "speed, type, mode, open: $gameSpeed, $gameType, $gameMode, $open" );

    my $gameId = undef;
    my $uid = undef;
    if ($gameMode eq 'practice') {
                  # speed, type, open, rated, whiteId, blackId
        $gameId = createGame($gameType, $gameSpeed, 0, ($user ? $user->{player_id} : ANON_USER), ($user ? $user->{player_id} : -1), ($user ? $user->{player_id} : ANON_USER), ($user ? $user->{player_id} : -1));
        if (! $user) {
            app->db()->do("UPDATE games SET black_anon_key = white_anon_key WHERE game_id = ?", {}, $gameId);
        }
    } elsif ($gameMode eq 'ai') {
        $gameId = createGame($gameType, $gameSpeed, 0, ($user ? $user->{player_id} : ANON_USER), AI_USER);
    } else {
        $uid = createChallenge(($user ? $user->{player_id} : ANON_USER), $gameSpeed, $gameType, ($open ? 1 : 0), $rated, undef);
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
    print "user: \n\n";
    $c->stash('user' => $user);

    if (! $user) {
        $user = new KungFuChess::Player({ anon => 1 }, app->db());
    }

    my ($origGameId) = ($c->req->param('gameId'));

    my $gameRow = app->db()->selectrow_hashref('SELECT * FROM games WHERE game_id = ?', { 'Slice' => {} }, $origGameId);

    my $myId = undef;
    my $challengeId = undef;
    my $color = undef;
    if ($gameRow->{white_player} eq $user->{player_id}) {
        $myId        = $gameRow->{white_player};
        $challengeId = $gameRow->{black_player};
        $color = 'white';
    } elsif ($gameRow->{black_player} eq $user->{player_id}) {
        $myId        = $gameRow->{black_player};
        $challengeId = $gameRow->{white_player};
        $color = 'black';
    } elsif ($gameRow->{red_player} eq $user->{player_id}) {
        $myId        = $gameRow->{red_player};
        $color = 'red';
    } elsif ($gameRow->{green_player} eq $user->{player_id}) {
        $myId        = $gameRow->{green_player};
        $color = 'green';
    } else {
        print " player not in game!!!\n";
        my $returnError = {
            'error' => 'player not in the game issuing rematch',
        };
        $c->render('json' => $returnError );
        ### abort 403
    }

    app->log->debug("myId: $myId, gameId: $gameRow->{game_id}");

    my $gameId = undef;
    my $uid = undef;
    ### this means it is a practice game
    if ($gameRow->{white_player} eq $gameRow->{black_player} && $gameRow->{white_anon_key} eq $gameRow->{black_anon_key} ) {
                  # speed, open, rated, whiteId, blackId
        $gameId = createGame($gameRow->{game_type}, $gameRow->{game_speed}, 0, $gameRow->{white_player}, $gameRow->{black_player}, $gameRow->{red_player}, $gameRow->{green_player});
        if (! $user) {
            app->db()->do("UPDATE games SET black_anon_key = white_anon_key WHERE game_id = ?", {}, $gameId);
        }
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

        if ($gameRow->{game_type} eq '4way') {
            my $existingRematch = app->db()->selectrow_hashref(
                'SELECT * FROM pool
                WHERE private_game_key = ?
                ', { },
                $gameRow->{game_id},
            );
            if ($existingRematch) {
                if ($existingRematch->{matched_game}) {
                    $gameId = $existingRematch->{matched_game};
                } else {
                    ### we are already in the rematch
                    if ($user->{player_id} eq $existingRematch->{player_id} || 
                        $user->{player_id} eq $existingRematch->{challenge_player_id} || 
                        $user->{player_id} eq $existingRematch->{challenge_player_2_id} || 
                        $user->{player_id} eq $existingRematch->{challenge_player_3_id}
                    ) {
                        app->db()->do( 'UPDATE pool SET last_ping = NOW()
                            WHERE private_game_key = ?',
                            {},
                            $existingRematch->{private_game_key}
                        );
                    } else {
                        if (! $existingRematch->{challenge_player_id}) {
                            app->db()->do( 'UPDATE pool SET challenge_player_id = ?, last_ping = NOW()
                                WHERE private_game_key = ?',
                                {},
                                $user->{player_id},
                                $existingRematch->{private_game_key}
                            );
                        } elsif (! $existingRematch->{challenge_player_2_id}) {
                            app->db()->do( 'UPDATE pool SET challenge_player_2_id = ?, last_ping = NOW()
                                WHERE private_game_key = ?',
                                {},
                                $user->{player_id},
                                $existingRematch->{private_game_key}
                            );
                        } elsif (! $existingRematch->{challenge_player_3_id}) {
                            ### we are the last to rematch so we are now ready to play.
                            $gameId = createGame($gameRow->{game_type}, $gameRow->{game_speed}, $gameRow->{rated}, $gameRow->{white_player}, $gameRow->{black_player}, $gameRow->{red_player}, $gameRow->{green_player});
                            ### all uuids should be the same as before
                            app->db()->do("UPDATE games SET white_anon_key = ?, black_anon_key = ?, red_anon_key = ?, green_anon_key = ? WHERE game_id = ?", {},
                                $gameRow->{white_anon_key},
                                $gameRow->{black_anon_key},
                                $gameRow->{red_anon_key},
                                $gameRow->{green_anon_key},
                                $gameId
                            );
                            app->db()->do('UPDATE pool SET challenge_player_3_id = ?, matched_game = ?, last_ping = NOW()
                                WHERE private_game_key = ?',
                                {},
                                $user->{player_id},
                                $gameId,
                                $existingRematch->{private_game_key}
                            );
                        }
                    }
                }
            } else {
                app->db()->do(
                    'DELETE FROM pool WHERE player_id = ?',
                    {},
                    $user->{player_id}
                );
                my $sth = app->db()->prepare('INSERT INTO pool
                    (player_id, game_speed, game_type, open_to_public, rated, private_game_key, in_matching_pool, last_ping)
                    VALUES (?, ?, ?, ?, ?, ?, 0, NOW())');

                my $uuid = create_uuid_as_string();
                if ($user->{player_id} eq $gameRow->{white_player} ||
                    $user->{player_id} eq $gameRow->{black_player} ||
                    $user->{player_id} eq $gameRow->{red_player} ||
                    $user->{player_id} eq $gameRow->{green_player}
                ) {
                    $sth->execute(
                        $user->{player_id},
                        $gameRow->{game_speed},
                        $gameRow->{game_type},
                        0,
                        $gameRow->{rated},
                        $gameRow->{game_id},
                    );
                }
            }

        } else { ###### 2way
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
                $gameId = createGame($gameRow->{game_type}, $gameRow->{game_speed}, $gameRow->{rated}, $challengeId, $myId);
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
                ### all uuids should be the same as before
                app->db()->do("UPDATE games SET white_anon_key = ?, black_anon_key = ?, red_anon_key = ?, green_anon_key = ? WHERE game_id = ?", {},
                    $gameRow->{white_anon_key},
                    $gameRow->{black_anon_key},
                    $gameRow->{red_anon_key},
                    $gameRow->{green_anon_key},
                    $gameId
                );
                print "updating anon keys\n";
            } elsif ($myRematchAccepted) {
                $gameId = $myRematchAccepted->{matched_game};
            } else {
                $uid = createChallenge($myId, $gameRow->{game_speed}, $gameRow->{game_type}, 0, $gameRow->{rated}, $challengeId);
            }
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
    my $msg = {
        'c' => 'rematch',
        'color' => $color
    };
    if ($gameId) {
        $msg->{gameId} = $gameId;
    }

    my $count = 0;
    gameBroadcast($msg, $origGameId);
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
            my $screenname = $1;
            my $myGame = getMyOpenGame($user, $c->req->param('uid'));
            if ($myGame && $c->req->param('uid')) {
                my $msg = {
                    'c' => 'invite',
                    'screenname' => $user->{screenname},
                    'gameSpeed'  => $myGame->{game_speed},
                    'gameType'   => $myGame->{game_type},
                    'rated'      => $myGame->{rated},
                    'uid'        => $c->req->param('uid')
                };
                my $success = screennameBroadcast($msg, $screenname);
                if ($success == -1) {
                    $return{'message'} = 'delivery failed, unknown screenname';
                } elsif ($success == 0) {
                    $return{'message'} = 'delivery failed, user offline';
                } else {
                    $return{'message'} = "Invited $screenname to your game.";
                }
            } else {
                $return{'message'} = "You must have an open game to send invites.";
            }
        } else {
            $return{'message'} = "Unknown command";
        }
    } else {
        my $authColor = '';
        if ($c->req->param('gameId')) {
            my $gameRow = app->db()->selectrow_hashref('SELECT * FROM games WHERE game_id = ?', { 'Slice' => {} }, $c->req->param('gameId'));
            if ($c->req->param('auth')) {
                my $auth = $c->req->param('auth');
                if ($auth eq $gameRow->{white_anon_key}) {
                    $authColor = 'white';
                } elsif ($auth eq $gameRow->{black_anon_key}) {
                    $authColor = 'black';
                } elsif ($auth eq $gameRow->{red_anon_key}) {
                    $authColor = 'red';
                } elsif ($auth eq $gameRow->{green_anon_key}) {
                    $authColor = 'green';
                }
            }
            if (!$user) {
                my $msg = {
                    'c' => 'gameChatchat',
                    'author'    => $authColor . " (anon)",
                    'user_id'   => ANON_USER,
                    'message'   => $message
                };

                app->db()->do('INSERT INTO chat_log (comment_text, player_id, player_color, game_id, post_time) VALUES (?,?,?,?,NOW())', {},
                    $msg->{'message'},
                    ANON_USER,
                    'green',
                    $c->req->param('gameId')
                );
                $msg->{'color'} = 'green';
                $msg->{c} = 'gamechat';
                gameBroadcast($msg, $c->req->param('gameId'));
            }
        }
        if ($user) {
            my $screename = $user->{screenname};
            if ($user->isAdmin()) {
                $screename .= " (ADMIN)";
            }

            my $msg = {
                'c' => 'globalchat',
                'author'    => $screename,
                'user_id'   => $user->{player_id},
                'message'   => $message
            };

            app->db()->do('INSERT INTO chat_log (comment_text, player_id, player_color, game_id, post_time) VALUES (?,?,?,?,NOW())', {},
                $msg->{'message'},
                $user->{player_id},
                $user->getBelt(),
                $c->req->param('gameId')
            );
            $msg->{'color'} = $user->getBelt();
            if ($c->req->param('gameId')) {
                $msg->{c} = 'gamechat';
                gameBroadcast($msg, $c->req->param('gameId'));
            } else {
                globalBroadcast($msg);
            }
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

    my $gameSpeed = $c->stash('speed');
    my $gameType  = $c->stash('type');
    if ($gameSpeed !~ m/standard|lightning/) {
        $gameSpeed = 'standard';
    }
    if ($gameType !~ m/2way|4way/) {
        $gameType = '2way';
    }

    my $user = $c->current_user();
    my $uuid = enterUpdatePool(
        $user,
        { 
            'gameSpeed' => $gameSpeed,
            'gameType'  => $gameType,
            'uuid'      => $c->req->param('uuid'),
        }
    );
    my $gameId = matchPool($user, $gameSpeed, $gameType, $uuid);

    my $json = {
        'uid' => $uuid,
    };

    if ($gameId) {
        $json->{'gameId'} = $gameId;
        if (! $user) {
            $json->{anonKey} = $uuid;
        }
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

get '/faq' => sub {
    my $c = shift;
    my $user = $c->current_user();
    $c->stash('user' => $user);

    $c->render('template' => 'faq', format => 'html', handler => 'ep');
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

get '/profile/:screenname/games/:speed/:type' => sub {
    my $c = shift;
    my $user = $c->current_user();
    $c->stash('user' => $user);

    my $data      = { 'screenname' => $c->stash('screenname') };
    my $gameSpeed = { 'screenname' => $c->stash('speed') };
    my $gameType  = { 'screenname' => $c->stash('speed') };
    my $player = new KungFuChess::Player($data, app->db());

    $c->stash('player' => $player);

    my $games = getGameHistory($player, $gameSpeed, $gameType);

    return $c->render('template' => 'profile', format => 'html', handler => 'ep');
};

get '/matchGame/:uid' => sub {
    my $c = shift;
    my $user = $c->current_user();

    my $gameId = matchGameUid($user, $c->stash('uid'));

    if (! $gameId ) {
        $c->stash('error' => 'Game not found.');
        return $c->redirect_to("/");
    } elsif ($gameId == -1) { ### signal that we are a 4way game
        $c->session('currentGameUid' => $c->stash('uid'));
        return $c->redirect_to('/?activeTab=openGames&uid=' . $c->stash('uid'));
    }

    return $c->redirect_to('/game/' . $gameId);
};

get '/ajax/matchGame/:uid' => sub {
    my $c = shift;
    my $user = $c->current_user();

    my $gameId = matchGameUid($user, $c->stash('uid'));

    if ($gameId) {
        ### they are matched, but the game is not ready to start
        if ($gameId == -1) {
            my $json = {
                'uid' => $c->stash('uid')
            };
            $c->render('json' => $json);
        } else {
            my $json = {};
            $json->{'gameId'} = $gameId;
            if (!$user) {
                my @row = app->db()->selectrow_array('SELECT white_anon_key FROM games WHERE game_id = ?', {}, $gameId);
                if (@row) {
                    $json->{'anonKey'} = $row[0];
                }
            }

            $c->render('json' => $json);
        }
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
    if ($myGame) {
        my @grep = grep { $_->{player_id} != $myGame->{player_id} } @games;
        $c->stash('openGames' => \@grep);
    } else {
        $c->stash('openGames' => \@games);
    }
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

    my $ratingType = ($c->req->param('ratingType') // 'standard');
    
    ### no funny business
    if ($ratingType ne 'lightning') {
        $ratingType = 'standard';
    }

    my $players = getActivePlayers($ratingType);
    $c->stash('players' => $players);
    $c->stash('ratingType' => $ratingType);
    $c->render('template' => 'players', format => 'html', handler => 'ep');
};

get '/rankings' => sub {
    my $c = shift;
    my $user = $c->current_user();
    $c->stash('user' => $user);

    my $playersStandard  = getTopPlayers('standard', 15);
    my $playersLightning = getTopPlayers('lightning', 15);
    $c->stash('playersStandard' => $playersStandard);
    $c->stash('playersLightning' => $playersLightning);

    $c->render('template' => 'rankings', format => 'html', handler => 'ep');
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
    $c->stash('title' => "KungFuChess game:$gameId");

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

    ### if the game isn't active we just use ours
    $c->stash('wsGameDomain'  => $game ? $gameRow->{ws_server} : $cfg->param('ws_domain'));

    $c->stash('whiteReady'  => $game ? $game->{whiteReady} : -1);
    $c->stash('blackReady'  => $game ? $game->{blackReady} : -1);
    $c->stash('redReady'    => $game ? $game->{redReady}   : -1);
    $c->stash('greenReady'  => $game ? $game->{greenReady} : -1);

    $c->stash('positionGameMsgs' => $gameRow->{final_position});
    $c->stash('gameLog'          => $gameRow->{game_log} ? $gameRow->{game_log} : '[]');
    $c->stash('gameStatus'       => $gameRow->{status});
    my ($timerSpeed, $timerRecharge) = getPieceSpeed($gameRow->{game_speed});
    $c->stash('gameSpeed'     => $gameRow->{game_speed});
    $c->stash('gameType'      => $gameRow->{game_type});
    $c->stash('rated'         => $gameRow->{rated});
    $c->stash('score'         => $gameRow->{score});
    $c->stash('result'        => $gameRow->{result});
    $c->stash('timerSpeed'    => $timerSpeed);
    $c->stash('timerRecharge' => $timerRecharge);

    my $chatLog = app->db()->selectall_arrayref(
        "SELECT chat_log.*, chat_log.player_color as color, UNIX_TIMESTAMP() - UNIX_TIMESTAMP(post_time) as unix_seconds_back, p.screenname FROM chat_log
            LEFT JOIN players p ON chat_log.player_id = p.player_id
            WHERE game_id = ?
            ORDER BY chat_log_id
            DESC limit 100",
        { 'Slice' => {} },
        $gameId
    );
    my $chatLogString = ($chatLog ? encode_json \@{$chatLog} : '[]');
    ### hacky but not sure how to do it proper. Because it is a javascript string
    #   we must double escape "
    #$chatLogString =~ s/\\"/\\\\"/g;
    $c->stash('gameChatLog' => $chatLogString);

    if (defined($white->{player_id})){
        my $matchedKey = 1;
        if ($white->{player_id} == -1) {
            my @row = app->db()->selectrow_array('SELECT white_anon_key FROM games WHERE game_id = ?', {}, $gameId);
            if (@row) {
                $matchedKey = ($row[0] && $row[0] eq $c->param('anonKey'));
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
                $matchedKey = ($row[0] && $row[0] eq $c->param('anonKey'));
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
                $matchedKey = ($row[0] && $row[0] eq $c->param('anonKey'));
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
                $matchedKey = ($row[0] && $row[0] eq $c->param('anonKey'));
            }
        }
        if ($green->{player_id} == $user->{player_id} && $matchedKey){
            app->log->debug(" User is the green player $green->{player_id} vs $user->{player_id}" );
            $color = ($color eq 'both' ? 'both' : 'green');
        }
    }
    if ($color ne 'watch' && $game) {
        if ($game) {
            $game->addPlayer($user, $color);
        }
    } else {
        if ($game) {
            $game->addWatcher($user, $color);
        }
    }
    $c->stash('color', $color);
    $c->stash('watchers', (defined($game) ? $game->getWatchers : []));

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
    my ($type, $speed, $rated, $white, $black, $red, $green, $options) = @_;
    #app->log->debug("creating game with $type, $speed, $rated, $white, $black, $red, $green\n");

    $options = $options // {};

    my $whiteUid = ($white == ANON_USER || $black == AI_USER ? $options->{whiteUuid} // create_uuid_as_string() : undef);
    my $blackUid = ($black == ANON_USER || $black == AI_USER ? $options->{blackUuid} // create_uuid_as_string() : undef);
    my $redUid   = undef;
    my $greenUid = undef;
    if ($type eq '4way') {
        $redUid   = ($white == ANON_USER ? $options->{redUuid}   // create_uuid_as_string() : undef);
        $greenUid = ($black == ANON_USER ? $options->{greenUuid} // create_uuid_as_string() : undef);
    }

    my $auth = create_uuid_as_string();

    my $sth = app->db()->prepare("INSERT INTO games (game_id, game_speed, game_type, white_player, black_player, red_player, green_player, rated, white_anon_key, black_anon_key, red_anon_key, green_anon_key, ws_server)
        VALUES (NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
    $sth->execute($speed, $type, $white, $black, $red, $green, $rated, $whiteUid, $blackUid, $redUid, $greenUid, $cfg->param('ws_domain'));

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
        $type,
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
        $type,
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
            $type,
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

    my $rules = [
        {
            'required'   => 1,
            'key'        => 'username',
            'name'       => 'User name',
            'check'      => 'length',
            'check_args' => [5, 255],
        },
        {
            'required'   => 0,
            'key'        => 'username',
            'name'       => 'User name',
            'check'      => 'word_only',
        },
        {
            'required'   => 1,
            'key'        => 'password',
            'name'       => 'Password',
            'check'      => 'min_length',
            'check_args' => [5],
        },
        {
            'required'   => 0,
            'key'        => 'email',
            'name'       => 'Email',
            'check'      => 'email',
        },
        {
            'required'   => 0,
            'key'        => 'username',
            'check'      => 'custom',
            'check_args' => [$c, $c->req->param('username')],
            'sub'        => sub {
                my $c = shift;
                my $u = shift;

                my $existing = app->db()->selectall_arrayref('SELECT * FROM players WHERE screenname = ?', {}, $u);
                return (! @$existing)
            },
            'custom_message' => 'User name ' . $c->req->param('username') . ' already exists.',
        },
    ];

    my ($validated, $passed, $failed, $errors) = validate($c, $rules);
    if (! $validated) {
        $c->render('template' => 'register', format => 'html', handler => 'ep');
        return;
    }

    $c->db()->do('INSERT INTO players (screenname, password, email, rating_standard, rating_lightning, rating_standard_4way, rating_lightning_4way)
            VALUES (?, ?, ?, 1400, 1400, 1400, 1400)', {}, $passed->{username}, encryptPassword($passed->{password}), $passed->{email});

    if ($c->authenticate($passed->{username}, encryptPassword($passed->{password}))){
        my $user = $c->current_user();
        $c->stash('user' => $user);
    }

    $c->redirect_to("/");
};

sub validate {
    my $c = shift;
    my $rules = shift;

    my %passed = ();
    my %failed = ();
    my @errors = ();
    my $validated = 1;
    foreach my $rule (@$rules) {
        my $key   = $rule->{key};
        my $value = $c->req->param($key);
        my $name  =  $rule->{name};
        my $check = $rule->{check};
        ### filter at the end
        $passed{$key} = $value;
        if ($rule->{required} && (! defined($value) || $value eq '')) {
            $validated = 0;
            $failed{$key} = $value;
            push @errors, "$name is required.";
            next;
        } elsif (! defined($value) || $value eq '') { ### optional param is missing, this is fine
            next;
        }

        if ($check eq 'length') {
            my ($minLen, $maxLen) = @{$rule->{check_args}}; 
            if (length($value) < $minLen || length($value) > $maxLen) {
                $failed{$key} = $value;
                $validated = 0;
                push @errors, "$name must be between $minLen and $maxLen.";
                next;
            }
        } elsif ($check eq 'min_length'){
            my ($minLen) = @{$rule->{check_args}}; 
            if (length($value) < $minLen) {
                $failed{$key} = $value;
                $validated = 0;
                push @errors, "$name must be greater than $minLen.";
                next;
            }
        } elsif ($check eq 'max_length'){
            my ($maxLen) = @{$rule->{check_args}}; 
            if (length($value) > $maxLen) {
                $failed{$key} = $value;
                $validated = 0;
                push @errors, "$name must be less than $maxLen.";
                next;
            }
        } elsif ($check eq 'word_only'){
            if ($value !~ m/^[\w_-]+$/) {
                $validated = 0;
                push @errors, "$value must contain only letters, numbers, -, or _";
                next;
            }
        } elsif ($check eq 'email'){
            if ($value !~ m/.@./) {
                $failed{$key} = $value;
                $validated = 0;
                push @errors, "$value doesn't look like a valid email";
                next;
            }
        } elsif ($check eq 'custom'){
            my $result = &{ $rule->{sub} }(
                @{ $rule->{check_args} }
            );
            if (! $result) {
                $failed{$key} = $value;
                $validated = 0;
                push @errors, $rule->{custom_message};
                next;
            }
        }
    }

    foreach my $key (keys %failed) {
        delete $passed{$key};
    }

    my $errors = $c->stash('error');
    $errors .= join("<br />", @errors);
    $c->stash('error', $errors);
    return $validated, \%passed, \%failed, \@errors;
}

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
                delete $gameConnections{$gameId}->{$connId};
                app->log->debug("game connection closed $connId");
            }
        } else {
            app->log->debug("conneciton $connId closing, but not found!");
        }
        delete $globalConnections{$connId};
    });

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

        #app->log->debug('message about to be game checked ' . $msg->{c});
        #### below are the in game only msgs
        return 0 if (! $msg->{gameId} );
        my $game = $currentGames{$msg->{gameId}};
        return 0 if (! $game);
        #app->log->debug('message game checked ' . $msg->{c});

        if ($msg->{'c'} eq 'join'){
            $game->addConnection($connId, $self);
            $gameConnections{$msg->{gameId}}->{$connId} = $self;
            $playerGamesByServerConn{$connId} = $msg->{gameId};

            if ($game->serverReady()) {
                my $ret = {
                    'c' => 'joined',
                };
                $self->send(encode_json $ret);

                ## pass msg to server to send piece pos
                $msg->{connId} = $connId;
                $game->serverBroadcast($msg);
                app->log->debug('player joined');
            } else {
                my $retNotReady = {
                    'c' => 'notready',
                };
                $self->send(encode_json $retNotReady);
            }
        } elsif ($msg->{'c'} eq 'chat'){
            my $player = new KungFuChess::Player({auth_token => $msg->{auth}}, app->db());

            if ($msg->{'message'} =~ m/^\/(\S+)(?:\s(.*))?/) {
                my $command = $1;
                my $args    = $2;
                if ($command eq 'switch') {
                    my $color = $game->authMove($msg);
                    my ($colorSrc, $colorDst) = split(' ', $args);
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
                } elsif ($command eq 'resetRecording' && $player->isAdmin()) {
                    $game->resetRecording();
                    ### force re-spawning
                    my $commandMsg = {
                        'c' => 'join',
                    };
                    $game->serverBroadcast($commandMsg);
                } else {
                    my $commandMsg = {
                        'c' => 'systemMsg',
                        'msg' => 'unknown command.'
                    };
                    $game->playerBroadcast($commandMsg);
                }
            } else {
                ### we already set non commands above
            }
        } elsif ($msg->{'c'} eq 'readyToBegin'){
            my $return = $game->playerReady($msg);
            app->log->debug("ready to begin msg");
            if ($return > 0){
                app->db()->do('UPDATE games SET status = "active" WHERE game_id = ?', {}, $game->{id});
                app->db()->do('DELETE FROM pool WHERE matched_game = ?', {}, $game->{id});
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
        } elsif ($msg->{'c'} eq 'forceDraw'){
            if (! gameauth($msg) ){ return 0; }
            endGame($msg->{gameId}, 'draw');
        } elsif ($msg->{'c'} eq 'revokeDraw'){
            if (! gameauth($msg) ){ return 0; }
            my $color = $game->authMove($msg);
            return 0 if (!$color);

            $game->playerRevokeDraw($msg);

            my $drawnMsg = {
                'c' => 'revokeDraw',
                'color' => $color
            };
            $game->playerBroadcast($drawnMsg);
            $game->serverBroadcast($drawnMsg);
        } elsif ($msg->{'c'} eq 'requestDraw'){
            my $color = $game->authMove($msg);
            return 0 if (!$color);

            my $drawConfirmed = $game->playerDraw($msg);
            if ($drawConfirmed) {
                ### TODO fix for 4way
                endGame($msg->{gameId}, 'draw', '0.5-0.5');
            }

            my $drawnMsg = {
                'c' => 'requestDraw',
                'color' => $color
            };
            $game->playerBroadcast($drawnMsg);
            $game->serverBroadcast($drawnMsg);

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
            if ($score) {
                endGame($msg->{gameId}, 'resigned', $score);
            }
        } elsif ($msg->{'c'} eq 'playerlost'){
            if (! gameauth($msg) ){ return 0; }
            $game->playerBroadcast($msg);

            my $score = $game->killPlayer($msg->{color});
            if ($score) {
                endGame($msg->{gameId}, 'king killed', $score);
            }
        } elsif ($msg->{'c'} eq 'authkill'){
            if (! gameauth($msg) ){ return 0; }

            $msg->{'c'} = 'kill';
            $game->playerBroadcast($msg);
        } elsif ($msg->{'c'} eq 'gamePositionMsgs'){
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

sub getGameHistory {
    my ($player, $gameSpeed, $gameType) = @_;

    my $gameLog = app()->db->selectall_arrayref('SELECT * from game_log WHERE player_id = ? AND game_speed = ? and game_type = ?', { 'Slice' => {}},
        $player->{player_id},
        $gameSpeed,
        $gameType
    );

    return $gameLog;
}

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
    if (! $globalConnectionsByAuth{ $userRow[1] }) { return 0; }

    my $connection = $globalConnectionsByAuth{ $userRow[1] };
    eval {
        $connection->send(encode_json $msg);
    };
}

sub globalBroadcast {
    my $msg = shift;

    foreach my $conn (values %globalConnections) {
        eval {
            if ($conn) {
                $conn->send(encode_json $msg);
            }
        };
    }
}

sub gameBroadcast {
    my $msg = shift;
    my $gameId = shift;

    print "game broadcast $gameId\n";

    foreach my $conn (values %{$gameConnections{$gameId}}) {
        eval {
            if ($conn) {
                $conn->send(encode_json($msg));
            }
        };
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
    my $gameType = shift;
    my $score  = shift;

    app()->log->debug("updating ratings for $gameId, " . ($score ? $score : '(no score)'));

    ### score must exist and look something like 1-0, 0.5-0.5, 1-0-0-0, etc
    if (!$score || $score !~ m/^[015\.-]+$/) {
        app()->log->debug("invalid score. $score");
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
    
    if ($gameType eq '4way') { ### was a 4way game
        my ($whiteChange, $blackChange, $redChange, $greenChange) = calculateRating2way(
            $score,
            $white->{$ratingColumn},
            $black->{$ratingColumn},
            $red->{$ratingColumn},
            $green->{$ratingColumn},
            $white->getProvisionalFactor($gameSpeed),
            $black->getProvisionalFactor($gameSpeed),
            $red->getProvisionalFactor($gameSpeed),
            $green->getProvisionalFactor($gameSpeed)
        );

        $white->{$ratingColumn} = $white->{$ratingColumn} + $whiteChange;
        $black->{$ratingColumn} = $black->{$ratingColumn} + $blackChange;
        $red->{$ratingColumn}   = $red->{$ratingColumn} + $redChange;
        $green->{$ratingColumn} = $green->{$ratingColumn} + $greenChange;

        savePlayer($white, $result,  $gameSpeed, '4way');
        savePlayer($black, $bresult, $gameSpeed, '4way');
        savePlayer($red  , $cresult, $gameSpeed, '4way');
        savePlayer($green, $cresult, $gameSpeed, '4way');
    } else {
        my ($whiteChange, $blackChange) = calculateRating2way(
            $score,
            $white->{$ratingColumn},
            $black->{$ratingColumn},
            $white->getProvisionalFactor($gameSpeed),
            $black->getProvisionalFactor($gameSpeed)
        );

        $white->{$ratingColumn} = $white->{$ratingColumn} + $whiteChange;
        $black->{$ratingColumn} = $black->{$ratingColumn} + $blackChange;
        savePlayer($white, $result,  $gameSpeed, '2way');
        savePlayer($black, $bresult, $gameSpeed, '2way');
    }

    return ($white, $black, $red, $green);
}

sub calculateRating2way {
    my ($score, $whiteRating, $blackRating, $whiteProv, $blackProv) = @_;
    print "caclu: $score $whiteRating $blackRating $whiteProv $blackProv\n";

    # k variable controls change rate
    my $k = 32;

    my ($result, $bresult) = split('-', $score);

    my $r1 = 10 ** ($whiteRating / 400);
    my $r2 = 10 ** ($blackRating / 400);

    # expected score
    my $e1 = $r1 / ($r1 + $r2);
    my $e2 = $r2 / ($r1 + $r2);

    my $whiteChange = $k * ($result - $e1);
    my $blackChange = $k * ($bresult - $e2);

    $whiteChange = adjustProv($whiteChange, $whiteProv, $blackProv);
    $blackChange = adjustProv($blackChange, $blackProv, $whiteProv);

    print "$whiteChange, $blackChange\n";
    return ($whiteChange, $blackChange);
}

sub calculateRating4way {
    my ($score, $whiteRating, $blackRating, $redRating, $greenRating, $whiteProv, $blackProv, $redProv, $greenProv) = @_;

    # k variable controls change rate
    my $k = 32;

    my ($result, $bresult, $cresult, $dresult) = split('-', $score);

    # transformed rating (on a normal curve)
    my $r1 = 10 ** ($whiteRating / 400);
    my $r2 = 10 ** ($blackRating / 400);
    my $r3 = 10 ** ($redRating   / 400);
    my $r4 = 10 ** ($greenRating / 400);

    # expected score -------- divide second part by two again??
    my $e1 = $r1 / ($r1 + $r2 + $r3 + $r4);
    my $e2 = $r2 / ($r1 + $r2 + $r3 + $r4);
    my $e3 = $r3 / ($r1 + $r2 + $r3 + $r4);
    my $e4 = $r4 / ($r1 + $r2 + $r3 + $r4);

    my $whiteChange = $k * ($result  - $e1);
    my $blackChange = $k * ($bresult - $e2);
    my $redChange   = $k * ($cresult - $e3);
    my $greenChange = $k * ($dresult - $e4);

    $whiteChange = adjustProv($whiteChange, $whiteProv, ($blackProv + $redProv + $greenProv) / 3);
    $blackChange = adjustProv($blackChange, $blackProv, ($whiteProv + $redProv + $greenProv) / 3);
    $redChange   = adjustProv($redChange  , $whiteProv, ($blackProv + $whiteProv + $greenProv) / 3);
    $greenChange = adjustProv($greenChange, $blackProv, ($blackProv + $redProv + $whiteProv) / 3);

    return ($whiteChange, $blackChange, $redChange, $greenChange);
}

sub adjustProv {
    my ($ratingChange, $provMe, $provThem) = @_;

    if ($provMe > 0) {
        # rating changes more
        my $factor = ($provMe / 2);
        if ($factor > 20) { $factor = 20; }
        if ($factor < 1) { $factor = 1; }

        $ratingChange *= $factor;
    }
    if ($provThem > $provMe) {
        # rating changes less
        my $factor = 1 - ($provThem - $provMe) / 20;
        if ($factor > 1) { $factor = 1; }
        if ($factor < 0) { $factor = 0; }

        $ratingChange *= $factor;
    }

    return $ratingChange;
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

    ### set result
    app->db()->do(
        'UPDATE games SET `status` = "finished", result = ?, score = ?, time_ended = NOW(), game_log = ? WHERE game_id = ?',
        {},
        $result,
        $score,
        $gameLog,
        $gameId,
    );

    my ($whiteStart, $blackStart, $redStart, $greenStart) = getPlayers($gameId);

    my ($whiteEnd, $blackEnd, $redEnd, $greenEnd) = ($whiteStart, $blackStart, $redStart, $greenStart);
    if ($rated) {
        ($whiteEnd, $blackEnd, $redEnd, $greenEnd) = updateRatings($gameId, $gameSpeed, $gameType, $score);   
    }

    if ($score && $score =~ m/^[015\.-]+$/) {
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
                ($score eq '0.5-0.5' ? 'draw' : ($score eq '1-0' || $score eq '1-0-0-0' ? 'win' : 'loss') ),
                ($whiteStart->{"rating_$gameSpeed"} ? $whiteStart->{"rating_$gameSpeed"} : undef),
                ($whiteEnd->{"rating_$gameSpeed"} ? $whiteEnd->{"rating_$gameSpeed"} : undef),
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
                ($score eq '0.5-0.5' ? 'draw' : ($score eq '0-1' || $score eq '0-1-0-0' ? 'win' : 'loss') ),
                ($blackStart->{"rating_$gameSpeed"} ? $blackStart->{"rating_$gameSpeed"} : undef),
                ($blackEnd->{"rating_$gameSpeed"} ? $blackEnd->{"rating_$gameSpeed"} : undef),
                $rated
            );
        }
        if ($gameType eq '4way') {
            if ($redStart->{player_id}) {
                app->db()->do('INSERT INTO game_log
                    (game_id, player_id, opponent_id, game_speed, game_type, result, rating_before, rating_after, rated)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {},
                    $gameId,
                    $redStart->{player_id},
                    $blackStart->{player_id},
                    $gameSpeed,
                    $gameType,
                    ($score eq '0.5-0.5' ? 'draw' : ($score eq '1-0' || $score eq '1-0-0-0' ? 'win' : 'loss') ),
                    ($redStart->{"rating_$gameSpeed"} ? $redStart->{"rating_$gameSpeed"} : undef),
                    ($redEnd->{"rating_$gameSpeed"} ? $redEnd->{"rating_$gameSpeed"} : undef),
                    $rated
                );
            }

            if ($greenStart->{player_id}) {
                app->db()->do('INSERT INTO game_log
                    (game_id, player_id, opponent_id, game_speed, game_type, result, rating_before, rating_after, rated)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {},
                    $gameId,
                    $greenStart->{player_id},
                    $whiteStart->{player_id},
                    $gameSpeed,
                    $gameType,
                    ($score eq '0.5-0.5' ? 'draw' : ($score eq '0-1' || $score eq '0-1-0-0' ? 'win' : 'loss') ),
                    ($greenStart->{"rating_$gameSpeed"} ? $greenStart->{"rating_$gameSpeed"} : undef),
                    ($greenEnd->{"rating_$gameSpeed"} ? $greenEnd->{"rating_$gameSpeed"} : undef),
                    $rated
                );
            }
        }
    }

    my $game = $currentGames{$gameId};
    my $whiteStartRating = (defined($whiteEnd->{"rating_$gameSpeed"}) ? $whiteEnd->{"rating_$gameSpeed"} :
        (defined($whiteStart->{"rating_$gameSpeed"}) ? $whiteStart->{"rating_$gameSpeed"} : 0));
    my $whiteEndRating =  (defined($whiteStart->{"rating_$gameSpeed"}) ? $whiteStart->{"rating_$gameSpeed"} : 0);
    my $blackStartRating = (defined($blackEnd->{"rating_$gameSpeed"}) ? $blackEnd->{"rating_$gameSpeed"} :
        (defined($blackStart->{"rating_$gameSpeed"}) ? $blackStart->{"rating_$gameSpeed"} : 0));
    my $blackEndRating =  (defined($blackStart->{"rating_$gameSpeed"}) ? $blackStart->{"rating_$gameSpeed"} : 0);

    my $ratingsAdj = {
        'white' => $whiteStartRating - $whiteEndRating,
        'black' => $blackStartRating - $blackEndRating
    };
    if ($gameType eq '4way') {
        my $redStartRating = (defined($redEnd->{"rating_$gameSpeed"}) ? $redEnd->{"rating_$gameSpeed"} :
            (defined($redStart->{"rating_$gameSpeed"}) ? $redStart->{"rating_$gameSpeed"} : 0));
        my $redEndRating =  (defined($redStart->{"rating_$gameSpeed"}) ? $redStart->{"rating_$gameSpeed"} : 0);
        my $greenStartRating = (defined($greenEnd->{"rating_$gameSpeed"}) ? $greenEnd->{"rating_$gameSpeed"} :
            (defined($greenStart->{"rating_$gameSpeed"}) ? $greenStart->{"rating_$gameSpeed"} : 0));
        my $greenEndRating =  (defined($greenStart->{"rating_$gameSpeed"}) ? $greenStart->{"rating_$gameSpeed"} : 0);
        $ratingsAdj->{'red'}   = $redStartRating   - $redEndRating;
        $ratingsAdj->{'green'} = $greenStartRating - $greenEndRating;
    };

    my $msg = {
        'c' => 'gameOver',
        'result' => $result,
        'score' => $score,
        'ratingsAdj' => $ratingsAdj,
    };
    if ($game) {
        $game->serverBroadcast($msg);
    }
    gameBroadcast($msg, $gameId);
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
    my $games = app->db()->selectall_arrayref("SELECT game_id from games WHERE status = 'active' OR status = 'waiting to begin'");
    foreach my $row (@$games) {
        my $gameId = $row->[0];
        if (! exists($currentGames{$gameId})){
            endGame($gameId, 'clear inactive');
        }
    }
}

sub getActivePlayers {
    my $speed = shift // 'standard';

    if ($speed !~ m/standard|lightning|standard_4way|lightning_4way/) {
        $speed = 'standard';
    }
    my $playerRows = app->db()->selectall_arrayref('
        SELECT *
        FROM players
        WHERE last_seen > NOW() - INTERVAL 10 SECOND ORDER BY rating_' . $speed . " DESC",
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

sub getTopPlayers {
    my $ratingsType = shift;
    my $number = shift;

    my $ratingsColumn = '';
    if ($ratingsType eq 'standard') {
        $ratingsColumn = 'rating_standard';
    } elsif ($ratingsType eq 'lightning') {
        $ratingsColumn = 'rating_lightning';
    } else {
        return [];
    }

    my $playerRows = app->db()->selectall_arrayref("
        SELECT *
        FROM players
        ORDER BY $ratingsColumn DESC LIMIT $number",
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


sub savePlayer {
    my $player = shift;
    my $result = shift;
    my $gameSpeed = shift;
    my $gameType = shift;

    app->log->debug("saving player rating $player->{player_id} $player->{rating_standard}, $player->{rating_lightning} result $result");
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
        SELECT
            p.player_id,
            p.rated,
            p.private_game_key,
            p.game_speed,
            p.game_type,
            p.matched_game,
            py.rating_standard,
            py.rating_lightning,
            IF(p.player_id = -1, "(anon)", py.screenname),
            py2.rating_standard as rating2_standard,
            py2.rating_lightning as rating2_lightning,
            py2.screenname as screenname2,
            py3.rating_standard as rating3_standard,
            py3.rating_lightning as rating3_lightning,
            py3.screenname as screenname3
        FROM pool p
        LEFT JOIN players py ON p.player_id = py.player_id
        LEFT JOIN players py2 ON p.challenge_player_id = py2.player_id
        LEFT JOIN players py3 ON p.challenge_player_2_id = py3.player_id
            WHERE (p.player_id = ? OR challenge_player_id = ? OR challenge_player_2_id = ? OR challenge_player_3_id = ?)
            AND (p.private_game_key = ? OR p.private_game_key = ?)
        ',
        { 'Slice' => {} },
        $playerId,
        $playerId,
        $playerId,
        $playerId,
        $uid,
        $playerId
    );

    if ($myGame) {
        app->db()->do('UPDATE pool SET last_ping = NOW()
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
        SELECT
            p.player_id,
            p.rated,
            p.private_game_key,
            p.game_speed,
            p.game_type,
            py.rating_standard,
            py.rating_lightning,
            IF(py.player_id = -1, "(anon)", py.screenname) as screenname,
            py2.rating_standard as rating2_standard,
            py2.rating_lightning as rating2_lightning,
            IF(p.challenge_player_id = -1, "(anon)", py2.screenname) as screenname2,
            py3.rating_standard as rating3_standard,
            py3.rating_lightning as rating3_lightning,
            IF(p.player_id = -1, "(anon)", py3.screenname) as screenname3
        FROM pool p
        LEFT JOIN players py ON p.player_id = py.player_id
        LEFT JOIN players py2 ON p.challenge_player_id = py2.player_id
        LEFT JOIN players py3 ON p.challenge_player_2_id = py3.player_id
            WHERE last_ping > NOW() - INTERVAL 4 SECOND
            AND open_to_public = 1
            AND (in_matching_pool = 0 OR game_type = "2way")
        ',
        { 'Slice' => {} }
    );

    return $poolRows;
}

### entering the pool WILL destroy any open games you have, you cannot do both
sub enterUpdatePool {
    my $player = shift;
    my $options = shift;

    my $rated           = $player ? 1 : 0;
    my $playerId        = $player ? $player->{player_id} : ANON_USER;
    my $gameSpeed       = $options->{gameSpeed}  // 'standard';
    my $gameType        = $options->{gameType}   // '2way';
    my $uuid            = $options->{uuid}       // 0;

    if ($uuid) {
        my $poolRow = app->db()->selectrow_hashref('SELECT * FROM pool WHERE private_game_key = ?',
            { 'Slice' => {} },
            $uuid
        );
        if (! $poolRow ) {
            $uuid = 0;
        }
    }

    if (! $uuid) {
        $uuid = createChallenge($playerId, $gameSpeed, $gameType, 1, $rated, undef);
    };

    app->db()->do( 'UPDATE pool SET last_ping = NOW(), in_matching_pool = 1
        WHERE private_game_key = ?',
        {},
        $uuid
    );

    return $uuid;
}

sub createChallenge {
    my ($playerId, $gameSpeed, $gameType, $open, $rated, $challengePlayer) = @_;

    if ($playerId != ANON_USER) {
        app->db()->do("DELETE FROM pool WHERE player_id = ?", {}, $playerId);
    }

    my $sth = app->db()->prepare('INSERT INTO pool
        (player_id, game_speed, game_type, open_to_public, rated, private_game_key, in_matching_pool, last_ping, challenge_player_id)
        VALUES (?, ?, ?, ?, ?, ?, 0, NOW(), ?)');

    my $uuid = create_uuid_as_string();
    $sth->execute($playerId, $gameSpeed, $gameType, $open, $rated, $uuid, $challengePlayer);

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
    }
    if ($poolRow->{rated} && $playerId == ANON_USER) {
        return undef;
    }
    if ($poolRow->{game_type} eq '4way') {
        ### check if this player is already matched to the game.
        if (
            ($poolRow->{player_id} eq $playerId) || 
            ($poolRow->{challenge_player_id} && $poolRow->{challenge_player_id} eq $playerId) ||
            ($poolRow->{challenge_player_2_id} && $poolRow->{challenge_player_2_id} eq $playerId) ||
            ($poolRow->{challenge_player_3_id} && $poolRow->{challenge_player_3_id} eq $playerId)
        ) {
            # undef or game_id
            return ($poolRow->{matched_game} ? $poolRow->{matched_game} : -1);
        }
        if (! $poolRow->{challenge_player_id}) {
            app->db()->do('UPDATE pool SET challenge_player_id = ? WHERE private_game_key = ?', {}, $playerId, $uid);
            return -1; ### special signal that we just added
        } elsif (! $poolRow->{challenge_player_2_id} ) {
            app->db()->do('UPDATE pool SET challenge_player_2_id = ? WHERE private_game_key = ?', {}, $playerId, $uid);
            return -1; ### special signal that we just added
        } elsif (! $poolRow->{challenge_player_3_id} ) {
            ### we are the last to join, make the game.
            my $gameId = createGame(
                $poolRow->{game_type},
                $poolRow->{game_speed},
                $poolRow->{rated},
                $poolRow->{player_id},
                $poolRow->{challenge_player_id},
                $poolRow->{challenge_player_2_id},
                $playerId
            );
            app->db()->do('UPDATE pool SET matched_game = ?, challenge_player_3_id = ? WHERE private_game_key = ?', {}, $gameId, $playerId, $uid);
            return $gameId;
        }

    } else {
        my $options = {
        };
        if ($poolRow->{player_id} == ANON_USER) {
            $options->{blackUuid} = $poolRow->{private_game_key}
        }
        # speed, open, rated, whiteId, blackId
        my $gameId = createGame($poolRow->{game_type}, $poolRow->{game_speed}, $poolRow->{rated}, $playerId, $poolRow->{player_id}, undef, undef, $options);

        app->db()->do('UPDATE pool SET matched_game = ? WHERE private_game_key = ?', {}, $gameId, $uid);
        return $gameId;
    }
}

sub cancelGameUid {
    my $player = shift;
    my $uid = shift;

    my $playerId = ($player ? $player->{player_id} : -1);

    my $poolRow = app->db()->selectrow_hashref('SELECT * FROM pool WHERE private_game_key = ?',
        { 'Slice' => {} },
        $uid
    );
    if ($poolRow->{player_id} eq $playerId) {
        app->db()->do('DELETE FROM pool WHERE player_id = ? AND private_game_key = ?', {}, $playerId, $uid);
    } elsif ($poolRow->{challenge_player_id} eq $playerId) {
        app->db()->do('UPDATE pool SET challenge_player_id = NULL WHERE private_game_key = ?', {}, $uid);
    } elsif ($poolRow->{challenge_player_2_id} eq $playerId) {
        app->db()->do('UPDATE pool SET challenge_player_2_id = NULL WHERE private_game_key = ?', {}, $uid);
    } elsif ($poolRow->{challenge_player_3_id} eq $playerId) {
        app->db()->do('UPDATE pool SET challenge_player_3_id = NULL WHERE private_game_key = ?', {}, $uid);
    }

    return 1;
}

sub matchPool {
    my $player    = shift;
    my $gameSpeed = shift;
    my $gameType  = shift;
    my $uuid      = shift;

    if (!$gameSpeed) { $gameSpeed = 'standard'; }
    if (!$gameType)  { $gameType  = '4way'; }
    my $playerId = $player->{player_id} // ANON_USER;

    my $ratingColumn = 'rating_' . $gameSpeed;
    my @poolRow = app->db()->selectrow_array(
        'SELECT player_id, matched_game, rated FROM pool WHERE private_game_key = ?',
        {},
        $uuid
    );

    my ($player_id, $matched_game, $rated);
    if (@poolRow) {
        ($player_id, $matched_game, $rated) = @poolRow;
        if ($matched_game) {
            my @gameRow = app->db()->selectrow_array(
                'SELECT status, white_player, black_player, green_player, red_player FROM games WHERE game_id = ?',
                {},
                $matched_game
            );
            
            my ($gameStatus, $blackPlayer, $whitePlayer, $greenPlayer, $redPlayer) = @gameRow;
            if (($gameStatus eq 'waiting to begin' || $gameStatus eq 'active') &&
                ($blackPlayer == $playerId
                    || $whitePlayer == $playerId
                    || $redPlayer   == $playerId
                    || $greenPlayer == $playerId
                )
            ) {
                return $matched_game;
            } else { ### the matched game is over or obsolete
                app->db()->do("DELETE FROM pool private_game_key = ?", {}, $uuid);
                return undef;
            }
        }
    }

    ### now we try to find if any player matched them.
    my $needed = $gameType eq '4way' ? 3 : 1;
    my $matchSql = 
        'SELECT p.player_id, p.private_game_key FROM pool p
            LEFT JOIN players pl ON p.player_id = pl.player_id
            WHERE p.private_game_key != ?
            AND game_speed = ?
            AND game_type = ?
            AND rated = ?
            AND last_ping > NOW() - INTERVAL 5 SECOND
            LIMIT ' . $needed;
    my $playerMatchedRow = app->db()->selectall_arrayref(
        $matchSql,
        {},
        $uuid,
        $gameSpeed,
        $gameType,
        $rated,
        #$player->{$ratingColumn} // '1600'  #TODO find best matched rating
    );

    if ($#{$playerMatchedRow} + 1 >= $needed) {
        my $playerMatchedId = $playerMatchedRow->[0][0];
        my $playerMatchedId2 = ($gameType eq '4way' ? $playerMatchedRow->[1][0] : undef);
        my $playerMatchedId3 = ($gameType eq '4way' ? $playerMatchedRow->[2][0] : undef);

        my $uuid2 = $playerMatchedRow->[0][1];
        my $uuid3 = ($gameType eq '4way' ? $playerMatchedRow->[1][1] : undef);
        my $uuid4 = ($gameType eq '4way' ? $playerMatchedRow->[2][1] : undef);

        my $options = {
            'whiteUuid' => $uuid,
            'blackUuid' => $uuid2,
            'redUuid'   => $uuid3,
            'greenUuid' => $uuid4,
        };
                  # speed, rated, whiteId, blackId, redId, greenId, options
        my $gameId = createGame($gameType, $gameSpeed, 1, $playerId, $playerMatchedId, $playerMatchedId2, $playerMatchedId3, $options);

        app->db()->do('UPDATE pool SET matched_game = ? WHERE private_game_key = ?', {}, $gameId, $uuid);
        app->db()->do('UPDATE pool SET matched_game = ? WHERE private_game_key = ?', {}, $gameId, $playerMatchedRow->[0][1]);
        if ($gameType eq '4way') {
            app->db()->do('UPDATE pool SET matched_game = ? WHERE private_game_key = ?', {}, $gameId, $playerMatchedRow->[1][1]);
            app->db()->do('UPDATE pool SET matched_game = ? WHERE private_game_key = ?', {}, $gameId, $playerMatchedRow->[2][1]);
        }

        return $gameId;
    }

    return undef;
}

app->start;
