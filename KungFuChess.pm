#!/usr/bin/perl
use strict; use warnings;

package KungFuChess;
use AnyEvent::WebSocket::Client;
use AnyEvent;
use ChessPiece;
use JSON::XS;
use Data::Dumper;

$| = 1;

sub new {
	my $class = shift;

	my $self = {};
	bless( $self, $class );

	if ($self->_init(@_)){
		return $self;
	} else {
		return undef;
	}
}

sub _init {
	my $self = shift;
	my $gameKey = shift;
	my $authKey = shift;

	$self->{gamekey} = $gameKey;
	$self->{authkey} = $authKey;
	$self->{pieceIdCount} = 1;

	$self->{board} = {};

	my $client = AnyEvent::WebSocket::Client->new;

	$client->connect("ws://localhost:3000/ws")->cb(sub {
		print "begin connection callback...\n";
		# make $connection an our variable rather than
		# my so that it will stick around.  Once the
		# connection falls out of scope any callbacks
		# tied to it will be destroyed.
		my $hs = shift;
		our $connection = eval { $hs->recv };
		$self->{conn} = $connection;
		if($@) {
		 # handle error...
		 warn $@;
		 return;
		}
		   
		my $msg = {
		   'c' => 'authjoin',
		};
		print "sending authjoin\n";
		$self->send($msg);

		$self->setupInitialBoard();

		# recieve message from the websocket...
		$connection->on(each_message => sub {
			# $connection is the same connection object
			# $message isa AnyEvent::WebSocket::Message
			my($connection, $message) = @_;
			my $msg = $message->body;
			print "message: $msg\n";
			my $msgJSON = decode_json($msg);
			print "desoded: $msgJSON\n";
			$self->handleMessage($msgJSON, $connection);
		});

		# handle a closed connection...
		$connection->on(finish => sub {
			# $connection is the same connection object
			my($connection) = @_;
			print "finish\n";
			AnyEvent->condvar->send;
			exit;
		});

		# close the connection (either inside or
		# outside another callback)
		# $connection->close;

	});

	$self->{client} = $client;
	my $w = AnyEvent->timer(
		after => 1,
		interval => 1.2,
		cb => sub {
			return;
			print "timer: " . time . "\n";
            my $msg = {
                'c' => 'serverping',
            };
			$self->{conn}->send($msg);
		}
	);
	AnyEvent->condvar->recv;
	print "GAME ENDING\n";
}

sub setupInitialBoard {
	my $self = shift;
	my $id = $self->{pieceIdCount}++;
	# pawns
	foreach my $x (0..7){
		$id++;
		$self->{board}->{$id} = new ChessPiece(
			 $x,
			 1,
			 'black',
			 'pawn',
			 $id,
			 $self
		);
		$id++;
		$self->{board}->{$id} = new ChessPiece(
			 $x,
			 6,
			 'white',
			 'pawn',
			 $id,
			 $self
		);
	}
	$id++;
	$self->{board}->{$id++} = new ChessPiece(
			 0,
			 0,
			 'black',
			 'rook',
			 $id,
			 $self
	);
	$self->{board}->{$id++} = new ChessPiece(
			 1,
			 0,
			 'black',
			 'knight',
			 $id,
			 $self
	);
	$self->{board}->{$id++} = new ChessPiece(
			 2,
			 0,
			 'black',
			 'bishop',
			 $id,
			 $self
	);
	$self->{board}->{$id++} = new ChessPiece(
			 3,
			 0,
			 'black',
			 'queen',
			 $id,
			 $self
	);
	$self->{board}->{$id++} = new ChessPiece(
			 4,
			 0,
			 'black',
			 'king',
			 $id,
			 $self
	);
	$self->{board}->{$id++} = new ChessPiece(
			 5,
			 0,
			 'black',
			 'bishop',
			 $id,
			 $self
	);
	$self->{board}->{$id++} = new ChessPiece(
			 6,
			 0,
			 'black',
			 'knight',
			 $id,
			 $self
	);
	$self->{board}->{$id++} = new ChessPiece(
			 7,
			 0,
			 'black',
			 'rook',
			 $id,
			 $self
	);
	########### WHITE
	#
	$self->{board}->{$id++} = new ChessPiece(
			 0,
			 7,
			 'white',
			 'rook',
			 $id,
			 $self
	);
	$self->{board}->{$id++} = new ChessPiece(
			 1,
			 7,
			 'white',
			 'knight',
			 $id,
			 $self
	);
	$self->{board}->{$id++} = new ChessPiece(
			 2,
			 7,
			 'white',
			 'bishop',
			 $id,
			 $self
	);
	$self->{board}->{$id++} = new ChessPiece(
			 3,
			 7,
			 'white',
			 'queen',
			 $id,
			 $self
	);
	$self->{board}->{$id++} = new ChessPiece(
			 4,
			 7,
			 'white',
			 'king',
			 $id,
			 $self
	);
	$self->{board}->{$id++} = new ChessPiece(
			 5,
			 7,
			 'white',
			 'bishop',
			 $id,
			 $self
	);
	$self->{board}->{$id++} = new ChessPiece(
			 6,
			 7,
			 'white',
			 'knight',
			 $id,
			 $self
	);
	$self->{board}->{$id++} = new ChessPiece(
			 7,
			 7,
			 'white',
			 'rook',
			 $id,
			 $self
	);
	$self->{pieceIdCount} = $id++;
}

