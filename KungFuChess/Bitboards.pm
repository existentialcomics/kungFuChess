#!/usr/bin/perl

use strict;
#use warnings;

package KungFuChess::Bitboards;
use Math::BigInt;

use constant ({
    NO_COLOR => 0,
    WHITE    => 1,
    BLACK    => 2,

    DIR_NONE =>  0,
    NORTH =>  8,
    EAST  =>  1,
    SOUTH => -8,
    WEST  => -1,
    NORTH_EAST =>  9, # north + east
    SOUTH_EAST => -7,
    SOUTH_WEST => -9,
    NORTH_WEST =>  7,

    MOVE_NONE       => 0,
    MOVE_NORMAL     => 1,
    MOVE_EN_PASSANT => 2,
    MOVE_CASTLE_OO  => 3,
    MOVE_CASTLE_OOO => 4,
    MOVE_KNIGHT     => 5,
    MOVE_PUT_PIECE  => 6,
    MOVE_PROMOTE    => 7,

    FILES => { 
        a => 0x0101010101010101,
        b => 0x0101010101010101 << 1,
        c => 0x0101010101010101 << 2,
        d => 0x0101010101010101 << 3,
        e => 0x0101010101010101 << 4,
        f => 0x0101010101010101 << 5,
        g => 0x0101010101010101 << 6,
        h => 0x0101010101010101 << 7,
    },

    RANKS => {
        1 => 0x00000000000000FF,
        2 => 0x000000000000FF00,
        3 => 0x0000000000FF0000,
        4 => 0x00000000FF000000,
        5 => 0x000000FF00000000,
        6 => 0x0000FF0000000000,
        7 => 0x00FF000000000000,
        8 => 0xFF00000000000000,
    },

    FILE_TO_Y => {
        a => 8,
        b => 7,
        c => 6,
        d => 5,
        e => 4,
        f => 3,
        g => 2,
        h => 1,
    },
    RANK_TO_X => {
        1 => 8,
        2 => 7,
        3 => 6,
        4 => 5,
        5 => 4,
        6 => 3,
        7 => 2,
        8 => 1,
    },
});


### similar to stockfish we have multiple bitboards that we intersect
### to determine the position of things and state of things.
### init all bitboards to zero

### piece types
my $pawns    = 0x0000000000000000;
my $knights  = 0x0000000000000000;
my $bishops  = 0x0000000000000000;
my $rooks    = 0x0000000000000000;
my $queens   = 0x0000000000000000;
my $kings    = 0x0000000000000000;

### colors
my $white    = 0x0000000000000000;
my $black    = 0x0000000000000000;
my $occupied = 0x0000000000000000;

my $enPassant = 0x0000000000000000;

my $whiteCastleK  = RANKS->{1} & FILES->{'e'};
my $blackCastleK  = RANKS->{8} & FILES->{'e'};
my $whiteCastleR  = RANKS->{1} & FILES->{'h'};
my $blackCastleR  = RANKS->{8} & FILES->{'h'};
my $whiteQCastleR = RANKS->{1} & FILES->{'a'};
my $blackQCastleR = RANKS->{8} & FILES->{'a'};

### frozen pieces, can't move
my $frozenBB = 0x0000000000000000;
### pieces currently moving, don't attack these!
my $movingBB = 0x0000000000000000;
### these track how long a piece has moved thus far
### used to resolve collisions between two moving pieces
my $momentumOccupied = [
    0x0000000000000000,
    0x0000000000000000,
    0x0000000000000000,
    0x0000000000000000,
    0x0000000000000000,
    0x0000000000000000,
    0x0000000000000000,
    0x0000000000000000
];

