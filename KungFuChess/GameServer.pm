#!/usr/bin/perl
use strict; use warnings;

# this is the server that manages the pieces and connect to KungFuWeb.pl

package KungFuChess::GameServer;

use AnyEvent::WebSocket::Client;
use AnyEvent;
use JSON::XS;
#use KungFuChess::Bitboards;
use IPC::Open2;
use Config::Simple;
use Time::HiRes qw(time);
use Data::Dumper;

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

    my $cout = $self->{ai_out};
    my $timeout = 0;
    while(my $line = <$cout>) {
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

            $self->{aiStates}->{possibleMoves}->{$move} = {
                'move' => $move,
                'score' => $score,
                'ranking' => $ranking
            };
        }
    }
}

sub writeStockfishMsg {
    my $self = shift;
    my $msg = shift;
    my $cin = $self->{ai_in};
}

sub _init {
    my $self = shift;
    my $gameKey = shift;
    my $authKey = shift;
    my $speed = shift;
    my $gameType = shift;
    my $ai = shift;

    print "game key: $gameKey, authkey: $authKey, speed: $speed, gameType: $gameType\n";
    
    my $cfg = new Config::Simple('kungFuChess.cnf');
    $self->{config} = $cfg;
    $self->{gameType} = $gameType;
    if ($self->{gameType} eq '4way') {
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
        #$self->{aiStates}->{uciok} = 0;
        $self->{aiInterval} = AnyEvent->timer(
            after => 1,
            interval => 1.0,
            cb => sub {
                my ($score, $bestMoves, $moves) = KungFuChess::Bitboards::aiThink(2);
                foreach my $move (@{$bestMoves->[2]}) {
                    my $fr_bb = $moves->[2]->{$move}->[0];
                    my $to_bb = $moves->[2]->{$move}->[1];
                    $self->moveIfLegal('black', $fr_bb, $to_bb);
                }

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

    if ($msg->{c} eq 'join'){
        $self->sendAllGamePieces($msg->{connId});
    } elsif ($msg->{c} eq 'move'){
        if ($msg->{move}) {
            $self->moveIfLegal($msg->{color}, $msg->{move});
        } elsif($msg->{fr_bb}) {
            $self->moveIfLegal($msg->{color}, $msg->{fr_bb}, $msg->{to_bb});
        }
    } elsif ($msg->{c} eq 'gameOver'){
        gameOver();
    } elsif ($msg->{c} eq 'gameBegins'){
        print "game begins\n";
        # to prevent autodraw from coming up right away
        my $startTime = time() + $msg->{seconds};
        foreach my $piece ($self->getPieces()) {
            $piece->{readyToMove} = $startTime;
        }
    } elsif ($msg->{c} eq 'resign'){
            KungFuChess::Bitboards::_removeColorByName($msg->{color});
    } elsif ($msg->{c} eq 'requestDraw'){
        if ($self->checkForForceDraw) {
            my $drawMsg = {
                'c' => 'forceDraw'
            };
            $self->send($drawMsg);
        }
    }
}

sub checkForForceDraw {
    my $self = shift;
    return 0;
}

### TODO possible to send the bitboards themselves and have js decode
### also figure out a way to send these to only the person that needs it
sub sendAllGamePieces {
    my $self = shift;
    my $connId = shift;
    my $returnOnly = shift;
    my $conn = $self->{conn};

    my @msgs = ();
    foreach my $r ( @{ $self->{ranks} } ) {
        foreach my $f ( @{ $self->{files} } ) {
            my $chr = KungFuChess::Bitboards::_getPiece($f, $r);
            if ($chr) {
                my $msg = {
                    'c' => 'spawn',
                    'chr'    => $chr,
                    'square' => $f . $r,
                    'connId' => $connId
                };
                push @msgs, $msg;
            }
        }
    }
    while (my ($key, $value) = each %{$self->{timeoutSquares}}) {
        my $msg = {
            'c' => 'authstop',
            'fr_bb'  => $key,
            'time_remaining' => $self->{pieceRecharge} - (time() - $value->{'time'}),
            'connId' => $connId
        };
        push @msgs, $msg;
    }
    while (my ($key, $value) = each %{$self->{activeMoves}}) {
        my $msg = {
            'c' => 'authmove',
            'fr_bb' => $key,
            'to_bb' => $value->{to_bb},
            'connId' => $connId
        };
        push @msgs, $msg;
    }
    if (!$returnOnly) {
        foreach my $msg (@msgs) {
            $self->send($msg);
        }
    }
    return @msgs;
}

sub endGame {
    my $self = shift;

    print "game ending...\n";
    my @msgs = $self->sendAllGamePieces(undef, 1);
    my $msg = {
        'c' => 'gamePositionMsgs',
        'msgs' => encode_json(\@msgs) ### double encoded because want to store the json not use it
    };
    $self->send($msg);
    if ($self->{stockfishPid}) { system("kill $self->{stockfishPid}"); }

    ### just to prevent server disconnect from beating the game over msg
    sleep 1;
    exit;
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

sub moveIfLegal {
    my $self = shift;

    my $color = shift;
    my $move  = shift;
    my $to_move = shift;

    my $move_fr_bb = undef;
    my $move_to_bb = undef;

    my ($fr_rank, $fr_file, $to_rank, $to_file);

    ### this means we passed in bitboards
    if (defined($to_move)) {
        $move_fr_bb = $move;
        $move_to_bb = $to_move;
    } else { ### this means we passed in a string like a1b2
        ($move_fr_bb, $move_to_bb, $fr_rank, $fr_file, $to_rank, $to_file) = 
        KungFuChess::Bitboards::parseMove($move);
    }

    if (exists($self->{timeoutSquares}->{$move_fr_bb})) {
        # can't use the key because it is converted to string secretly
        $self->{timeoutSquares}->{$move_fr_bb}->{'fr_bb'} = $move_fr_bb;
        $self->{timeoutSquares}->{$move_fr_bb}->{'to_bb'} = $move_to_bb;
        $self->{timeoutSquares}->{$move_fr_bb}->{'color'} = $color;
        print "setting premove $color $move_fr_bb\n";
        return 0;
    }

    my ($colorbit, $moveType, $moveDir, $fr_bb, $to_bb)
        = KungFuChess::Bitboards::isLegalMove($move_fr_bb, $move_to_bb, $fr_rank, $fr_file, $to_rank, $to_file);

    print "moveType: $moveType\n";
    if ($moveType == 0) {
        return 0;
    }

    if ($color ne 'both') {
        if ($color eq 'white' && $colorbit != 1) {
            return 0;
        }
        if ($color eq 'black' && $colorbit != 2) {
            return 0;
        }
        if ($color eq 'red'   && $colorbit != 3) {
            return 0;
        }
        if ($color eq 'green' && $colorbit != 4) {
            return 0;
        }
    }

    my $timer = undef;
    my $timer2 = undef;
    my $moveStep = sub {
        my ($self, $func, $fr_bb, $to_bb, $dir, $startTime, $moveType, $piece) = @_;

        my $next_fr_bb = 0;
        #print KungFuChess::Bitboards::pretty();

        # something else has deleted our active move marker, probably because the piece was killed.
        # so we cannot proceed or strange things will happen!
        # only for normal moves
        if (
            ($moveType == KungFuChess::Bitboards::MOVE_NORMAL || 
                $moveType == KungFuChess::Bitboards::MOVE_PROMOTE ||
                $moveType == KungFuChess::Bitboards::MOVE_EN_PASSANT 
            ) 
            &&
            (! defined($self->{activeMoves}->{$fr_bb}) || $self->{activeMoves}->{$fr_bb}->{to_bb} != $to_bb)
        ) {
            print "undefined activeMove someone killed us\n";
            return undef;
        }
        # remove the active move from the old space
        delete $self->{activeMoves}->{$fr_bb};

        my $done = 0;
        my $nextMoveSpeed = $self->{pieceSpeed};

        if ($moveType == KungFuChess::Bitboards::MOVE_EN_PASSANT) {
            my @kill_bbs = KungFuChess::Bitboards::getEnPassantKills($fr_bb, $to_bb);
            ### if 4way it is possible to kill two!
            foreach my $kill_bb (@kill_bbs) {
                $self->killPieceBB($kill_bb);
            }
        }

        if ($moveType == KungFuChess::Bitboards::MOVE_NORMAL || 
            $moveType == KungFuChess::Bitboards::MOVE_PROMOTE || 
            $moveType == KungFuChess::Bitboards::MOVE_EN_PASSANT 
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
            my $usColor   = KungFuChess::Bitboards::occupiedColor($fr_bb);
            if ($usColor == 0) {
                print "trying to move a piece that doesn't exist!\n";
                return 0;
            }
            my $themColor = KungFuChess::Bitboards::occupiedColor($moving_to_bb);

            ### enemy collision
            if ($themColor != 0 && $themColor != $usColor) {
                ### active collision
                if (exists($self->{activeMoves}->{$moving_to_bb})) {
                    my $themStartTime = $self->{activeMoves}->{$moving_to_bb}->{start_time};
                    if ($themStartTime < $startTime) {
                        print "     and so we must die\n";
                        ### the place we are moving has a piece that started before
                        ### so we get killed.
                        $self->killPieceBB($fr_bb);

                        return 1;
                    } else {
                        print "    THEY die\n";
                        $self->killPieceBB($moving_to_bb);

                        KungFuChess::Bitboards::move($fr_bb, $moving_to_bb);
                        my $msgStep = {
                            'c' => 'authmovestep',
                            'color'  => $self->{color},
                            'fr_bb'  => $fr_bb,
                            'to_bb'  => $moving_to_bb
                        };
                        $self->send($msgStep);
                    }
                } else { ### we hit a stopped enemy
                    $self->killPieceBB($moving_to_bb);
                    KungFuChess::Bitboards::move($fr_bb, $moving_to_bb);
                    my $msgStep = {
                        'c' => 'authmovestep',
                        'color'  => $self->{color},
                        'fr_bb'  => $fr_bb,
                        'to_bb'  => $moving_to_bb
                    };
                    $self->send($msgStep);

                    $self->{"stoptimer_$moving_to_bb"} = AnyEvent->timer(
                        after => $self->{pieceSpeed},
                        cb => sub {
                            print "delay authstop\n";
                            my $msg = {
                                'c' => 'authstop',
                                'color' => $self->{color},
                                'fr_bb' => $moving_to_bb,
                            };
                            $self->send($msg);
                            delete $self->{"stoptimer_$moving_to_bb"};
                        }
                    );

                    ### to make us done
                    $to_bb = $moving_to_bb;
                }
            } elsif ($themColor == $usColor) { ## we hit ourselves, stop!
                ### message that animates a move on the board
                my $msg = {
                    'c' => 'authstop',
                    'color' => $self->{color},
                    'fr_bb' => $fr_bb,
                };
                $self->send($msg);

                ### to make us done at the spot we started
                $to_bb = $fr_bb;
                $moving_to_bb = $fr_bb;
            } else { ### moving into a free space
                KungFuChess::Bitboards::move($fr_bb, $moving_to_bb);
                my $msgStep = {
                    'c' => 'authmovestep',
                    'color'  => $self->{color},
                    'fr_bb'  => $fr_bb,
                    'to_bb'  => $moving_to_bb
                };
                $self->send($msgStep);
            }

            if ($moveType == KungFuChess::Bitboards::MOVE_PROMOTE) {
                my $msgPromote = {
                    'c' => 'promote',
                    'bb'  => $moving_to_bb,
                };
                $self->send($msgPromote);
                my $pawn = KungFuChess::Bitboards::_getPieceBB($moving_to_bb);
                KungFuChess::Bitboards::_removePiece($moving_to_bb);
                KungFuChess::Bitboards::_putPiece($pawn + 5, $moving_to_bb);
            }
            if ($moving_to_bb == $to_bb) {
                $done = 1;
            }
            if (! $done){
                $self->{activeMoves}->{$moving_to_bb} = {
                    'to_bb' => $to_bb,
                    'start_time' => $startTime
                };
            }
            $next_fr_bb = $moving_to_bb;
        } elsif ($moveType == KungFuChess::Bitboards::MOVE_KNIGHT) {
            ### we remove the piece then put it next turn
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
            $self->killPieceBB($to_bb);

            my $msgSpawn = {
                'c' => 'authunsuspend',
                'chr' => $piece,
                'to_bb'  => $to_bb
            };
            $self->send($msgSpawn);

            KungFuChess::Bitboards::_putPiece($piece, $to_bb);
            $done = 1;
        } elsif ($moveType == KungFuChess::Bitboards::MOVE_CASTLE_OO) {
            $piece = KungFuChess::Bitboards::_getPieceBB($fr_bb);
            my $pieceTo = KungFuChess::Bitboards::_getPieceBB($to_bb);
            KungFuChess::Bitboards::_removePiece($fr_bb);
            KungFuChess::Bitboards::_removePiece($to_bb);
            $moveType = KungFuChess::Bitboards::MOVE_PUT_PIECE;

            my $rook_moving_to = 0;
            if ($colorbit == KungFuChess::Bitboards::WHITE || $colorbit == KungFuChess::Bitboards::BLACK) {
                ### 4way bitboards are messed up and EAST and WEST are switched. Actually seems to effect nothing else.
                if ($self->{gameType} eq '4way') {
                    $rook_moving_to = KungFuChess::Bitboards::shift_BB($fr_bb, KungFuChess::Bitboards::WEST);
                } else {
                    $rook_moving_to = KungFuChess::Bitboards::shift_BB($fr_bb, KungFuChess::Bitboards::EAST);
                }
            } else {
                $rook_moving_to = KungFuChess::Bitboards::shift_BB($fr_bb, KungFuChess::Bitboards::SOUTH);
            }
            my $king_moving_to = 0;
            if ($colorbit == KungFuChess::Bitboards::WHITE || $colorbit == KungFuChess::Bitboards::BLACK) {
                if ($self->{gameType} eq '4way') {
                    $king_moving_to = KungFuChess::Bitboards::shift_BB($to_bb, KungFuChess::Bitboards::EAST);
                } else {
                    $king_moving_to = KungFuChess::Bitboards::shift_BB($to_bb, KungFuChess::Bitboards::WEST);
                }
            } else {
                $king_moving_to = KungFuChess::Bitboards::shift_BB($to_bb, KungFuChess::Bitboards::NORTH);
            }
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
                    $func->($self, $func, $fr_bb, $king_moving_to, $dir, $startTime, $moveType, $piece);
                }
            );
            $timer2 = AnyEvent->timer(
                after => $self->{pieceSpeed} * 2,
                cb => sub {
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

            my $rook_moving_to = 0;
            if ($colorbit == KungFuChess::Bitboards::WHITE || $colorbit == KungFuChess::Bitboards::BLACK) {
                ### 4way bitboards are messed up and EAST and WEST are switched. Actually seems to effect nothing else.
                if ($self->{gameType} eq '4way') {
                    $rook_moving_to = KungFuChess::Bitboards::shift_BB(
                        KungFuChess::Bitboards::shift_BB($fr_bb, KungFuChess::Bitboards::EAST),
                        KungFuChess::Bitboards::EAST);
                } else {
                    $rook_moving_to = KungFuChess::Bitboards::shift_BB(
                        KungFuChess::Bitboards::shift_BB($fr_bb, KungFuChess::Bitboards::WEST),
                        KungFuChess::Bitboards::WEST);
                }
            } else {
                $rook_moving_to = KungFuChess::Bitboards::shift_BB(
                    KungFuChess::Bitboards::shift_BB($fr_bb, KungFuChess::Bitboards::NORTH),
                    KungFuChess::Bitboards::NORTH);
            }
            my $king_moving_to = 0;
            if ($colorbit == KungFuChess::Bitboards::WHITE || $colorbit == KungFuChess::Bitboards::BLACK) {
                ### 4way bitboards are messed up and EAST and WEST are switched. Actually seems to effect nothing else.
                if ($self->{gameType} eq '4way') {
                    $king_moving_to = KungFuChess::Bitboards::shift_BB($to_bb, KungFuChess::Bitboards::WEST);
                } else {
                    $king_moving_to = KungFuChess::Bitboards::shift_BB($to_bb, KungFuChess::Bitboards::EAST);
                }
            } else {
                $king_moving_to = KungFuChess::Bitboards::shift_BB($to_bb, KungFuChess::Bitboards::SOUTH);
            }
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
                    $func->($self, $func, $fr_bb, $king_moving_to, $dir, $startTime, $moveType, $piece);
                }
            );
            $timer2 = AnyEvent->timer(
                after => $self->{pieceSpeed} * 2,
                cb => sub {
                    $func->($self, $func, $fr_bb, $rook_moving_to, $dir, $startTime, $moveType, $pieceTo);
                }
            );
            return ; ## return early because there is no more movement
        } else {
            warn "unknown movetype $moveType\n";
        }

        if (! $done) {
            KungFuChess::Bitboards::unsetMoving($fr_bb);
            KungFuChess::Bitboards::setMoving($next_fr_bb);
            $timer = AnyEvent->timer(
                after => $nextMoveSpeed,
                cb => sub {
                    $func->($self, $func, $next_fr_bb, $to_bb, $dir, $startTime, $moveType, $piece);
                }
            );
        } else {
            my $time = time();
            $self->{timeoutSquares}->{$to_bb} = { 'time' => $time };
            $self->{timeoutCBs}->{$to_bb} = AnyEvent->timer(
                after => $self->{pieceRecharge} + $nextMoveSpeed,
                cb => sub {
                    KungFuChess::Bitboards::clearEnPassant($to_bb);
                    # TODO replicate in Bitboards
                    #KungFuChess::Bitboards::unsetFrozen($to_bb);

                    ### if the time doesn't match, another piece has moved here
                    if ($time == $self->{timeoutSquares}->{$to_bb}->{'time'}) { 
                        my $timeoutData = $self->{timeoutSquares}->{$to_bb};
                        delete $self->{timeoutSquares}->{$to_bb};
                        delete $self->{timeoutCBs}->{$to_bb};
                        ### signal that we have a premove
                        if ($timeoutData->{color}) {
                            $self->moveIfLegal(
                                $timeoutData->{color},
                                $timeoutData->{fr_bb},
                                $timeoutData->{to_bb}
                            );
                        }
                    } else {
                        print " new piece?\n";
                    }
                }
            );
            #return;
        }
    };

    ### message that animates a move on the board
    my $msg = {
        'c' => 'authmove',
        'color' => $self->{color},
        'fr_bb' => $fr_bb,
        'to_bb' => $to_bb,
        'moveType' => $moveType
    };
    $self->send($msg);

    my $startTime = time();
    ### usually times are set here but we set just to 1 to show it exists
    $self->{activeMoves}->{$fr_bb} = {
        to_bb => $to_bb,
        start_time => 1
    };
    $moveStep->($self, $moveStep, $fr_bb, $to_bb, $moveDir, $startTime, $moveType, '');

    KungFuChess::Bitboards::resetAiBoards();
    return 1;
}

sub killPieceBB {
    my ($self, $bb) = @_;

    ### mark that it is no longer active, stopping any movement
    my $piece = KungFuChess::Bitboards::_getPieceBB($bb);
    delete $self->{activeMoves}->{$bb};
    if ($piece) {
        my $killMsg = {
            'c'  => 'authkill',
            'bb' => $bb
        };
        $self->send($killMsg);
        if ($piece % 100 == KungFuChess::Bitboards::KING) {
            KungFuChess::Bitboards::_removeColorByPiece($piece);
            my $color =
                $piece < 200 ? 'white' :
                $piece < 300 ? 'black' :
                $piece < 400 ? 'red'   : 'green';
            my $msg = {
                'c' => 'playerlost',
                'color' => $color,
            };
            $self->send($msg);
        }
    }
    KungFuChess::Bitboards::_removePiece($bb);
}

sub gameOver() {
    print "gameOver()\n";
    exit;
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
