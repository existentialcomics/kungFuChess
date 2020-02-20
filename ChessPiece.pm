package ChessPiece;
use strict;
use warnings;
use Time::HiRes qw(time);
use AnyEvent;
use Data::Dumper;

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
	my ($x, $y, $color, $type, $id, $game) = @_;
	$self->{x} = $x;
	$self->{y} = $y;
	$self->{color} = $color;
	$self->{type} = $type;
	$self->{id} = $id;
    $self->{game} = $game;
    $self->{readyToMove} = time();

	$self->{firstMove} = 1;
	$self->{isMoving} = 0;
	$self->{beganMove} = 0;

    if ($color eq 'white'){
        $self->{pawnDir} = 1;
    } elsif ($color eq 'black'){
        $self->{pawnDir} = -1;
    }

	return 1;
}

sub readyToMove {
    my $self = shift;
    return $self->{readyToMove} < time();
}

sub isLegalMove {
	my $self = shift;
	my $destx = shift;
	my $desty = shift;
	my $board = shift;

    if ($self->isBlocked($destx, $desty, $board)) {
        return 0;
    }

	print "checking piece legal move...\n";
	my $x = ($self->{x} - $destx);
	my $y = ($self->{y} - $desty);
	print "$x, $y\n";
	

	if ($x == 0 && $y == 0){ return 0; }
	if ($self->{type} eq 'king'){
		if (abs($x) <= 1 && abs($y) <= 1){
			return 1;
		}
        if ($y == 0 && $x == 2 && $self->{firstMove}) {
            foreach my $piece (@{$board}) {
                if ($piece->{type} eq 'rook'
                    && $piece->{color} eq $self->{color}
                    && $piece->{firstMove}
                    && $piece->{x} == 0
                ) {
                    $piece->move($destx + 1, $piece->{y});
                    return 1;
                }
            }
            return 0;
        }
        if ($y == 0 && $x == -2 && $self->{firstMove}) {
            foreach my $piece (@{$board}) {
                if ($piece->{type} eq 'rook'
                    && $piece->{color} eq $self->{color}
                    && $piece->{firstMove}
                    && $piece->{x} == 7
                ) {
                    $piece->move($destx - 1, $piece->{y});
                    return 1;
                }
            }
            return 0;
        }
        if ($y == 0 && $x == -2 && $self->{firstMove}) {
            return 1;
        }
	} elsif ($self->{type} eq 'queen'){
		if (abs($x) == abs($y)) { return 1; }
		if ($x == 0 || $y == 0){ return 1; }
	} elsif ($self->{type} eq 'bishop'){
		if (abs($x) == abs($y)) { return 1; }
	} elsif ($self->{type} eq 'rook'){
		if ($x == 0 || $y == 0){ return 1; }
	} elsif ($self->{type} eq 'knight'){
		if (abs($x) == 1 && abs($y) == 2){ return 1; }
		if (abs($x) == 2 && abs($y) == 1){ return 1; }
	} elsif ($self->{type} eq 'pawn'){
        my $yDir = $self->{pawnDir};
        ### the blocked sub will figure out capture vs regular move
        # diagonal move
        if (($x == 1 || $x == -1) && $y == $yDir){
            return 1;
        }
        # first move 2
        if ($x == 0 && $y == $yDir * 2 && $self->{firstMove} == 1){
            return 1;
        }
        # regular move
        if ($x == 0 && $y == $yDir){
            return 1;
        }
	}

	return 0;
}

sub pieceOnSquare {
    my $self = shift;
    my $board = shift;

}