sub setupInitialPosition {
    ### pawns
    $occupied |= RANKS->{2};
    $pawns    |= RANKS->{2};
    $white    |= RANKS->{2};
        
    # rook 1
    $occupied |= (FILES->{a} & RANKS->{1});
    $rooks    |= (FILES->{a} & RANKS->{1});
    $white    |= (FILES->{a} & RANKS->{1});
        
    # knight 1
    $occupied |= (FILES->{b} & RANKS->{1});
    $knights  |= (FILES->{b} & RANKS->{1});
    $white    |= (FILES->{b} & RANKS->{1});
        
    # bishop 1
    $occupied |= (FILES->{c} & RANKS->{1});
    $bishops  |= (FILES->{c} & RANKS->{1});
    $white    |= (FILES->{c} & RANKS->{1});
        
    # queen
    $occupied |= (FILES->{d} & RANKS->{1});
    $queens   |= (FILES->{d} & RANKS->{1});
    $white    |= (FILES->{d} & RANKS->{1});
        
    # king
    $occupied |= (FILES->{e} & RANKS->{1});
    $kings    |= (FILES->{e} & RANKS->{1});
    $white    |= (FILES->{e} & RANKS->{1});
        
    # bishop2
    $occupied |= (FILES->{f} & RANKS->{1});
    $bishops  |= (FILES->{f} & RANKS->{1});
    $white    |= (FILES->{f} & RANKS->{1});
        
    # knight2
    $occupied |= (FILES->{g} & RANKS->{1});
    $knights  |= (FILES->{g} & RANKS->{1});
    $white    |= (FILES->{g} & RANKS->{1});
        
    # rook2
    $occupied |= (FILES->{h} & RANKS->{1});
    $rooks    |= (FILES->{h} & RANKS->{1});
    $white    |= (FILES->{h} & RANKS->{1});

    #### black ####
    
    ### pawns
    $occupied |= RANKS->{7};
    $pawns    |= RANKS->{7};
    $black    |= RANKS->{7};
        
    # rook 1
    $occupied |= (FILES->{a} & RANKS->{8});
    $rooks    |= (FILES->{a} & RANKS->{8});
    $black    |= (FILES->{a} & RANKS->{8});
        
    # knight 1
    $occupied |= (FILES->{b} & RANKS->{8});
    $knights  |= (FILES->{b} & RANKS->{8});
    $black    |= (FILES->{b} & RANKS->{8});
        
    # bishop 1
    $occupied |= (FILES->{c} & RANKS->{8});
    $bishops  |= (FILES->{c} & RANKS->{8});
    $black    |= (FILES->{c} & RANKS->{8});
        
    # queen
    $occupied |= (FILES->{d} & RANKS->{8});
    $queens   |= (FILES->{d} & RANKS->{8});
    $black    |= (FILES->{d} & RANKS->{8});
        
    # king
    $occupied |= (FILES->{e} & RANKS->{8});
    $kings    |= (FILES->{e} & RANKS->{8});
    $black    |= (FILES->{e} & RANKS->{8});
        
    # bishop2
    $occupied |= (FILES->{f} & RANKS->{8});
    $bishops  |= (FILES->{f} & RANKS->{8});
    $black    |= (FILES->{f} & RANKS->{8});
        
    # knight2
    $occupied |= (FILES->{g} & RANKS->{8});
    $knights  |= (FILES->{g} & RANKS->{8});
    $black    |= (FILES->{g} & RANKS->{8});
        
    # rook2
    $occupied |= (FILES->{h} & RANKS->{8});
    $rooks    |= (FILES->{h} & RANKS->{8});
    $black    |= (FILES->{h} & RANKS->{8});
}

### copied from shift function in Stockfish
sub shift_BB {
    my ($bb, $direction) = @_;
    return  $direction == NORTH      ?  $bb                << 8 : $direction == SOUTH      ?  $bb                >> 8
          : $direction == NORTH+NORTH?  $bb                <<16 : $direction == SOUTH+SOUTH?  $bb                >>16
          : $direction == EAST       ? ($bb & ~FILES->{h}) << 1 : $direction == WEST       ? ($bb & ~FILES->{a}) >> 1
          : $direction == NORTH_EAST ? ($bb & ~FILES->{h}) << 9 : $direction == NORTH_WEST ? ($bb & ~FILES->{a}) << 7
          : $direction == SOUTH_EAST ? ($bb & ~FILES->{h}) >> 7 : $direction == SOUTH_WEST ? ($bb & ~FILES->{a}) >> 9
          : 0;
}

sub _removePiece {
    my $pieceBB = shift;

    $occupied &= ~$pieceBB;
    $white    &= ~$pieceBB;
    $black    &= ~$pieceBB;
    $pawns    &= ~$pieceBB;
    $rooks    &= ~$pieceBB;
    $bishops  &= ~$pieceBB;
    $knights  &= ~$pieceBB;
    $kings    &= ~$pieceBB;
    $queens   &= ~$pieceBB;

    $frozenBB &= ~$pieceBB;
    $movingBB &= ~$pieceBB;

    for (0 .. 7) {
        $momentumOccupied->[$_] &= ~$pieceBB;
    }
}

sub setFrozen {
    my $bb = shift;
    $frozenBB |= $bb;
}
sub unsetFrozen {
    my $bb = shift;
    $frozenBB &= ~$bb;
}
sub setMoving {
    my $bb = shift;
    $movingBB |= $bb;
}
sub unsetMoving {
    my $bb = shift;
    $movingBB &= ~$bb;
}

