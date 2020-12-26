#!/usr/bin/perl

use strict;
#use warnings;

package KungFuChess::Bitboards4way;
use parent 'KungFuChess::Bitboards';
use Math::BigInt;

use constant ({
    NO_COLOR => 0,
    WHITE    => 1,
    BLACK    => 2,
    RED      => 3,
    GREEN    => 4,

    DIR_NONE =>  0,
    NORTH =>  16,
    EAST  =>  1,
    SOUTH => -16,
    WEST  => -1,
    NORTH_EAST =>  17, # north + east
    SOUTH_EAST => -15,
    SOUTH_WEST => -17,
    NORTH_WEST =>  15,

    MOVE_NONE       => 0,
    MOVE_NORMAL     => 1,
    MOVE_EN_PASSANT => 2,
    MOVE_CASTLE_OO  => 3,
    MOVE_CASTLE_OOO => 4,
    MOVE_KNIGHT     => 5,
    MOVE_PUT_PIECE  => 6,
    MOVE_PROMOTE    => 7,

    WHITE_PAWN   => 001,
    WHITE_ROOK   => 002,
    WHITE_KNIGHT => 003,
    WHITE_BISHOP => 004,
    WHITE_KING   => 005,
    WHITE_QUEEN  => 006,

    BLACK_PAWN   => 101,
    BLACK_ROOK   => 102,
    BLACK_KNIGHT => 103,
    BLACK_BISHOP => 104,
    BLACK_KING   => 105,
    BLACK_QUEEN  => 106,

    RED_PAWN   => 201,
    RED_ROOK   => 202,
    RED_KNIGHT => 203,
    RED_BISHOP => 204,
    RED_KING   => 205,
    RED_QUEEN  => 206,

    GREEN_PAWN   => 301,
    GREEN_ROOK   => 302,
    GREEN_KNIGHT => 303,
    GREEN_BISHOP => 304,
    GREEN_KING   => 305,
    GREEN_QUEEN  => 306,

# binary number for file 1 (12x12)
# 100000000000
# 100000000000
# 100000000000
# 100000000000
# 100000000000
# 100000000000
# 100000000000
# 100000000000
# 100000000000
# 100000000000
# 100000000000
# 100000000000
# hex number:
# 800800800800800800800800800800800800
    FILES => {
        a  => Math::BigInt->new('0x800800800800800800800800800800800800'),
        b  => Math::BigInt->new('0x800800800800800800800800800800800800') >> 1,
        c  => Math::BigInt->new('0x800800800800800800800800800800800800') >> 2,
        d  => Math::BigInt->new('0x800800800800800800800800800800800800') >> 3,
        e  => Math::BigInt->new('0x800800800800800800800800800800800800') >> 4,
        f  => Math::BigInt->new('0x800800800800800800800800800800800800') >> 5,
        g  => Math::BigInt->new('0x800800800800800800800800800800800800') >> 6,
        h  => Math::BigInt->new('0x800800800800800800800800800800800800') >> 7,
        i  => Math::BigInt->new('0x800800800800800800800800800800800800') >> 8,
        j  => Math::BigInt->new('0x800800800800800800800800800800800800') >> 9,
        k  => Math::BigInt->new('0x800800800800800800800800800800800800') >> 10,
        l  => Math::BigInt->new('0x800800800800800800800800800800800800') >> 11,
    },

# binary number for file 1:
# 000000000000
# 000000000000
# 000000000000
# 000000000000
# 000000000000
# 000000000000
# 000000000000
# 000000000000
# 000000000000
# 000000000000
# 000000000000
# 111111111111
# hex number:
# 0000000000000000000000000000FFFF
    RANKS => {
        1  => Math::BigInt->new('0x000000000000000000000000000000000FFF'),
        2  => Math::BigInt->new('0x000000000000000000000000000000FFF000'),
        3  => Math::BigInt->new('0x000000000000000000000000000FFF000000'),
        4  => Math::BigInt->new('0x000000000000000000000000FFF000000000'),
        5  => Math::BigInt->new('0x000000000000000000000FFF000000000000'),
        6  => Math::BigInt->new('0x000000000000000000FFF000000000000000'),
        7  => Math::BigInt->new('0x000000000000000FFF000000000000000000'),
        8  => Math::BigInt->new('0x000000000000FFF000000000000000000000'),
        9  => Math::BigInt->new('0x000000000FFF000000000000000000000000'),
        10 => Math::BigInt->new('0x000000FFF000000000000000000000000000'),
        11 => Math::BigInt->new('0x000FFF000000000000000000000000000000'),
        12 => Math::BigInt->new('0xFFF000000000000000000000000000000000'),
    },

    FILE_TO_Y => {
        a => 16,
        b => 15,
        c => 14,
        d => 13,
        e => 12,
        f => 11,
        g => 10,
        h => 9,
        i => 8,
        j => 7,
        k => 6,
        l => 5,
    },
    RANK_TO_X => {
        1 => 16,
        2 => 15,
        3 => 14,
        4 => 13,
        5 => 12,
        6 => 11,
        7 => 10,
        8 => 9,
        9 => 8,
        10 => 7,
        11 => 6,
        12 => 5,
    },
});


