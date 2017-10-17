#!/usr/bin/perl
#
use strict; use warnings;
use Mojolicious::Lite;
use UUID::Tiny ':std';
use Data::Dumper;
use ChessPiece;
use JSON::XS;

my %games = ();

get '/' => {
	text => 'I ♥ Mojolicious!'
};

get '/game/:game' => sub {
	my $c = shift;
	app->log->debug( "Entering game" );

	$c->render('template' => 'board', format => 'html', handler => 'ep');
	return;
};

get '/create' => sub {
	my $c = shift;

	my $gameId = create_uuid_as_string();
	my $auth   = create_uuid_as_string();

	$games{$gameId} = {
		'players' => {},
		'readyToJoin' => 0,
		'serverConn' => '',
		'auth'       => $auth,
	};

	# spin up game server, wait for it to send authjoin
	app->log->debug( "starting game client $gameId, $auth" );
	system('/usr/bin/perl /home/corey/kungFuChessGame.pl ' . $gameId . ' ' . $auth . ' > /home/corey/game.log 2>/home/corey/errors.log &');

	$c = $c->redirect_to("/game/$gameId");
};

get '/login' => sub {

};

post '/login' => sub {

};

websocket '/game' => sub {
	my $self = shift;

	app->log->debug(sprintf 'Client connected: %s', $self->tx);
	my $id = sprintf "%s", $self->tx;
	#$clients->{$id} = $self->tx;

	$self->on(message => sub {
		my ($self, $msg) = @_;
		eval {
			$msg = decode_json($msg);
		} or do {
			print "bad JSON: $msg\n";
			return 0;
		};

		if ($msg->{'c'} eq 'join'){
			return 0 if (! $msg->{gameId} );
			my $auth   = create_uuid_as_string();

			my $color = 'white';
			$games{$msg->{gameId}}->{players}->{$auth} =
				{
					'color' => $color,
					'conn'  => $self,
				};
			my $ret = {
				'c' => 'joined',
				'color' => 'white',
				'p_auth' => $auth
			};

			$self->send(encode_json $ret);
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
			$games{$msg->{gameId}}->{'serverConn'} = $self;
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
			print "bad message: $msg\n";
		}
	});


};

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
		$player->{conn}->send(encode_json $msg);
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

app->start;
