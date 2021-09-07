#!/usr/bin/perl

use strict;
#use warnings;

package KungFuChess::Bitboards;
use Math::BigInt;
use Data::Dumper;
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
    
    ### matches Stockfish
    ALL_P  => 000,
    PAWN   => 001,
    KNIGHT => 002,
    BISHOP => 003,
    ROOK   => 004,
    KING   => 005,
    QUEEN  => 006,

    ### array of a move
    MOVE_FR         => 0,
    MOVE_TO         => 1,
    MOVE_PIECE      => 2,
    MOVE_PIECE_TYPE => 3,
    MOVE_SCORE      => 4,
    MOVE_NEXT_MOVES => 5,
     
    WHITE_PAWN   => 101,
    WHITE_KNIGHT => 102,
    WHITE_BISHOP => 103,
    WHITE_ROOK   => 104,
    WHITE_KING   => 105,
    WHITE_QUEEN  => 106,

    BLACK_PAWN   => 201,
    BLACK_KNIGHT => 202,
    BLACK_BISHOP => 203,
    BLACK_ROOK   => 204,
    BLACK_KING   => 205,
    BLACK_QUEEN  => 206,

    FILES => [ 
        0x0101010101010101,
        0x0101010101010101 << 1,
        0x0101010101010101 << 2,
        0x0101010101010101 << 3,
        0x0101010101010101 << 4,
        0x0101010101010101 << 5,
        0x0101010101010101 << 6,
        0x0101010101010101 << 7,
    ],
    FILES_H => { 
        a => 0x0101010101010101,
        b => 0x0101010101010101 << 1,
        c => 0x0101010101010101 << 2,
        d => 0x0101010101010101 << 3,
        e => 0x0101010101010101 << 4,
        f => 0x0101010101010101 << 5,
        g => 0x0101010101010101 << 6,
        h => 0x0101010101010101 << 7,
    },
    FILE_TO_X => {
        1 => 0,
        2 => 1,
        3 => 2,
        4 => 3,
        5 => 4,
        6 => 5,
        7 => 6,
        8 => 7
    },

    RANKS => [
        0x00000000000000FF,
        0x000000000000FF00,
        0x0000000000FF0000,
        0x00000000FF000000,
        0x000000FF00000000,
        0x0000FF0000000000,
        0x00FF000000000000,
        0xFF00000000000000,
    ],
    RANKS_H => {
        1 => 0x00000000000000FF,
        2 => 0x000000000000FF00,
        3 => 0x0000000000FF0000,
        4 => 0x00000000FF000000,
        5 => 0x000000FF00000000,
        6 => 0x0000FF0000000000,
        7 => 0x00FF000000000000,
        8 => 0xFF00000000000000,
    },

    RANK_TO_Y => {
        a => 0,
        b => 1,
        c => 2,
        d => 3,
        e => 4,
        f => 5,
        g => 6,
        h => 7
    }
});

########################## for AI only ###########################
#
# copied from stockfish, only the "middlegame" numbers for now
# black must flip this
my $SQ_BONUS = [
    [], # all
    [   # pawn
        [  3,   3,  10, 19, 16, 19,   7,  -5 ],
        [ -9, -15,  11, 15, 32, 22,   5, -22 ],
        [ -8, -23,   6, 20, 40, 17,   4, -12 ],
        [ 13,   0, -13,  1, 11, -2, -13,  5  ],
        [ -5, -12,  -7, 22, -8, -5, -15, -18 ],
        [ -7,   7,  -3, -13, 5, -16, 10, -8  ],
        [] ### pawn shouldn't fuckin be here
    ],
    [ # Knight
        [ -175, -92, -74, -73, -73, -74, -92, -175 ],
        [  -77, -41, -27, -15, -15, -27, -41,  -77 ],
        [  -61, -17,   6,  12,  12,   6, -17,  -61 ],
        [  -35,   8,  40,  49,  49,  40,   8,  -35 ],
        [  -34,  13,  44,  51,  51,  44,  13,  -34 ],
        [   -9,  22,  58,  53,  53,  58,  22,   -9 ],
        [  -67, -27,   4,  37,  37,   4, -27,  -67 ],
        [ -201, -83, -56, -26, -26, -56, -83, -201 ],
    ],
    [ # Bishop
        [ -53,  -5,  -8, -23, -23,  -8,  -5, -53 ],
        [ -15,   8,  19,   4,   4,  19,   8, -15 ],
        [  -7,  21,  -5,  17,  17,  -5,  21,  -7 ],
        [  -5,  11,  25,  39,  39,  25,  11,  -5 ],
        [ -12,  29,  22,  31,  31,  22,  29, -12 ],
        [ -16,   6,   1,  11,  11,   1,   6, -16 ],
        [ -17, -14,   5,   0,   0,   5, -14, -17 ],
        [ -48,   1, -14, -23, -23, -14,   1, -48 ],
    ],
    [ # Rook
        [ -31, -20, -14, -5, -5, -14, -20, -31 ],
        [ -21, -13,  -8,  6,  6,  -8, -13, -21 ],
        [ -25, -11,  -1,  3,  3,  -1, -11, -25 ],
        [ -13,  -5,  -4, -6, -6,  -4,  -5, -13 ],
        [ -27, -15,  -4,  3,  3,  -4, -15, -27 ],
        [ -22,  -2,   6, 12, 12,   6,  -2, -22 ],
        [  -2,  12,  16, 18, 18,  16,  12,  -2 ],
        [ -17, -19,  -1,  9,  9,  -1, -19, -17 ],
    ],
    [ # Queen
        [  3, -5, -5,  4,  4, -5, -5,  3 ],
        [ -3,  5,  8, 12, 12,  8,  5, -3 ],
        [ -3,  6, 13,  7,  7, 13,  6, -3 ],
        [  4,  5,  9,  8,  8,  9,  5,  4 ],
        [  0, 14, 12,  5,  5, 12, 14,  0 ],
        [ -4, 10,  6,  8,  8,  6, 10, -4 ],
        [ -5,  6, 10,  8,  8, 10,  6, -5 ],
        [ -2, -2,  1, -2, -2,  1, -2, -2 ],
    ],
    [ # King
        [ 271, 327, 271, 198, 198, 271, 327, 271 ],
        [ 278, 303, 234, 179, 179, 234, 303, 278 ],
        [ 195, 258, 169, 120, 120, 169, 258, 195 ],
        [ 164, 190, 138,  98,  98, 138, 190, 164 ],
        [ 154, 179, 105,  70,  70, 105, 179, 154 ],
        [ 123, 145,  81,  31,  31,  81, 145, 123 ],
        [  88, 120,  65,  33,  33,  65, 120,  88 ],
        [  59,  89,  45,  -1,  -1,  45,  89,  59 ],
    ]
];

