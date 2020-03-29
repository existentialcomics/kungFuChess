#!/usr/bin/perl
use strict; use warnings;

# this is the server that manages the pieces and connect to KungFuWeb.pl

package KungFuChess::GameServer;

use AnyEvent::WebSocket::Client;
use AnyEvent;
use KungFuChess::Piece;
use KungFuChess::Bitboards;
use JSON::XS;
use Data::Dumper;
use IPC::Open2;
use Config::Simple;

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
	my $ai = shift;
    
    my $cfg = new Config::Simple('kungFuChess.cnf');
    $self->{config} = $cfg;

	$self->{gamekey} = $gameKey;
	$self->{authkey} = $authKey;
	$self->{pieceIdCount} = 1;

    print "AI: $ai\n";

    if ($ai) {
        print "initalizing stockfish...\n";
        my($cout, $cin);
        my $pid = open2($cout, $cin, $cfg->param('path_to_stockfish') . ' 2>&1 | tee /var/log/stockfish.log');
        $cout->blocking(0);
        $self->{ai_out} = $cout;
        $self->{ai_in}  = $cin;
        $self->{stockfishPid} = $pid;
        $self->getStockfishMsgs();
        print $cin "uci\n";
        $self->getStockfishMsgs();
    }

    ### needed for KungFuChess::Pieces 
    if ($speed eq 'standard') {
        $self->{pieceSpeed} = 10;
        $self->{pieceRecharge} = 10;
    } elsif ($speed eq 'lightning') {
        $self->{pieceSpeed} = 2;
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

	my $client = AnyEvent::WebSocket::Client->new;

	$client->connect("ws://localhost:3000/ws")->cb(sub {
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
        $self->{aiStates}->{uciok} = 0;
        print "setting ai interval:\n";
        $self->{aiInterval} = AnyEvent->timer(
            after => 1,
            interval => 1.0,
            cb => sub {
                $self->writeStockfishMsg('stop');
                $self->writeStockfishMsg('position fen ' . $self->getFENstring());
                $self->writeStockfishMsg('go');
                print "stockfish interval\n";
                $self->getStockfishMsgs();
            }
        );
    }
	AnyEvent->condvar->recv;
	print "GAME ENDING\n";
}

sub setupInitialBoard {
	my $self = shift;
	my $id = $self->{pieceIdCount}++;
	# pawns
	foreach my $x (0..7){
		$id++;
		$self->{board}->{$id} = new KungFuChess::Piece(
			 $x,
			 1,
			 'black',
			 'pawn',
			 $id,
			 $self
		);
		$id++;
		$self->{board}->{$id} = new KungFuChess::Piece(
			 $x,
			 6,
			 'white',
			 'pawn',
			 $id,
			 $self
		);
	}
	$id++;
	$self->{board}->{$id++} = new KungFuChess::Piece(
			 0,
			 0,
			 'black',
			 'rook',
			 $id,
			 $self
	);
	$self->{board}->{$id++} = new KungFuChess::Piece(
			 1,
			 0,
			 'black',
			 'knight',
			 $id,
			 $self
	);
	$self->{board}->{$id++} = new KungFuChess::Piece(
			 2,
			 0,
			 'black',
			 'bishop',
			 $id,
			 $self
	);
	$self->{board}->{$id++} = new KungFuChess::Piece(
			 3,
			 0,
			 'black',
			 'queen',
			 $id,
			 $self
	);
	$self->{board}->{$id++} = new KungFuChess::Piece(
			 4,
			 0,
			 'black',
			 'king',
			 $id,
			 $self
	);
	$self->{board}->{$id++} = new KungFuChess::Piece(
			 5,
			 0,
			 'black',
			 'bishop',
			 $id,
			 $self
	);
	$self->{board}->{$id++} = new KungFuChess::Piece(
			 6,
			 0,
			 'black',
			 'knight',
			 $id,
			 $self
	);
	$self->{board}->{$id++} = new KungFuChess::Piece(
			 7,
			 0,
			 'black',
			 'rook',
			 $id,
			 $self
	);
	########### WHITE
	#
	$self->{board}->{$id++} = new KungFuChess::Piece(
			 0,
			 7,
			 'white',
			 'rook',
			 $id,
			 $self
	);
	$self->{board}->{$id++} = new KungFuChess::Piece(
			 1,
			 7,
			 'white',
			 'knight',
			 $id,
			 $self
	);
	$self->{board}->{$id++} = new KungFuChess::Piece(
			 2,
			 7,
			 'white',
			 'bishop',
			 $id,
			 $self
	);
	$self->{board}->{$id++} = new KungFuChess::Piece(
			 3,
			 7,
			 'white',
			 'queen',
			 $id,
			 $self
	);
	$self->{board}->{$id++} = new KungFuChess::Piece(
			 4,
			 7,
			 'white',
			 'king',
			 $id,
			 $self
	);
	$self->{board}->{$id++} = new KungFuChess::Piece(
			 5,
			 7,
			 'white',
			 'bishop',
			 $id,
			 $self
	);
	$self->{board}->{$id++} = new KungFuChess::Piece(
			 6,
			 7,
			 'white',
			 'knight',
			 $id,
			 $self
	);
	$self->{board}->{$id++} = new KungFuChess::Piece(
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

	if ($msg->{c} eq 'join'){
		$self->sendAllGamePieces();
	} elsif ($msg->{c} eq 'playerjoin'){
		$self->sendAllGamePieces();
	} elsif ($msg->{c} eq 'move'){
		my $piece = $self->getPiece($msg->{id});
		return 0 if ($msg->{color} ne $piece->{color} && $msg->{color} ne 'both');
		$self->moveIfLegal($piece, $msg->{x}, $msg->{y});
	} elsif ($msg->{c} eq 'gameBegins'){
        print "game begins\n";
        # to prevent autodraw from coming up right away
        my $startTime = time() + $msg->{seconds};
        foreach my $piece ($self->getPieces()) {
            $piece->{readyToMove} = $startTime;
        }
	} elsif ($msg->{c} eq 'requestDraw'){
        if ($self->checkForForceDraw) {
            my $drawMsg = {
                'c' => 'forceDraw'
            };
            $self->send($drawMsg);
        }
	} elsif ($msg->{c} eq 'gameDrawn'){
        $self->endGame();
	} elsif ($msg->{c} eq 'resign'){
        $self->endGame();
	}
}

sub checkForForceDraw {
    my $self = shift;
    my @pieces = $self->getPieces();
    my $shortestPawnMove = 999999999999999;
    foreach my $piece (@pieces) {
        if ($piece->{type} eq 'pawn') {
            if (time - $piece->{readyToMove} < $shortestPawnMove) {
                $shortestPawnMove = time - $piece->{readyToMove};
            }
        }
    }
    if ($shortestPawnMove > 25) { return 1; }
    return 0;
}

sub sendAllGamePieces {
	my $self = shift;
    my $returnOnly = shift;
	my $conn = $self->{conn};

    my @msgs = ();
	foreach my $id (keys %{ $self->{board} }){
		my $piece = $self->{board}->{$id};

		my $msg = {
			'c' => 'spawn',
			'type'  => $piece->{type},
			'id'    => $id,
			'color' => $piece->{color},
			'x'     => $piece->{x},
			'y'     => $piece->{y},
		};

        if ($returnOnly) {
            push @msgs, $msg;
        } else {
            $self->send($msg);
        }
	}
    return @msgs;
}

# called by the piece that landed
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

sub endGame {
    my $self = shift;

    print "game ending...\n";
    my @msgs = $self->sendAllGamePieces(1);
    my $msg = {
        'c' => 'gamePositionMsgs',
        'msgs' => encode_json(\@msgs) ### double encoded because want to store the json not use it
    };
    $self->send($msg);
    if ($self->{stockfishPid}) { system("kill $self->{stockfishPid}"); }
    exit;
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
        $self->endGame(); ### TODO in 4way the game won't end here!
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

    print "sending msgs $msg->{c}\n";

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
            $self->moveIfLegal($piece, $endX, $endY);
        }
    }
}

