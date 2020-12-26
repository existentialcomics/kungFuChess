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
use Time::HiRes qw(time);

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

    print "game key: $gameKey, authkey: $authKey, speed: $speed\n";
    
    my $cfg = new Config::Simple('kungFuChess.cnf');
    $self->{config} = $cfg;

	$self->{gamekey} = $gameKey;
	$self->{authkey} = $authKey;
	$self->{pieceIdCount} = 1;

    ### currently animating moves
    $self->{activeMoves}    = {};
    ### squares that are on hold before they can move again
    $self->{timeoutSquares} = {};
    $self->{timeoutCBs} = {};

    print "AI: $ai\n";

    if ($ai) {
        print "initalizing stockfish...\n";
        my($cout, $cin);
        my $pid = open2($cout, $cin, $cfg->param('path_to_stockfish') . ' 2>&1 | tee /var/log/stockfish/stockfish.log');
        $cout->blocking(0);
        $self->{ai_out} = $cout;
        $self->{ai_in}  = $cin;
        $self->{stockfishPid} = $pid;
        $self->getStockfishMsgs();
    }

    ### needed for KungFuChess::Pieces 
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
    KungFuChess::Bitboards::setupInitialPosition();
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
		$self->moveIfLegal($msg->{color}, $msg->{move});
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

### TODO possible to send the bitboards themselves and have js decode
sub sendAllGamePieces {
	my $self = shift;
    my $returnOnly = shift;
	my $conn = $self->{conn};

    print "sending all game pieces...\n";
    print KungFuChess::Bitboards::pretty();
    print "done pretty\n";
    my @msgs = ();
    foreach my $r ( qw(8 7 6 5 4 3 2 1) ) {
        foreach my $f ( 'a' .. 'h' ) {
            my $chr = KungFuChess::Bitboards::_getPiece($f, $r);
            if ($chr) {
                my $msg = {
                    'c' => 'spawn',
                    'chr'    => $chr,
                    'square' => $f . $r
                };

                if ($returnOnly) {
                    push @msgs, $msg;
                } else {
                    $self->send($msg);
                }
            }
        }
    }
    return @msgs;
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
    return 0;
}

