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
use UUID::Tiny ':std';

use Proc::PID::File;
die "Already running!" if Proc::PID::File->running();

my $run = 1;
my $mech = WWW::Mechanize->new();
my $baseUrl = shift;
my $secure  = shift // 1;
while($run) {
    my $url = 'open-json/ai';
    print "getting $url\n";
    $mech->get($baseUrl . $url);

    my $content = decode_json($mech->content());
    foreach my $gameRow (@$content) {
        eval {
            my $type   = $gameRow->{type};
            my $color  = $gameRow->{color};
            my $gameId = $gameRow->{game_id};
            my $uid = create_uuid_as_string();
            my $speedAdvantage = undef;
            my $pieceSpeed = 1;
            my $pieceRecharge = 10;

            my $aiColor = (
                $color eq 'white' ? 1 :
                $color eq 'black' ? 2 :
                $color eq 'red'   ? 3 :
                $color eq 'green' ? 4 : 2);  ### default to black i guess

            my $claimUrl = "claim-game/$gameId/color/$color/ai/$uid";
            print "url $baseUrl$claimUrl\n";
            $mech->get($baseUrl . $claimUrl);

            my $cmdAi = sprintf('/usr/bin/perl ./kungFuChessGame%sAi.pl %s %s %s %s %s %s %s %s 1>%s 2>%s &',
                $gameRow->{game_type},
                $gameRow->{game_id},
                $uid,
                $gameRow->{piece_speed},
                $gameRow->{piece_recharge},
                $gameRow->{speed_advantage} // "1:1:1:1",
                $gameRow->{level},
                $aiColor,
                ($secure ? "wss://" : "ws://") . $gameRow->{ws_server} . "/ws",
                '/var/log/kungfuchess/' . $gameRow->{game_id} . '-game-' . $color . '-ai.log',
                '/var/log/kungfuchess/' . $gameRow->{game_id} . '-error-' . $color . '-ai.log'
            );

            print "$cmdAi\n";
            system($cmdAi);
        }
    }
    print "sleeping...\n";
    sleep(2);
}
