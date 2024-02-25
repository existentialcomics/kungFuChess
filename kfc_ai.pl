#!/usr/bin/perl

use strict;
use warnings;

use HTTP::CookieJar::LWP ();
use LWP::UserAgent       ();
use JSON::XS;
use HTTP::Request::Common qw{ POST };
use Data::Dumper;
use WWW::Mechanize ();
use AnyEvent::WebSocket::Client;
use AnyEvent;
use Sys::MemInfo qw(totalmem freemem totalswap);

my $user   = shift;
my $pass   = shift;
my $domain = shift;
my $level  = shift;
my $speed    = shift // 'standard';
my $way      = shift // '2way';
my $register = shift // 0;
my $globalMode = shift // 'normal';
my $timeToExit = shift // (time + (60 * 20));

my $minMemory = 1500000;

if (! $speed) {
    print "usage: perl kfc_ai.pl <user> <password> <domain> <level> <speed> <register?>
    perl kfc_ai.pl ai_bot_123 123456 https://kungfuchess.org 1 standard 1
";
    exit;
}
print "\n\nstarting with $user, $pass, $domain, $level, $speed, $register\n";

#my $domain = "http://127.0.0.1:3000";
#my $domain = "https://kungfuchess.org";
my $mech = WWW::Mechanize->new();
my $loginUrl = $domain . '/login';
my $registerUrl = $domain . '/register';

if ($register && $user ne 'anon') {
    $mech->get($domain);
    $mech->get($registerUrl);
    my $params =  {
        'username' => $user,
        'password' => $pass
    };
    my $forms = $mech->forms();

    my $inputs = $forms->[0]->{inputs};
    foreach my $input (@$inputs){ 
        if ($input->{type} eq 'hidden') {
            $params->{$input->{name}} = $input->{value};
        }
    }
    my $return = $mech->submit_form(
        form_number => 1,
        fields    => $params,
        #button    => 'Search Now'
    );
}

$mech->get($domain);
if ($user ne 'anon') {
    $mech->get($loginUrl);

    sleep(1);
    my $params =  {
        'username' => $user,
        'password' => $pass
    };
    my $forms = $mech->forms();

    my $inputs = $forms->[0]->{inputs};
    foreach my $input (@$inputs){ 
        if ($input->{type} eq 'hidden') {
            $params->{$input->{name}} = $input->{value};
        }
    }
    $mech->submit_form(
        form_number => 1,
        fields    => $params,
        #button    => 'Search Now'
    );
}
$mech->get('/ajax/userId');
my $userId = -1;
my $jsonUser = decode_json($mech->content());
$userId = $jsonUser->{userId};
print "userId: $userId\n";

my $mode = 'searchForGame';
my $gameId = undef;;

$mech->get($domain);

my $authToken;
if ($mech->content() =~ m/var userAuthToken = "(.+?)"/){ 
    $authToken = $1;
};
print "authToken: $authToken\n";

my $uid = '';
my $wsdomain = '';
my $color;

