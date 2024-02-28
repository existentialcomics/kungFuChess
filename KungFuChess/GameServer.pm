#!/usr/bin/perl
use strict; use warnings;

# this is the server that manages the pieces and connect to KungFuWeb.pl

package KungFuChess::GameServer;

use AnyEvent::WebSocket::Client;
use AnyEvent;
use JSON::XS;
use IPC::Open2;
use Config::Simple;
use Time::HiRes qw(time);
use Data::Dumper;
use KungFuChess::BBHash;

### taken from Chess::Rep
### can't use the whole lib because of chess specific rules like check
use constant ({
    FEN_STANDARD => 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',

    TACTIC_PEEKABOO     => 0x01, # we have dodged ourself
    TACTIC_PUNCHTHROUGH => 0x02, # the enemy has dodged us
    TACTIC_DODGED       => 0x04, # the enemy has dodged us
    TACTIC_SWEEP        => 0x08, # we have swept a piece
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

sub setAdjustedSpeed {
    my ($self, $pieceSpeed, $pieceRecharge, $speedAdj) = @_;

    my $whiteAdj = 1;
    my $blackAdj = 1;
    my $redAdj = 1;
    my $greenAdj = 1;
    if ($speedAdj) {
        ($whiteAdj, $blackAdj, $redAdj, $greenAdj) = split(':', $speedAdj);
    }

    $self->{1}->{pieceSpeed} = $pieceSpeed * $whiteAdj;
    $self->{1}->{pieceRecharge} = $pieceRecharge * $whiteAdj;

    $self->{2}->{pieceSpeed} = $pieceSpeed * $blackAdj;
    $self->{2}->{pieceRecharge} = $pieceRecharge * $blackAdj;
    
    $self->{3}->{pieceSpeed} = $pieceSpeed * $redAdj;
    $self->{3}->{pieceRecharge} = $pieceRecharge * $redAdj;

    $self->{4}->{pieceSpeed} = $pieceSpeed * $greenAdj;
    $self->{4}->{pieceRecharge} = $pieceRecharge * $greenAdj;
}

sub _init {
    my $self = shift;
    my $gameKey = shift;
    my $authKey = shift;
    my $pieceSpeed = shift;
    my $pieceRecharge = shift;
    my $speedAdj = shift;
    my $gameType = shift;
    my $fen = shift;

    print "game key: $gameKey, authkey: $authKey, speed: $pieceSpeed/$pieceRecharge, adj: $speedAdj, gameType: $gameType\n";
    
    $self->{continuous} = 1;
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

    ### squares that always cause stop/pause (when castling)
    $self->{stopSquares}    = {};

    ### time when a piece last vacated this sq
    # for achievements. This is by color
    $self->{leaveSqTimes}    = {
        KungFuChess::Bitboards::WHITE => {},
        KungFuChess::Bitboards::BLACK => {},
        #KungFuChess::Bitboards::RED => {},
        #KungFuChess::Bitboards::GREEN => {},
    };
    ### this tracks when the piece left it's LAST sq
    $self->{lastLeaveSqTimes}    = {
        KungFuChess::Bitboards::WHITE => {},
        KungFuChess::Bitboards::BLACK => {},
        #KungFuChess::Bitboards::RED => {},
        #KungFuChess::Bitboards::GREEN => {},
    };
    ### tracks for combos, etc
    $self->{killStack}    = {
        KungFuChess::Bitboards::WHITE => [],
        KungFuChess::Bitboards::BLACK => [],
        #KungFuChess::Bitboards::RED => {},
        #KungFuChess::Bitboards::GREEN => {},
    };
    $self->{moveStack}    = {
        KungFuChess::Bitboards::WHITE => [],
        KungFuChess::Bitboards::BLACK => [],
        #KungFuChess::Bitboards::RED => {},
        #KungFuChess::Bitboards::GREEN => {},
    };

    ### keep track of original move times for stopped pieces
    # for sweeps and achievements
    $self->{startMoves} = {};
    $self->{stopMoves}  = {};
    ### squares that are on hold before they can move again
    $self->{timeoutSquares} = {};
    $self->{timeoutCBs} = {};

    $self->{basePieceSpeed} = $pieceSpeed;
    $self->{basePieceRecharge} = $pieceRecharge;

    $self->setAdjustedSpeed($pieceSpeed, $pieceRecharge, $speedAdj);

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

    my $wsDomain = 'ws://localhost:3001/ws';

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
            warn $@;
            exit;
        }
           
        my $msg = {
           'c' => 'authjoin',
        };
        $self->send($msg);

        if ($fen) {
            KungFuChess::Bitboards::loadFENstring($fen);
        } else {
            $self->setupInitialBoard();
        }

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
            exit;
        });

        # close the connection (either inside or
        # outside another callback)
        # $connection->close;

    });

    $self->{client} = $client;

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

    if ($msg->{fr_bb}) {
        KungFuChess::Bitboards::strToInt($msg->{fr_bb});
    }
    if ($msg->{to_bb}) {
        KungFuChess::Bitboards::strToInt($msg->{to_bb});
    }
    if ($msg->{bb}) {
        KungFuChess::Bitboards::strToInt($msg->{bb});
    }

    if ($msg->{c} eq 'join'){
        $self->sendAllGamePieces($msg->{connId});
    } elsif ($msg->{c} eq 'cancelPremove'){
        my $bb = KungFuChess::Bitboards::parseSquare($msg->{sq});
        if ($self->{timeoutSquares}->{$bb} && $self->{timeoutSquares}->{$bb}->{'color'}) {
            if ($msg->{color} eq $self->{timeoutSquares}->{$bb}->{'color'}) {
                $msg->{fr_bb} = $self->{timeoutSquares}->{$bb}->{'fr_bb'};
                $msg->{to_bb} = $self->{timeoutSquares}->{$bb}->{'to_bb'};
                delete $self->{timeoutSquares}->{$bb}->{'fr_bb'};
                delete $self->{timeoutSquares}->{$bb}->{'to_bb'};
                delete $self->{timeoutSquares}->{$bb}->{'color'};
                $msg->{c} = 'authcancelpremove';
                $self->send($msg);
            }
        }
    } elsif ($msg->{c} eq 'move'){
        if ($msg->{move}) {
            $self->moveIfLegal($msg->{color}, $msg->{move});
        } elsif($msg->{fr_bb}) {
            $self->moveIfLegal($msg->{color}, $msg->{fr_bb}, $msg->{to_bb});
        }
    } elsif ($msg->{c} eq 'FENload'){
        KungFuChess::Bitboards::loadFENstring($msg->{FEN});
        my $refreshMsg = {
            'c' => 'forceRefresh'
        };
        $self->send($refreshMsg);
    } elsif ($msg->{c} eq 'berserk'){
        $self->setAdjustedSpeed($self->{basePieceSpeed}, $self->{basePieceRecharge}, $msg->{speedAdj});
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
    my $colorOnly = shift;
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
        ### TODO we need to adjust for color here on speed advantage games.
        ### not a huge deal since this is only on refresh
        my $msg = {
            'c' => 'authstop',
            'fr_bb'  => $key,
            'time_remaining' => $self->{1}->{pieceRecharge} - (time() - $value->{'time'}),
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
    if ($msg->{'bb'})    { $msg->{'bb'}    = "$msg->{'bb'}";       }
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

    ### trying to move a currently moving piece
    if (exists($self->{activeMoves}->{$move_fr_bb})) {
        return 0;
    }

    ### here we queue up a premove
    if (exists($self->{timeoutSquares}->{$move_fr_bb})) {
        # can't use the key because it is converted to string secretly
        $self->{timeoutSquares}->{$move_fr_bb}->{'fr_bb'} = $move_fr_bb;
        $self->{timeoutSquares}->{$move_fr_bb}->{'to_bb'} = $move_to_bb;
        $self->{timeoutSquares}->{$move_fr_bb}->{'color'} = $color;
        my $msg = {
            'c' => 'authPremove',
            'color' => $color,
            'fr_bb' => $move_fr_bb,
            'to_bb' => $move_to_bb,
        };
        $self->send($msg);
        return 0;
    }

    my ($colorbit, $moveType, $moveDir, $fr_bb, $to_bb)
        = KungFuChess::Bitboards::isLegalMove($move_fr_bb, $move_to_bb, $fr_rank, $fr_file, $to_rank, $to_file);

    my $usColor   = KungFuChess::Bitboards::occupiedColor($fr_bb);
    my $themColor = KungFuChess::Bitboards::occupiedColor($to_bb);

    ### capture
    if ($usColor && $themColor && ($usColor != $themColor)) {
        ### distance of one, we want to prevent quick captures here
        #   quick capture is a piece that just landed, we wait half a beat
        #   before allowing it
        if ($to_bb == KungFuChess::Bitboards::shift_BB($fr_bb, $moveDir) ) {
            my $isQuickCapture = (
                ($self->{stopMoves}->{$to_bb}
                   && $self->{stopMoves}->{$to_bb} > time() - ($self->{$colorbit}->{pieceSpeed}) / 2)
            );

            if ($isQuickCapture) {
                $moveType = 0;
            }

            ### disallowing one square moving into sweep
            #   mostly to protect AI from being stupid
            #   probably should be legal but SUPER rare tactic
            my $isOneSpaceMoving = exists($self->{activeMoves}->{$to_bb});
            if ($isOneSpaceMoving) {
                $moveType = 0;
            }
        }
    }

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

    ### fr_bb means the square we are on now, NOT the start sq
    my $moveStep = sub {
        my (
            $self,
            $func,
            $fr_bb,
            $to_bb,
            $dir,
            $startTime,
            $lastStartTime,
            $moveType,
            $piece,
            $colorbit,
            $restartAnimation,
            $tactics
        ) = @_;

        if ($restartAnimation) {
            my $msg = {
                'c' => 'authcontinue',
                'color' => $colorbit,
                'fr_bb' => $fr_bb,
            };
            $self->send($msg);
        }
        my $next_fr_bb = 0;

        # something else has deleted our active move marker, probably because the piece was killed.
        # so we cannot proceed or strange things will happen!
        # only for normal moves
        if (
            ($moveType == KungFuChess::Bitboards::MOVE_NORMAL || 
                $moveType == KungFuChess::Bitboards::MOVE_PROMOTE ||
                $moveType == KungFuChess::Bitboards::MOVE_DOUBLE_PAWN ||
                $moveType == KungFuChess::Bitboards::MOVE_EN_PASSANT 
            ) 
            &&
            (! defined($self->{activeMoves}->{$fr_bb}) || $self->{activeMoves}->{$fr_bb}->{to_bb} != $to_bb)
        ) {
            if (! defined($self->{activeMoves}->{$fr_bb})){
                print "\nundefined activeMove someone killed us\n";
                print $fr_bb;
                print " -> ";
                print $to_bb;
                warn "undefined $fr_bb activeMove someone killed us\n";
            } else {
                print "\nmistach activeMove someone killed us\n";
                print $fr_bb;
                print " -> ";
                print $to_bb;
                warn "mistach $fr_bb activeMove someone killed us\n";
            }
            return undef;
        }
        # remove the active move from the old space
        delete $self->{activeMoves}->{$fr_bb};

        my $done = 0;
        my $nextMoveSpeed = $self->{$colorbit}->{pieceSpeed};

        if ($moveType == KungFuChess::Bitboards::MOVE_EN_PASSANT) {
            my @kill_bbs = KungFuChess::Bitboards::getEnPassantKills($fr_bb, $to_bb);
            ### if 4way it is possible to kill two!
            foreach my $kill_bb (@kill_bbs) {
                $self->killPieceBB($kill_bb, $colorbit, $tactics, $startTime, $lastStartTime);
            }
        }

        ####################################################################################
        ### regularish moves
        ###
        if ($moveType == KungFuChess::Bitboards::MOVE_NORMAL || 
            $moveType == KungFuChess::Bitboards::MOVE_PROMOTE || 
            $moveType == KungFuChess::Bitboards::MOVE_DOUBLE_PAWN ||
            $moveType == KungFuChess::Bitboards::MOVE_EN_PASSANT 
        ) {
            my $moving_to_bb = 0;
            ### for DIR_NONE it means we want to move directly there (King)
            if ($dir == KungFuChess::Bitboards::DIR_NONE) {
                $moving_to_bb = $to_bb;
            } else {
                $moving_to_bb = KungFuChess::Bitboards::shift_BB($fr_bb, $dir);
            }
            ######################## TACTICS
            if (
                exists($self->{leaveSqTimes}->{$colorbit}->{$moving_to_bb}) &&
                $self->{leaveSqTimes}->{$colorbit}->{$moving_to_bb} > $startTime
            ) {
                $tactics |= TACTIC_PEEKABOO;
            }
            # TODO only works in 2way
            my $enemyColorbit = ($colorbit == KungFuChess::Bitboards::WHITE ? 
                KungFuChess::Bitboards::BLACK : KungFuChess::Bitboards::WHITE);
            if (
                exists($self->{leaveSqTimes}->{$enemyColorbit}->{$moving_to_bb}) &&
                $self->{leaveSqTimes}->{$enemyColorbit}->{$moving_to_bb} > $startTime
            ) {
                $tactics |= TACTIC_PUNCHTHROUGH;
                $tactics |= TACTIC_DODGED;

                $self->sendTactic($enemyColorbit, 'dodged');
            }
            ######################## END TACTICS

            ### TODO replace this with a perfect hash of all 64 bb destinations
            ### only check this if the moving bitboard is occupied.
            ### if the piece is ours, stop here.
            my $usColor   = KungFuChess::Bitboards::occupiedColor($fr_bb);
            if ($usColor == 0) {
                warn "trying to move a piece that doesn't exist!\n";
                return 0;
            }
            my $themColor = KungFuChess::Bitboards::occupiedColor($moving_to_bb);

            ### enemy collision
            if ($themColor != 0 && $themColor != $usColor) {
                ### active collision
                if (exists($self->{activeMoves}->{$moving_to_bb})) {
                    my $themStartTime = $self->{activeMoves}->{$moving_to_bb}->{start_time};
                    if ($themStartTime < $startTime) {
                        $tactics |= TACTIC_SWEEP;
                        ### the place we are moving has a piece that started before
                        ### so we get killed.
                        $self->killPieceBB($fr_bb, $colorbit, $tactics, $startTime, $lastStartTime);

                        return 1;
                    } else {
                        $tactics |= TACTIC_SWEEP;
                        $self->killPieceBB($moving_to_bb, $colorbit, $tactics, $startTime, $lastStartTime);

                        KungFuChess::Bitboards::move($fr_bb, $moving_to_bb);
                        my $msgStep = {
                            'c' => 'authmovestep',
                            'color'  => $colorbit,
                            'fr_bb'  => $fr_bb,
                            'to_bb'  => $moving_to_bb
                        };
                        $self->send($msgStep);
                    }
                } else { ### we hit a stopped enemy
                    ### UNCOMMENT to restore full sweep
                    ### stop unless the piece starting moving after us;
                    #my $shouldStop = (! $self->{startMoves}->{$moving_to_bb}
                        #|| $self->{startMoves}->{$moving_to_bb} < $startTime);

                    ### stop if the piece has been still for at least one beat (1 sec standard)
                    ### OR if the piece started before (i.e. would have swept us
                    my $shouldStop = (
                            (! $self->{stopMoves}->{$moving_to_bb}
                            || $self->{stopMoves}->{$moving_to_bb} < time() - $self->{$colorbit}->{pieceSpeed})
                        ) || (
                            (! $self->{startMoves}->{$moving_to_bb}
                            || $self->{startMoves}->{$moving_to_bb} < $startTime)
                        );

                    ### double pawn moves always stop if they hit something, even enemy
                    ### AND we don't move!
                    if ($moveType == KungFuChess::Bitboards::MOVE_DOUBLE_PAWN) {
                        $shouldStop = 2; ### 2 means stop now...
                    } else {
                        if (! $shouldStop) {
                            $tactics |= TACTIC_SWEEP;
                        }
                        # technically if we don't stop here it's a sweep
                        # they didn't arrive in time to complete the animation and stand their ground
                        $self->killPieceBB($moving_to_bb, $colorbit, $tactics, $startTime, $lastStartTime);
                        KungFuChess::Bitboards::move($fr_bb, $moving_to_bb);
                        my $msgStep = {
                            'c' => 'authmovestep',
                            'color'  => $colorbit,
                            'fr_bb'  => $fr_bb,
                            'to_bb'  => $moving_to_bb
                        };
                        $self->send($msgStep);
                    }
                    if ($shouldStop) {
                        my $msg = {
                            'c' => 'authstop',
                            'delay' => ($shouldStop == 2 ? 0 : $self->{$colorbit}->{pieceSpeed}),
                            'color' => $colorbit,
                            'fr_bb' => ($shouldStop == 2 ? $fr_bb : $moving_to_bb),
                        };
                        $self->send($msg);
                        delete $self->{"stoptimer_$moving_to_bb"};

                        ### to make us done
                        $to_bb = $moving_to_bb;
                    }
                }
            } elsif ($themColor == $usColor || exists($self->{stopSquares}->{$moving_to_bb})) { ## we hit ourselves, stop! (or a stop sq)
                ### we hit our own piece, but it is moving so let's politely wait for it to get out of the way.
                if (exists($self->{activeMoves}->{$moving_to_bb})
                    && ! KungFuChess::Bitboards::movingOppositeDirs($moveDir, $self->{activeMoves}->{$moving_to_bb}->{moveDir})
                    ) {
                    ### message that animates a move on the board
                    my $msg = {
                        'c' => 'authpause',
                        'color' => $colorbit,
                        'fr_bb' => $fr_bb,
                    };
                    $self->send($msg);

                    $restartAnimation = 1;
                    ### we are still on the same spot
                    $moving_to_bb = $fr_bb;
                } else {
                    ### message that animates a move on the board
                    my $msg = {
                        'c' => 'authstop',
                        'color' => $colorbit,
                        'fr_bb' => $fr_bb,
                    };
                    $self->send($msg);

                    ### to make us done at the spot we started
                    $to_bb = $fr_bb;
                    $moving_to_bb = $fr_bb;
                }
            } else { ### moving into a free space
                KungFuChess::Bitboards::move($fr_bb, $moving_to_bb);
                my $msgStep = {
                    'c' => 'authmovestep',
                    'color'  => $colorbit,
                    'fr_bb'  => $fr_bb,
                    'to_bb'  => $moving_to_bb
                };
                $self->send($msgStep);
            }

            ### send a promote if we reached the end
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
                    'start_time' => $startTime,
                    'moveDir' => $moveDir
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
            $nextMoveSpeed = $self->{$colorbit}->{pieceSpeed};
        } elsif ($moveType == KungFuChess::Bitboards::MOVE_PUT_PIECE) {
            #################### TACTICS
            my $enemyColorbit = ($colorbit == KungFuChess::Bitboards::WHITE ? 
                KungFuChess::Bitboards::BLACK : KungFuChess::Bitboards::WHITE);
            if (
                exists($self->{leaveSqTimes}->{$enemyColorbit}->{$to_bb}) &&
                $self->{leaveSqTimes}->{$enemyColorbit}->{$to_bb} > $startTime
            ) {
                $self->sendTactic($enemyColorbit, 'dodged');
            }
            #################### end TACTICS

            ###------------------ comment this out to free horsey
            ### enemy collision active
            my $themColor = KungFuChess::Bitboards::occupiedColor($to_bb);
            if ($themColor != 0
                && $themColor != $colorbit
                && exists($self->{activeMoves}->{$to_bb})
                && ($self->{activeMoves}->{$to_bb}->{start_time} < $startTime)
            ) {
                ### tell the client to remove the suspended piece
                my $msgSpawn = {
                    'c' => 'authkillsuspend',
                    'chr' => $piece,
                    'to_bb'  => $to_bb
                };
                $self->send($msgSpawn);

                return 1;
            }
            ###-----------------

            $self->killPieceBB($to_bb, $colorbit, $tactics, $startTime, $lastStartTime);
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
                $rook_moving_to = KungFuChess::Bitboards::shift_BB($fr_bb, KungFuChess::Bitboards::EAST);
            } else {
                $rook_moving_to = KungFuChess::Bitboards::shift_BB($fr_bb, KungFuChess::Bitboards::SOUTH);
            }
            my $king_moving_to = 0;
            if ($colorbit == KungFuChess::Bitboards::WHITE || $colorbit == KungFuChess::Bitboards::BLACK) {
                $king_moving_to = KungFuChess::Bitboards::shift_BB($to_bb, KungFuChess::Bitboards::WEST);
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
            $self->{stopSquares}->{$king_moving_to} = 1;
            $self->{stopSquares}->{$rook_moving_to} = 1;
            $timer = AnyEvent->timer(
                after => $self->{$colorbit}->{pieceSpeed},
                cb => sub {
                    #### undef fr_bb to prevent it deleting random active moves
                    $func->($self, $func, undef, $king_moving_to, $dir, $startTime, $lastStartTime, $moveType, $piece, $colorbit, $restartAnimation);
                    delete $self->{stopSquares}->{$king_moving_to};
                }
            );
            $timer2 = AnyEvent->timer(
                after => $self->{$colorbit}->{pieceSpeed},
                cb => sub {
                    $func->($self, $func, undef, $rook_moving_to, $dir, $startTime, $lastStartTime, $moveType, $pieceTo, $colorbit, $restartAnimation);
                    delete $self->{stopSquares}->{$rook_moving_to};
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
                $rook_moving_to = KungFuChess::Bitboards::shift_BB($fr_bb, KungFuChess::Bitboards::WEST);
            } else {
                $rook_moving_to = KungFuChess::Bitboards::shift_BB($fr_bb, KungFuChess::Bitboards::NORTH);
            }
            my $king_moving_to = 0;
            if ($colorbit == KungFuChess::Bitboards::WHITE || $colorbit == KungFuChess::Bitboards::BLACK) {
                $king_moving_to = KungFuChess::Bitboards::shift_BB(
                    KungFuChess::Bitboards::shift_BB($to_bb, KungFuChess::Bitboards::EAST),
                    KungFuChess::Bitboards::EAST);
            } else {
                $king_moving_to = KungFuChess::Bitboards::shift_BB(
                    KungFuChess::Bitboards::shift_BB($to_bb, KungFuChess::Bitboards::SOUTH),
                    KungFuChess::Bitboards::SOUTH);
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
            $self->{stopSquares}->{$king_moving_to} = 1;
            $timer = AnyEvent->timer(
                after => $self->{$colorbit}->{pieceSpeed},
                cb => sub {
                    $func->($self, $func, undef, $king_moving_to, $dir, $startTime, $lastStartTime, $moveType, $piece, $colorbit, $restartAnimation);
                    delete $self->{stopSquares}->{$king_moving_to};
                }
            );
            $self->{stopSquares}->{$rook_moving_to} = 1;
            $timer2 = AnyEvent->timer(
                after => $self->{$colorbit}->{pieceSpeed},
                cb => sub {
                    $func->($self, $func, undef, $rook_moving_to, $dir, $startTime, $lastStartTime, $moveType, $pieceTo, $colorbit, $restartAnimation);
                    delete $self->{stopSquares}->{$rook_moving_to};
                }
            );
            return ; ## return early because there is no more movement
        } else {
            warn "unknown movetype $moveType\n";
        }

        #### DONE
        if ($done) {
            my $time = time();

            $self->{startMoves}->{$to_bb} = $startTime;
            $self->{stopMoves}->{$to_bb}  = $time;
            $self->{timeoutSquares}->{$to_bb} = { 'time' => $time };
            my $msg = {
                'c' => 'authstop',
                'expected' => 1,
                'fr_bb'  => $to_bb,
                'time_remaining' => $self->{$colorbit}->{pieceRecharge},
            };
            $self->send($msg);
            $self->{timeoutCBs}->{$to_bb} = AnyEvent->timer(
                after => $self->{$colorbit}->{pieceRecharge} + $nextMoveSpeed,
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
                        warn " new piece?\n";
                    }
                }
            );
            #return;
        } else {
            KungFuChess::Bitboards::unsetMoving($fr_bb);
            KungFuChess::Bitboards::setMoving($next_fr_bb);
            $timer = AnyEvent->timer(
                after => $nextMoveSpeed,
                cb => sub {
                    $func->(
                        $self,
                        $func,
                        $next_fr_bb,
                        $to_bb,
                        $dir,
                        $startTime,
                        $lastStartTime,
                        $moveType,
                        $piece,
                        $colorbit,
                        $restartAnimation,
                        $tactics
                    );
                }
            );
        }
    };

    ### message that animates a move on the board
    my $msg = {
        'c' => 'authmove',
        'color' => $colorbit,
        'fr_bb' => $fr_bb,
        'to_bb' => $to_bb,
        'dir' => $moveDir, ### to help AI find move path
        'moveType' => $moveType
    };
    $self->send($msg);

    push(@{$self->{moveStack}->{$colorbit}}, time());

    my $startTime = time();
    ### usually times are set here but we set just to 1 to show it exists
    $self->{activeMoves}->{$fr_bb} = {
        to_bb => $to_bb,
        start_time => 1,
        moveDir => $moveDir,
    };
    my $restartAnimation = 0;
    my $tactics = 0;

    $self->{leaveSqTimes}->{$colorbit}->{$fr_bb} = time();
    my $lastStartTime = $self->{stopMoves}->{$fr_bb} // 0.0;

    #print "init move starttime: $startTime, $lastStartTime\n";

    ### call the function
    $moveStep->(
        $self,
        $moveStep,
        $fr_bb,
        $to_bb,
        $moveDir,
        $startTime,
        $lastStartTime,
        $moveType,
        '', # piece
        $colorbit,
        $restartAnimation,
        $tactics
    );

    return 1;
}

### number of items in a stack in x seconds
sub numberInStack {
    my $timeDiff = shift;

    my $count = 0;
    while (my $stackTime = pop (@_)) {
        $count++;
        if ($timeDiff < (time() - $stackTime)) { print "less than, exiting at $count\n"; return $count; }
    }
    $count++;
    return $count;
}

sub killPieceBB {
    my ($self, $bb, $killerColorbit, $tactics, $startTime, $lastStartTime) = @_;

    my $wasFrozen = exists($self->{timeoutSquares}->{$bb});

    ### mark that it is no longer active, stopping any movement
    my $piece = KungFuChess::Bitboards::_getPieceBB($bb);
    if ($piece) {
        my $deathColorBit = KungFuChess::Bitboards::colorOfPiece($piece);
        my $killMsg = {
            'c'  => 'authkill',
            'bb' => $bb
        };
        my $comboKills = numberInStack(0.5, @{$self->{killStack}->{$killerColorbit}});
        if ($comboKills >= 2) {
            $self->sendTactic($killerColorbit, 'combo of ' . $comboKills);
        }
        ### distraction moves
        if (
            ! $wasFrozen &&
            $piece != KungFuChess::Bitboards::PAWN &&
            (time() - $startTime) > 1.9 )
        {
            my $distractmoves = numberInStack(3, @{$self->{moveStack}->{$killerColorbit}});
            if ($distractmoves > 2) {
                $self->sendTactic($killerColorbit, 'divserion');
            }
        }
        delete $self->{leaveSqTimes}->{$deathColorBit}->{$bb};
        delete $self->{lastLeaveSqTimes}->{$deathColorBit}->{$bb};

        push(@{$self->{killStack}->{$killerColorbit}}, time());

        ### TACTICS
        ### we capture a frozen piece who began moving before we did (last move)
        if (
            $wasFrozen && exists($self->{startMoves}->{$bb}) &&
            $piece != KungFuChess::Bitboards::PAWN &&
            $self->{startMoves}->{$bb} < $lastStartTime
        ) {
            $self->sendTactic($killerColorbit, 'anticipate');
        }

        if ($tactics & TACTIC_SWEEP) {
            $killMsg->{is_sweep} = 1;
            $self->sendTactic($killerColorbit, 'sweep');
        }
        if ($tactics & TACTIC_PEEKABOO) {
            $self->sendTactic($killerColorbit, 'peekaboo');
        }
        if ($tactics & TACTIC_PUNCHTHROUGH) {
            $self->sendTactic($killerColorbit, 'punch through');
        }
        ### END TACTCIS
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
    delete $self->{startMoves}->{$bb};
    delete $self->{stopMoves}->{$bb};
    delete $self->{activeMoves}->{$bb};

    return;
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

sub sendTactic {
    my $self = shift;
    my $colorbit = shift;
    my $tactic = shift;

    my $msg = {
        'c' => 'authtactic',
        'message' => KungFuChess::Bitboards::getColorName($colorbit) . " $tactic!",
    };
    $self->send($msg);
}

sub getPieces {
    my $self = shift;
    my @pieces = values %{$self->{board}};

    return @pieces;
}

sub human {
    my $bb = shift;
    return KungFuChess::Bitboards::human($bb);
}

sub prettyBoard {
    return KungFuChess::Bitboards::pretty();
}

1;
