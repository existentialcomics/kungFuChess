#!/usr/bin/perl

use strict;
#use warnings;

package KungFuChess::Bitboards;
use Math::BigInt;
use base 'Exporter';

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

our @EXPORT_OK = qw(MOVE_NONE MOVE_NORMAL MOVE_PROMOTE MOVE_EN_PASSANT MOVE_CASTLE_OO MOVE_CASTLE_OOO MOVE_KNIGHT WHITE_PAWN WHITE_KNIGHT WHITE_ROOK WHITE_BISHOP WHITE_KING WHITE_QUEEN BLACK_PAWN BLACK_KNIGHT BLACK_ROOK BLACK_BISHOP BLACK_KING BLACK_QUEEN);

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
            if ($fromBB == 0)         { return 0; } ### off the board
            if ($fromBB & $blockingBB){ return 0; }
        }
    }
    return 1;
}

### returns the color that moved and type of move
sub isLegalMove {
    my $move = shift;

    my ($fr_f, $fr_r, $to_f, $to_r);
    if ($move =~ m/^([a-z])([0-9]{1,2})([a-z])([0-9]{1,2})$/) {
        ($fr_f, $fr_r, $to_f, $to_r) = ($1, $2, $3, $4);
    } else {
        warn "bad move $move!\n";
        return (NO_COLOR, MOVE_NONE, DIR_NONE, 0, 0);
    }

    my $fr_rank = RANKS->{$fr_r};
    my $fr_file = FILES->{$fr_f};
    my $to_rank = RANKS->{$to_r};
    my $to_file = FILES->{$to_f};
    my $fr_bb = $fr_rank & $fr_file;
    my $to_bb = $to_rank & $to_file;

    my @noMove = (NO_COLOR, MOVE_NONE, DIR_NONE, $fr_bb, $to_bb);

    my $checkBlockers = 0;

    if (! $occupied & $fr_bb ) {
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
        return @noMove;
    }

    if ($fr_bb & $pawns) {
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
            my $enemyCapturesE = shift_BB($to_bb, EAST);
            my $enemyCapturesW = shift_BB($to_bb, WEST);
            if      (shift_BB($fr_bb, $pawnDir) & $enemyCapturesW){
                return ($color, $pawnMoveType, $pawnDir + EAST, $fr_bb, $to_bb);
            } elsif (shift_BB($fr_bb, $pawnDir) & $enemyCapturesE){
                return ($color, $pawnMoveType, $pawnDir + WEST, $fr_bb, $to_bb);
            } else {
                #print "can't take\n";
            }
        }
        ### TODO en passant check frozen squares
        return @noMove;
    }
    if ($fr_bb & $knights) {
        if ( shift_BB($fr_bb, NORTH + NORTH) &
             (shift_BB($to_bb, WEST) | shift_BB($to_bb, EAST)) ){
            return ($color, MOVE_KNIGHT, DIR_NONE, $fr_bb, $to_bb);
        }
        if ( shift_BB($fr_bb, SOUTH + SOUTH) &
             (shift_BB($to_bb, WEST) | shift_BB($to_bb, EAST)) ){
            return ($color, MOVE_KNIGHT, DIR_NONE, $fr_bb, $to_bb);
        }
        if ( shift_BB(shift_BB($fr_bb, WEST), WEST) &
             (shift_BB($to_bb, NORTH) | shift_BB($to_bb, SOUTH)) ){
            return ($color, MOVE_KNIGHT, DIR_NONE, $fr_bb, $to_bb);
        }
        if ( shift_BB(shift_BB($fr_bb, EAST), EAST) &
             (shift_BB($to_bb, NORTH) | shift_BB($to_bb, SOUTH)) ){
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
    return (NO_COLOR, MOVE_NONE, DIR_NONE, $fr_bb, $to_bb);
}

sub _legalBishops {
    my ($fr_rank, $fr_file, $to_rank, $to_file, $fr_bb, $to_bb, $color) = @_;

    if ($fr_rank == $to_rank || $fr_file == $to_file) {
        return (NO_COLOR, MOVE_NONE, DIR_NONE, $fr_bb, $to_bb);
    }

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
    if ($p == BLACK_PAWN) {
        return (\$occupied, \$pawns, \$black);
    }
    if ($p == WHITE_PAWN) {
        return (\$occupied, \$pawns, \$white);
    }

    if ($p == BLACK_ROOK) {
        return (\$occupied, \$rooks, \$black);
    }
    if ($p == WHITE_ROOK) {
        return (\$occupied, \$rooks, \$white);
    }

    if ($p == BLACK_BISHOP) {
        return (\$occupied, \$bishops, \$black);
    }
    if ($p == WHITE_BISHOP) {
        return (\$occupied, \$bishops, \$white);
    }

    if ($p == BLACK_KNIGHT) {
        return (\$occupied, \$knights, \$black);
    }
    if ($p == WHITE_KNIGHT) {
        return (\$occupied, \$knights, \$white);
    }

    if ($p == BLACK_KING) {
        return (\$occupied, \$kings, \$black);
    }
    if ($p == WHITE_KING) {
        return (\$occupied, \$kings, \$white);
    }

    if ($p == BLACK_QUEEN) {
        return (\$occupied, \$queens, \$black);
    }
    if ($p == WHITE_QUEEN) {
        return (\$occupied, \$queens, \$white);
    }

    return ();
}

sub _getPieceBB {
    my $squareBB = shift;
    if (! ($occupied & $squareBB)) {
        return undef;
    }
    my $chr = '';
    if ( $pawns & $squareBB) {
        $chr = WHITE_PAWN;
    } elsif ($rooks & $squareBB) {
        $chr = WHITE_ROOK;
    } elsif ($bishops & $squareBB) {
        $chr = WHITE_BISHOP;
    } elsif ($knights & $squareBB) {
        $chr = WHITE_KNIGHT;
    } elsif ($queens & $squareBB) {
        $chr = WHITE_QUEEN;
    } elsif ($kings & $squareBB) {
        $chr = WHITE_KING;
    }

    if ($black & $squareBB) {
        return ($chr + 100); # black is 100 higher
    }
    return $chr;

}

sub _getPiece {
    my ($f, $r) = @_;

    my $squareBB = RANKS->{$r} & FILES->{$f};
    return _getPieceBB($squareBB);
}

sub _getBBat {
    my ($f, $r) = @_;

    return RANKS->{$r} & FILES->{$f};
}

sub moveStep {
    my ($fr_bb, $dir) = @_;
    my $to_bb = shift_BB($fr_bb, $dir);
    return (move($fr_bb, $to_bb), $to_bb);
}

### returns 1 for normal, 0 for not occupied
### warning! does not check if the move is legal
sub move {
    my ($fr_bb, $to_bb) = @_;

    if (! ($fr_bb & $occupied)) {
        #print "not occupied\n";
        return 0;
    }

    my $piece = _getPieceBB($fr_bb);

    _removePiece($fr_bb);
    _removePiece($to_bb);
    _putPiece($piece, $to_bb);
    return 1;
}

### for display purpose only
sub getPieceDisplay {
    my $piece = shift;
    my $color =  "\033[0m";
    if ($piece > 100) {
        $color =  "\033[90m";
    }
    my $normal = "\033[0m";
    if ($piece % 100 == WHITE_PAWN) {
        return $color . 'P' . $normal;
    }
    if ($piece % 100 == WHITE_ROOK) {
        return $color . 'R' . $normal;
    }
    if ($piece % 100 == WHITE_BISHOP) {
        return $color . 'B' . $normal;
    }
    if ($piece % 100 == WHITE_KNIGHT) {
        return $color . 'N' . $normal;
    }
    if ($piece % 100 == WHITE_QUEEN) {
        return $color . 'Q' . $normal;
    }
    if ($piece % 100 == WHITE_KING) {
        return $color . 'K' . $normal;
    }
    return ' ';
}

sub pretty {
    my $board = '';
    $board .= "\n   +---+---+---+---+---+---+---+----\n";
    foreach my $r ( qw(8 7 6 5 4 3 2 1) ) {
        foreach my $f ( 'a' .. 'h' ) {
            if ($f eq 'a'){ $board .= " $r | "; }
            my $chr = getPieceDisplay(_getPiece($f, $r));
            $board .= "$chr | ";
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