### similar to stockfish we have multiple bitboards that we intersect
### to determine the position of things and state of things.
### init all bitboards to zero

### piece types
my $pawns    = Math::BigInt->new('0x00000000000000000000000000000000');
my $knights  = Math::BigInt->new('0x00000000000000000000000000000000');
my $bishops  = Math::BigInt->new('0x00000000000000000000000000000000');
my $rooks    = Math::BigInt->new('0x00000000000000000000000000000000');
my $queens   = Math::BigInt->new('0x00000000000000000000000000000000');
my $kings    = Math::BigInt->new('0x00000000000000000000000000000000');

### colors
my $white    = Math::BigInt->new('0x00000000000000000000000000000000');
my $black    = Math::BigInt->new('0x00000000000000000000000000000000');
my $red      = Math::BigInt->new('0x00000000000000000000000000000000');
my $green    = Math::BigInt->new('0x00000000000000000000000000000000');
my $occupied = Math::BigInt->new('0x00000000000000000000000000000000');

my $enPassant = Math::BigInt->new('0x00000000000000000000000000000000');

my $whiteCastleK  = RANKS->{1} & FILES->{'e'};
my $blackCastleK  = RANKS->{8} & FILES->{'e'};
my $whiteCastleR  = RANKS->{1} & FILES->{'h'};
my $blackCastleR  = RANKS->{8} & FILES->{'h'};
my $whiteQCastleR = RANKS->{1} & FILES->{'a'};
my $blackQCastleR = RANKS->{8} & FILES->{'a'};

### frozen pieces, can't move
my $frozenBB = Math::BigInt->new('0x00000000000000000000000000000000');
### pieces currently moving, don't attack these!
my $movingBB = Math::BigInt->new('0x00000000000000000000000000000000');