sub move {
	my $self = shift;
	my ($x, $y) = @_;

    $self->{firstMove} = 0;

	$self->{moving_x} = $x;
	$self->{moving_y} = $y;
	$self->{isMoving} = 1;
    $self->{beganMove} = time;

	my $diffX = $x - $self->{x};
	my $diffY = $y - $self->{y};

    print "checking for kills\n";

	print "$self->{x}, $self->{y} => $x, $y\n";

	my $xI = 1;
	my $yI = 1;
	if ($x < $self->{x}) { $xI = -1 }
	if ($x == $self->{x}){ $xI = 0  }
	if ($y < $self->{y}) { $yI = -1 }
	if ($y == $self->{y}){ $yI = 0  }

	$self->{interval} = $self->{game}->{pieceSpeed} / 10;

	print time() . " - ix, iy: $xI, $yI\n";

	if ($self->{type} eq 'knight'){
		$xI = $diffX;
		$yI = $diffY;

		$self->{interval} = $self->{game}->{pieceSpeed} / 5;
	}

	$self->{xI} = $xI;
	$self->{yI} = $yI;

    my $msg = {
        'c' => 'authmove',
        'color' => $self->{color},
        'x' => $x,
        'y' => $y,
        'id' => $self->{id}
    };
    print "sending inside\n";
    $self->{game}->send($msg);

	$self->setMovingInterval();
}

sub setMovingInterval {
	my $self = shift;

	$self->{w} = AnyEvent->timer(
		after => $self->{interval},
		cb => sub {
			$self->{x} += $self->{xI};
			$self->{y} += $self->{yI};

			if ($self->{x} == $self->{moving_x} && 
				$self->{y} == $self->{moving_y}){
				print time() . " - finished moving \n";
				$self->{isMoving} = 0;
                $self->{readyToMove} = time() + $self->{game}->{pieceRecharge};
			} else {
				$self->setMovingInterval();
			}
            $self->{game}->checkForKills($self);
			if ($self->{type} eq 'pawn'){
				# don't have to worry about colors because pawns don't go backwards
				if ($self->{y} == 0 || $self->{y} == 7){
					$self->{type} = 'queen';
					$self->{game}->send(
						{
							'c' => 'promote',
							'id' => $self->{id}
						}
					);
				}
			}
		}
	);
}

sub isBlocked {
	my $self = shift;
	my $x = shift;
	my $y = shift;
	my $board = shift;

	if ($self->{type} eq 'knight'){ return 0; }
	print "args $x, $y:\n";
	print "board :\n";
    if ($board){
        print ref $board . "\n";
    }

    my $destX = $x;
    my $destY = $y;

	my $xI = 1;
	my $yI = 1;
	if ($x > $self->{x}) { $xI = -1 }
	if ($x == $self->{x}){ $xI = 0  }
	if ($y > $self->{y}) { $yI = -1 }
	if ($y == $self->{y}){ $yI = 0  }

    my $pawnCapture = 0;

	print "checking to see if blocked...\n";
	print "$self->{x}, $self->{y} => $x, $y\n";
	print "ix, iy: $xI, $yI\n";
	while (! ($x == $self->{x} && $y == $self->{y})){
		foreach my $piece (@{$board}){
			next if ($self->{id} == $piece->{id});
            if ($piece->{isMoving}){
                if ($piece->{moving_x} == $destX && $piece->{moving_y} == $destY && $piece->{color} eq $self->{color}){
                    print "blocked by dest piece\n";
                    return 1;
                } else {
                    if ($yI != 0){
                        $pawnCapture = 1;
                    }
                    next;
                }
            }
			if ($piece->{x} == $x && $piece->{y} == $y){
                # landing square
                if ($x == $destX && $y == $destY){
                    # able to kill opponents on final piece
                    if ($self->{type} eq 'pawn'){
                        # moving diag
                        if ($xI != 0){
                            if ($piece->{color} ne $self->{color}){
                                $pawnCapture = 1;
                                next;
                            }
                        } else {
                            # always blocked moving forward
                        }
                    } else {
                        next if ($piece->{color} ne $self->{color});
                    }
                }
				print "$self->{id} blocked by $piece->{id} ($piece->{type})\n";
				return 1;
			}
		}
		if ($x != $self->{x}){
			$x += $xI;
		}
		if ($y != $self->{y}){
			$y += $yI;
		}
	}
	print "no blocks!\n";
    if ($self->{type} eq 'pawn' && $xI != 0 && $pawnCapture == 0){
        return 1;
    }
	return 0;
}
1;
