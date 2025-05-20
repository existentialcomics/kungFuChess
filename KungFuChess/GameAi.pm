#!/usr/bin/perl
use strict; use warnings;

# this is the server that manages the pieces and connect to KungFuWeb.pl

package KungFuChess::GameAi;

#use AnyEvent::WebSocket::Client;
use AnyEvent::WebSocket::Client 0.12;
use AnyEvent;
use JSON::XS;
#use KungFuChess::Bitboards;
use IPC::Open2;
use Config::Simple;
use Time::HiRes qw(time usleep);
use Data::Dumper;
use KungFuChess::BBHash;
use Sys::MemInfo qw(totalmem freemem totalswap);

$| = 1;
my $minMemory = 250000;

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
	my $speed = shift;
    my $pieceSpeed = shift;
    my $pieceRecharge = shift;
	my $speedAdj = shift;
	my $teams = shift;
	my $mode  = shift;
    my $difficulty = shift;
    my $color = shift;
    my $domain = shift;
	my $ai = 1;

    print "game key: $gameKey, authkey: $authKey, speed: $speed, mode: $mode, diff: $difficulty, color: $color, domain: $domain, teams: $teams\n";

    $self->{startTime} = time();

    my $cfg = new Config::Simple('kungFuChess.cnf');
    $self->{config} = $cfg;
    $self->{mode}   = $mode;
    $self->{teams}  = $teams;

    ### correct for a bug elsewhere lol
    if ($color eq 'white') {
        $color = 1;
    } elsif ($color eq 'black') {
        $color = 2;
    } elsif ($color eq 'red') {
        $color = 3;
    } elsif ($color eq 'green') {
        $color = 4;
    }
    $self->{color}  = $color;
    if ($color == 1) {
        $self->{colorHuman} = 'white';
    } elsif ($color == 2) {
        $self->{colorHuman} = 'black';
    } elsif ($color == 3) {
        $self->{colorHuman} = 'red';
    } elsif ($color == 4) {
        $self->{colorHuman} = 'green';
    }
    if ($self->{mode} eq '4way') {
        $self->{ranks} = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'];
        $self->{files} = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l'];
    } else {
        $self->{ranks} = ['1', '2', '3', '4', '5', '6', '7', '8'];
        $self->{files} = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    }

	$self->{gamekey} = $gameKey;
	$self->{authkey} = $authKey;

    ### currently animating moves
    $self->{activeMoves}    = {};
    ### squares that are on hold before they can move again
    $self->{timeoutSquares} = {};
    $self->{timeoutCBs} = {};

    $self->{lastMoved} = time();

    print "AI: $ai\n";
    $self->{ai} = $ai;
    $self->{resignCount} = 0;

    ### variables:
    # ai_thinkTime     max time calculating moves
    # ai_depth         max depth MUST BE AT LEAST 2.
    # ai_simul_moves   max moves to make at once horizontally
    # ai_simul_depth   max moves to make at once depth wise
    # ai_delay         random delay before move for queued moves only (opening)
    # ai_min_delay     min random delay
    # ai_interval      time to wait before next move
    # ai_randomness    randomness of scores, centipawns

    if ($speed eq 'standard') {
        $self->{pieceSpeed} = 1;
        $self->{pieceRecharge} = 10;
        if ($difficulty eq '1' || $difficulty eq 'ai-easy') {
            $self->{ai_thinkTime} = 1;
            $self->{ai_depth} = 1;
            $self->{ai_simul_moves} = 1;
            $self->{ai_simul_depth} = 1;
            $self->{ai_delay} = 1_000_000; 
            $self->{ai_min_delay} = 1_000_000;
            $self->{ai_interval} = 2_500_000;
            $self->{randomness} = 300;
            $self->{no_move_penalty} = 0.1; # multiplier
            $self->{long_capture_penalty} = 0; # centipawns
            $self->{distance_penalty} = 0; # centipawns
        } elsif ($difficulty eq '2' || $difficulty eq 'ai-medium') {
            $self->{ai_thinkTime} = 1;
            $self->{ai_depth} = 2;
            $self->{ai_simul_moves} = 1;
            $self->{ai_simul_depth} = 1;
            $self->{ai_delay} = 1800_000; 
            $self->{ai_min_delay} = 250_000;
            $self->{ai_interval} = 1_500_000;
            $self->{randomness} = 250;
            $self->{no_move_penalty} = 0.1; # multiplier
            $self->{long_capture_penalty} = 100; # centipawns
            $self->{distance_penalty} = 10; # centipawns
        } elsif ($difficulty eq '3' || $difficulty eq 'ai-hard') {
            #$self->{ai_thinkTime} = 2.0;
            #$self->{ai_depth} = 4;
            #$self->{ai_simul_moves} = 1;
            #$self->{ai_simul_depth} = 2;
            #$self->{ai_delay} = 50_000; 
            #$self->{ai_min_delay} = 50_000;
            #$self->{ai_interval} = 600_000;
            #$self->{randomness} = 30;
            #$self->{no_move_penalty} = 0.1; # multiplier
            #$self->{long_capture_penalty} = 200; # centipawns
            #$self->{distance_penalty} = 15; # centipawns

            $self->{ai_thinkTime} = 2.0;
            $self->{ai_depth} = 4;
            $self->{ai_simul_moves} = 1;
            $self->{ai_simul_depth} = 2;
            $self->{ai_delay} = 1_500_000; 
            $self->{ai_min_delay} = 150_000;
            $self->{ai_interval} = 500_000;
            $self->{randomness} = 20;
            $self->{no_move_penalty} = 0.1; # multiplier
            $self->{long_capture_penalty} = 200; # centipawns
            $self->{distance_penalty} = 15; # centipawns
        } elsif (
            $difficulty eq '4' || $difficulty eq 'ai-berserk'
            || $difficulty eq '5' || $difficulty eq 'ai-crane'
            || $difficulty eq '6' || $difficulty eq 'ai-turtle'
            || $difficulty eq '7' || $difficulty eq 'ai-centipede'
            || $difficulty eq '8' || $difficulty eq 'ai-dragon'
            || $difficulty eq '9' || $difficulty eq 'ai-master'
        ) {
            $self->{ai_thinkTime} = 2.0;
            $self->{ai_depth} = 4;
            $self->{ai_simul_moves} = 1;
            $self->{ai_simul_depth} = 2;
            $self->{ai_delay} = 50_000; 
            $self->{ai_min_delay} = 50_000;
            $self->{ai_interval} = 400_000;
            $self->{randomness} = 30;
            $self->{no_move_penalty} = 0.2; # multiplier
            $self->{long_capture_penalty} = 150; # centipawns
            $self->{distance_penalty} = 12; # centipawns
        } elsif ($difficulty eq 'human_a') {
            $self->{ai_thinkTime} = 2.0;
            $self->{ai_depth} = 4;
            $self->{ai_simul_moves} = 1;
            $self->{ai_simul_depth} = 2;
            $self->{ai_delay} = 400_000; 
            $self->{ai_min_delay} = 150_000;
            $self->{ai_interval} = 300_000;
            $self->{randomness} = 150;
            $self->{ai_human} = 1;
            $self->{no_move_penalty} = 0.2; # multiplier
            $self->{long_capture_penalty} = 200; # centipawns
            $self->{distance_penalty} = 15; # centipawns
        } elsif ($difficulty eq 'human_b') {
            $self->{ai_thinkTime} = 2.0;
            $self->{ai_depth} = 4;
            $self->{ai_simul_moves} = 1;
            $self->{ai_simul_depth} = 2;
            $self->{ai_delay} = 1_500_000; 
            $self->{ai_min_delay} = 450_000;
            $self->{ai_interval} = 500_000;
            $self->{randomness} = 40;
            $self->{ai_human} = 1;
            $self->{no_move_penalty} = 0.2; # multiplier
            $self->{long_capture_penalty} = 200; # centipawns
            $self->{distance_penalty} = 15; # centipawns
        } elsif ($difficulty eq 'human_c') {
            $self->{ai_thinkTime} = 2.0;
            $self->{ai_depth} = 2;
            $self->{ai_simul_moves} = 1;
            $self->{ai_simul_depth} = 2;
            $self->{ai_delay} = 500_000; 
            $self->{ai_min_delay} = 250_000;
            $self->{ai_interval} = 400_000;
            $self->{randomness} = 350;
            $self->{ai_human} = 1;
            $self->{no_move_penalty} = 0.2; # multiplier
            $self->{long_capture_penalty} = 20; # centipawns
            $self->{distance_penalty} = 5; # centipawns
        } else {
            $self->{ai_thinkTime} = 2.0;
            $self->{ai_depth} = 2;
            $self->{ai_simul_moves} = 1;
            $self->{ai_simul_depth} = 2;
            $self->{ai_delay} = 300_000; 
            $self->{ai_min_delay} = 0;
            $self->{ai_interval} = 500_000;
            $self->{randomness} = 0.0;
            $self->{no_move_penalty} = 0.2; # multiplier
            $self->{long_capture_penalty} = 20; # centipawns
            $self->{distance_penalty} = 5; # centipawns
        }
    } elsif ($speed eq 'lightning') {
        $self->{pieceSpeed} = 0.1;
        $self->{pieceRecharge} = 1;
        if ($difficulty eq '1' || $difficulty eq 'ai-easy') {
            $self->{ai_thinkTime} = 1.0;
            $self->{ai_depth} = 2;
            $self->{ai_simul_moves} = 1;
            $self->{ai_simul_depth} = 2;
            $self->{ai_delay} = 1_000_000; 
            $self->{ai_min_delay} = 500_000;
            $self->{ai_interval} = 2_000_000;
            $self->{randomness} = 300;
            $self->{no_move_penalty} = 0.1; # multiplier
            $self->{long_capture_penalty} = 0; # centipawns
            $self->{distance_penalty} = 0; # centipawns
        } elsif ($difficulty eq '2' || $difficulty eq 'ai-medium') {
            $self->{ai_thinkTime} = 1.0;
            $self->{ai_depth} = 2;
            $self->{ai_simul_moves} = 1;
            $self->{ai_simul_depth} = 1;
            $self->{ai_delay} = 1_000_000; 
            $self->{ai_min_delay} = 500_000;
            $self->{ai_interval} = 750_000;
            $self->{randomness} = 200;
            $self->{no_move_penalty} = 0.3; # multiplier
            $self->{long_capture_penalty} = 0; # centipawns
            $self->{distance_penalty} = 0; # centipawns
        } elsif ($difficulty eq '3' || $difficulty eq 'ai-hard') {
            $self->{ai_thinkTime} = 1.0;
            $self->{ai_depth} = 2;
            $self->{ai_simul_moves} = 2;
            $self->{ai_simul_depth} = 2;
            $self->{ai_delay} = 200_000; 
            $self->{ai_min_delay} = 150_000;
            $self->{ai_interval} = 250_000;
            $self->{randomness} = 100;
            $self->{no_move_penalty} = 0.5; # multiplier
            $self->{long_capture_penalty} = 0; # centipawns
            $self->{distance_penalty} = 5; # centipawns
        } elsif ($difficulty eq '4' || $difficulty eq 'ai-berserk') {
            $self->{ai_thinkTime} = 1.0;
            $self->{ai_depth} = 2;
            $self->{ai_simul_moves} = 2;
            $self->{ai_simul_depth} = 2;
            $self->{ai_delay} = 100_000; 
            $self->{ai_min_delay} = 70_000;
            $self->{ai_interval} = 200_000;
            $self->{randomness} = 500;
            $self->{no_move_penalty} = 0.9; # multiplier
            $self->{long_capture_penalty} = 0; # centipawns
            $self->{distance_penalty} = 0; # centipawns
        } elsif ($difficulty eq '6' || $difficulty eq 'ai-turtle') {
            $self->{ai_thinkTime} = 1.0;
            $self->{ai_depth} = 2;
            $self->{ai_simul_moves} = 2;
            $self->{ai_simul_depth} = 2;
            $self->{ai_delay} = 100_000; 
            $self->{ai_min_delay} = 50_000;
            $self->{ai_interval} = 350_000;
            $self->{randomness} = 500;
            $self->{no_move_penalty} = 0.9; # multiplier
            $self->{long_capture_penalty} = 10; # centipawns
            $self->{distance_penalty} = 0; # centipawns
        } elsif ($difficulty eq '7' || $difficulty eq 'ai-centipede') {
            $self->{ai_thinkTime} = 1.0;
            $self->{ai_depth} = 2;
            $self->{ai_simul_moves} = 2;
            $self->{ai_simul_depth} = 2;
            $self->{ai_delay} = 100_000; 
            $self->{ai_min_delay} = 70_000;
            $self->{ai_interval} = 300_000;
            $self->{randomness} = 500;
            $self->{no_move_penalty} = 0.9; # multiplier
            $self->{long_capture_penalty} = 0; # centipawns
            $self->{distance_penalty} = 0; # centipawns
        } elsif ($difficulty eq '5' || $difficulty eq 'ai-crane') {
            $self->{ai_thinkTime} = 1.0;
            $self->{ai_depth} = 2;
            $self->{ai_simul_moves} = 2;
            $self->{ai_simul_depth} = 2;
            $self->{ai_delay} = 100_000; 
            $self->{ai_min_delay} = 75_000;
            $self->{ai_interval} = 350_000;
            $self->{randomness} = 600;
            $self->{no_move_penalty} = 0.9; # multiplier
            $self->{long_capture_penalty} = 0; # centipawns
            $self->{distance_penalty} = 0; # centipawns
        } elsif ($difficulty eq '8' || $difficulty eq 'ai-dragon') {
            $self->{ai_thinkTime} = 1.0;
            $self->{ai_depth} = 2;
            $self->{ai_simul_moves} = 2;
            $self->{ai_simul_depth} = 2;
            $self->{ai_delay} = 100_000; 
            $self->{ai_min_delay} = 70_000;
            $self->{ai_interval} = 200_000;
            $self->{randomness} = 200;
            $self->{no_move_penalty} = 0.9; # multiplier
            $self->{long_capture_penalty} = 0; # centipawns
            $self->{distance_penalty} = 0; # centipawns
        } elsif ($difficulty eq '9' || $difficulty eq 'ai-master') {
            $self->{ai_thinkTime} = 1.0;
            $self->{ai_depth} = 1;
            $self->{ai_simul_moves} = 1;
            $self->{ai_simul_depth} = 1;
            $self->{ai_delay} = 0; 
            $self->{ai_min_delay} = 0;
            $self->{ai_interval} = 10_000;
            $self->{randomness} = 50;
            $self->{no_move_penalty} = 1.9; # multiplier
            $self->{long_capture_penalty} = 0; # centipawns
            $self->{distance_penalty} = 0; # centipawns
        } elsif ($difficulty eq 'human_a') {
            $self->{ai_thinkTime} = 1.0;
            $self->{ai_depth} = 2;
            $self->{ai_simul_moves} = 1;
            $self->{ai_simul_depth} = 2;
            $self->{ai_delay} = 1_000_000; 
            $self->{ai_min_delay} = 300_000;
            $self->{ai_interval} = 500_000;
            $self->{randomness} = 200;
            $self->{ai_human} = 1;
            $self->{no_move_penalty} = 0.5; # multiplier
            $self->{long_capture_penalty} = 0; # centipawns
            $self->{distance_penalty} = 5; # centipawns
        } elsif ($difficulty eq 'human_b') {
            $self->{ai_thinkTime} = 1.0;
            $self->{ai_depth} = 2;
            $self->{ai_simul_moves} = 1;
            $self->{ai_simul_depth} = 2;
            $self->{ai_delay} = 1_000_000; 
            $self->{ai_min_delay} = 1_000_000;
            $self->{ai_interval} = 1_500_000;
            $self->{randomness} = 400;
            $self->{ai_human} = 1;
            $self->{no_move_penalty} = 0.5; # multiplier
            $self->{long_capture_penalty} = 0; # centipawns
            $self->{distance_penalty} = 5; # centipawns
        } elsif ($difficulty eq 'human_c') {
            $self->{ai_thinkTime} = 1.0;
            $self->{ai_depth} = 2;
            $self->{ai_simul_moves} = 1;
            $self->{ai_simul_depth} = 2;
            $self->{ai_delay} = 1_000_000; 
            $self->{ai_min_delay} = 300_000;
            $self->{ai_interval} = 500_000;
            $self->{ai_human} = 1;
            $self->{randomness} = 600;
            $self->{no_move_penalty} = 0.5; # multiplier
            $self->{long_capture_penalty} = 0; # centipawns
            $self->{distance_penalty} = 5; # centipawns
        } else {
            $self->{ai_thinkTime} = 1.0;
            $self->{ai_depth} = 2;
            $self->{ai_simul_moves} = 2;
            $self->{ai_simul_depth} = 2;
            $self->{ai_delay} = 1_000_000; 
            $self->{ai_min_delay} = 500_000;
            $self->{ai_interval} = 1_000_000;
            $self->{randomness} = 0.0;
            $self->{no_move_penalty} = 0.2;
        }
    } else {
        warn "unknown game speed $speed\n";
    }
    if (
        $difficulty eq '5' || $difficulty eq 'ai-crane'
        || $difficulty eq '6' || $difficulty eq 'ai-turtle'
        || $difficulty eq '7' || $difficulty eq 'ai-centipede'
        || $difficulty eq '8' || $difficulty eq 'ai-dragon'
        || $difficulty eq '9' || $difficulty eq 'ai-master'
    ) {
        $self->{skipOpenings} = 1;
    }
    $self->setAdjustedSpeed($self->{pieceSpeed}, $self->{pieceRecharge}, $speedAdj);
    print "Difficulty: $difficulty\n";
    print "AI human: " . ($self->{ai_human} ? 'true' : 'false') . "\n";

    ### reduce CPU load of 4way AI, skipp openings
    if ($self->{mode} eq '4way') {
        $self->{ai_depth} = $self->{ai_depth} < 3 ? $self->{ai_depth} : 2;
        $self->{ai_delay} *= 2; 
        $self->{ai_min_delay} *= 2;
        $self->{ai_interval} *= 2;
        $self->{skipOpenings} = 1;
    }


	$self->{board} = {};
    $self->{boardMap} = [
        [ undef, undef, undef, undef, undef, undef, undef, undef ],
        [ undef, undef, undef, undef, undef, undef, undef, undef ],
        [ undef, undef, undef, undef, undef, undef, undef, undef ],
        [ undef, undef, undef, undef, undef, undef, undef, undef ],
        [ undef, undef, undef, undef, undef, undef, undef, undef ],
        [ undef, undef, undef, undef, undef, undef, undef, undef ],
        [ undef, undef, undef, undef, undef, undef, undef, undef ],
        [ undef, undef, undef, undef, undef, undef, undef, undef ],
        [ undef, undef, undef, undef, undef, undef, undef, undef ]
    ];

	my $client = AnyEvent::WebSocket::Client->new(
        ssl_no_verify => 1,
    );

    my $wsDomain = $domain // 'ws://localhost:3001/ws';
    print "$wsDomain\n";

    $client->connect($wsDomain)->cb(sub {
		# make $connection an our variable rather than
		# my so that it will stick around.  Once the
		# connection falls out of scope any callbacks
		# tied to it will be destroyed.
		my $hs = shift;
		our $connection = eval { $hs->recv };
		$self->{conn} = $connection;
		if($@) {
		 # handle error...
         print "ERROR:\n";
		 warn $@;
         exit;
		}
        print "connected\n";
		
        sleep(1);
        # TODO do a proper "repeat until confirmed" like the js does here
		my $msg = {
		   'c' => 'join',
		};
		$self->send($msg);
        if ($self->{mode} eq '4way') {
            $self->setupInitialBoard();
        }

        sleep(1);
		$msg = {
		   'c' => 'readyToBegin',
		};
        print "sending readyToBegin\n";
		$self->send($msg);

		#$connection->on(error => sub {
                #print "ERROR: $!\n";
        #});

		# recieve message from the websocket...
		$connection->on(each_message => sub {
			# $connection is the same connection object
			# $message isa AnyEvent::WebSocket::Message
			my($connection, $message) = @_;
			my $msg = $message->body;
			my $msgJSON = decode_json($msg);
            if ($msgJSON->{c}) {

            }
			$self->handleMessage($msgJSON, $connection);
		});

		# handle a closed connection...
		$connection->on(finish => sub {
			# $connection is the same connection object
			my($connection) = @_;
			AnyEvent->condvar->send;
			exit;
		});

		# close the connection (either inside or
		# outside another callback)
		# $connection->close;

	});

	$self->{client} = $client;
    $self->{movesQueue} = [];
    $self->{inducedMoves} = [];

    $self->{aiPing} = AnyEvent->timer(
        after => 1,
        interval => 2.5,
        cb => sub {
            if (! defined($self->{gameStartTime}) &&
                time() - $self->{startTime} > 60
            ) {
                my $standMsg = {
                    'c' => 'stand',
                };
                $self->send($standMsg);
                my $abortMsg = {
                    'c' => 'abort',
                };
                $self->send($abortMsg);
                exit;
            }
            my $msg = {
                'c' => 'ping',
                'timestamp' => time(),
                'ping' => int(rand(100) + 50) # don't care about really figuring out our true ping
            };
            $self->send($msg);

            if ($self->{ai_human}) {
                my $msgMain = {
                    'c' => 'main_ping',
                    'userAuthToken' => $self->{authkey},
                };
                $self->send($msgMain);
            }
        }
    );

    print "GAME BEGIN condvar\n";
	AnyEvent->condvar->recv;
	print "GAME ENDING\n";
}