my %uidHashCount = ();
my $aiInterval = AnyEvent->timer(
    after => 1,
    interval => 3.5,
    cb => sub {
        if (time > $timeToExit) { exit; }
        if (Sys::MemInfo::get("freeswap") < $minMemory) { exit; }

        if ($mode eq 'searchForGame' or $mode eq 'chill') {
            print "interval searchForGame\n";
            #$mech->get('/activePlayers?ratingType=standard');
            my $url = '/ajax/openGames/json';
            $url .= "?update-time=true";
            $mech->get($url);
            eval {
                if (rand() < 0.06 && $globalMode eq 'normal' && $user ne 'anon') {
                    print "setting $user globalMode to pool\n";
                    $mode = 'pool';
                    return;
                }
                if (rand() < 0.01 && $globalMode eq 'chill' && $user ne 'anon') {
                    print "setting $user globalMode to pool\n";
                    $mode = 'pool';
                    return;
                }
                $gameId = undef;
                my $game = {};
                my $json = decode_json($mech->content());
                ### look for a rematch first
                ### this means we are already in a game
                #   possibly from a rematch accepted
                foreach my $pool (@$json) {
                    if ($pool->{gameId} && $pool->{is_my_game}) {
                        $gameId = $pool->{gameId};
                        print "join game/rematch $pool->{gameId}\n";
                        $mech->get('/ajax/joinGame/' . $pool->{gameId});
                        my $joinGame = decode_json($mech->content());
                        if ($joinGame->{color}) {
                            $mech->get('/ajax/game/' . $pool->{gameId});
                            $game = decode_json($mech->content());
                        }
                        last;
                    }
                }
                if (! $gameId ) {
                    foreach my $pool (@$json) {
                        ### pool games
                        if ($userId == -1 && $pool->{rated} == 1) {
                            print "skip rated anon\n";
                            next;
                        }
                        if ($pool->{private_game_key}) {
                            if (! $uidHashCount{$pool->{private_game_key}}) {
                                print "adding to hash=1\n";
                                $uidHashCount{$pool->{private_game_key}} = 1;
                            } else {
                                print "adding to hash++\n";
                                $uidHashCount{$pool->{private_game_key}}++;
                            }
                            if ($uidHashCount{$pool->{private_game_key}} > ($mode eq 'normal' ? 3 : 10)) {
                                print "GET: " . '/ajax/matchGame/' . $pool->{private_game_key} . "\n";
                                $mech->get('/ajax/matchGame/' . $pool->{private_game_key});
                                my $poolMatch = decode_json($mech->content());
                                my $color = "";
                                ### we have matched with this game possibly
                                if ($poolMatch->{gameId}) {
                                    $gameId = $poolMatch->{gameId};
                                    $mech->get('/ajax/game/' . $poolMatch->{gameId});
                                    $game = decode_json($mech->content());
                                    last;
                                }
                            }
                        }
                        ### 4way games that are open
                        if ($pool->{gameId}) {
                            if (! $uidHashCount{$pool->{gameId}}) {
                                print "adding to hash=1\n";
                                $uidHashCount{$pool->{gameId}} = 1;
                            } else {
                                print "adding to hash++\n";
                                $uidHashCount{$pool->{gameId}}++;
                            }
                            if ($uidHashCount{$pool->{gameId}} > 2) {
                                $mech->get('/ajax/joinGame/' . $pool->{gameId});
                                my $poolMatch = decode_json($mech->content());
                                ### we have matched with this game possibly
                                if ($poolMatch->{gameId}) {
                                    $gameId = $poolMatch->{gameId};
                                    $mech->get('/ajax/game/' . $poolMatch->{gameId});
                                    $game = decode_json($mech->content());
                                    last;
                                }
                            }
                        }
                    }
                }
                if (! $gameId) {
                    return;
                }

                $color = $game->{color};
                if ($color) {
                    print "game matched $color\n";
                    my $cmdAi = sprintf('/usr/bin/perl ./kungFuChessGame%sAi.pl %s %s %s %s %s %s %s %s %s >>%s 2>>%s',
                        $game->{game_type},
                        $gameId,
                        $authToken,
                        $game->{piece_speed},
                        $game->{piece_recharge},
                        '1:1:1:1', ## berserk speed advantage
                        $game->{teams} // '1-1-1-1',
                        $level,
                        $color,
                        $game->{ws_protocol} . "://" . $game->{ws_server} . "/ws",
                        "/var/log/kungfuchess/$gameId-$color-game-ai.log",
                        "/var/log/kungfuchess/$gameId-$color-error-ai.log"
                    );
                    print "$cmdAi\n";
                    system($cmdAi);
                }
                print "\n\n\n";
            };
        } elsif ($mode eq 'pool') {
            if (rand() < 0.05 && $globalMode eq 'normal') {
                if (rand() < 0.5) {
                    print "setting globalMode to search\n";
                    $mode = 'searchForGame';
                    return;
                } else {
                    print "setting globalMode to chill\n";
                    $mode = 'chill';
                    return;
                }
            }
            my $url = '/ajax/pool/' . $speed . '/' . $way;
            if (! $uid) {
                my $token;
                my $csr_input;
                #my ($csr_input) = $mech->find_all_inputs(name => 'csrftoken');
                #$token = $csr_input->value();

                $mech->get($domain);
                if ($mech->content() =~ m/<meta name="csrftoken" content="(.+?)"/) {
                    print "regex token: $1\n";
                    $token = $1;
                }
                #$mech->add_header("X-CSRFToken", $token);
                $mech->add_header("X-CSRFToken", $token);
                print "token: $token\n";
                $mech->post($url, ['csrftoken' => $token]);

                print $mech->content();
                if ($mech->content() =~ m/"uid":"(.+?)"/) {
                    $uid = $1;
                }
            } else {
                $mech->get('/ajax/openGames?uid=' . $uid . "&update-time=true");
            }

            if ($mech->content() =~ m/"(?:gameId|matchedGame)":"?(\d+)"?/) {
                $gameId = $1;
                $mode = 'game';
                print "getting GAME $gameId\n";
                $mech->get('/game/' . $gameId);
                if ($mech->content() =~ m/var userAuthToken = "(.+?)"/){ 
                    $authToken = $1;
                };
                my $color = 1;
                if ($mech->content() =~ m/var myColor\s+=\s*"black"/) {
                    $color = 2;
                }
                if ($mech->content() =~ m/var wsGameDomain\s+=\s*"(.+?)"/) {
                    print $mech->content();
                    my $d = $1;
                    if ($d =~ m/localhost|127|dragon/) {
                        $wsdomain = "ws://" . $d . "/ws";
                    } else {
                        $wsdomain = "wss://" . $d . "/ws";
                    }
                }
                my $cmdAi = sprintf(
                    '/usr/bin/perl ./kungFuChessGame%sAi.pl %s %s %s %s %s %s %s %s %s >%s 2>%s',
                    $way,
                    $gameId,
                    $authToken,
                    ($speed eq 'standard' ? 10 : 1),
                    ($speed eq 'standard' ? 10 : 1),
                    '1:1:1:1', ### speed advantage
                    '1-1-1-1', ### teams
                    $level,
                    $color,
                    $wsdomain,
                    "/var/log/kungfuchess/$gameId-$color-game-ai.log",
                    "/var/log/kungfuchess/$gameId-$color-error-ai.log"
                );

                print $cmdAi . "\n";
                my $pid = system($cmdAi);
                print "game finished\n";
                $uid = undef;
                $mode = 'searchForGame';
            }
        }
    }
);

sub sendMsg {
    my $conn = shift;
    my $msg = shift;
    $msg->{auth} = $authToken;
    $conn->send(encode_json $msg);
}

print "ae->recv\n";
my $ae = AnyEvent->condvar;
$ae->recv;