our @EXPORT_OK = qw(MOVE_NONE MOVE_NORMAL MOVE_PROMOTE MOVE_EN_PASSANT MOVE_CASTLE_OO MOVE_CASTLE_OOO MOVE_KNIGHT WHITE_PAWN WHITE_KNIGHT WHITE_ROOK WHITE_BISHOP WHITE_KING WHITE_QUEEN BLACK_PAWN BLACK_KNIGHT BLACK_ROOK BLACK_BISHOP BLACK_KING BLACK_QUEEN);

### similar to stockfish we have multiple bitboards that we intersect
### to determine the position of things and state of things.
### init all bitboards to zero


### these should be perfect hashes of all bitboard squares
my %whiteMoves = ();
my %blackMoves = ();

### ALL bitboards used to track position
my $pawns    = 0x0000000000000000;
my $knights  = 0x0000000000000000;
my $bishops  = 0x0000000000000000;
my $rooks    = 0x0000000000000000;
my $queens   = 0x0000000000000000;
my $kings    = 0x0000000000000000;
my $white     = 0x0000000000000000;
my $black     = 0x0000000000000000;
my $occupied  = 0x0000000000000000;
my $enPassant = 0x0000000000000000;

my $whiteCastleK      = RANKS->[0] & FILES->[4];
my $whiteCastleR      = RANKS->[0] & FILES->[7];
my $whiteCastleR_off  = RANKS->[0] & FILES->[6]; # if you moved next to the rook that's still a castle attempt
my $whiteQCastleR     = RANKS->[0] & FILES->[0];
my $whiteQCastleR_off = RANKS->[0] & FILES->[1]; # if you moved next to the rook that's still a castle attempt
my $blackCastleK      = RANKS->[7] & FILES->[4];
my $blackCastleR      = RANKS->[7] & FILES->[7];
my $blackCastleR_off  = RANKS->[7] & FILES->[6]; # if you moved next to the rook that's still a castle attempt
my $blackQCastleR     = RANKS->[7] & FILES->[0];
my $blackQCastleR_off = RANKS->[7] & FILES->[1]; # if you moved next to the rook that's still a castle attempt

### kungfuChess specific: frozen pieces waiting to move and currently moving 
my $frozenBB = 0x0000000000000000;
my $movingBB = 0x0000000000000000;

### same as above but for ai to manipulate
my $ai_pawns    = 0x0000000000000000;
my $ai_knights  = 0x0000000000000000;
my $ai_bishops  = 0x0000000000000000;
my $ai_rooks    = 0x0000000000000000;
my $ai_queens   = 0x0000000000000000;
my $ai_kings    = 0x0000000000000000;
my $ai_white     = 0x0000000000000000;
my $ai_black     = 0x0000000000000000;
my $ai_occupied  = 0x0000000000000000;
my $ai_enPassant = 0x0000000000000000;
my $ai_whiteCastleK  = RANKS->[0] & FILES->[4];
my $ai_blackCastleK  = RANKS->[7] & FILES->[4];
my $ai_whiteCastleR  = RANKS->[0] & FILES->[7];
my $ai_blackCastleR  = RANKS->[7] & FILES->[7];
my $ai_whiteQCastleR = RANKS->[0] & FILES->[0];
my $ai_blackQCastleR = RANKS->[7] & FILES->[0];
### kungfuChess specific: frozen pieces waiting to move and currently moving 
my $ai_frozenBB = 0x0000000000000000;
my $ai_movingBB = 0x0000000000000000;

my $currentAiMoveTree = undef;

# set the ai boards back to the current real position;
sub resetAiBoards {
  $ai_pawns    = $pawns;
  $ai_knights  = $knights;
  $ai_bishops  = $bishops;
  $ai_rooks    = $rooks;
  $ai_queens   = $queens; 
  $ai_kings    = $kings;
  $ai_white     = $white;
  $ai_black     = $black;
  $ai_occupied  = $occupied;
  $ai_enPassant = $enPassant;
  $ai_whiteCastleK  = $whiteCastleK ;
  $ai_blackCastleK  = $blackCastleK ;
  $ai_whiteCastleR  = $whiteCastleR ;
  $ai_blackCastleR  = $blackCastleR ;
  $ai_whiteQCastleR = $whiteQCastleR;
  $ai_blackQCastleR = $blackQCastleR;

  $ai_frozenBB = $frozenBB;
  $ai_movingBB = $movingBB;
}

### bitshift these for moves
my @MOVES_N = (
    NORTH + NORTH_WEST, NORTH + NORTH_EAST,
    SOUTH + SOUTH_WEST, SOUTH + SOUTH_EAST,
    WEST  + SOUTH_WEST, WEST  + NORTH_WEST,
    EAST  + SOUTH_EAST, EAST  + NORTH_EAST
);
my @MOVES_B = (NORTH_WEST, NORTH_EAST, SOUTH_WEST, SOUTH_EAST);
my @MOVES_R = (NORTH, SOUTH, EAST, WEST);
my @MOVES_K = (@MOVES_B, @MOVES_R);
my @MOVES_Q = (@MOVES_B, @MOVES_R);