sub setupInitialBoard {
	my $self = shift;
    KungFuChess::Bitboards::setupInitialPosition();
}

sub setFrozen {
    my $self = shift;
    my $to_bb = shift;

    my $time = time();
    $self->{timeoutSquares}->{$to_bb}->{'time'} = $time;
    KungFuChess::Bitboards::addFrozen($to_bb);
    my $unsetTime = $self->{pieceRecharge} * 0.85; ### TODO variable 
    $self->{timeoutCBs}->{$to_bb} = AnyEvent->timer(
        after => $unsetTime,
        cb => sub {
            ### if the time doesn't match, another piece has moved here
            if ($time == $self->{timeoutSquares}->{$to_bb}->{'time'}) {
                KungFuChess::Bitboards::unsetFrozen($to_bb);
                delete $self->{timeoutSquares}->{$to_bb};
                delete $self->{timeoutCBs}->{$to_bb};
            } else {
                print "time doesn't match\n";
            }
        }
    );
}

sub handleMessage {
	my $self = shift;
	my ($msg, $conn) = @_;

    if ($msg->{fr_bb}) {
        KungFuChess::Bitboards::strToInt($msg->{fr_bb});
    }
    if ($msg->{to_bb}) {
        KungFuChess::Bitboards::strToInt($msg->{to_bb});
    }
    if ($msg->{bb}) {
        KungFuChess::Bitboards::strToInt($msg->{bb});
    }

	if ($msg->{c} eq 'moveAnimate'){
        my $moveType = $msg->{moveType} + 0;
        my $dir      = $msg->{dir} + 0;
        my $fr_bb    = $msg->{fr_bb} + 0;
        my $to_bb    = $msg->{to_bb} + 0;
        #### blackout the entire line, we don't want to risk crossing it
        if ($moveType == KungFuChess::Bitboards::MOVE_NORMAL) {
            my $bb = $fr_bb;
            my $count = 1;
            while ($bb && $bb != $to_bb) {
                $bb = KungFuChess::Bitboards::shift_BB($bb, $dir);
                KungFuChess::Bitboards::setMoving($bb);
                my $bb2 = $bb;
                $self->{"aiInterval_unmove_{$bb}_{$count}"} = AnyEvent->timer(
                    after => ($self->{pieceSpeed} * ($count + 3)), 
                    cb => sub {
                        my $_bb = $bb2;
                        KungFuChess::Bitboards::unsetMoving($_bb);
                    }
                );
                $count++;
            }
        } elsif ($moveType == KungFuChess::Bitboards::MOVE_KNIGHT) {
            KungFuChess::Bitboards::setMoving($to_bb);
            $self->{"aiInterval_unmove_$to_bb"} = AnyEvent->timer(
                after => ($self->{pieceSpeed} * 3) + 1, 
                cb => sub {
                    KungFuChess::Bitboards::unsetMoving($to_bb);
                }
            );
        }
        ### dodge that shit
        if ($msg->{color} != $self->{color}) {
            push @{$self->{inducedMoves}}, [$msg->{fr_bb}+0, $msg->{to_bb}+0];
        }
    } elsif ($msg->{c} eq 'move'){
        KungFuChess::Bitboards::move($msg->{fr_bb}+0, $msg->{to_bb}+0);
        KungFuChess::Bitboards::resetAiBoards($self->{color});
        $self->setFrozen($msg->{to_bb});
	} elsif ($msg->{c} eq 'teamsChange'){
        $self->{teams} = $msg->{'teamsReal'};
	} elsif ($msg->{c} eq 'stop'){
        KungFuChess::Bitboards::unsetMoving($msg->{fr_bb});
        delete $self->{frozen}->{$msg->{fr_bb}};
	} elsif ($msg->{c} eq 'gamechat'){
        if ($msg->{authColor} && $msg->{authColor} ne $self->{colorHuman}) {
            if ($msg->{message} =~ m/\b(hello|hi|hey)\b/i) {
                if (! defined($self->{helloSaid})) {
                    sleep 1;
                    my $msg = {
                        'c'     => 'chat',
                        'message' => $1,
                    };
                    $self->send($msg);
                    $self->{helloSaid} = 1;
                }
            } elsif ($msg->{message} =~ m/\b(gg|good game)\b/i) {
                if (! defined($self->{ggSaid})) {
                    sleep 1;
                    my $msg = {
                        'c'     => 'chat',
                        'message' => 'gg',
                    };
                    $self->send($msg);
                    $self->{ggSaid} = 1;
                }
            }
        }
	} elsif ($msg->{c} eq 'aiOnly'){
        sleep(rand() * 6);
        my $msg = {
            'c'     => 'resign'
        };
        $self->send($msg);
        $self->endGame();
	} elsif ($msg->{c} eq 'spawn'){
        KungFuChess::Bitboards::_putPiece(
            $msg->{chr} + 0,
            KungFuChess::Bitboards::getBBfromSquare($msg->{square}),
        );
        KungFuChess::Bitboards::resetAiBoards($self->{color});
	} elsif ($msg->{c} eq 'requestDraw'){
        #print "drawing...\n";
        #my $msg = {
            #'c'     => 'requestDraw'
        #};
        #$self->send($msg);
	} elsif ($msg->{c} eq 'suspend'){
        $self->{suspendedPieces}->{$msg->{to_bb}} =
            KungFuChess::Bitboards::_getPieceBB($msg->{fr_bb});

        KungFuChess::Bitboards::_removePiece($msg->{fr_bb});
        delete $self->{frozen}->{$msg->{fr_bb}};
    } elsif ($msg->{c} eq 'unsuspend'){
        KungFuChess::Bitboards::_putPiece(
            $self->{suspendedPieces}->{$msg->{to_bb}},
            $msg->{to_bb}
        );
        $self->setFrozen($msg->{to_bb});
        delete $self->{suspendedPieces}->{$msg->{to_bb}};
        KungFuChess::Bitboards::resetAiBoards($self->{color});
    } elsif ($msg->{c} eq 'promote'){
        my $p = KungFuChess::Bitboards::_getPieceBB($msg->{bb});
        if ($p == 101) {
            $p = 106;
        } elsif( $p == 201) {
            $p = 206;
        } elsif( $p == 301) {
            $p = 306;
        } elsif( $p == 301) {
            $p = 306;
        } elsif( $p == 401) {
            $p = 406;
        } else {
            print KungFuChess::Bitboards::pretty_ai();
            print "promote none pawn? *$p*\n";
        }

        KungFuChess::Bitboards::_removePiece($msg->{bb} + 0);
        KungFuChess::Bitboards::_putPiece(
            $p + 0,
            $msg->{bb} + 0
        );
        KungFuChess::Bitboards::resetAiBoards($self->{color});
    } elsif ($msg->{c} eq 'kill'){
        delete $self->{frozen}->{$msg->{bb}};
        KungFuChess::Bitboards::_removePiece($msg->{bb});
        KungFuChess::Bitboards::resetAiBoards($self->{color});
	} elsif ($msg->{c} eq 'rematch'){
        if ($self->{gameEnded}) {
            my $dataPost = {
                'uid' => $self->{anonKey},
                'gameId' => $self->{gameId},
                'c' => 'rematch',
            };
            $self->send($dataPost);
            sleep 1;
            exit;
        }
	} elsif ($msg->{c} eq 'gameOver' || $msg->{c} eq 'abort'){
        $self->endGame();
	} elsif ($msg->{c} eq 'gameBegins'){
        $self->{gameStartTime} = time();
        # to prevent autodraw from coming up right away
        my $startTime = time() + $msg->{seconds};
        #$self->{aiStates}->{uciok} = 0;
        $self->{teams} = $msg->{teams};

        #usleep(($startTime + 0.1) * 1000);
        my @moves = ();
        my $rand = rand();

        if ($self->{color} == 1) {
            if ($rand < 0.3) {
                @moves = qw(d2d4 e2e4 c2c3 f2f3 c1e3 f1d3 g1e2 b1d2);
            } elsif ($rand < 0.6) {
                @moves = qw(f2f4 e2e4 d2d3 e2e3 b2b3 g2g3 f1g2 c1b2);
            } else {
                @moves = qw(c2c4 e2e3 f1e2 g1f3 e1g1 b2b3 c1b2 b1c3 h2h3);
            }
        } else {
            if ($rand < 0.3) {
                @moves = qw(c7c5 f7f5 b7b6 g7g6 f8g7 g8f6 e8g8);
            } elsif ($rand < 0.6) {
                @moves = qw(c7c5 e7e5 b7b6 f7f5 g7g6 f8g7 g8f6 e8g8);
            } else {
                @moves = qw(d7d5 g7g5 h7h6 e7e6 b7b6 c8b7 d8d7 e8c8);
            }
        }

        if (! $self->{skipOpenings}) {
            $self->{movesQueue} = \@moves;
        }

        my $w2; 

        my $aiIntervalDecimal = 0.5;
        if (exists($self->{ai_interval})) {
            $aiIntervalDecimal = ($self->{ai_interval} / 1_000_000);
        }
        print "aiIntervalDecical: $aiIntervalDecimal\n";
        # Start a timer that, at most once every 0.5 seconds, sleeps
        # for 1 second, and then prints "timer":
        my $w1; $w1 = deferred_interval(
            after => 3.1,
            reference => \$w2,  
            interval => $aiIntervalDecimal,
            cb => sub {
                $self->aiTick();
                #sleep 1; # Simulated blocking operation.
                #say "timer";
            },
        );
        #$self->{aiInterval} = AnyEvent->timer(
            #after => 3.2,
            #cb => sub {
                #$self->aiTick();
            #}
        #);
	}
}