sub setupInitialPosition {
    # rook 1
    $occupied |= (FILES->{c} & RANKS->{1});
    $rooks    |= (FILES->{c} & RANKS->{1});
    $white    |= (FILES->{c} & RANKS->{1});
    # pawn 
    $occupied |= (FILES->{c} & RANKS->{2});
    $pawns    |= (FILES->{c} & RANKS->{2});
    $white    |= (FILES->{c} & RANKS->{2});
        
    # knight 1
    $occupied |= (FILES->{d} & RANKS->{1});
    $knights  |= (FILES->{d} & RANKS->{1});
    $white    |= (FILES->{d} & RANKS->{1});
    # pawn 
    $occupied |= (FILES->{d} & RANKS->{2});
    $pawns    |= (FILES->{d} & RANKS->{2});
    $white    |= (FILES->{d} & RANKS->{2});
        
    # bishop 1
    $occupied |= (FILES->{e} & RANKS->{1});
    $bishops  |= (FILES->{e} & RANKS->{1});
    $white    |= (FILES->{e} & RANKS->{1});
    # pawn 
    $occupied |= (FILES->{e} & RANKS->{2});
    $pawns    |= (FILES->{e} & RANKS->{2});
    $white    |= (FILES->{e} & RANKS->{2});
        
    # queen
    $occupied |= (FILES->{f} & RANKS->{1});
    $queens   |= (FILES->{f} & RANKS->{1});
    $white    |= (FILES->{f} & RANKS->{1});
    # pawn 
    $occupied |= (FILES->{f} & RANKS->{2});
    $pawns    |= (FILES->{f} & RANKS->{2});
    $white    |= (FILES->{f} & RANKS->{2});
        
    # king
    $occupied |= (FILES->{g} & RANKS->{1});
    $kings    |= (FILES->{g} & RANKS->{1});
    $white    |= (FILES->{g} & RANKS->{1});
    # pawn 
    $occupied |= (FILES->{g} & RANKS->{2});
    $pawns    |= (FILES->{g} & RANKS->{2});
    $white    |= (FILES->{g} & RANKS->{2});
        
    # bishop2
    $occupied |= (FILES->{h} & RANKS->{1});
    $bishops  |= (FILES->{h} & RANKS->{1});
    $white    |= (FILES->{h} & RANKS->{1});
    # pawn 
    $occupied |= (FILES->{h} & RANKS->{2});
    $pawns    |= (FILES->{h} & RANKS->{2});
    $white    |= (FILES->{h} & RANKS->{2});
        
    # knight2
    $occupied |= (FILES->{i} & RANKS->{1});
    $knights  |= (FILES->{i} & RANKS->{1});
    $white    |= (FILES->{i} & RANKS->{1});
    # pawn 
    $occupied |= (FILES->{i} & RANKS->{2});
    $pawns    |= (FILES->{i} & RANKS->{2});
    $white    |= (FILES->{i} & RANKS->{2});
        
    # rook2
    $occupied |= (FILES->{j} & RANKS->{1});
    $rooks    |= (FILES->{j} & RANKS->{1});
    $white    |= (FILES->{j} & RANKS->{1});
    # pawn 
    $occupied |= (FILES->{j} & RANKS->{2});
    $pawns    |= (FILES->{j} & RANKS->{2});
    $white    |= (FILES->{j} & RANKS->{2});

    #### black ####
    
    # rook 1
    $occupied |= (FILES->{c} & RANKS->{12});
    $rooks    |= (FILES->{c} & RANKS->{12});
    $black    |= (FILES->{c} & RANKS->{12});
    # pawn 
    $occupied |= (FILES->{c} & RANKS->{11});
    $pawns    |= (FILES->{c} & RANKS->{11});
    $black    |= (FILES->{c} & RANKS->{11});
        
    # knight 1
    $occupied |= (FILES->{d} & RANKS->{12});
    $knights  |= (FILES->{d} & RANKS->{12});
    $black    |= (FILES->{d} & RANKS->{12});
    # pawn 
    $occupied |= (FILES->{d} & RANKS->{11});
    $pawns    |= (FILES->{d} & RANKS->{11});
    $black    |= (FILES->{d} & RANKS->{11});
        
    # bishop 1
    $occupied |= (FILES->{e} & RANKS->{12});
    $bishops  |= (FILES->{e} & RANKS->{12});
    $black    |= (FILES->{e} & RANKS->{12});
    # pawn 
    $occupied |= (FILES->{e} & RANKS->{11});
    $pawns    |= (FILES->{e} & RANKS->{11});
    $black    |= (FILES->{e} & RANKS->{11});
        
    # queen
    $occupied |= (FILES->{f} & RANKS->{12});
    $queens   |= (FILES->{f} & RANKS->{12});
    $black    |= (FILES->{f} & RANKS->{12});
    # pawn 
    $occupied |= (FILES->{f} & RANKS->{11});
    $pawns    |= (FILES->{f} & RANKS->{11});
    $black    |= (FILES->{f} & RANKS->{11});
        
    # king
    $occupied |= (FILES->{g} & RANKS->{12});
    $kings    |= (FILES->{g} & RANKS->{12});
    $black    |= (FILES->{g} & RANKS->{12});
    # pawn 
    $occupied |= (FILES->{g} & RANKS->{11});
    $pawns    |= (FILES->{g} & RANKS->{11});
    $black    |= (FILES->{g} & RANKS->{11});
        
    # bishop2
    $occupied |= (FILES->{h} & RANKS->{12});
    $bishops  |= (FILES->{h} & RANKS->{12});
    $black    |= (FILES->{h} & RANKS->{12});
    # pawn 
    $occupied |= (FILES->{h} & RANKS->{11});
    $pawns    |= (FILES->{h} & RANKS->{11});
    $black    |= (FILES->{h} & RANKS->{11});
        
    # knight2
    $occupied |= (FILES->{i} & RANKS->{12});
    $knights  |= (FILES->{i} & RANKS->{12});
    $black    |= (FILES->{i} & RANKS->{12});
    # pawn 
    $occupied |= (FILES->{i} & RANKS->{11});
    $pawns    |= (FILES->{i} & RANKS->{11});
    $black    |= (FILES->{i} & RANKS->{11});
        
    # rook2
    $occupied |= (FILES->{j} & RANKS->{12});
    $rooks    |= (FILES->{j} & RANKS->{12});
    $black    |= (FILES->{j} & RANKS->{12});
    # pawn 
    $occupied |= (FILES->{j} & RANKS->{11});
    $pawns    |= (FILES->{j} & RANKS->{11});
    $black    |= (FILES->{j} & RANKS->{11});
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
    $red      &= ~$pieceBB;
    $green    &= ~$pieceBB;
    $pawns    &= ~$pieceBB;
    $rooks    &= ~$pieceBB;
    $bishops  &= ~$pieceBB;
    $knights  &= ~$pieceBB;
    $kings    &= ~$pieceBB;
    $queens   &= ~$pieceBB;

    $frozenBB &= ~$pieceBB;
    $movingBB &= ~$pieceBB;
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
    my $fr_bb = Math::BigInt->new($fr_rank & $fr_file);
    my $to_bb = Math::BigInt->new($to_rank & $to_file);

    my $checkBlockers = 0;

    my @noMove = (NO_COLOR, MOVE_NONE, DIR_NONE, $fr_bb, $to_bb);

    if (! ($occupied & $fr_bb) ) {
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
    if ($_[0] == WHITE) { return $black; }
    if ($_[0] == WHITE) { return $black; }
    if ($_[0] == WHITE) { return $black; }
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
    if (! ($occupied & $squareBB)) {
        return undef;
    }
    my $chr = 'x';
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
    my ($f, $r) = @_;

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

    if (! ($fr_bb & $occupied)) {
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
    $board .= "\n   +---+---+---+---+---+---+---+---+---+---+---+---+\n";
    foreach my $r ( qw(12 11 10 9 8 7 6 5 4 3 2 1) ) {
        foreach my $f ( 'a' .. 'l' ) {
            if ($f eq 'a'){ $board .= sprintf('%2s | ', $r); }
            my $chr = _getPiece($f, $r);
            if ($chr) {
                $board .= "$chr | ";
            } else {
                $board .= "  | ";
            }
        }
        $board .= "\n   +---+---+---+---+---+---+---+---+---+---+---+---+\n";
    }
    $board .= "     a   b   c   d   e   f   g   h   i   j   k   l\n";
    return $board;
}

sub prettyMoving {
    return prettyBoard($movingBB);
}
sub prettyOccupied {
    return prettyBoard($occupied);
}
sub prettyBoardTest {
    #my $bb = FILES->{'a'};
    my $bb = FILES->{'e'};
    #my $bb = RANKS->{'1'};
    #my $bb = RANKS->{'1'} & FILES->{'c'};
    #my $bb = RANKS->{'2'} | FILES->{'c'};
    return prettyBoard($bb);
}
#10000000000010000000000010000000000010000000000010000000000010000000000010000000000010000000000010000000000010000000000010111111111111000000000000
sub prettyBoard {
    my $BB = shift;
    my $board = "BB: " . $BB . "\n";;
    my $bin = Math::BigInt->new($BB);
    my $bin = $bin->as_bin();
    $bin =~ s/^0b//;
    $bin = sprintf('%0144s', $bin);
    while ($bin =~ m/.{12}/g) {
        print "$&\n";
    }
    $board .= "\n   +---+---+---+---+---+---+---+---+---+---+---+---\n";
    foreach my $r ( qw(12 11 10 9 8 7 6 5 4 3 2 1) ) {
        foreach my $f ( 'a' .. 'l' ) {
            if ($f eq 'a'){ $board .= sprintf('%2s | ', $r); }
                my $rf = RANKS->{$r} & FILES->{$f};
            if ($BB & $rf) {
                $board .= "X | ";
            } else {
                $board .= "  | ";
            }
        }
        $board .= "\n   +---+---+---+---+---+---+---+---+---+---+---+---\n";
    }
    $board .= "     a   b   c   d   e   f   g   h   i   j   k   l\n";
    return $board;
}

1;