sub setupInitialPosition {
    ### pawns
    $occupied |= RANKS_H->{2};
    $pawns    |= RANKS_H->{2};
    $white    |= RANKS_H->{2};
        
    # rook 1
    $occupied |= (FILES_H->{a} & RANKS_H->{1});
    $rooks    |= (FILES_H->{a} & RANKS_H->{1});
    $white    |= (FILES_H->{a} & RANKS_H->{1});
        
    # knight 1
    $occupied |= (FILES_H->{b} & RANKS_H->{1});
    $knights  |= (FILES_H->{b} & RANKS_H->{1});
    $white    |= (FILES_H->{b} & RANKS_H->{1});
        
    # bishop 1
    $occupied |= (FILES_H->{c} & RANKS_H->{1});
    $bishops  |= (FILES_H->{c} & RANKS_H->{1});
    $white    |= (FILES_H->{c} & RANKS_H->{1});
        
    # queen
    $occupied |= (FILES_H->{d} & RANKS_H->{1});
    $queens   |= (FILES_H->{d} & RANKS_H->{1});
    $white    |= (FILES_H->{d} & RANKS_H->{1});
        
    # king
    $occupied |= (FILES_H->{e} & RANKS_H->{1});
    $kings    |= (FILES_H->{e} & RANKS_H->{1});
    $white    |= (FILES_H->{e} & RANKS_H->{1});
        
    # bishop2
    $occupied |= (FILES_H->{f} & RANKS_H->{1});
    $bishops  |= (FILES_H->{f} & RANKS_H->{1});
    $white    |= (FILES_H->{f} & RANKS_H->{1});
        
    # knight2
    $occupied |= (FILES_H->{g} & RANKS_H->{1});
    $knights  |= (FILES_H->{g} & RANKS_H->{1});
    $white    |= (FILES_H->{g} & RANKS_H->{1});
        
    # rook2
    $occupied |= (FILES_H->{h} & RANKS_H->{1});
    $rooks    |= (FILES_H->{h} & RANKS_H->{1});
    $white    |= (FILES_H->{h} & RANKS_H->{1});

    #### black ####
    
    ### pawns
    $occupied |= RANKS_H->{7};
    $pawns    |= RANKS_H->{7};
    $black    |= RANKS_H->{7};
        
    # rook 1
    $occupied |= (FILES_H->{a} & RANKS_H->{8});
    $rooks    |= (FILES_H->{a} & RANKS_H->{8});
    $black    |= (FILES_H->{a} & RANKS_H->{8});
        
    # knight 1
    $occupied |= (FILES_H->{b} & RANKS_H->{8});
    $knights  |= (FILES_H->{b} & RANKS_H->{8});
    $black    |= (FILES_H->{b} & RANKS_H->{8});
        
    # bishop 1
    $occupied |= (FILES_H->{c} & RANKS_H->{8});
    $bishops  |= (FILES_H->{c} & RANKS_H->{8});
    $black    |= (FILES_H->{c} & RANKS_H->{8});
        
    # queen
    $occupied |= (FILES_H->{d} & RANKS_H->{8});
    $queens   |= (FILES_H->{d} & RANKS_H->{8});
    $black    |= (FILES_H->{d} & RANKS_H->{8});
        
    # king
    $occupied |= (FILES_H->{e} & RANKS_H->{8});
    $kings    |= (FILES_H->{e} & RANKS_H->{8});
    $black    |= (FILES_H->{e} & RANKS_H->{8});
        
    # bishop2
    $occupied |= (FILES_H->{f} & RANKS_H->{8});
    $bishops  |= (FILES_H->{f} & RANKS_H->{8});
    $black    |= (FILES_H->{f} & RANKS_H->{8});
        
    # knight2
    $occupied |= (FILES_H->{g} & RANKS_H->{8});
    $knights  |= (FILES_H->{g} & RANKS_H->{8});
    $black    |= (FILES_H->{g} & RANKS_H->{8});
        
    # rook2
    $occupied |= (FILES_H->{h} & RANKS_H->{8});
    $rooks    |= (FILES_H->{h} & RANKS_H->{8});
    $black    |= (FILES_H->{h} & RANKS_H->{8});

    resetAiBoards();
}