sub deferred_interval {
    my %args = @_;
    # Some silly wrangling to emulate AnyEvent's normal
    # "watchers are uninstalled when they are destroyed" behavior:
    ${$args{reference}} = 1;
    $args{oldref} //= delete($args{reference});
    return unless ${$args{oldref}};

    AnyEvent::postpone {
        ${$args{oldref}} = AnyEvent->timer(
            after => delete($args{after}) // $args{interval},
            cb => sub {
                $args{cb}->(@_);
                deferred_interval(%args);
            }
        );
    };

    return ${$args{oldref}};
}

sub aiTick {
    my $self = shift;
    my $aiStartTime = time();
    my $debug = 0;

    #if (Sys::MemInfo::get("freeswap") < $minMemory) { exit; }
    if (1) {
        print "\naiTick() " . time() . " , elasped: " . (time() - $self->{startTime}) . "\n";
    }
    my $handle = $self->{conn}->{handle};
        $handle->push_read( 'line' => sub {}
    );
    ### an attempt to clear the read q of websockets to prevent log jams
    while (my $q = pop(@{$handle->{_queue}})) {
        &$q();
    }

    ### auto resign after 10 minutes to prevent stale games
    if (time() - $self->{startTime} > (60 * 10)) {
        my $msg = {
            'c'     => 'resign'
        };
        $self->send($msg);
        $self->endGame();
    }

    ### game is over and no rematch in 20 seconds
    if (defined($self->{gameEnded}) && (time() - $self->{gameEnded}) > 20) {
        print "exiting after endgame\n";
        exit;
    }

    ### progressive pentalties against NO_MOVE
    my $sinceLastMove = time() - $self->{lastMoved};
    my $noMovePenalty = $sinceLastMove * ($self->{no_move_penalty} // 0.1);
    if ($debug) {
        print "no move penalty: $noMovePenalty\n";
        print "no move base $self->{no_move_penalty} * $sinceLastMove\n";
    }
    KungFuChess::Bitboards::setNoMovePenalty($noMovePenalty);
    if ($self->{distance_penalty}) {
        KungFuChess::Bitboards::setDistancePenalty($self->{distance_penalty});
    }
    if ($self->{long_capture_penalty}) {
        KungFuChess::Bitboards::setLongCapturePenalty($self->{long_capture_penalty});
    }

    if ($#{$self->{movesQueue}} > -1) {
        foreach my $move (@{$self->{movesQueue}}) {
            my ($fr_bb, $to_bb, $fr_rank, $fr_file, $to_rank, $to_file) = KungFuChess::Bitboards::parseMove($move);
            my $msg = {
                'fr_bb' => "$fr_bb",
                'to_bb' => "$to_bb",
                'c'     => 'move'
            };
            $self->send($msg);
            usleep(rand($self->{ai_delay}) + $self->{ai_min_delay});
        }
        $self->{movesQueue} = [];
    } else {
        ### so we can turn off moves to test anticipate
        if (1) {
            # depth, thinkTime
            my $start = time();
            my $score = 0;
            if ($debug) {
                print "AI THINK $self->{ai_depth}, $self->{ai_thinkTime}, $self->{color}\n";
                print KungFuChess::Bitboards::pretty_ai();
                print KungFuChess::Bitboards::getFENstring();
            }

            # aiScore not used
            # moves only used for debug,
            # totalMaterial TODO for changing to endgame
            # attackedBy used for recommendBB
            my ($aiScore, $moves, $totalMaterial, $attackedBy) = KungFuChess::Bitboards::aiThink(
                $self->{ai_depth},
                $self->{ai_thinkTime},
                $self->{mode} eq '4way' ? 1 : $self->{color},
                $self->{teams},
            );

            if ($debug) {
                #print "current score: " . KungFuChess::Bitboards::getCurrentScore() . "\n";
                KungFuChess::BBHash::displayMoves(
                    $moves,
                    $self->{mode} eq '4way' ? 1 : $self->{color},
                    0,
                    undef,
                    undef,
                    undef
                );
            }

            ### 0 = fr, 1 = to, that's all that's used
            my $suggestedMoves = KungFuChess::Bitboards::aiRecommendMoves(
                $self->{mode} eq '4way' ? 1 : $self->{color}, # 4way is always white
                $self->{ai_simul_moves},
                $self->{ai_depth_moves},
                $self->{randomness}
            );

            my $fr_moves = {};
            my $to_moves = {};

            ### this is for testing, there is no reason to resign lost positions for the real AI
            ### wait at least 2 minutes though
            if (time() - $self->{startTime} > (60 * 2) && $self->{ai_human} ) {
                if (KungFuChess::Bitboards::getCurrentScore() < -2000) {
                    $self->{resignCount} ++;
                    if ($self->{resignCount} > 15) {
                        print "resigning...\n";
                        my $msg = {
                            'c'     => 'resign'
                        };
                        $self->send($msg);
                        $self->endGame();
                    }
                } else {
                    $self->{resignCount} = 0;
                }
                if (KungFuChess::Bitboards::getCurrentScore() > -1000) {
                    $self->{drawCount} ++;
                    if ($self->{drawCount} > 15) {
                        #print "drawing...\n";
                        #my $msg = {
                            #'c'     => 'requestDraw'
                        #};
                        #$self->send($msg);
                        $self->{drawCount} = 0;
                    }
                } else {
                    $self->{drawCount} = 0;
                }
            }

            foreach my $move (@$suggestedMoves) {
                if ($debug) {
                    print "moving...";
                    print KungFuChess::BBHash::getSquareFromBB($move->[0]);
                    print KungFuChess::BBHash::getSquareFromBB($move->[1]);
                    print "\n";
                }

                # no suggested moves, everything is probably frozen
                if (! defined($move->[0])) {
                    last;
                }
                ### skip frozen pieces or it will premove
                if (defined($self->{timeoutSquares}->{$move->[0]})) {
                    last;
                }
                ### don't move if we already moved from or to the same spot!
                if (exists($fr_moves->{$move->[1]})) {
                    #print "fr move!\n";
                    next;
                }
                if (exists($to_moves->{$move->[1]})) {
                    #print "to move!\n";
                    next;
                }

                ### NO_MOVE guard
                if ($move->[0] != $move->[1]) {
                    $fr_moves->{$move->[0]} = 1;
                    $to_moves->{$move->[1]} = 1;

                    $self->{lastMoved} = time();
                    my $msg = {
                        'fr_bb' => $move->[0],
                        'to_bb' => $move->[1],
                        'c'     => 'move'
                    };
                    $self->send($msg);
                    if ($debug) {
                        print Dumper($msg);
                    }
                    usleep(rand($self->{ai_delay}) + $self->{ai_min_delay});
                } else {
                    if ($debug) {
                        print "no move\n";
                    }

                }
            }
        }
        KungFuChess::Bitboards::setPosXS();
        ### dodges or anticipated attacks
        foreach my $induced (@{$self->{inducedMoves}}) {
            ### no longer compatible with perl AI but only a few adjustments, it only used the to_bb
            my $move = KungFuChess::Bitboards::recommendMoveForBB($induced->[0], $induced->[1], $self->{color}, 0x0); ### 0x0 is attackedBy, not used for now
            if ($move) {
                $self->{lastMoved} = time();
                my $msg = {
                    'fr_bb' => $move->[0],
                    'to_bb' => $move->[1],
                    'c'     => 'move'
                };
                $self->send($msg);
            }
        }
        $self->{inducedMoves} = [];
    }
    my $timeSpent = time() - $aiStartTime;
    #my $intervalLeft = $timeSpent - (($self->{ai_interval} // 1_000_000) / 1_000_000);

    #### at least two tenth of a second to recieve messages
    #if ($intervalLeft < 0.2) {
        #$intervalLeft = 0.2;
    #}
    #$intervalLeft = 1;

    if ($self->{debug}) {
        print "time ending " . time() . "\n";
    }
    #$self->{aiInterval} = AnyEvent->timer(
        #after => $intervalLeft, 
        #cb => sub {
            #$self->aiTick();
        #}
    #);
}

sub checkForForceDraw {
    my $self = shift;
    return 0;
}

sub endGame {
    my $self = shift;

    if ($self->{ai_human}) {
        $self->{gameEnded} = time();
        ### we'll hang around a bit in case they want to rematch
        #sleep(rand(5));
        #my $dataPost = {
            #'uid' => $self->{anonKey},
            #'gameId' => $self->{gameId},
            #'c' => 'rematch',
        #};
        #$self->send($dataPost);
        #sleep 1;
    } else {
        exit;
    }
}

sub send {
	my $self = shift;
	my $msg  = shift;

    ### this ensures bitboards are sent as strings
    #   some BB are too big for javascript and will
    #   get rounded off by floating point storage!
    if ($msg->{'bb'})    { $msg->{'bb'} = "$msg->{'bb'}";       }
    if ($msg->{'fr_bb'}) { $msg->{'fr_bb'} = "$msg->{'fr_bb'}"; }
    if ($msg->{'to_bb'}) { $msg->{'to_bb'} = "$msg->{'to_bb'}"; }

	$msg->{auth} = $self->{authkey};
	$msg->{gameId} = $self->{gamekey};
	return $self->{conn}->send(encode_json $msg);
}

sub moveNotation {
    my %rankToY = (
        1 => 7,
        2 => 6,
        3 => 5,
        4 => 4,
        5 => 3,
        6 => 2,
        7 => 1,
        8 => 0
    );
    my %fileToX = (
        'a' => 0,
        'b' => 1,
        'c' => 2,
        'd' => 3,
        'e' => 4,
        'f' => 5,
        'g' => 6,
        'h' => 7
    );

    my $self = shift;
    my $notation = shift;
    #print "ai move: $notation\n";
    if ($notation =~ m/([a-z])([0-9])([a-z])([0-9])/) {
        my ($startFile, $startRank, $endFile, $endRank) = ($1, $2, $3, $4);

        my $startX = $fileToX{$startFile};
        my $startY = $rankToY{$startRank};
        my $endX = $fileToX{$endFile};
        my $endY = $rankToY{$endRank};

        my $piece = $self->getPieceAt($startX, $startY);

        if ($piece) {
            my $filter = $self->filterAiMove($piece, $endX, $endY);
            $self->moveIfLegal('black', $notation);
        }
    }
}


sub killPieceBB {
    my ($self, $bb) = @_;

    ### mark that it is no longer active, stopping any movement
    delete $self->{activeMoves}->{$bb};
    my $piece = KungFuChess::Bitboards::_getPieceBB($bb);
    if ($piece) {
        my $killMsg = {
            'c'  => 'authkill',
            'bb' => $bb
        };
        $self->send($killMsg);
        if ($piece == KungFuChess::Bitboards::BLACK_KING) {
            my $msg = {
                'c' => 'playerlost',
                'color' => 'black'
            };
            $self->send($msg);
            exit; ### game over
        } elsif ($piece == KungFuChess::Bitboards::WHITE_KING) {
            my $msg = {
                'c' => 'playerlost',
                'color' => 'white'
            };
            $self->send($msg);
            exit; ### game over
        }
    }
}

### https://en.wikipedia.org/wiki/Forsyth%E2%80%93Edwards_Notation
sub getFENstring {
    my $self = shift;
    my $fenString;

    my $rowCount = 0;
    my $rowGapCount = 0;
    my $colCount = 0;
    my $colGapCount = 0;

    for ($colCount = 0; $colCount < 8; $colCount++) {
        my $bb = KungFuChess::Bitboards::_getBBat('a', (8 - $colCount));
        for ($rowCount = 0; $rowCount < 8; $rowCount++) {

            my $piece = KungFuChess::Bitboards::_getPieceBB($bb);
            if ($piece) {
                if ($colGapCount > 0){
                    $fenString .= $colGapCount;
                    $colGapCount = 0;
                }
                $fenString .= $piece;
            } else {
                $colGapCount ++;
            }
            $bb = KungFuChess::Bitboards::shift_BB($bb, KungFuChess::Bitboards::EAST);
        }
        if ($colGapCount > 0){
            $fenString .= $colGapCount;
            $colGapCount = 0;
        }
        if ($colCount != 7) {
            $fenString .= '/';
        }
    }
    ### black's turn because ai is black, no castling for now for ai
    $fenString .= ' b - - 0 1';
    return $fenString;
}

sub getPiece {
	my $self = shift;
	my $pieceId = shift;

	return $self->{board}->{$pieceId};
}

sub getPieces {
	my $self = shift;
	my @pieces = values %{$self->{board}};

    return @pieces;
}

sub setAdjustedSpeed {
    my ($self, $pieceSpeed, $pieceRecharge, $speedAdj) = @_;

    my $whiteAdj = 1;
    my $blackAdj = 1;
    my $redAdj = 1;
    my $greenAdj = 1;
    if ($speedAdj) {
        ($whiteAdj, $blackAdj, $redAdj, $greenAdj) = split(':', $speedAdj);
    }

    if ($self->{color} == 1) {
        $self->{pieceSpeed} = $pieceSpeed * $whiteAdj;
        $self->{pieceRecharge} = $pieceRecharge * $whiteAdj;
    } elsif($self->{color} == 2) {
        $self->{pieceSpeed} = $pieceSpeed * $blackAdj;
        $self->{pieceRecharge} = $pieceRecharge * $blackAdj;
    } elsif($self->{color} == 3) {
        $self->{pieceSpeed} = $pieceSpeed * $redAdj;
        $self->{pieceRecharge} = $pieceRecharge * $redAdj;
    } elsif($self->{color} == 4) {
        $self->{pieceSpeed} = $pieceSpeed * $greenAdj;
        $self->{pieceRecharge} = $pieceRecharge * $greenAdj;
    }
}

1;
