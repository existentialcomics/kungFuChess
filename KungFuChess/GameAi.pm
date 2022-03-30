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

### taken from Chess::Rep
### can't use the whole lib because of chess specific rules like check
use constant ({
    CASTLE_W_OO  => 1,
    CASTLE_W_OOO => 2,
    CASTLE_B_OO  => 4,
    CASTLE_B_OOO => 8,
    PIECE_TO_ID => {
        p => 0x01,              # black pawn
        n => 0x02,              # black knight
        k => 0x04,              # black king
        b => 0x08,              # black bishop
        r => 0x10,              # black rook
        q => 0x20,              # black queen
        P => 0x81,              # white pawn
        N => 0x82,              # white knight
        K => 0x84,              # white king
        B => 0x88,              # white bishop
        R => 0x90,              # white rook
        Q => 0xA0,              # white queen
    },
    ID_TO_PIECE => [
        undef,                  # 0
        'p',                    # 1
        'n',                    # 2
        undef,                  # 3
        'k',                    # 4
        undef,                  # 5
        undef,                  # 6
        undef,                  # 7
        'b',                    # 8
        undef,                  # 9
        undef,                  # 10
        undef,                  # 11
        undef,                  # 12
        undef,                  # 13
        undef,                  # 14
        undef,                  # 15
        'r',                    # 16
        undef,                  # 17
        undef,                  # 18
        undef,                  # 19
        undef,                  # 20
        undef,                  # 21
        undef,                  # 22
        undef,                  # 23
        undef,                  # 24
        undef,                  # 25
        undef,                  # 26
        undef,                  # 27
        undef,                  # 28
        undef,                  # 29
        undef,                  # 30
        undef,                  # 31
        'q',                    # 32
    ],
    FEN_STANDARD => 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
});

my @MOVES_N = (31, 33, 14, 18, -18, -14, -33, -31);
my @MOVES_B = (15, 17, -15, -17);
my @MOVES_R = (1, 16, -16, -1);
my @MOVES_K = (@MOVES_B, @MOVES_R);

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

# http://wbec-ridderkerk.nl/html/UCIProtocol.html
sub getStockfishMsgs {
    my $self = shift;

    print "--- begin reading...\n";
    my $cout = $self->{ai_out};
    my $timeout = 0;
    while(my $line = <$cout>) {
        print "$line";
        chomp($line);
        if ($line eq 'uciok') {
            $self->{aiStates}->{uciok} = 1;
            $self->writeStockfishMsg('setoption name MultiPV value 5');
            $self->writeStockfishMsg('setoption name Debug Log File value /var/log/stockfish/debug.log');
            $self->writeStockfishMsg('ucinewgame');
            #$self->writeStockfishMsg('position startpos');
            #$self->writeStockfishMsg('go infinite');
        }
        if ($line =~ m/^bestmove\s(.+?)\s/){
            my $move = $1;
            print "bestmove $move\n";
            my $bestScore = -999999;
            if ($self->{aiStates}->{possibleMoves}->{$move}) {
                my $moveScore = $self->{aiStates}->{possibleMoves}->{$move}->{score};
                if ($moveScore =~ m/^mate/) {
                    next;
                }
            }
            ### prevent moving on top of yourself.
            $move =~ m/(..)(..)$/;
            my ($src, $dst) = ($1, $2);
            my $allMoveSrc = {
                $src => 1
            };
            my $allMoveDests = {
                $dst => 1
            };
            foreach (values %{$self->{aiStates}->{possibleMoves}}) {
                if ($_->{score} =~ m/^mate/) {
                    next;
                }
                if ($_->{score} > $bestScore - 100) {
                    $_->{move} =~ m/(..)(..)$/;
                    if ($allMoveSrc->{$1}) {
                        next;
                    }
                    if ($allMoveDests->{$2}) {
                        next;
                    }
                    $allMoveSrc->{$1} = 1;
                    $allMoveDests->{$2} = 1;

                    $self->moveNotation($_->{move});
                }
            }
            $self->{aiStates}->{possibleMoves} = {};
        } elsif ($line =~ m/info depth (\d+).*? multipv (\d+) score cp (.+) nodes (\d+) .*? pv ([a-h][0-9][a-h][0-9])/) {
            my ($depth, $ranking, $score, $nodes, $move) = ($1, $2, $3, $4, $5);
            print "pv move $score $nodes $move\n";

            $self->{aiStates}->{possibleMoves}->{$move} = {
                'move' => $move,
                'score' => $score,
                'ranking' => $ranking
            };
        }
    }
    print "--- end reading\n";
}

