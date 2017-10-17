#!/usr/bin/perl
#
use strict; use warnings;
use Net::WebSocket::Server;
use UUID::Tiny ':std';
use Data::Dumper;
use ChessPiece;
use JSON::XS;

my %games = ();

my $wi = AnyEvent->timer (after => 1, cb => sub {
	warn "timeout\n";
});
print "Starting websocket server...\n";
my $server = Net::WebSocket::Server->new(
	listen => 8080,
	on_connect => sub {
		my ($serv, $conn) = @_;
		$conn->on(
			handshake => sub {
				my ($conn, $handshake) = @_;
				print "handshake\n";
			},
			utf8 => sub {
				my ($conn, $msgStr) = @_;
				my $msg = {};
				eval {
					$msg = decode_json($msgStr);
				} or do {
					print "bad JSON: $msgStr\n";
					return 0;
				};
				print "MSG: $msgStr\n";
				if ($msg->{'c'} eq 'join'){
					return 0 if (! $msg->{gameId} );
					my $auth   = create_uuid_as_string();

					my $color = 'white';
					$games{$msg->{gameId}}->{players}->{$auth} =
						{
							'color' => $color,
							'conn'  => $conn,
						};
					my $ret = {
						'c' => 'joined',
						'color' => 'white',
						'p_auth' => $auth
					};

					$conn->send_utf8(encode_json $ret);
					serverBroadcast($msg->{gameId}, $msg);
					print "player joined, auth: $auth\n";
				} elsif ($msg->{'c'} eq 'move'){
					return 0 if (! ($msg->{gameId} && $msg->{auth}));                          # no game / auth tokens
					return 0 if (! exists($games{$msg->{gameId}}->{players}->{$msg->{auth}})); # player doesn't exist

					# pass the move request to the server
					serverBroadcast($msg->{gameId}, $msg);
				} elsif ($msg->{'c'} eq 'authmove'){
					return 0 if (! ($msg->{gameId} && $msg->{auth}));                          # no game / auth tokens
					return 0 if ($games{$msg->{gameId}}->{auth} ne $msg->{auth});              # incorrect server auth

					# pass the move request to the server
					$msg->{'c'} = 'move';
					playerBroadcast($msg->{gameId}, $msg);
				} elsif ($msg->{'c'} eq 'spawn'){
					return 0 if (! ($msg->{gameId} && $msg->{auth}));                          # no game / auth tokens
					return 0 if ($games{$msg->{gameId}}->{auth} ne $msg->{auth});              # incorrect server auth

					print "broadcast spawn...\n";
					playerBroadcast($msg->{gameId}, $msg);

				} elsif ($msg->{'c'} eq 'authkill'){
					return 0 if (! ($msg->{gameId} && $msg->{auth}));                          # no game / auth tokens
					return 0 if ($games{$msg->{gameId}}->{auth} ne $msg->{auth});              # incorrect server auth

                    $msg->{'c'} = 'kill';
                    playerBroadcast($msg->{gameId}, $msg);
				} elsif ($msg->{'c'} eq 'authjoin'){
					return 0 if (! ($msg->{gameId} && $msg->{auth}));                          # no game / auth tokens
					return 0 if ($games{$msg->{gameId}}->{auth} ne $msg->{auth});              # incorrect server auth
					$games{$msg->{gameId}}->{'serverConn'} = $conn;
					$games{$msg->{gameId}}->{'readyToJoin'} = 1;
					print "game client ready...\n";
					my $ret = {
						'c' => 'readyToJoin',
						'gameId' => $msg->{gameId}
					};
					playerBroadcast($msg->{gameId}, $ret);
					#$games{$msg->{gameId}}->{creatorConn}->send_utf8(encode_json $msg);
				} elsif ($msg->{'c'} eq 'create'){
					my $gameId = create_uuid_as_string();
					my $auth   = create_uuid_as_string();

					$games{$gameId} = {
						'players' => {},
						'readyToJoin' => 0,
						'serverConn' => '',
						'auth'       => $auth,
					};

					# spin up game server, wait for it to send authjoin
					print "starting game client $gameId, $auth\n";
					system('/usr/bin/perl /home/corey/kungFuChessGame.pl ' . $gameId . ' ' . $auth . ' > /home/corey/game.log 2>/home/corey/errors.log &');
				} else {
					print "bad message: $msgStr\n";
				}
			},
		);
	},
);

print "Done!\n";

$server->start();

sub setupGame {

}

sub creatorBroadcast {
	my ($gameId, $msg) = @_;
	print "creator broadcast $gameId\n";
	$games{$gameId}->{creatorConn}->send_utf8(encode_json $msg);
}

sub playerBroadcast {
	my ($gameId, $msg) = @_;
	print "player broadcast $gameId\n";
	delete $msg->{auth};
	foreach my $player (values %{ $games{$gameId}->{players}}){
		print "broadcasting to player $msg->{c}\n";
		$player->{conn}->send_utf8(encode_json $msg);
	}
}

sub serverBroadcast {
	my ($gameId, $msg) = @_;
	$games{$gameId}->{serverConn}->send_utf8(encode_json $msg);
}

sub addConn {
	my $gameId = shift;
	my $conn = shift;
	push @{ $games{$gameId}->{connections} }, $conn;
}
