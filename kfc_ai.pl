#!/usr/bin/perl
#

use strict;
use warnings;

use HTTP::CookieJar::LWP ();
use LWP::UserAgent       ();
use HTTP::Request::Common qw{ POST };
use Data::Dumper;
use WWW::Mechanize ();

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

while() {
    $mech->get($domain);

    my $authToken;
    if ($mech->content() =~ m/var userAuthToken = "(.+?)"/){ 
        $authToken = $1;
    };
    print "authToken: $authToken\n";


    my $uid = '';
    my $gameId;
    while () {
        sleep 2;
        #$mech->get('/activePlayers?ratingType=standard');
        $mech->get('/ajax/pool/' . $speed . '/2way?uuid=' . $uid);
        if ($mech->content() =~ m/"uid":"(.+?)"/) {
            $uid = $1;
        }
        if ($mech->content() =~ m/"gameId":"?(\d+)"?/) {
            $gameId = $1;
            print "getting GAME $gameId\n";
            $mech->get('/game/' . $gameId);
            last;
        }
    }

    if ($mech->content() =~ m/var userAuthToken = "(.+?)"/){ 
        $authToken = $1;
    };

    my $color = 1;

    if ($mech->content() =~ m/var myColor\s+=\s*"black"/) {
        $color = 2;
    }

    my $wsdomain; 
    # var wsGameDomain = "ws1.kungfuchess.org";
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

    my $pid;
    #if ($pid = fork) {

    #} else {
        system($cmdAi);
    #}
}