###
sub getPieceAt {
    my $self = shift;
    my ($x, $y) = @_;
    if ($x > 7 || $y > 7 || $x < 0 || $y < 0) {
        return undef;
    }
    return $self->{boardMap}->[$x]->[$y];
}

### looks for obvious kung fu problems with moves
sub filterAiMove {
	my $self = shift;
	my $piece = shift;
	my ($x, $y) = @_;

    my $xDis = abs($piece->{x} - $x);
    my $yDis = abs($piece->{y} - $y);

    my $pieceAtDest = $self->getPieceAt($x, $y);

    ### check for too long of a risky move
    my $distance = ($xDis > $yDis ? $xDis : $yDis);

    if ($distance > 4 && ! $pieceAtDest) {
        print "  filter: too long no piece\n";
        return 1;
    }

    ### check for nearby pawns that can move up
    my $yDir = $piece->{pawnDir};
    my $pawnLeft  = $self->getPieceAt($x - 1, $y + ($yDir * 2));
    my $pawnRight = $self->getPieceAt($x - 1, $y + ($yDir * 2));

    if ($pawnLeft)  {
        print "  filter: dangerous pawn left\n";
        return 1; 
    }
    if ($pawnRight) {
        print "  filter: dangerous pawn right\n";
        return 1;
    }

    ### check for piece capture that can dodge
    if ($pieceAtDest &&  $pieceAtDest->readyToMove() && $distance > 2) {
        print "  filter: dangerous dodge chance\n";
        return 1;
    }

    return 0;
}

sub moveIfLegal {
	my $self = shift;
	my $piece = shift;
	my ($x, $y) = @_;

    ### TODO premove
    if ( ! $piece->readyToMove() ) { return 0; }
    if ( $piece->{isMoving} )    { return 0; }

	my @pieces = $self->getPieces();

	if ($piece->isLegalMove($x, $y, \@pieces)){
		$piece->move($x, $y);
		return 1;
	}
	return 0;
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
        for ($rowCount = 0; $rowCount < 8; $rowCount++) {
            if ($self->{boardMap}->[$rowCount]->[$colCount]) {
                if ($colGapCount > 0){
                    $fenString .= $colGapCount;
                    $colGapCount = 0;
                }
                my $piece = $self->{boardMap}[$rowCount][$colCount];
                if ($piece) {
                    $fenString .= $piece->getFENchar();
                }
            } else {
                $colGapCount ++;
            }
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
