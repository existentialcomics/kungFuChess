#!/usr/bin/perl
#
use strict; use warnings;
use Mojolicious::Lite;
use UUID::Tiny ':std';
use Data::Dumper;
use ChessPiece;
use JSON::XS;

### current running games
my %games = ();
### all connected clients
my %clients = ();

get '/' => {
	text => 'I ♥ Mojolicious!'
};

get '/game/:gameId' => sub {
	my $c = shift;
	app->log->debug( "Entering game" );

	my $playerAuth = "";
	$c->stash('playerAuth' => $playerAuth);

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
	# spin up game server, wait for it to send authjoin
	app->log->debug('/usr/bin/perl /home/corey/kungfuchess/kungFuChessGame.pl ' . $gameId . ' ' . $auth . ' > /home/corey/game.log 2>/home/corey/errors.log &');
	system('/usr/bin/perl /home/corey/kungfuchess/kungFuChessGame.pl ' . $gameId . ' ' . $auth . ' > /home/corey/game.log 2>/home/corey/errors.log &');

	$c = $c->redirect_to("/game/$gameId");
};

get '/login' => sub {

};

post '/login' => sub {

};

websocket '/ws' => sub {
	my $self = shift;

	app->log->debug(sprintf 'Client connected: %s', $self->tx);
	my $id = sprintf "%s", $self->tx;
	$self->inactivity_timeout(300);
	$clients{$id} = $self->tx;
	#
	$self->on(finish => sub {
		## delete player
		app->log->debug("connection closed for $id");

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

		if ($msg->{'c'} eq 'join'){
			return 0 if (! $msg->{gameId} );

			my $ret = {
				'c' => 'joined',
			};
			$games{$msg->{gameId}}->{players}->{$id} =
				{
					'conn'  => $self,
				};

			$self->send(encode_json $ret);
			serverBroadcast($msg->{gameId}, $msg);
			app->log->debug('player joined');
		} elsif ($msg->{'c'} eq 'playerjoin'){
			my @availableColors = getAvailableColors($msg->{gameId});
			print Dumper(@availableColors);

			if (scalar(@availableColors > 0)){
				my $color = $availableColors[rand @availableColors];
				my $auth   = create_uuid_as_string();
				$games{$msg->{gameId}}->{players}->{$id} =
					{
						'color' => $color,
						'conn'  => $self,
						'auth'  => $auth
					};
				my $ret = {
					'c' => 'joined',
					'color' =>  $color,
					'p_auth' => $auth
				};
				$self->send(encode_json $ret);
			}

		} elsif ($msg->{'c'} eq 'move'){
			app->log->debug('move');
			return 0 if (! ($msg->{gameId} && $msg->{auth}));                          # no game / auth tokens
			return 0 if (! exists($games{$msg->{gameId}}->{players}->{$id}));		   # player doesn't exist
			app->log->debug('move authed');
			app->log->debug(Dumper($msg));

			$msg->{color} = $games{$msg->{gameId}}->{players}->{$id}->{color};
			return 0 if ($msg->{color} eq '');

			# pass the move request to the server
			# TODO pass the player's color to the server
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
		} elsif ($msg->{'c'} eq 'promote'){
			return 0 if (! ($msg->{gameId} && $msg->{auth}));                          # no game / auth tokens
			return 0 if ($games{$msg->{gameId}}->{auth} ne $msg->{auth});              # incorrect server auth
			playerBroadcast($msg->{gameId}, $msg);
		} elsif ($msg->{'c'} eq 'authjoin'){
			app->log->debug('authjoin recieved');
			return 0 if (! ($msg->{gameId} && $msg->{auth}));                          # no game / auth tokens
			return 0 if ($games{$msg->{gameId}}->{auth} ne $msg->{auth});              # incorrect server auth
			app->log->debug('authjoin verified');
			$games{$msg->{gameId}}->{'serverConn'} = $self->tx;
			$games{$msg->{gameId}}->{'readyToJoin'} = 1;
			print "game client ready...\n";
			my $ret = {
				'c' => 'readyToJoin',
				'gameId' => $msg->{gameId}
			};
			playerBroadcast($msg->{gameId}, $ret);
		} else {
			print "bad message: $msg\n";
			print Dumper($msg);
		}
	});
};

sub playerBroadcast {
	my ($gameId, $msg) = @_;
	print "player broadcast $gameId\n";
	delete $msg->{auth};
	foreach my $player (values %{ $games{$gameId}->{players}}){
		print "broadcasting to player $msg->{c}\n";
		$player->{conn}->send(encode_json $msg);
	}
}

sub getAvailableColors {
	my $gameId = shift;
	my %colors = (
		'black' => 1,
		'white' => 1,
	);
	foreach my $player (values %{ $games{$gameId}->{players}}){
		if ($player->{color} ne ''){
			delete $colors{$player->{color}};
		}
	}
	return keys %colors;
}

sub serverBroadcast {
	my ($gameId, $msg) = @_;
	print "server broadcast for gameId: $gameId\n";
	$games{$gameId}->{serverConn}->send(encode_json $msg);
}

sub addConn {
	my $gameId = shift;
	my $conn = shift;
	push @{ $games{$gameId}->{connections} }, $conn;
}

app->start;