sub blockers {
    my ($blockingBB, $dirBB, $fromBB, $toBB) = @_;

    while ($fromBB != $toBB) {
        $fromBB = shift_BB($fromBB, $dirBB);
        if (! ($fromBB & $movingBB) ){
            if ($fromBB == 0)         { return 0; } ### of the board
            if ($fromBB & $blockingBB){ return 0; }
        }
    }
    return 1;
}

### returns the color that moved and type of move
sub isLegalMove {
    my $move = shift;

    my ($fr_f, $fr_r, $to_f, $to_r) = split ('', $move);

    print "bb move: $fr_f, $fr_r, $to_f, $to_r\n";

    my $fr_rank = RANKS->{$fr_r};
    my $fr_file = FILES->{$fr_f};
    my $to_rank = RANKS->{$to_r};
    my $to_file = FILES->{$to_f};
    my $fr_bb = $fr_rank & $fr_file;
    my $to_bb = $to_rank & $to_file;

    my $checkBlockers = 0;

    my @noMove = (NO_COLOR, MOVE_NONE, DIR_NONE, $fr_bb, $to_bb);

    if (! $occupied & $fr_bb ) {
        print "from not occupied\n";
        return @noMove;
    }
    my $color   = ($white & $fr_bb ? WHITE : BLACK);
    my $pawnDir = ($white & $fr_bb ? NORTH : SOUTH);


    ### castles go before checking same color on to_bb
    if ($fr_bb & $kings) {
        my ($bbK, $bbR, $bbQR);
        if ($color == WHITE) {
            $bbK  = $whiteCastleK;
            $bbR  = $whiteCastleR;
            $bbQR = $whiteQCastleR;
        } else {
            $bbK  = $blackCastleK;
            $bbR  = $blackCastleR;
            $bbQR = $blackQCastleR;
        }

        if ($fr_bb & $bbK){ 
            if ($to_bb & $bbR) { 
                if (blockers(_piecesUs($color), EAST, $fr_bb, shift_BB($to_bb, WEST)) ){
                    return ($color, MOVE_CASTLE_OO, DIR_NONE, $fr_bb, $to_bb);
                } else {
                    return @noMove;
                }
            }
            if ($to_bb & $bbQR) { 
                if (blockers(_piecesUs($color), WEST, $fr_bb, shift_BB($to_bb, EAST)) ){
                    return ($color, MOVE_CASTLE_OOO, DIR_NONE, $fr_bb, $to_bb);
                } else {
                    return @noMove;
                }
            }
        }
    }

    ### if the same color is on the square
    if (_piecesUs($color) & $to_bb){
        print "to same color\n";
        return @noMove;
    }

    if ($fr_bb & $pawns) {
        print " -is pawn legal\n";
        my $pawnMoveType = MOVE_NORMAL;
        if ($to_bb & RANKS->{'1'} || $to_bb & RANKS->{'8'}) {
            $pawnMoveType = MOVE_PROMOTE;
        }
        if (shift_BB($fr_bb, $pawnDir) & $to_bb) {
            if ($to_bb & $occupied) { 
                return @noMove;
            }
            return ($color, $pawnMoveType, $pawnDir, $fr_bb, $to_bb);
        }

        # we dont worry about color for ranks because you can't move two that way anyway
        if ((shift_BB($fr_bb, $pawnDir + $pawnDir) & $to_bb) && ($fr_bb & (RANKS->{2} | RANKS->{7})) ){
            if ($to_bb & $occupied) {
                return @noMove;
            }
            return ($color, $pawnMoveType, $pawnDir, $fr_bb, $to_bb);
        }
        if ($to_bb & _piecesThem($color) ){
            print "enemy on pawn space\n";
            my $enemyCapturesE = shift_BB($to_bb, EAST);
            my $enemyCapturesW = shift_BB($to_bb, WEST);
            if      (shift_BB($fr_bb, $pawnDir) & $enemyCapturesW){
                return ($color, $pawnMoveType, $pawnDir + EAST, $fr_bb, $to_bb);
            } elsif (shift_BB($fr_bb, $pawnDir) & $enemyCapturesE){
                return ($color, $pawnMoveType, $pawnDir + WEST, $fr_bb, $to_bb);
            } else {
                print "can't take\n";
            }
        }
        ### TODO en passant check frozen squares
        return @noMove;
    }
    if ($fr_bb & $knights) {
        if ( shift_BB($fr_bb, NORTH + NORTH) &
             shift_BB($to_bb, WEST) | shift_BB($to_bb, EAST) ){
            return ($color, MOVE_KNIGHT, DIR_NONE, $fr_bb, $to_bb);
        }
        if ( shift_BB($fr_bb, SOUTH + SOUTH) &
             shift_BB($to_bb, WEST) | shift_BB($to_bb, EAST) ){
            return ($color, MOVE_KNIGHT, DIR_NONE, $fr_bb, $to_bb);
        }
        if ( shift_BB(shift_BB($fr_bb, WEST), WEST) &
             shift_BB($to_bb, NORTH) | shift_BB($to_bb, SOUTH) ){
            return ($color, MOVE_KNIGHT, DIR_NONE, $fr_bb, $to_bb);
        }
        if ( shift_BB(shift_BB($fr_bb, EAST), EAST) &
             shift_BB($to_bb, NORTH) | shift_BB($to_bb, SOUTH) ){
            return ($color, MOVE_KNIGHT, DIR_NONE, $fr_bb, $to_bb);
        }
        return (NO_COLOR, MOVE_NONE, DIR_NONE);
    }
    if ($fr_bb & $rooks) {
        return _legalRooks($fr_rank, $fr_file, $to_rank, $to_file, $fr_bb, $to_bb, $color);
    }
    if ($fr_bb & $bishops) {
        return _legalBishops($fr_rank, $fr_file, $to_rank, $to_file, $fr_bb, $to_bb, $color);
    }
    if ($fr_bb & $queens) {
        my ($r_color, $r_move, $r_dir) = _legalRooks($fr_rank, $fr_file, $to_rank, $to_file, $fr_bb, $to_bb, $color);
        if ($r_move != MOVE_NONE){
            return ($r_color, $r_move, $r_dir, $fr_bb, $to_bb);
        } else {
            return _legalBishops($fr_rank, $fr_file, $to_rank, $to_file, $fr_bb, $to_bb, $color);
        }
    }
    if ($fr_bb & $kings) {
        if ($to_bb &
            (shift_BB($fr_bb, NORTH_WEST) | shift_BB($fr_bb, NORTH) | shift_BB($fr_bb, NORTH_EAST) |
             shift_BB($fr_bb, WEST)       |                           shift_BB($fr_bb, EAST)       |
             shift_BB($fr_bb, SOUTH_WEST) | shift_BB($fr_bb, SOUTH) | shift_BB($fr_bb, SOUTH_EAST) )
        ){
            ### it's always one space so we don't bother with dir
            return ($color, MOVE_NORMAL, DIR_NONE, $fr_bb, $to_bb);
        }
        return @noMove;
    }
    return @noMove;
}