### copied from shift function in Stockfish
sub shift_BB {
    #my ($bb, $direction) = @_;
    return  $_[1] == NORTH      ?  $_[0]                << 8 : $_[1] == SOUTH      ?  $_[0]                >> 8
          : $_[1] == NORTH+NORTH?  $_[0]                <<16 : $_[1] == SOUTH+SOUTH?  $_[0]                >>16
          : $_[1] == EAST       ? ($_[0] & ~FILES->[7]) << 1 : $_[1] == WEST       ? ($_[0] & ~FILES->[0]) >> 1
          : $_[1] == NORTH_EAST ? ($_[0] & ~FILES->[7]) << 9 : $_[1] == NORTH_WEST ? ($_[0] & ~FILES->[0]) << 7
          : $_[1] == SOUTH_EAST ? ($_[0] & ~FILES->[7]) >> 7 : $_[1] == SOUTH_WEST ? ($_[0] & ~FILES->[0]) >> 9
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

sub _removeColorByName {
    my $colorName = shift;
    if ($colorName eq 'white') {
        _removePiece($white);
    } elsif($colorName eq 'black') {
        _removePiece($black);
    }
}

sub _removeColorByPiece {
    my $piece = shift;

    if ($piece < 200) {
        _removePiece($white);
    } elsif ($piece < 300) {
        _removePiece($black);
    }
}

sub _removePiece_ai {
    #my $pieceBB = shift;

    $ai_occupied &= ~$_[0];
    $ai_white    &= ~$_[0];
    $ai_black    &= ~$_[0];
    $ai_pawns    &= ~$_[0];
    $ai_rooks    &= ~$_[0];
    $ai_bishops  &= ~$_[0];
    $ai_knights  &= ~$_[0];
    $ai_kings    &= ~$_[0];
    $ai_queens   &= ~$_[0];

    $ai_frozenBB &= ~$_[0];
    $ai_movingBB &= ~$_[0];
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
    my ($blockingBB, $dirBB, $fromBB, $toBB, $depth) = @_;

    while ($fromBB != $toBB) {
        $fromBB = shift_BB($fromBB, $dirBB);
        if (! ($fromBB & $movingBB) ){
            if ($fromBB == 0)         { return 0; } ### off the board
            if ($fromBB & $blockingBB){ return 0; }

            ### we may want to only have the piece immediately in front block
            if (defined($depth) ){
                $depth--;
                if ($depth == 0) { $blockingBB = 0; }
            }
        }
    }
    return 1;
}

### returns of bitboard of all squares in that dir until we reach a blocker (your own pieces usually)
sub blockersBB {
    my ($color, $dirBB, $fromBB, $toBB) = @_;

    my $returnBB = 0x0;
    my $blockingBB = _piecesThem($color);

    my $origBB = $fromBB;

    while ($fromBB != $toBB) {
        $fromBB = shift_BB($fromBB, $dirBB);
        if (! ($fromBB & $movingBB) ){
            $returnBB &= $fromBB;
            # set guarding this square
        } else {
            # set attacking this square
        }
    }
    return $blockingBB;
}

### takes input like a2b4 and turns it into fr_bb and to_bb
sub parseMove {
    my $move = shift;

    my ($fr_f, $fr_r, $to_f, $to_r);
    if ($move =~ m/^([a-z])([0-9]{1,2})([a-z])([0-9]{1,2})$/) {
        ($fr_f, $fr_r, $to_f, $to_r) = ($1, $2, $3, $4);
    } else {
        warn "bad move $move!\n";
        return (NO_COLOR, MOVE_NONE, DIR_NONE, 0, 0);
    }

    my $fr_rank = RANKS_H->{$fr_r};
    my $fr_file = FILES_H->{$fr_f};
    my $to_rank = RANKS_H->{$to_r};
    my $to_file = FILES_H->{$to_f};
    my $fr_bb = $fr_rank & $fr_file;
    my $to_bb = $to_rank & $to_file;

    return ($fr_bb, $to_bb, $fr_rank, $fr_file, $to_rank, $to_file);
}

sub getPawnDir {
    my $bb = shift;
    return ($white & $bb ? NORTH : SOUTH);
}

sub getReverseDir {
    my $dir = shift;
    return $dir == NORTH ? SOUTH : NORTH;
}

sub getEnPassantKills {
    my $fr_bb = shift;
    my $to_bb = shift;

    my $usColor = occupiedColor($fr_bb);
    my $pawnDir = getPawnDir($fr_bb);
    my $reverse = getReverseDir($pawnDir);
    my $kill_bb = shift_BB($to_bb, $reverse);

    return ($kill_bb);
}

sub clearEnPassant {
    my $fr_bb = shift;

    if (! ($fr_bb & $pawns) ){ return undef; }
    my $usColor = occupiedColor($fr_bb);
    my $pawnDir = getPawnDir($fr_bb);
    my $reverse = getReverseDir($pawnDir);
    my $clear_bb = shift_BB($fr_bb, $reverse);

    $enPassant &= ~$clear_bb;
}

sub isLegalMove {
    my ($fr_bb, $to_bb, $fr_rank, $fr_file, $to_rank, $to_file) = @_;

    ### todo can probably figure a faster way to do this
    if (! defined($fr_rank)) {
        for (0 .. 7) {
            if (RANKS->[$_] & $fr_bb) {
                $fr_rank = RANKS->[$_];
                last;
            } 
        }
    }
    if (! defined($to_rank)) {
        for (0 .. 7) {
            if (RANKS->[$_] & $to_bb) {
                $to_rank = RANKS->[$_];
                last;
            } 
        }
    }
    if (! defined($fr_file)) {
        for (0 .. 7) {
            if (FILES->[$_] & $fr_bb) {
                $fr_file = FILES->[$_];
                last;
            } 
        }
    }
    if (! defined($to_file)) {
        for (0 .. 7) {
            if (FILES->[$_] & $to_bb) {
                $to_file = FILES->[$_];
                last;
            } 
        }
    }

    my @noMove = (NO_COLOR, MOVE_NONE, DIR_NONE, $fr_bb, $to_bb);

    my $checkBlockers = 0;

    if (! ($occupied & $fr_bb) ) {
        return @noMove;
    }
    my $color   = ($white & $fr_bb ? WHITE : BLACK);
    my $pawnDir = getPawnDir($fr_bb);

    ### castles go before checking same color on to_bb
    if ($fr_bb & $kings) {
        my ($bbK, $bbR, $bbQR, $bbR_off, $bbQR_off);
        if ($color == WHITE) {
            $bbK      = $whiteCastleK;
            $bbR      = $whiteCastleR;
            $bbR_off  = $whiteCastleR_off;
            $bbQR     = $whiteQCastleR;
            $bbQR_off = $whiteQCastleR_off;
        } else {
            $bbK      = $blackCastleK;
            $bbR      = $blackCastleR;
            $bbR_off  = $blackCastleR_off;
            $bbQR     = $blackQCastleR;
            $bbQR_off = $blackQCastleR_off;
        }

        ### we simply assume the pieces are there to move, since the castle bbs should be cleared if they move
        if ($fr_bb & $bbK){ 
            ### if they are moving to the "off" square we assume they are attempting to castle
            if ($to_bb & $bbR_off)  { $to_bb = $bbR ; } 
            if ($to_bb & $bbQR_off) { $to_bb = $bbQR; } 

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
    #if (_piecesUs($color) & $to_bb){
        #return @noMove;
    #}

    if ($fr_bb & $pawns) {
        my $pawnMoveType = MOVE_NORMAL;
        if ($to_bb & RANKS->[0] || $to_bb & RANKS->[7]) {
            $pawnMoveType = MOVE_PROMOTE;
        }
        if (shift_BB($fr_bb, $pawnDir) & $to_bb) {
            if ($to_bb & $occupied) { 
                return @noMove;
            }
            return ($color, $pawnMoveType, $pawnDir, $fr_bb, $to_bb);
        }

        # we dont worry about color for ranks because you can't move two that way anyway
        if ((shift_BB($fr_bb, $pawnDir + $pawnDir) & $to_bb) && ($fr_bb & (RANKS->[1] | RANKS->[6])) ){
            if ($to_bb & $occupied) {
                return @noMove;
            }
            # piece between
            if (shift_BB($fr_bb, $pawnDir) & $occupied) {
                return @noMove;
            }
            # activate en_passant bb, warning:
            # this activates on checking for legal move only. TODO should be when you actually move.
            # in the app we are expected to moveIfLegal so fine?
            # GameServer is expected to clear this when timer runs out.
            $enPassant |= shift_BB($to_bb, getReverseDir($pawnDir));

            return ($color, $pawnMoveType, $pawnDir, $fr_bb, $to_bb);
        }
        if ($to_bb & $enPassant) {
            my $enPassCapture_bb = shift_BB($to_bb, getReverseDir($pawnDir));
            ### if we can trust the clearing process this is unneeded TODO
            if ($enPassCapture_bb & _piecesThem($color) & $pawns) {
                my $enemyCapturesE = shift_BB($to_bb, EAST);
                my $enemyCapturesW = shift_BB($to_bb, WEST);

                if      (shift_BB($fr_bb, $pawnDir) & $enemyCapturesW){
                    return ($color, MOVE_EN_PASSANT, $pawnDir + EAST, $fr_bb, $to_bb);
                } elsif (shift_BB($fr_bb, $pawnDir) & $enemyCapturesE){
                    return ($color, MOVE_EN_PASSANT, $pawnDir + WEST, $fr_bb, $to_bb);
                }
            }
        }
        if ($to_bb & (_piecesThem($color))){
            my $enemyCapturesE = shift_BB($to_bb, EAST);
            my $enemyCapturesW = shift_BB($to_bb, WEST);

            if      (shift_BB($fr_bb, $pawnDir) & $enemyCapturesW){
                return ($color, $pawnMoveType, $pawnDir + EAST, $fr_bb, $to_bb);
            } elsif (shift_BB($fr_bb, $pawnDir) & $enemyCapturesE){
                return ($color, $pawnMoveType, $pawnDir + WEST, $fr_bb, $to_bb);
            }
        }
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
    if (blockers(_piecesUs($color), $dir, $fr_bb, $to_bb, 1) ){
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
    if (blockers(_piecesUs($color), $dir, $fr_bb, $to_bb, 1) ){
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

    ### TODO get rid of variable
    my @BBs = _getBBsForPiece($p);
    foreach (@BBs) {
        $$_ |= $BB;
    }
}

sub _putPiece_ai {
    my $p  = shift;
    my $BB = shift;

    $BB = $BB + 0;

    $ai_occupied |= $BB;
    if ($p == BLACK_PAWN) {
        $ai_pawns |= $BB;
        $ai_black |= $BB;
    }
    elsif ($p == WHITE_PAWN) {
        $ai_pawns |= $BB;
        $ai_white |= $BB;
    }
    elsif ($p == BLACK_ROOK) {
        $ai_rooks |= $BB;
        $ai_black |= $BB;
    }
    elsif ($p == WHITE_ROOK) {
        $ai_rooks |= $BB;
        $ai_white |= $BB;
    }
    elsif ($p == BLACK_BISHOP) {
        $ai_bishops |= $BB;
        $ai_black  |= $BB;
    }
    elsif ($p == WHITE_BISHOP) {
        $ai_bishops |= $BB;
        $ai_white  |= $BB;
    }
    elsif ($p == BLACK_KNIGHT) {
        $ai_knights |= $BB;
        $ai_black  |= $BB;
    }
    elsif ($p == WHITE_KNIGHT) {
        $ai_knights |= $BB;
        $ai_white  |= $BB;
    }
    elsif ($p == BLACK_KING) {
        $ai_kings |= $BB;
        $ai_black |= $BB;
    }
    elsif ($p == WHITE_KING) {
        $ai_kings |= $BB;
        $ai_white |= $BB;
    }
    elsif ($p == BLACK_QUEEN) {
        $ai_queens |= $BB;
        $ai_black  |= $BB;
    }
    elsif ($p == WHITE_QUEEN) {
        $ai_queens |= $BB;
        $ai_white  |= $BB;
    }
}

### TODO this is only used once, get rid of it
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
    #my $squareBB = shift;
    if (! ($occupied & $_[0])) {
        return undef;
    }
    my $chr = '';
    if ( $pawns & $_[0]) {
        $chr = WHITE_PAWN;
    } elsif ($rooks & $_[0]) {
        $chr = WHITE_ROOK;
    } elsif ($bishops & $_[0]) {
        $chr = WHITE_BISHOP;
    } elsif ($knights & $_[0]) {
        $chr = WHITE_KNIGHT;
    } elsif ($queens & $_[0]) {
        $chr = WHITE_QUEEN;
    } elsif ($kings & $_[0]) {
        $chr = WHITE_KING;
    }

    if ($black & $_[0]) {
        return ($chr + 100); # black is 100 higher
    }
    return $chr;
}

sub _getPieceBB_ai {
    #my $squareBB = shift;
    if (! ($ai_occupied & $_[0])) {
        return undef;
    }
    my $chr;
    if ( $ai_pawns & $_[0]) {
        $chr = WHITE_PAWN;
    } elsif ($ai_rooks & $_[0]) {
        $chr = WHITE_ROOK;
    } elsif ($ai_bishops & $_[0]) {
        $chr = WHITE_BISHOP;
    } elsif ($ai_knights & $_[0]) {
        $chr = WHITE_KNIGHT;
    } elsif ($ai_queens & $_[0]) {
        $chr = WHITE_QUEEN;
    } elsif ($ai_kings & $_[0]) {
        $chr = WHITE_KING;
    }

    if ($ai_black & $_[0]) {
        return ($chr + 100); # black is 100 higher
    }
    return $chr;
}

sub _getPiece {
    my ($f, $r) = @_;

    my $squareBB = RANKS_H->{$r} & FILES_H->{$f};
    return _getPieceBB($squareBB);
}

sub _getPieceXY {
    my ($f, $r) = @_;

    my $squareBB = RANKS->[$r] & FILES->[$f];
    return _getPieceBB($squareBB);
}
sub _getPieceXY_ai {
    #my ($f, $r) = @_;

    #my $squareBB = RANKS->[$_[1]] & FILES->[$_[0]];
    return _getPieceBB_ai(RANKS->[$_[1]] & FILES->[$_[0]]);
}

sub occupiedColor {
    my $bb = shift;
    if ( $bb & $white ) {
        return WHITE;
    } elsif ( $bb & $black ) {
        return BLACK
    }

    return 0;
}

sub isMoving {
    my $bb = shift;
    return $bb & $movingBB;
}

sub _getBBat {
    my ($f, $r) = @_;

    return RANKS_H->{$r} & FILES_H->{$f};
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

    ### clear castle opportunities
    if ($whiteCastleK && ($to_bb | $fr_bb) & $whiteCastleK) {
        $whiteCastleK = 0;
    }
    if ($whiteCastleR && ($to_bb | $fr_bb) & $whiteCastleK) {
        $whiteCastleR = 0;
    }
    if ($blackCastleK && ($to_bb | $fr_bb) & $blackCastleK) {
        $blackCastleK = 0;
    }
    if ($blackCastleR && ($to_bb | $fr_bb) & $blackCastleK) {
        $blackCastleR = 0;
    }

    my $piece = _getPieceBB($fr_bb);

    _removePiece($fr_bb);
    _removePiece($to_bb);
    _putPiece($piece, $to_bb);
    return 1;
}

### returns to piece for normal, 0 for from not occupied (failure)
### for ai we need to the toPiece to undo the move
### warning! does not check if the move is legal
sub do_move_ai {
    my ($fr_bb, $to_bb) = @_;

    ### should NOT happen. Moving piece that doesn't exist
    if (! ($fr_bb & $ai_occupied)) {
        print "NULL do_move_ai\n";
        return 0;
    }

    my $piece = _getPieceBB_ai($fr_bb);
    my $toPiece = _getPieceBB_ai($to_bb);

    _removePiece_ai($fr_bb | $to_bb);
    _putPiece_ai($piece, $to_bb);

    $ai_frozenBB &= $to_bb;

    return $toPiece;
}
### return 1 for success, 0 for failure (no piece on to_bb)
sub undo_move_ai {
    my ($fr_bb, $to_bb, $toPiece) = @_;

    ### should NOT happen. Undoing move where no piece exists
    if (! ($to_bb & $ai_occupied)) {
        print "NULL to_bb undo_move\n";
        return 0;
    }

    my $piece = _getPieceBB_ai($to_bb);

    _removePiece_ai($fr_bb | $to_bb);
    _putPiece_ai($piece, $fr_bb);
    if ($toPiece) {
        _putPiece_ai($toPiece, $to_bb);
    }
    $ai_frozenBB ^= $to_bb;
    return 1;
}

### for display purpose only
sub getPieceDisplay {
    my $piece = shift;
    my $color =  "\033[0m";
    if ($piece > 200) {
        $color =  "\033[90m";
    }
    #$color = "";
    my $normal = "\033[0m";
    $normal = "";
    if ($piece % 100 == PAWN) {
        return $color . 'P' . $normal;
    }
    if ($piece % 100 == ROOK) {
        return $color . 'R' . $normal;
    }
    if ($piece % 100 == BISHOP) {
        return $color . 'B' . $normal;
    }
    if ($piece % 100 == KNIGHT) {
        return $color . 'N' . $normal;
    }
    if ($piece % 100 == QUEEN) {
        return $color . 'Q' . $normal;
    }
    if ($piece % 100 == KING) {
        return $color . 'K' . $normal;
    }
    return ' ';
}

### evaluate a single board position staticly, returns the score and moves
sub evaluate {
    my $score         = 0;
    my @moves = (
        {}, # no color
        {}, # white
        {}  # black
    );
    my @material = (
        0,
        0,
        0
    );
    my @squareBonus = (
        0,
        0,
        0
    );
    my @mobilityBonus = (
        0,
        0,
        0
    );
    my @additionalBonus = (
        0,
        0,
        0
    );
    my @kingDangerPenalty = (
        0,
        0,
        0
    );
    my @queenDangerPenalty = (
        0,
        0,
        0
    );
    my @additionalPenalty = (
        0,
        0,
        0
    );
    my @attacking = (
        [ 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0 ], 
        [ 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0 ],  # white
        [ 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0 ],  # black
    );
    ### 3x3 square of king
    my @kingRing = (
        0x0,
        0x0,
        0x0
    );

    my @kingAttackersCount = (
        0,
        0,
        0
    );
    my @pieces = (
        undef,
        [ [], [], [], [], [], [], [] ],  # white pieces
        [ [], [], [], [], [], [], [] ],  # black pieces
    );

    ### TODO reset all eval vars here
    foreach my $r ( 0 .. 7 ) {
        foreach my $f ( 0 .. 7 ) {
            my $fr = RANKS->[$r] & FILES->[$f];
            if ($fr & $ai_movingBB) { next; }
            if ($fr & $ai_frozenBB) { next; }
            my $piece = _getPieceBB_ai($fr);
            next if (! defined($piece));

            ### begin evaluating a piece
            my $pieceType = $piece % 100;
            my $color = $piece > 200 ? BLACK : WHITE;
            ### bitboard of us and them
            my $us       = $color == WHITE ? $ai_white : $ai_black;
            my $them     = $color == BLACK ? $ai_white : $ai_black;
            my $pawnDir  = $color == WHITE ? NORTH  : SOUTH ;
            my $pieceAttackingBB     = 0x0;
            my $pieceAttackingXrayBB = 0x0;

            ### tracks all the pieces for calulating bonuses
            #   TODO here. we cannot use the hash, it converts it to a string
            #   this does not work, clobbers the bb
            #push @{$pieces[$color]->[$pieceType]}, $fr;
            $pieces[$color]->[$pieceType] = $fr;

            ### for square bonuses
            my $sq_f = $f;
            my $sq_r = $color == WHITE ? $r : 7 - $r;
            $squareBonus[$color] += $SQ_BONUS->[$pieceType]->[$sq_r]->[$sq_f];

            if ($pieceType == KING) {
                foreach my $shift (@MOVES_Q) {
                    my $to = $fr;
                    $to = shift_BB($to, $shift);
                    if ($to != 0) {
                        $attacking[$color]->[$pieceType] |= $to;
                        $attacking[$color]->[ALL_P]      |= $to;
                    }
                }
            } elsif ($pieceType == BISHOP || $pieceType == ROOK || $pieceType == QUEEN) {
                my @pmoves;
                if ($pieceType == BISHOP) {
                    $material[$color] += 300;

                    @pmoves = @MOVES_B;
                } elsif ($pieceType == ROOK) {
                    $material[$color] += 500;
                    @pmoves = @MOVES_R;
                } elsif ($pieceType == QUEEN) {
                    $material[$color] += 900;
                    @pmoves = @MOVES_Q;
                }
                my $inXray = 0;
                foreach my $shift (@pmoves) {
                    my $to = $fr;
                    $to = shift_BB($to, $shift);
                    while ($to != 0) {
                        $attacking[$color]->[$pieceType] |= $to;
                        $attacking[$color]->[ALL_P]      |= $to;
                        if ($to & $them){
                            $to = 0;
                            next;
                        }
                        #if ($to & $us & ($movingBB | $frozenBB)){
                        if ($to & $us){
                            $to = 0;
                            next;
                        }
                        if ($inXray == 0) {
                            $mobilityBonus[$color] += 10;
                            $moves[$color]->{sprintf('%s-%s', $fr, $to)} = [
                                $fr,
                                $to,
                                $piece,
                                $pieceType,
                                0,    # score
                                undef # children moves
                            ];
                        }
                        $to = shift_BB($to, $shift);
                    }
                }
            } elsif ($pieceType == KNIGHT) {
                
                $material[$color] += 3;
                foreach my $to (
                   shift_BB(shift_BB($fr, NORTH), NORTH_EAST),
                   shift_BB(shift_BB($fr, NORTH), NORTH_WEST),
                   shift_BB(shift_BB($fr, SOUTH), SOUTH_EAST),
                   shift_BB(shift_BB($fr, SOUTH), SOUTH_WEST),
                   shift_BB(shift_BB($fr, EAST) , NORTH_EAST),
                   shift_BB(shift_BB($fr, EAST) , SOUTH_EAST),
                   shift_BB(shift_BB($fr, WEST) , NORTH_WEST),
                   shift_BB(shift_BB($fr, WEST) , SOUTH_WEST),
                ) {
                    if ($to != 0) {
                        $attacking[$color]->[$pieceType] |= $to;
                        $attacking[$color]->[ALL_P]      |= $to;
                        $mobilityBonus[$color] += 25;
                        if (! ($to & $us) ) {
                            $moves[$color]->{sprintf('%s-%s', $fr, $to)} = [
                                $fr,
                                $to,
                                $piece,
                                $pieceType,
                                0,    # score
                                undef # children moves
                            ];
                        }
                    }
                }
            } elsif ($pieceType == PAWN) {
                $material[$color] += 100;
                my $to = (shift_BB($fr, $pawnDir));
                if (! ($to & $us)) {
                    $moves[$color]->{sprintf('%s-%s', $fr, $to)} = [
                        $fr,
                        $to,
                        $piece,
                        $pieceType,
                        0,    # score
                        undef # children moves
                    ];
                }
                $to = shift_BB($fr, $pawnDir + WEST);
                $attacking[$color]->[$pieceType] |= $to;
                $attacking[$color]->[ALL_P]      |= $to;
                if ($to & $them) {
                    $moves[$color]->{sprintf('%s-%s', $fr, $to)} = [
                        $fr,
                        shift_BB($fr, $pawnDir + WEST),
                        $piece,
                        $pieceType,
                        0,    # score
                        undef # children moves
                    ];
                }
                $to = shift_BB($fr, $pawnDir + EAST);
                $attacking[$color]->[$pieceType] |= $to;
                $attacking[$color]->[ALL_P]      |= $to;
                if ($to & $them) {
                    $moves[$color]->{sprintf('%s-%s', $fr, $to)} = [
                        $fr,
                        shift_BB($fr, $pawnDir + EAST),
                        $piece,
                        $pieceType,
                        0,    # score
                        undef # children moves
                    ];
                }
            }
        }
    }

    foreach my $color (1 .. 2) {
        my $them = ($color == WHITE ? BLACK : WHITE);
        foreach my $pType (1 .. 7) {
            foreach my $bb ($pieces[$color]->[$pType]) {
                if ($pType == BISHOP || $pType == KNIGHT) {
                    if ($attacking[$them][PAWN] & $bb) {
                        $additionalPenalty[$color] -= 2;
                    }
                }
                if ($pType == ROOK) {
                    if ($attacking[$them][PAWN] & $bb) {
                        $additionalPenalty[$color] -= 4;
                    }
                }
                if ($pType == QUEEN) {
                    if ($attacking[$them][PAWN] & $bb) {
                        $additionalPenalty[$color] -= 7;
                    }
                }
                if ($pType == KING) {
                    if ($attacking[$them][PAWN] & $bb) {
                        $additionalPenalty[$color] -= 15;
                    }
                }
            }
        }
    }

    my $score =
          ($material[1]           - $material[2]          )
        + ($squareBonus[1]        - $squareBonus[2]       )
        + ($mobilityBonus[1]      - $mobilityBonus[2]     )
        + ($additionalBonus[1]    - $additionalBonus[2]   )
        - ($kingDangerPenalty[1]  - $kingDangerPenalty[2] )
        - ($queenDangerPenalty[1] - $queenDangerPenalty[2])
        - ($additionalPenalty[1]  - $additionalPenalty[2] )
    ;

    return ($score, \@moves);
}

sub aiThink {
    my ($depth, $timeToThink) = @_;

    my ($score, $bestMoves, $moves) = evaluateTree(0, $depth, time() + $timeToThink);
    #print Dumper($bestMoves);
    $currentAiMoveTree = $moves;

    return ($score, $bestMoves, $moves);
}

sub aiThinkAndMove {
    my ($depth, $timeToThink, $color) = @_;

    my ($score, $bestMoves, $moves) = evaluateTree(0, $depth, time() + $timeToThink);

    foreach my $move (@{$bestMoves->[$color]}) {
        my $fr_bb = $moves->[$color]->{$move}->[MOVE_FR];
        my $to_bb = $moves->[$color]->{$move}->[MOVE_TO];
        if (isLegalMove($fr_bb, $to_bb)) {
            move($fr_bb, $to_bb);
            do_move_ai($fr_bb, $to_bb);
        }
    }
    return ($score, $bestMoves, $moves);
}

sub evaluateTree {
    my ($depth, $maxDepth, $stopTime) = @_;
    #print "evalTree: $color, $depth, $maxDepth, $stopTime\n";
    $| = 1;
    if ($depth > $maxDepth) { return (undef, undef, undef); }

    my ($score, $moves) = evaluate();
            #print pretty_ai();
            #print "   ---- $depth eval score:  $score -----\n";

    my @bestMoves = (
        [],
        [
            undef,
            undef,
            undef,
            undef
        ],
        [
            undef,
            undef,
            undef,
            undef
        ]
    );
    my @bestScores = (
        [],
        [
            -999999,
            -999999,
            -999999,
            -999999,
        ],
        [
            999999,
            999999,
            999999,
            999999,
        ],
    );

    foreach my $color (WHITE, BLACK) {
        while (my ($key, $move) = each %{$moves->[$color]}) {
            my $undoPiece = do_move_ai($move->[0], $move->[1]);
            #print " ---------------------- prettyAI --------------\n";
            my ($newScore, $newBestMoves, $newMoves)          = evaluateTree($depth + 1, $maxDepth, $stopTime);
            $moves->[$color]->{$key}->[MOVE_SCORE]      = $newScore;
            $moves->[$color]->{$key}->[MOVE_NEXT_MOVES] = $newMoves;
            undo_move_ai($move->[0], $move->[1], $undoPiece);

            if ($color == WHITE) {
                if ($newScore) {
                    if ($newScore > $bestScores[WHITE]->[0]) {
                        ### move scores down
                        $bestMoves[WHITE]->[1]  = $bestMoves[WHITE]->[0];
                        $bestScores[WHITE]->[1] = $bestScores[WHITE]->[0];
                        $bestMoves[WHITE]->[2]  = $bestMoves[WHITE]->[1];
                        $bestScores[WHITE]->[2] = $bestScores[WHITE]->[1];
                        $bestMoves[WHITE]->[3]  = $bestMoves[WHITE]->[2];
                        $bestScores[WHITE]->[3] = $bestScores[WHITE]->[2];

                        $bestMoves[WHITE]->[0]  = $key;
                        $bestScores[WHITE]->[0] = $newScore;
                    } elsif ($newScore > $bestScores[WHITE]->[1]) {
                        $bestMoves[WHITE]->[2]  = $bestMoves[WHITE]->[1];
                        $bestScores[WHITE]->[2] = $bestScores[WHITE]->[1];
                        $bestMoves[WHITE]->[3]  = $bestMoves[WHITE]->[2];
                        $bestScores[WHITE]->[3] = $bestScores[WHITE]->[2];

                        $bestMoves[WHITE]->[1]  = $key;
                        $bestScores[WHITE]->[1] = $newScore;
                    } elsif ($newScore > $bestScores[WHITE]->[2]) {
                        $bestMoves[WHITE]->[3]  = $bestMoves[WHITE]->[2];
                        $bestScores[WHITE]->[3] = $bestScores[WHITE]->[2];

                        $bestMoves[WHITE]->[2]  = $key;
                        $bestScores[WHITE]->[2] = $newScore;
                    } elsif ($newScore > $bestScores[WHITE]->[3]) {
                        $bestMoves[WHITE]->[3]  = $key;
                        $bestScores[WHITE]->[3] = $newScore;
                    }
                }
            } else { #### need less than instead of gt
                if ($newScore) {
                    if ($newScore < $bestScores[BLACK]->[0]) {
                        ### move scores down
                        $bestMoves[BLACK]->[1]  = $bestMoves[BLACK]->[0];
                        $bestScores[BLACK]->[1] = $bestScores[BLACK]->[0];
                        $bestMoves[BLACK]->[2]  = $bestMoves[BLACK]->[1];
                        $bestScores[BLACK]->[2] = $bestScores[BLACK]->[1];
                        $bestMoves[BLACK]->[3]  = $bestMoves[BLACK]->[2];
                        $bestScores[BLACK]->[3] = $bestScores[BLACK]->[2];

                        $bestMoves[BLACK]->[0]  = $key;
                        $bestScores[BLACK]->[0] = $newScore;
                    } elsif ($newScore < $bestScores[BLACK]->[1]) {
                        $bestMoves[BLACK]->[2]  = $bestMoves[BLACK]->[1];
                        $bestScores[BLACK]->[2] = $bestScores[BLACK]->[1];
                        $bestMoves[BLACK]->[3]  = $bestMoves[BLACK]->[2];
                        $bestScores[BLACK]->[3] = $bestScores[BLACK]->[2];

                        $bestMoves[BLACK]->[1]  = $key;
                        $bestScores[BLACK]->[1] = $newScore;
                    } elsif ($newScore < $bestScores[BLACK]->[2]) {
                        $bestMoves[BLACK]->[3]  = $bestMoves[BLACK]->[2];
                        $bestScores[BLACK]->[3] = $bestScores[BLACK]->[2];

                        $bestMoves[BLACK]->[2]  = $key;
                        $bestScores[BLACK]->[2] = $newScore;
                    } elsif ($newScore < $bestScores[BLACK]->[3]) {
                        $bestMoves[BLACK]->[3]  = $key;
                        $bestScores[BLACK]->[3] = $newScore;
                    }
                }
            }
            #print " ---------------------- DONE --------------\n";
        }
    }


    if ($bestScores[WHITE]->[0] != -999999) { ### this means we hit max depth
        my $treeScore = (
            ($bestScores[WHITE]->[0] + $bestScores[BLACK]->[0])
            #+ ($bestScores[WHITE]->[1] + $bestScores[BLACK]->[1])
        ) / 2;
        #print "  " x $depth;
        #print "$depth treeScore: $treeScore vs eval: $score\n";

        $score = $treeScore;
    }
    return ($score, \@bestMoves, $moves);
}

sub pretty {
    my $board = '';
    $board .= "\n   +---+---+---+---+---+---+---+----\n";
    foreach my $i ( 0 .. 7 ) {
        my $r = 7-$i;
        foreach my $f ( 0 .. 7 ) {
            if ($f == 0){ $board .= " " . ($r + 1) . " | "; }
            my $chr = getPieceDisplay(_getPieceXY($f, $r));
            $board .= "$chr | ";
        }
        $board .= "\n   +---+---+---+---+---+---+---+----\n";
    }
    $board .= "     a   b   c   d   e   f   g   h  \n";
    return $board;
}

sub pretty_ai {
    my $board = '';
    $board .= "\n   +---+---+---+---+---+---+---+----\n";
    foreach my $i ( 0 .. 7 ) {
        my $r = 7-$i;
        foreach my $f ( 0 .. 7 ) {
            if ($f == 0){ $board .= " " . ($r + 1) . " | "; }
            my $chr = getPieceDisplay(_getPieceXY_ai($f, $r));
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
    printf('hex: 0x%016x' . "\n", $BB);
    $board .= "\n   +---+---+---+---+---+---+---+----\n";
    foreach my $i ( 0 .. 7 ) {
        my $r = 7-$i;
        foreach my $f ( 0 .. 7 ) {
            if ($f eq 0){ $board .= " $r | "; }
                my $rf = RANKS->[$r] & FILES->[$f];
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

sub debug {
    #return _getPiece('a', '1');
    #print prettyBoard($occupied);
    return prettyBoard($rooks);
}

1;
