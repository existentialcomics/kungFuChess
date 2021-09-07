#!/usr/bin/perl
use strict; use warnings;

# this is the server that manages the pieces and connect to KungFuWeb.pl

package KungFuChess::GameAi;

use AnyEvent::WebSocket::Client;
use AnyEvent;
use JSON::XS;
#use KungFuChess::Bitboards;
use IPC::Open2;
use Config::Simple;
use Time::HiRes qw(time);
use Data::Dumper;
# do it all in one line .env file
use Dotenv -load;
use Env;

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
	my $mode = shift;
	my $ai = 1;

    print "game key: $gameKey, authkey: $authKey, speed: $speed, mode: $mode\n";
    
    my $cfg = new Config::Simple('kungFuChess.cnf');
    $self->{config} = $cfg;
    $self->{mode} = $mode;
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

    print "AI: $ai\n";
    $self->{ai} = $ai;

    if ($ai) {
        #print "initalizing stockfish...\n";
        #my($cout, $cin);
        #my $pid = open2($cout, $cin, $cfg->param('path_to_stockfish') . ' 2>&1 | tee /var/log/stockfish/stockfish.log');
        #$cout->blocking(0);
        #$self->{ai_out} = $cout;
        #$self->{ai_in}  = $cin;
        #$self->{stockfishPid} = $pid;
        #$self->getStockfishMsgs();
    }

    if ($speed eq 'standard') {
        $self->{pieceSpeed} = 1;
        $self->{pieceRecharge} = 10;
    } elsif ($speed eq 'lightning') {
        $self->{pieceSpeed} = 0.2;
        $self->{pieceRecharge} = 2;
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

    $client->connect(
        ($ENV{KFC_WS_PROTOCOL} // 'ws') . '://' . ($ENV{KFC_WS_DOMAIN} // 'localhost:3000') . "/ws"
    )->cb(sub {
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
		   'c' => 'join',
		};
		$self->send($msg);

		$self->setupInitialBoard();

		# recieve message from the websocket...
		$connection->on(each_message => sub {
			# $connection is the same connection object
			# $message isa AnyEvent::WebSocket::Message
			my($connection, $message) = @_;
			my $msg = $message->body;
			my $msgJSON = decode_json($msg);
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

    if ($ai) {
        #$self->{aiStates}->{uciok} = 0;
        print "setting ai interval:\n";
        $self->{aiInterval} = AnyEvent->timer(
            after => 1,
            interval => 1.0,
            cb => sub {
                my ($score, $bestMoves, $moves) = KungFuChess::Bitboards::aiThink(2, 0.5);
                foreach my $move (@{$bestMoves->[2]}) {
                    my $fr_bb = $moves->[2]->{$move}->[0];
                    my $to_bb = $moves->[2]->{$move}->[1];
                    my $msg = {
                        'fr_bb' => $fr_bb,
                        'to_bb' => $to_bb,
                        'c'     => 'move'
                    };
                    $self->send($msg);
                }

                print Dumper($bestMoves);

                #$self->writeStockfishMsg('stop');
                #$self->writeStockfishMsg('position fen ' . $self->getFENstring());
                #$self->writeStockfishMsg('go');
                #print "stockfish interval\n";
                #$self->getStockfishMsgs();
            }
        );
    }
	AnyEvent->condvar->recv;
	print "GAME ENDING\n";
}

sub setupInitialBoard {
	my $self = shift;
    KungFuChess::Bitboards::setupInitialPosition();
}

sub handleMessage {
	my $self = shift;
	my ($msg, $conn) = @_;

	if ($msg->{c} eq 'move'){
        print "move:\n";
        print Dumper($msg);
		#$self->moveIfLegal($msg->{color}, $msg->{move});
        print KungFuChess::Bitboards::pretty();
        ### + 0 to insure int
        KungFuChess::Bitboards::move($msg->{fr_bb} + 0, $msg->{to_bb} + 0);
        KungFuChess::Bitboards::resetAiBoards();
        print KungFuChess::Bitboards::pretty();
        print KungFuChess::Bitboards::pretty_ai();
	} elsif ($msg->{c} eq 'suspend'){
        $self->{suspendedPieces}->{$msg->{to_bb}} = 
            KungFuChess::Bitboards::_getPieceBB($msg->{fr_bb} + 0);

        print "suspended: $self->{suspendedPieces}->{$msg->{fr_bb}}\n";
        print "bb: $msg->{fr_bb}\n";
        KungFuChess::Bitboards::_removePiece($msg->{fr_bb} + 0);
        KungFuChess::Bitboards::resetAiBoards();
        print KungFuChess::Bitboards::pretty();
        print KungFuChess::Bitboards::pretty_ai();
    } elsif ($msg->{c} eq 'unsuspend'){
        print "unsuspend\n";
        print "$self->{suspendedPieces}->{$msg->{to_bb}}\n";
        print "to_bb: $msg->{to_bb}\n";
        KungFuChess::Bitboards::_putPiece(
            $self->{suspendedPieces}->{$msg->{to_bb}},
            $msg->{to_bb} + 0
        );
        delete $self->{suspendedPieces}->{$msg->{to_bb}};
        KungFuChess::Bitboards::resetAiBoards();
        print KungFuChess::Bitboards::pretty();
        print KungFuChess::Bitboards::pretty_ai();
    } elsif ($msg->{c} eq 'kill'){
        KungFuChess::Bitboards::_removePiece($msg->{bb} + 0);
	} elsif ($msg->{c} eq 'playerlost' || $msg->{c} eq 'resign'){
        exit;
	} elsif ($msg->{c} eq 'gameBegins'){
        print "game begins\n";
        # to prevent autodraw from coming up right away
        my $startTime = time() + $msg->{seconds};
        foreach my $piece ($self->getPieces()) {
            $piece->{readyToMove} = $startTime;
        }
	}
}

sub checkForForceDraw {
    my $self = shift;
    return 0;
}

sub endGame {
    my $self = shift;

    if ($self->{stockfishPid}) { system("kill $self->{stockfishPid}"); }
    exit;
}

sub send {
	my $self = shift;
	my $msg  = shift;

    print "sending msgs $msg->{c}\n";

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
    print "ai move: $notation\n";
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
    print Dumper($self->{activeMoves});
    delete $self->{activeMoves}->{$bb};
    print "killing piece $bb\n";
    print Dumper($self->{activeMoves});
    my $piece = KungFuChess::Bitboards::_getPieceBB($bb);
    if ($piece) {
        print "piece: $piece\n";
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
            print "sending black lost\n";
            $self->send($msg);
            exit; ### game over
        } elsif ($piece == KungFuChess::Bitboards::WHITE_KING) {
            my $msg = {
                'c' => 'playerlost',
                'color' => 'white'
            };
            print "sending white lost\n";
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