sub _legalRooks {
    my ($fr_rank, $fr_file, $to_rank, $to_file, $fr_bb, $to_bb, $color) = @_;

    my $dir = 0;
    if (!($fr_file & $to_file) && $fr_rank & $to_rank) {
        if ($fr_file < $to_file) {
            $dir = EAST;
        } else {
            $dir = WEST;
        }
    } elsif ($fr_file & $to_file  && !($fr_rank & $to_rank)) {
        if ($fr_rank < $to_rank) {
            $dir = NORTH;
        } else {
            $dir = SOUTH;
        }
    } else { # from and to were not on a parallel rank or file
        return (NO_COLOR, MOVE_NONE, DIR_NONE, $fr_bb, $to_bb);
    }
    ###
    if (blockers(_piecesUs($color), $dir, $fr_bb, $to_bb) ){
        return ($color, MOVE_NORMAL, $dir, $fr_bb, $to_bb);
    }

}

sub _legalBishops {
    my ($fr_rank, $fr_file, $to_rank, $to_file, $fr_bb, $to_bb, $color) = @_;

    if ($fr_rank == $to_rank || $fr_file == $to_file) { return 0; }

    print "legal bishop....\n";

    my $dir = 0;
    if ($fr_file < $to_file) { # north
        if ($fr_rank > $to_rank) { # west
            $dir = SOUTH_EAST;
        } else {
            $dir = NORTH_EAST;
        }
    }
    if ($fr_file > $to_file) { # south
        if ($fr_rank > $to_rank) { # west
            $dir = SOUTH_WEST;
        } else {
            $dir = NORTH_WEST;
        }
    }
    if (blockers(_piecesUs($color), $dir, $fr_bb, $to_bb) ){
        return ($color, MOVE_NORMAL, $dir, $fr_bb, $to_bb);
    }
    return (NO_COLOR, MOVE_NONE, DIR_NONE, $fr_bb, $to_bb);
}

sub _piecesUs {
    if ($_[0] == WHITE) { return $white; }
    print "pieces US black\n";
    return $black;
}
sub _piecesThem {
    if ($_[0] == WHITE) { return $black; }
    return $white;
}