sub writeStockfishMsg {
    my $self = shift;
    my $msg = shift;
    my $cin = $self->{ai_in};
    print "sending stockfish: $msg\n";
    print $cin $msg . "\n";
}

sub _init {
	my $self = shift;
	my $gameKey = shift;
	my $authKey = shift;
	my $speed = shift;
    my $pieceSpeed = shift;
    my $pieceRecharge = shift;
	my $speedAdj = shift;
	my $mode  = shift;
    my $difficulty = shift;
    my $color = shift;
    my $domain = shift;
	my $ai = 1;

    print "game key: $gameKey, authkey: $authKey, speed: $speed, mode: $mode, diff: $difficulty, color: $color, domain: $domain\n";

    $self->{startTime} = time();

    my $cfg = new Config::Simple('kungFuChess.cnf');
    $self->{config} = $cfg;
    $self->{mode}   = $mode;
    $self->{color}  = $color;
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
    # ai_depth         max depth
    # ai_simul_moves   max moves to make at once
    # ai_delay         random delay before move for queued moves only (opening)
    # ai_min_delay     min random delay
    # ai_interval      time to wait before next move
    # ai_skip_best     % chance to skip the best move (and next again)

    if ($speed eq 'standard') {
        $self->{pieceSpeed} = 1;
        $self->{pieceRecharge} = 10;
        if ($difficulty eq '1') {
            $self->{ai_thinkTime} = 1;
            $self->{ai_depth} = 1;
            $self->{ai_simul_moves} = 1;
            $self->{ai_delay} = 1_000_000; 
            $self->{ai_min_delay} = 1_000_000;
            $self->{ai_interval} = 2_000_000;
            $self->{ai_skip_best} = 0.7;
        } elsif ($difficulty eq '2') {
            $self->{ai_thinkTime} = 1;
            $self->{ai_depth} = 1;
            $self->{ai_simul_moves} = 1;
            $self->{ai_delay} = 800_000; 
            $self->{ai_min_delay} = 200_000;
            $self->{ai_interval} = 1_000_000;
            $self->{ai_skip_best} = 0.4;
        } elsif ($difficulty eq '3') {
            $self->{ai_thinkTime} = 2.0;
            $self->{ai_depth} = 2;
            $self->{ai_simul_moves} = 1;
            $self->{ai_delay} = 100_000; 
            $self->{ai_min_delay} = 0;
            $self->{ai_interval} = 500_000;
            $self->{ai_skip_best} = 0.0;
        } elsif ($difficulty eq 'human_a') {
            $self->{ai_thinkTime} = 2.0;
            $self->{ai_depth} = 3;
            $self->{ai_simul_moves} = 1;
            $self->{ai_delay} = 300_000; 
            $self->{ai_min_delay} = 150_000;
            $self->{ai_interval} = 300_000;
            $self->{ai_skip_best} = 0.0;
            $self->{ai_human} = 1;
        } else {
            $self->{ai_thinkTime} = 2.0;
            $self->{ai_depth} = 1;
            $self->{ai_simul_moves} = 1;
            $self->{ai_delay} = 300_000; 
            $self->{ai_min_delay} = 0;
            $self->{ai_interval} = 500_000;
            $self->{ai_skip_best} = 0.0;
        }
    } elsif ($speed eq 'lightning') {
        $self->{pieceRecharge} = 2;
        if ($difficulty eq '1') {
            $self->{ai_thinkTime} = 1.0;
            $self->{ai_depth} = 1;
            $self->{ai_simul_moves} = 1;
            $self->{ai_delay} = 1_000_000; 
            $self->{ai_min_delay} = 500_000;
            $self->{ai_interval} = 2_000_000;
            $self->{ai_skip_best} = 0.7;
        } elsif ($difficulty eq '2') {
            $self->{ai_thinkTime} = 1.0;
            $self->{ai_depth} = 1;
            $self->{ai_simul_moves} = 1;
            $self->{ai_delay} = 1_000_000; 
            $self->{ai_min_delay} = 500_000;
            $self->{ai_interval} = 500_000;
            $self->{ai_skip_best} = 0.4;
        } elsif ($difficulty eq '3') {
            $self->{ai_thinkTime} = 1.0;
            $self->{ai_depth} = 2;
            $self->{ai_simul_moves} = 1;
            $self->{ai_delay} = 200_000; 
            $self->{ai_min_delay} = 100_000;
            $self->{ai_interval} = 250_000;
            $self->{ai_skip_best} = 0.0;
        } elsif ($difficulty eq 'human_a') {
            $self->{ai_thinkTime} = 1.0;
            $self->{ai_depth} = 1;
            $self->{ai_simul_moves} = 1;
            $self->{ai_delay} = 1_000_000; 
            $self->{ai_min_delay} = 500_000;
            $self->{ai_interval} = 1_000_000;
            $self->{ai_skip_best} = 0.0;
        } else {
            $self->{ai_thinkTime} = 1.0;
            $self->{ai_depth} = 1;
            $self->{ai_simul_moves} = 1;
            $self->{ai_delay} = 1_000_000; 
            $self->{ai_min_delay} = 500_000;
            $self->{ai_interval} = 1_000_000;
            $self->{ai_skip_best} = 0.0;
        }
    } else {
        warn "unknown game speed $speed\n";
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

        sleep(1);
		$msg = {
		   'c' => 'readyToBegin',
		};
        print "sending readyToBegin\n";
		$self->send($msg);

		$self->setupInitialBoard();

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
            print "handling message time: " . time() . "\n";
			$self->handleMessage($msgJSON, $connection);
		});

		# handle a closed connection...
		$connection->on(finish => sub {
			# $connection is the same connection object
			my($connection) = @_;
			AnyEvent->condvar->send;
            if ($self->{stockfishPid}) { system("kill $self->{stockfishPid}"); }
			exit;
		});

		# close the connection (either inside or
		# outside another callback)
		# $connection->close;

	});

	$self->{client} = $client;
    $self->{movesQueue} = [];
    $self->{inducedMoves} = [];

    #if ($ai) {
        ##$self->{aiStates}->{uciok} = 0;
        #print "setting ai interval:\n";
        #$self->{aiInterval} = AnyEvent->timer(
            #after => 1,
            #interval => 1.0,
            #cb => sub {
                #my ($score, $bestMoves, $moves) = KungFuChess::Bitboards::aiThink(2, 0.5);
                #foreach my $move (@{$bestMoves->[2]}) {
                    #my $fr_bb = $moves->[2]->{$move}->[0];
                    #my $to_bb = $moves->[2]->{$move}->[1];
                    #my $msg = {
                        #'fr_bb' => $fr_bb,
                        #'to_bb' => $to_bb,
                        #'c'     => 'move'
                    #};
                    #$self->send($msg);
                #}

                ##$self->writeStockfishMsg('stop');
                ##$self->writeStockfishMsg('position fen ' . $self->getFENstring());
                ##$self->writeStockfishMsg('go');
                ##print "stockfish interval\n";
                ##$self->getStockfishMsgs();
            #}
        #);
    #}

    $self->{aiPing} = AnyEvent->timer(
        after => 1,
        interval => 2.5,
        cb => sub {
            if (! defined($self->{gameStartTime}) &&
                time() - $self->{startTime} > 60
            ) {
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
        }
    );

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
    my $unsetTime = $self->{pieceRecharge} * 0.7; 
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

	if ($msg->{c} eq 'move'){
        ### + 0 to insure int
        KungFuChess::Bitboards::move($msg->{fr_bb} + 0, $msg->{to_bb} + 0);
        KungFuChess::Bitboards::setMoving($msg->{to_bb} + 0);
        KungFuChess::Bitboards::resetAiBoards(1);
        $self->setFrozen($msg->{to_bb} + 0);
	} elsif ($msg->{c} eq 'stop'){
        KungFuChess::Bitboards::unsetMoving($msg->{fr_bb} + 0);
        delete $self->{frozen}->{$msg->{fr_bb}};
	} elsif ($msg->{c} eq 'moveAnimate'){
        ### dodge that shit
        if ($msg->{color} != $self->{color}) {
            push @{$self->{inducedMoves}}, $msg->{to_bb};
        }
	} elsif ($msg->{c} eq 'suspend'){
        $self->{suspendedPieces}->{$msg->{to_bb}} =
            KungFuChess::Bitboards::_getPieceBB($msg->{fr_bb} + 0);

        KungFuChess::Bitboards::_removePiece($msg->{fr_bb} + 0);
        delete $self->{frozen}->{$msg->{fr_bb}};
    } elsif ($msg->{c} eq 'unsuspend'){
        KungFuChess::Bitboards::_putPiece(
            $self->{suspendedPieces}->{$msg->{to_bb}},
            $msg->{to_bb} + 0
        );
        $self->setFrozen($msg->{to_bb} + 0);
        delete $self->{suspendedPieces}->{$msg->{to_bb}};
        KungFuChess::Bitboards::resetAiBoards(1);
    } elsif ($msg->{c} eq 'promote'){
        my $p = KungFuChess::Bitboards::_getPieceBB($msg->{bb} + 0);
        if ($p == 101) {
            $p = 106;
        } elsif( $p == 201) {
            $p = 206;
        } else {
            print KungFuChess::Bitboards::pretty_ai();
            print "promote none pawn? *$p*\n";
        }

        KungFuChess::Bitboards::_removePiece($msg->{bb} + 0);
        KungFuChess::Bitboards::_putPiece(
            $p + 0,
            $msg->{bb} + 0
        );
        KungFuChess::Bitboards::resetAiBoards(1);
        print KungFuChess::Bitboards::pretty_ai();
    } elsif ($msg->{c} eq 'kill'){
        delete $self->{frozen}->{$msg->{bb}};
        KungFuChess::Bitboards::_removePiece($msg->{bb} + 0);
        KungFuChess::Bitboards::resetAiBoards(1);
	} elsif ($msg->{c} eq 'playerlost' || $msg->{c} eq 'resign' || $msg->{c} eq 'gameOver' || $msg->{c} eq 'abort'){
        $self->endGame();
	} elsif ($msg->{c} eq 'gameBegins'){
        #print "game begins\n";
        $self->{gameStartTime} = time();
        # to prevent autodraw from coming up right away
        my $startTime = time() + $msg->{seconds};
        #$self->{aiStates}->{uciok} = 0;

        #usleep(($startTime + 0.1) * 1000);
        my @moves = ();
        my $rand = rand();

        if ($self->{color} == 1) {
            if ($rand < 0.3) {
                #@moves = qw(e2e3 d2d4 g1f3 a2a4 a1a3 c1d2 b1c3 h2h3 d1e2);
                @moves = qw(d2d4 e2e4 c2c3 f2f3 c1e3 f1d3 g1e2 b1d2);
            } elsif ($rand < 0.6) {
                @moves = qw(f2f4 e2e4 d2d3 e2e3 b2b3 g2g3 f1g2 c1b2);
                #@moves = qw(f2f4 e2e4 d2d3 g2g3 f1e2 c1d2 g1f3 b1c3 a2a3);
            } else {
                @moves = qw(c2c4 e2e3 f1e2 g1f3 e1g1 b2b3 c1b2 b1c3 h2h3);
            }
        } else {
            if ($rand < 0.3) {
                @moves = qw(e7e5 d7d5 c7c6 f7f6 c8e6 f8d6 g8e7 b8d7);
                #@moves = qw(e7e5 d7d6 c8f6 f8f7 g7g6 f8g7 b8b7 a8a7 b8c6);
            } elsif ($rand < 0.6) {
                @moves = qw(f7f5 e7e5 d7d6 e7e6 b7b6 g7g6 f8g7 c7b6);
                #@moves = qw(c7c5 d7d5 e7e6 b7b6 c8b7 b8c6 g7g6 f8g7 d8e7);
            } else {
                @moves = qw(e7e6 f8c5 d7d5 b8c6 b7b6 g8f6 c8b2 d8d6 e8c8);
            }
        }

        #print "setting ai interval:\n";
        $self->{movesQueue} = \@moves;

        my $w2; 
        # Start a timer that, at most once every 0.5 seconds, sleeps
        # for 1 second, and then prints "timer":
        my $w1; $w1 = deferred_interval(
            after => 3.2,
            reference => \$w2,  
            interval => 0.5,
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

    my $handle = $self->{conn}->{handle};
    $handle->push_read( 'line' => sub {
    });
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
    my $debug = 0;
    if ($#{$self->{movesQueue}} > -1) {
        foreach my $move (@{$self->{movesQueue}}) {
            my ($fr_bb, $to_bb, $fr_rank, $fr_file, $to_rank, $to_file) = KungFuChess::Bitboards::parseMove($move);
            my $msg = {
                'fr_bb' => $fr_bb,
                'to_bb' => $to_bb,
                'c'     => 'move'
            };
            $self->send($msg);
            usleep(rand($self->{ai_delay}) + $self->{ai_min_delay});
        }
        $self->{movesQueue} = [];
    } else {
        KungFuChess::Bitboards::resetAiBoards($self->{color});
        # depth, thinkTime
        my $start = time();
        my $score = 0;
        my ($aiScore, $moves, $totalMaterial, $attackedBy) = KungFuChess::Bitboards::aiThink($self->{ai_depth}, $self->{ai_thinkTime}, $self->{color});

        if ($debug) {
            print "current score: " . KungFuChess::Bitboards::getCurrentScore() . "\n";
            KungFuChess::BBHash::displayMoves($moves, $self->{color}, 0, undef, undef, undef);
        }

        my $suggestedMoves = KungFuChess::Bitboards::aiRecommendMoves($self->{color}, $self->{ai_simul_moves});

        my $fr_moves = {};
        my $to_moves = {};
        if ($debug) {
            print KungFuChess::Bitboards::pretty_ai();
            #print KungFuChess::Bitboards::prettyFrozen();
            print KungFuChess::Bitboards::getFENstring();
        }

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
            $fr_moves->{$move->[0]} = 1;
            $to_moves->{$move->[1]} = 1;
            my $msg = {
                'fr_bb' => $move->[0],
                'to_bb' => $move->[1],
                'c'     => 'move'
            };
            $self->send($msg);
            #usleep(rand($self->{ai_delay}) + $self->{ai_min_delay});
        }

        ### dodges or anticipated attacks
        foreach my $induced_fr (@{$self->{inducedMoves}}) {
            $self->{lastMoved} = time();
            $induced_fr += 0;
            my ($best_to, $score) = KungFuChess::Bitboards::recommendMoveForBB($induced_fr, $self->{color}, $attackedBy);
            if ($best_to) {
                my $msg = {
                    'fr_bb' => $induced_fr,
                    'to_bb' => $best_to,
                    'c'     => 'move'
                };
                #print "sending induced:\n";
                #print KungFuChess::BBHash::getSquareFromBB($induced_fr);
                #print KungFuChess::BBHash::getSquareFromBB($best_to);
                #print "\n";
                $self->send($msg);
            }
        }
        $self->{inducedMoves} = [];
    }
    my $timeSpent = time() - $aiStartTime;
    my $intervalLeft = $timeSpent - (($self->{ai_interval} // 1_000_000) / 1_000_000);

    ### at least a tenth of a second to recieve messages
    if ($intervalLeft < 0.1) {
        $intervalLeft = 0.1;
    }
    $intervalLeft = 1;

    if ($self->{debug}) {
        print "time ending " . time() . "\n";
    }
    $self->{aiInterval} = AnyEvent->timer(
        after => $intervalLeft, 
        cb => sub {
            $self->aiTick();
        }
    );
}

sub doOpeningAndStart {
    my $self = shift;
    my $startTime = shift;
    print "do opening...\n";
}

sub checkForForceDraw {
    my $self = shift;
    return 0;
}

sub endGame {
    my $self = shift;

    if ($self->{is_human}) {
        sleep(rand(5));
        my $dataPost = {
            'uid' => $self->{anonKey},
            'gameId' => $self->{gameId},
            'c' => 'rematch',
        };
    } else {
        if ($self->{stockfishPid}) { system("kill $self->{stockfishPid}"); }
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
1;