sub moveIfLegal {
    print "moveIfLegal\n";
	my $self = shift;

	my $color = shift;
	my $move  = shift;

    print KungFuChess::Bitboards::pretty();

    ### TODO premove
    my ($colorbit, $moveType, $moveDir, $fr_bb, $to_bb) = KungFuChess::Bitboards::isLegalMove($move);
    print "isLegal: $colorbit, $moveType, $moveDir\n";
    if ($moveType == 0) {
        return 0;
    }
    print "checking for timeout on $to_bb\n";
    if (exists($self->{timeoutSquares}->{$fr_bb})) {
        return 0;
    }
    print " no timeout found\n";
    print "pass, check $color vs $colorbit\n";
    if ($color ne 'both') {
        if ($color eq 'white' && $colorbit != 1) {
            return 0;
        }
        if ($color eq 'black' && $colorbit != 2) {
            return 0;
        }
    }

    my $timer = undef;
    my $timer2 = undef;
    my $moveStep = sub {
        my ($self, $func, $fr_bb, $to_bb, $dir, $startTime, $moveType, $piece) = @_;

        my $next_fr_bb = 0;

        delete $self->{activeMoves}->{$fr_bb};

        my $done = 0;
        my $nextMoveSpeed = $self->{pieceSpeed};
        if ($moveType == KungFuChess::Bitboards::MOVE_NORMAL || 
            $moveType == KungFuChess::Bitboards::MOVE_PROMOTE 
        ) {
            my $moving_to_bb = 0;
            ### for DIR_NONE it means we want to move directly there (King)
            if ($dir == KungFuChess::Bitboards::DIR_NONE) {
                $moving_to_bb = $to_bb;
            } else {
                $moving_to_bb = KungFuChess::Bitboards::shift_BB($fr_bb, $dir);
            }

            ### TODO replace this with a perfect hash of all 64 bb destinations
            ### only check this if the moving bitboard is occupied.
            ### if the piece is ours, stop here.
            if (exists($self->{activeMoves}->{$moving_to_bb})) {
                my $themStartTime = $self->{activeMoves}->{$moving_to_bb};
                print "collision detected, me: $startTime vs $themStartTime\n"; 
                print "collision times, me $startTime vs $themStartTime\n"; 
                if ($themStartTime < $startTime) {
                    ### the place we are moving has a piece that started before
                    ### so we get killed.
                    print "collision detected we are getting killed\n";
                    $self->killPieceBB($fr_bb);
                    KungFuChess::Bitboards::_removePiece($fr_bb);

                    return 1;
                }
            }

            $self->killPieceBB($moving_to_bb);
            KungFuChess::Bitboards::move($fr_bb, $moving_to_bb);
            my $msgStep = {
                'c' => 'authmovestep',
                'color'  => $self->{color},
                'fr_bb'  => $fr_bb,
                'to_bb'  => $moving_to_bb
            };
            $self->send($msgStep);
            if ($moveType == KungFuChess::Bitboards::MOVE_PROMOTE) {
                print "MOVE_PROMOTE\n";
                my $msgPromote = {
                    'c' => 'promote',
                    'bb'  => $moving_to_bb,
                };
                $self->send($msgPromote);
                my $pawn = KungFuChess::Bitboards::_getPieceBB($moving_to_bb);
                my $p = ($pawn eq 'P' ? 'Q' : 'q');
                print " putting $pawn $p...\n";
                KungFuChess::Bitboards::_removePiece($moving_to_bb);
                KungFuChess::Bitboards::_putPiece($p, $moving_to_bb);
            }
            print KungFuChess::Bitboards::pretty();
            if ($moving_to_bb == $to_bb) {
                print "done!\n";
                $done = 1;
            } else {
                $self->{activeMoves}->{$moving_to_bb} = $startTime;
            }
            $next_fr_bb = $moving_to_bb;
        } elsif ($moveType == KungFuChess::Bitboards::MOVE_KNIGHT) {
            ### we remove the piece then put it next turn
            print "callback move_knight\n";
            $piece = KungFuChess::Bitboards::_getPieceBB($fr_bb);
            KungFuChess::Bitboards::_removePiece($fr_bb);
            my $msgStep = {
                'c' => 'authsuspend',
                'fr_bb'  => $fr_bb,
                'to_bb'  => $to_bb
            };
            $self->send($msgStep);
            $moveType = KungFuChess::Bitboards::MOVE_PUT_PIECE;
            $nextMoveSpeed = $self->{pieceSpeed};
        } elsif ($moveType == KungFuChess::Bitboards::MOVE_PUT_PIECE) {
            print "callback move_put_piece:$piece\n";
            print KungFuChess::Bitboards::pretty();

            $self->killPieceBB($to_bb);
            KungFuChess::Bitboards::_removePiece($to_bb);

            my $msgSpawn = {
                'c' => 'authunsuspend',
                'to_bb'  => $to_bb
            };
            $self->send($msgSpawn);

            KungFuChess::Bitboards::_putPiece($piece, $to_bb);
            print KungFuChess::Bitboards::pretty();
            print "--- done move_put_piece:$piece\n";
            $done = 1;
        } elsif ($moveType == KungFuChess::Bitboards::MOVE_CASTLE_OO) {
            $piece = KungFuChess::Bitboards::_getPieceBB($fr_bb);
            my $pieceTo = KungFuChess::Bitboards::_getPieceBB($to_bb);
            KungFuChess::Bitboards::_removePiece($fr_bb);
            KungFuChess::Bitboards::_removePiece($to_bb);
            $moveType = KungFuChess::Bitboards::MOVE_PUT_PIECE;

            my $rook_moving_to = KungFuChess::Bitboards::shift_BB(
                $fr_bb,
                KungFuChess::Bitboards::EAST
            );
            my $king_moving_to = KungFuChess::Bitboards::shift_BB(
                $to_bb,
                KungFuChess::Bitboards::WEST
            );
            print "rook moving: \n";
            print KungFuChess::Bitboards::prettyBoard($rook_moving_to);
            my $msgSus1 = {
                'c' => 'authsuspend',
                'fr_bb'  => $fr_bb,
                'to_bb'  => $king_moving_to
            };
            $self->send($msgSus1);
            my $msgSus2 = {
                'c' => 'authsuspend',
                'fr_bb'  => $to_bb,
                'to_bb'  => $rook_moving_to
            };
            $self->send($msgSus2);
            $timer = AnyEvent->timer(
                after => $self->{pieceSpeed} * 2,
                cb => sub {
                    print " callback for piece move king\n";
                    $func->($self, $func, $fr_bb, $king_moving_to, $dir, $startTime, $moveType, $piece);
                }
            );
            $timer2 = AnyEvent->timer(
                after => $self->{pieceSpeed} * 2,
                cb => sub {
                    print " callback for piece move rook\n";
                    $func->($self, $func, $fr_bb, $rook_moving_to, $dir, $startTime, $moveType, $pieceTo);
                }
            );
            return ; ## return early because there is no more movement
        } elsif ($moveType == KungFuChess::Bitboards::MOVE_CASTLE_OOO) {
            $piece = KungFuChess::Bitboards::_getPieceBB($fr_bb);
            my $pieceTo = KungFuChess::Bitboards::_getPieceBB($to_bb);
            KungFuChess::Bitboards::_removePiece($fr_bb);
            KungFuChess::Bitboards::_removePiece($to_bb);
            $moveType = KungFuChess::Bitboards::MOVE_PUT_PIECE;

            my $rook_moving_to = KungFuChess::Bitboards::shift_BB(
                KungFuChess::Bitboards::shift_BB($fr_bb, KungFuChess::Bitboards::WEST),
                KungFuChess::Bitboards::WEST
            );
            my $king_moving_to = KungFuChess::Bitboards::shift_BB($to_bb, KungFuChess::Bitboards::EAST);
            my $msgSus1 = {
                'c' => 'authsuspend',
                'fr_bb'  => $fr_bb,
                'to_bb'  => $king_moving_to
            };
            $self->send($msgSus1);
            my $msgSus2 = {
                'c' => 'authsuspend',
                'fr_bb'  => $to_bb,
                'to_bb'  => $rook_moving_to
            };
            $self->send($msgSus2);
            $timer = AnyEvent->timer(
                after => $self->{pieceSpeed} * 2,
                cb => sub {
                    print " callback for piece move king\n";
                    $func->($self, $func, $fr_bb, $king_moving_to, $dir, $startTime, $moveType, $piece);
                }
            );
            $timer2 = AnyEvent->timer(
                after => $self->{pieceSpeed} * 2,
                cb => sub {
                    print " callback for piece move rook\n";
                    $func->($self, $func, $fr_bb, $rook_moving_to, $dir, $startTime, $moveType, $pieceTo);
                }
            );
            return ; ## return early because there is no more movement
        } else {
            warn "unknown movetype $moveType\n";
        }

        if (! $done) {
            print KungFuChess::Bitboards::prettyMoving();
            KungFuChess::Bitboards::unsetMoving($fr_bb);
            KungFuChess::Bitboards::setMoving($next_fr_bb);
            print KungFuChess::Bitboards::prettyMoving();
            $timer = AnyEvent->timer(
                after => $nextMoveSpeed,
                cb => sub {
                    print " callback for piece move\n";
                    $func->($self, $func, $next_fr_bb, $to_bb, $dir, $startTime, $moveType, $piece);
                }
            );
        } else {
            $self->{timeoutSquares}->{$to_bb} = 1;
            $self->{timeoutCBs}->{$to_bb} = AnyEvent->timer(
                after => $self->{pieceRecharge},
                cb => sub {
                    print "  call back to end timeout for $to_bb\n";
                    delete $self->{timeoutSquares}->{$to_bb};
                    delete $self->{timeoutCBs}->{$to_bb};
                }
            );
        }
    };

    ### message that animates a move on the board
    my $msg = {
        'c' => 'authmove',
        'color' => $self->{color},
        'move'  => $move,
        'moveType' => $moveType
    };
    $self->send($msg);

    my $startTime = time();
    $moveStep->($self, $moveStep, $fr_bb, $to_bb, $moveDir, $startTime, $moveType, '');
    return 1;
}

sub killPieceBB {
    my ($self, $bb) = @_;

    print "killing piece $bb\n";
    my $piece = KungFuChess::Bitboards::_getPieceBB($bb);
    print "piece: $piece\n";
    if ($piece) {
        my $killMsg = {
            'c'  => 'authkill',
            'bb' => $bb
        };
        $self->send($killMsg);
    }
    if ($piece eq 'k') {
        my $msg = {
            'c' => 'playerlost',
            'color' => 'black'
        };
        print "sending black lost\n";
        $self->send($msg);
        exit; ### game over
    } elsif ($piece eq 'K') {
        my $msg = {
            'c' => 'playerlost',
            'color' => 'white'
        };
        print "sending white lost\n";
        $self->send($msg);
        exit; ### game over
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
        my $bb = KungFuChess::Bitboards::_getBBat('a' . (8 - $colCount));
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