### if this is called on a non-empty square it will cause problems
sub _putPiece {
    my $p  = shift;
    my $BB = shift;

    my @BBs = _getBBsForPiece($p);
    foreach (@BBs) {
        $$_ |= $BB;
    }
}

### TODO make this more static in a hash or something
sub _getBBsForPiece {
    my $p = shift;
    if ($p eq 'p') {
        return (\$occupied, \$pawns, \$black);
    }
    if ($p eq 'P') {
        return (\$occupied, \$pawns, \$white);
    }

    if ($p eq 'r') {
        return (\$occupied, \$rooks, \$black);
    }
    if ($p eq 'R') {
        return (\$occupied, \$rooks, \$white);
    }

    if ($p eq 'b') {
        return (\$occupied, \$bishops, \$black);
    }
    if ($p eq 'B') {
        return (\$occupied, \$bishops, \$white);
    }

    if ($p eq 'n') {
        return (\$occupied, \$knights, \$black);
    }
    if ($p eq 'N') {
        return (\$occupied, \$knights, \$white);
    }

    if ($p eq 'k') {
        return (\$occupied, \$kings, \$black);
    }
    if ($p eq 'K') {
        return (\$occupied, \$kings, \$white);
    }

    if ($p eq 'q') {
        return (\$occupied, \$queens, \$black);
    }
    if ($p eq 'Q') {
        return (\$occupied, \$queens, \$white);
    }

    return ();
}

sub _getPieceBB {
    my $squareBB = shift;
    if (! $occupied & $squareBB) {
        return undef;
    }
    my $chr = '';
    if ( $pawns & $squareBB) {
        $chr = 'p';
    } elsif ($rooks & $squareBB) {
        $chr = 'r';
    } elsif ($bishops & $squareBB) {
        $chr = 'b';
    } elsif ($knights & $squareBB) {
        $chr = 'n';
    } elsif ($queens & $squareBB) {
        $chr = 'q';
    } elsif ($kings & $squareBB) {
        $chr = 'k';
    }

    if ($white & $squareBB) {
        return uc($chr);
    }
    return $chr;

}

sub _getPiece {
    my $sq = shift;
    my ($f, $r) = split('', $sq);

    my $squareBB = RANKS->{$r} & FILES->{$f};
    return _getPieceBB($squareBB);
}

sub _getBBat {
    my $sq = shift;
    my ($f, $r) = split('', $sq);

    return RANKS->{$r} & FILES->{$f};
}

sub moveStep {
    my ($fr_bb, $dir) = @_;
    my $to_bb = shift_BB($fr_bb, $dir);
    return (move($fr_bb, $to_bb), $to_bb);
}

### returns 1 for normal, 0 for killed
sub move {
    my ($fr_bb, $to_bb) = @_;

    if (! $fr_bb & $occupied) {
        print "not occupied\n";
        return 0;
    }

    my $piece = _getPieceBB($fr_bb);
    print "piece: $piece\n";

    _removePiece($fr_bb);
    _removePiece($to_bb);
    _putPiece($piece, $to_bb);
    return 1;
}

sub pretty {
    my $board = '';
    print "pretty...\n";
    $board .= "\n   +---+---+---+---+---+---+---+----\n";
    foreach my $r ( qw(8 7 6 5 4 3 2 1) ) {
        foreach my $f ( 'a' .. 'h' ) {
            if ($f eq 'a'){ $board .= " $r | "; }
            my $chr = _getPiece($f . $r);
            if ($chr) {
                $board .= "$chr | ";
            } else {
                $board .= "  | ";
            }
        }
        $board .= "\n   +---+---+---+---+---+---+---+----\n";
    }
    $board .= "     a   b   c   d   e   f   g   h  \n";
    return $board;
}

sub prettyMoving {
    return prettyBoard($movingBB);
}

sub prettyBoard {
    my $BB = shift;
    my $board = "BB: " . $BB . "\n";;
    $board .= "\n   +---+---+---+---+---+---+---+----\n";
    foreach my $r ( qw(8 7 6 5 4 3 2 1) ) {
        foreach my $f ( 'a' .. 'h' ) {
            if ($f eq 'a'){ $board .= " $r | "; }
                my $rf = RANKS->{$r} & FILES->{$f};
            if ($BB & $rf) {
                $board .= "X | ";
            } else {
                $board .= "  | ";
            }
        }
        $board .= "\n   +---+---+---+---+---+---+---+----\n";
    }
    $board .= "     a   b   c   d   e   f   g   h  \n";
    return $board;
}

1;