sub handleMessage {
	my $self = shift;
	my ($msg, $conn) = @_;

	print "msg: $msg->{c}\n";

	if ($msg->{c} eq 'join'){
		$self->sendAllGamePieces();
	} elsif ($msg->{c} eq 'playerjoin'){
		$self->sendAllGamePieces();
	} elsif ($msg->{c} eq 'move'){
		print "moving piece $msg->{id}\n";
		my $piece = $self->getPiece($msg->{id});
		return if ($msg->{color} ne $piece->{color});
		if ($self->isLegalMove($piece, $msg->{x}, $msg->{y})){
			# change the category from move to authmove and reflect it back
			$msg->{c} = 'authmove';
			$self->send($msg);
		}
	}
}

sub sendAllGamePieces {
	my $self = shift;
	my $conn = $self->{conn};

	print "sending all game pieces...\n";

	foreach my $id (keys %{ $self->{board} }){
		my $piece = $self->{board}->{$id};
		print "id: $id\n";
		my $msg = {
			'c' => 'spawn',
			'type'  => $piece->{type},
			'id'    => $id,
			'color' => $piece->{color},
			'x'     => $piece->{x},
			'y'     => $piece->{y},
		};

		$self->send($msg);
	}
}

sub checkForKills {
    my $self = shift;
    my $piece = shift;
    my @pieces = $self->getPieces();

    print "checking for kills\n";

    foreach my $p (@pieces){
        if ($p->{color} ne $piece->{color}
             && $piece->{x} == $p->{x}
             && $piece->{y} == $p->{y}){
             if ($p->{isMoving} && $p->{beganMove} < $piece->{beganMove}){
                 print "kill yourself piece\n";
                 $self->killPiece($piece);
             } else {
                 print "kill piece $p->{id}\n";
                 $self->killPiece($p);
             }
         }

    }
}

sub pieceAt {
    my $self = shift;
    my ($x, $y) = @_;
    my @pieces = $self->getPieces();
    foreach my $p (@pieces){
        if ($x == $p->{x} && $y == $p->{y}){
            return $p;
        }
    }
    return undef;
}

sub killPiece {
    my $self = shift;
    my $piece = shift;

    if ($piece->{type} eq 'king'){
        my $msg = {
            'c' => 'playerlost',
            'color' => $piece->{color}
        };
        $self->send($msg);
        # game over
        exit;
    } else {
        my $msg = {
            'c' => 'authkill',
            'id' => $piece->{id}
        };
        $self->send($msg);
    }
    delete $self->{board}->{$piece->{id}};
}

sub send {
	my $self = shift;
	my $msg  = shift;

	$msg->{auth} = $self->{authkey};
	$msg->{gameId} = $self->{gamekey};
	return $self->{conn}->send(encode_json $msg);
}

sub isLegalMove {
	my $self = shift;
	my $piece = shift;
	my ($x, $y) = @_;

    if ($piece->{readyToMove} > time()){ return 0; }

	my @pieces = $self->getPieces();
	print "checking piece legal/blocked move $x, $y, $piece->{id}\n";
    if (@pieces){
        print "pieces after ret: $#pieces\n";
        print ref @pieces . "\n";
    }
	my $blocked = $piece->isBlocked($x, $y, \@pieces);

	my $canMove = (
		$piece->isLegalMove($x, $y, \@pieces) &&
		! $piece->isBlocked($x, $y, \@pieces)
	);
	if ($canMove){
		$piece->move($x, $y);
		return 1;
	}
	return 0;
}

sub getPiece {
	my $self = shift;
	my $pieceId = shift;

	return $self->{board}->{$pieceId};
}

sub getPieces {
	my $self = shift;
	my @pieces = values $self->{board};

    print "getPieces:\n";
    print "-- $#pieces\n";

    return @pieces;
	return wantarray ? @pieces : \@pieces;
}
1;
