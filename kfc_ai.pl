#!/usr/bin/perl
#

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

my $user = shift;
my $pass = shift;
my $domain = shift;
my $level = shift;
my $speed = shift;
my $register = shift;

if (! $speed) {
    print "usage: perl kfc_ai.pl <user> <password> <domain> <level> <speed> <register?>
    perl kfc_ai.pl ai_bot_123 123456 https://kungfuchess.org 1 standard 1
";
    exit;

}
print "starting with $user, $pass, $domain, $level, $speed, $register\n";

#my $domain = "http://127.0.0.1:3000";
#my $domain = "https://kungfuchess.org";
my $mech = WWW::Mechanize->new();
my $loginUrl = $domain . '/login';
my $registerUrl = $domain . '/register';

if ($register) {
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
$mech->get($loginUrl);

sleep(1);
my $params =  {
    'username' => $user,
    'password' => $pass
};
my $forms = $mech->forms();

#print Dumper($forms);
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
my $aiInterval = AnyEvent->timer(
    after => 3,
    interval => 3,
    cb => sub {
        if ($mode eq 'searchForGame') {
            #$mech->get('/activePlayers?ratingType=standard');
            if (! $uid) {
                $mech->get('/ajax/pool/' . $speed . '/2way');
                if ($mech->content() =~ m/"uid":"(.+?)"/) {
                    $uid = $1;
                }
            } else {
                $mech->get('/ajax/openGames?uid=' . $uid);
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
                    my $d = $1;
                    if ($d =~ m/localhost|127/) {
                        $wsdomain = "ws://" . $d . "/ws";
                    } else {
                        $wsdomain = "wss://" . $d . "/ws";
                    }
                }
                my $cmdAi = sprintf('/usr/bin/perl ./kungFuChessGame%sAi.pl %s %s %s %s %s %s %s %s >%s 2>%s',
                    '2way',
                    $gameId,
                    $authToken,
                    ($speed eq 'standard' ? 10 : 1),
                    ($speed eq 'standard' ? 10 : 1),
                    '1-1-1-1',
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
