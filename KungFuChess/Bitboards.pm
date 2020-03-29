#!/usr/bin/perl

use strict;
#use warnings;

package KungFuChess::Bitboards;
use Math::BigInt;

use constant ({
    WHITE => 1,
    BLACK => 2,

    NORTH =>  8,
    EAST  =>  1,
    SOUTH => -8,
    WEST  => -1,

    NORTH_EAST =>  9, # north + east
    SOUTH_EAST => -7,
    SOUTH_WEST => -9,
    NORTH_WEST =>  7,

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

### frozen pieces, can't move
my $frozen   = 0x0000000000000000;
### pieces currently moving, don't attack these!
my $moving   = 0x0000000000000000;
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

#template<Direction D>
#constexpr Bitboard shift(Bitboard b) {
  #return  D == NORTH      ?  b             << 8 : D == SOUTH      ?  b             >> 8
        #: D == NORTH+NORTH?  b             <<16 : D == SOUTH+SOUTH?  b             >>16
        #: D == EAST       ? (b & ~FileHBB) << 1 : D == WEST       ? (b & ~FileABB) >> 1
        #: D == NORTH_EAST ? (b & ~FileHBB) << 9 : D == NORTH_WEST ? (b & ~FileABB) << 7
        #: D == SOUTH_EAST ? (b & ~FileHBB) >> 7 : D == SOUTH_WEST ? (b & ~FileABB) >> 9
        #: 0;
#}

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
    $knights  &= ~$pieceBB;
    $kings    &= ~$pieceBB;
    $queens   &= ~$pieceBB;

    $frozen   &= ~$pieceBB;

    for (0 .. 7) {
        $momentumOccupied->[$_] &= ~$pieceBB;
    }
}

sub blockers {
    my ($enemyBB, $dirBB, $fromBB, $toBB) = @_;

    while ($fromBB != $toBB && $fromBB) {
        $fromBB = shift_BB($fromBB, $dirBB);
        if ($fromBB & $enemyBB){ return 0; }
    }
    return 1;
}

sub isLegalMove {
    my ($from, $to) = @_;

    my $move = shift;
    my ($fr_f, $fr_r, $to_f, $to_r) = split ('', $move);

    print "move: $fr_f, $fr_r, $to_f, $to_r\n";

    my $fr_rank = RANKS->{$fr_r};
    my $fr_file = FILES->{$fr_f};
    my $to_rank = RANKS->{$to_r};
    my $to_file = FILES->{$to_f};
    my $fr_bb = $fr_rank & $fr_file;
    my $to_bb = $to_rank & $to_file;

    my $checkBlockers = 0;

    if (! $occupied & $fr_bb ) {
        print "from not occupied\n";
        return 0;
    }
    my $color   = ($white & $fr_bb ? WHITE : BLACK);
    my $pawnDir = ($white & $fr_bb ? NORTH : SOUTH);

    ### if the same color is on the square
    if (($to_bb & $occupied) && (($color == WHITE ? $white : $black) & $fr_bb)){
        print "to same color\n";
        return 0;
    }

    if ($fr_bb & $pawns) {
        print " -is pawn legal\n";
        if (shift_BB($fr_bb, $pawnDir) & $to_bb) {
            if ($to_bb & $occupied) { return 0; }
            return 1;
        }
                                                                # we dont worry about color because you can't move two that way anyway

        if ((shift_BB($fr_bb, $pawnDir + $pawnDir) & $to_bb) && ($fr_bb & (RANKS->{2} | RANKS->{7})) ){
            if ($to_bb & $occupied) { return 0; }
            return 1;
        }
        if ($occupied & $to_bb & _piecesThem($color) ){
            if (shift_BB($fr_bb, $pawnDir) & (shift_BB($to_bb, EAST) | shiftBB($to_bb, WEST)) ){
                return 1;
            }
        }
        ### TODO en passant check frozen squares
        return 0;
    }
    if ($fr_bb & $knights) {
        if (shift_BB($pawnDir, NORTH + NORTH) & shift_BB($to_bb, WEST) ){
            return 1;
        }
        if (shift_BB($pawnDir, NORTH + NORTH) & shift_BB($to_bb, EAST) ){
            return 1;
        }
        if (shift_BB($pawnDir, SOUTH + SOUTH) & shift_BB($to_bb, WEST) ){
            return 1;
        }
        if (shift_BB($pawnDir, SOUTH + SOUTH) & shift_BB($to_bb, EAST) ){
            return 1;
        }
        return 0;
    }
    if ($fr_bb & $rooks) {
        print " - is rook legal\n";
        return _legalRooks($fr_rank, $fr_file, $to_rank, $to_file, $fr_bb, $to_bb, $color);
    }
    if ($fr_bb & $bishops) {
        return _legalBishops($fr_rank, $fr_file, $to_rank, $to_file, $fr_bb, $to_bb, $color);
    }
    if ($fr_bb & $queens) {
        #return _legalBishop($fr_x, $fr_y, $to_x, $to_y, $fr_bb, $to_bb, $color) ||
               #_legalRooks($fr_x, $fr_y, $to_x, $to_y, $fr_bb, $to_bb, $color);
    }
    if ($fr_bb & $kings) {
        if ($to_bb &
            (shift_BB($fr_bb, NORTH_WEST) | shift_BB($fr_bb, NORTH) | shift_BB($fr_bb, NORTH_EAST) |
             shift_BB($fr_bb, WEST)       |                           shift_BB($fr_bb, EAST)       |
             shift_BB($fr_bb, SOUTH_WEST) | shift_BB($fr_bb, SOUTH) | shift_BB($fr_bb, SOUTH_EAST) )
        ){
            return 1;
        }
        return 0;
    }
}

sub _legalRooks {
    my ($fr_rank, $fr_file, $to_rank, $to_file, $fr_bb, $to_bb, $color) = @_;

    if ($fr_file & $to_file  && !($fr_rank & $to_rank)) {
        if ($fr_rank > $to_rank) {
            print "checking west\n";
            return blockers(_piecesThem($color), WEST, $fr_bb, $to_bb, $color);
        } else {
            print "checking east\n";
            return blockers(_piecesThem($color), EAST, $fr_bb, $to_bb, $color);
        }
    } elsif (!($fr_file & $to_file) && $fr_rank & $to_rank) {
        if ($fr_file > $to_file) {
            print "checking north\n";
            return blockers(_piecesThem($color), NORTH, $fr_bb, $to_bb, $color);
        } else {
            print "checking south\n";
            return blockers(_piecesThem($color), SOUTH, $fr_bb, $to_bb, $color);
        }
    } else {
        print "no paralell\n";
        return 0;
    }

}

sub _legalBishops {
    my ($fr_rank, $fr_file, $to_rank, $to_file, $fr_bb, $to_bb, $color) = @_;

    if ($fr_rank == $to_rank || $fr_file == $to_file) { return 0; }

    if ($fr_file > $to_file) { # north
        if ($fr_rank > $to_rank) { # west
            return blockers(_piecesThem($color), NORTH_WEST, $fr_bb, $to_bb);
        } else {
            return blockers(_piecesThem($color), NORTH_EAST, $fr_bb, $to_bb);
        }
    }
    if ($fr_file < $to_file) { # south
        if ($fr_rank > $to_rank) { # west
            return blockers(_piecesThem($color), SOUTH_WEST, $fr_bb, $to_bb);
        } else {
            return blockers(_piecesThem($color), SOUTH_EAST, $fr_bb, $to_bb);
        }
    }
}

sub _piecesUs {
    if ($_ == WHITE) { return $white; }
    return $black;
}
sub _piecesThem {
    if ($_ == WHITE) { return $black; }
    return $white;
}

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

sub _getPiece {
    my $sq = shift;
    my ($f, $r) = split('', $sq);

    my $squareBB = RANKS->{$r} & FILES->{$f};
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

    if ( $white & $squareBB) {
        return uc($chr);
    }
    return $chr;
}

sub move {
    my $move = shift;
    my ($fr_f, $fr_r, $to_f, $to_r) = split ('', $move);

    my $fr_bb = RANKS->{$fr_r} & FILES->{$fr_f};
    if (! $fr_bb & $occupied) {
        print "not occupied\n";
        return 0;
    }
    my $to_bb = RANKS->{$to_r} & FILES->{$to_f};

    my $piece = _getPiece($fr_f . $fr_r);
    print "piece: $piece\n";

    #if (! $to_bb & $occupied) {
        #my ($winningBB, $winningLen) = resolveCollision($fr_bb, $to_bb);
        #if ($winningBB == $fr_bb) {
            #### stockfish doesn't remove first, maybe remove in put?
            #_removePiece($to_bb);
            #_putPiece($piece, $to_bb);
            #$momentumOccupied->[$winningLen + 1] |= $to_bb;
        #} elsif ($winningBB == $to_bb) {
            #### do nothing
        #} else {
            #print "neither matched winning?\n";
        #}
    #}
    _removePiece($fr_bb);
    _putPiece($piece, $to_bb);
}

sub resolveCollision {
    my ($fr_bb, $to_bb) = @_;

    foreach (qw( 7 6 5 4 3 2 1 0)) {
        if ($fr_bb & $momentumOccupied->[$_]) {
            return ($fr_bb, $_);
        } elsif ($fr_bb & $momentumOccupied->[$_]) {
            return ($to_bb, $_);
        }
    }
    print "should not happen?\n";
    return ($fr_bb, 0);
}

sub pretty {
    my $board = '';
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

sub prettyBoard {
    my $BB = shift;
    my $board = '';
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
