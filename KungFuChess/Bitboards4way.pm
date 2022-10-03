#!/usr/bin/perl

use strict;
#use warnings;

### same package name as Bitboards so the server doesn't have to know which it is using
package KungFuChess::Bitboards;
use Math::Int128  qw(uint128 string_to_uint128);
use Data::Dumper;
use base 'Exporter';

# 1 for tree debugging, 2 for addition eval debugging
my $aiDebug = 0;

my $aiRandomness = 50; # in points, 100 = PAWN

### for alpha/beta pruning
my $aiScore = undef;  ### current score

my $aiColor = undef;

sub setDebugLevel {
    $aiDebug = shift;
}

my $aiDebugEvalCount = 0;
### each player takes x moves in the ai search tree to simulate real time
my $aiMovesPerTurn = 2;

use constant ({
    NO_COLOR => 0,
    WHITE    => 1,
    BLACK    => 2,
    RED      => 3,
    GREEN    => 4,

    DIR_NONE =>  0,
    NORTH =>  12,
    EAST  =>  1,
    SOUTH => -12,
    WEST  => -1,
    NORTH_EAST =>  13, # north + east
    SOUTH_EAST => -11,
    SOUTH_WEST => -13,
    NORTH_WEST =>  11,

    MOVE_NONE       => 0,
    MOVE_NORMAL     => 1,
    MOVE_EN_PASSANT => 2,
    MOVE_CASTLE_OO  => 3,
    MOVE_CASTLE_OOO => 4,
    MOVE_KNIGHT     => 5,
    MOVE_PUT_PIECE  => 6,
    MOVE_PROMOTE    => 7,
    MOVE_DOUBLE_PAWN => 8,

    ### matches Stockfish
    ALL_PIECES => 000,
    PAWN   => 001,
    KNIGHT => 002,
    BISHOP => 003,
    ROOK   => 004,
    KING   => 005,
    QUEEN  => 006,

    ### array of a move
    MOVE_FR         => 0,
    MOVE_TO         => 1,
    MOVE_SCORE      => 2,
    MOVE_DISTANCE   => 3, 
    MOVE_NEXT_MOVES => 4,
    MOVE_ATTACKS    => 5,

    ### AI variables
    AI_FUTILITY  => 350,  # point loss from move to prune from tree
    AI_INFINITY     =>  99999,
    AI_NEG_INFINITY => -99999,
     
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

    RED_PAWN   => 301,
    RED_KNIGHT => 302,
    RED_BISHOP => 303,
    RED_ROOK   => 304,
    RED_KING   => 305,
    RED_QUEEN  => 306,

    GREEN_PAWN   => 401,
    GREEN_KNIGHT => 402,
    GREEN_BISHOP => 403,
    GREEN_ROOK   => 404,
    GREEN_KING   => 405,
    GREEN_QUEEN  => 406,

# binary number for file 1 (12x12)
#     10000000
#     10000000
# 1000100000000000
# 1000100000000000
# 1000100000000000
# 1000100000000000
# 1000100000000000
# 1000100000000000
# 1000100000000000
# 1000100000000000
#     10000000
#     10000000
# hex number:
# 800800800800800800800800800800800800
    FILES => [
        string_to_uint128('00000000000000001000000000001000000000001000000000001000000000001000000000001000000000001000000000001000000000000000000000000000', 2),
        string_to_uint128('00000000000000000100000000000100000000000100000000000100000000000100000000000100000000000100000000000100000000000000000000000000', 2),
        string_to_uint128('10000000100000000010000000000010000000000010000000000010000000000010000000000010000000000010000000000010000000001000000010000000', 2),
        string_to_uint128('01000000010000000001000000000001000000000001000000000001000000000001000000000001000000000001000000000001000000000100000001000000', 2),
        string_to_uint128('00100000001000000000100000000000100000000000100000000000100000000000100000000000100000000000100000000000100000000010000000100000', 2),
        string_to_uint128('00010000000100000000010000000000010000000000010000000000010000000000010000000000010000000000010000000000010000000001000000010000', 2),
        string_to_uint128('00001000000010000000001000000000001000000000001000000000001000000000001000000000001000000000001000000000001000000000100000001000', 2),
        string_to_uint128('00000100000001000000000100000000000100000000000100000000000100000000000100000000000100000000000100000000000100000000010000000100', 2),
        string_to_uint128('00000010000000100000000010000000000010000000000010000000000010000000000010000000000010000000000010000000000010000000001000000010', 2),
        string_to_uint128('00000001000000010000000001000000000001000000000001000000000001000000000001000000000001000000000001000000000001000000000100000001', 2),
        string_to_uint128('00000000000000000000000000100000000000100000000000100000000000100000000000100000000000100000000000100000000000100000000000000000', 2),
        string_to_uint128('00000000000000000000000000010000000000010000000000010000000000010000000000010000000000010000000000010000000000010000000000000000', 2),
    ],
    FILES_H => {
        a  => string_to_uint128('00000000000000001000000000001000000000001000000000001000000000001000000000001000000000001000000000001000000000000000000000000000', 2),
        b  => string_to_uint128('00000000000000000100000000000100000000000100000000000100000000000100000000000100000000000100000000000100000000000000000000000000', 2),
        c  => string_to_uint128('10000000100000000010000000000010000000000010000000000010000000000010000000000010000000000010000000000010000000001000000010000000', 2),
        d  => string_to_uint128('01000000010000000001000000000001000000000001000000000001000000000001000000000001000000000001000000000001000000000100000001000000', 2),
        e  => string_to_uint128('00100000001000000000100000000000100000000000100000000000100000000000100000000000100000000000100000000000100000000010000000100000', 2),
        f  => string_to_uint128('00010000000100000000010000000000010000000000010000000000010000000000010000000000010000000000010000000000010000000001000000010000', 2),
        g  => string_to_uint128('00001000000010000000001000000000001000000000001000000000001000000000001000000000001000000000001000000000001000000000100000001000', 2),
        h  => string_to_uint128('00000100000001000000000100000000000100000000000100000000000100000000000100000000000100000000000100000000000100000000010000000100', 2),
        i  => string_to_uint128('00000010000000100000000010000000000010000000000010000000000010000000000010000000000010000000000010000000000010000000001000000010', 2),
        j  => string_to_uint128('00000001000000010000000001000000000001000000000001000000000001000000000001000000000001000000000001000000000001000000000100000001', 2),
        k  => string_to_uint128('00000000000000000000000000100000000000100000000000100000000000100000000000100000000000100000000000100000000000100000000000000000', 2),
        l  => string_to_uint128('00000000000000000000000000010000000000010000000000010000000000010000000000010000000000010000000000010000000000010000000000000000', 2),
    },

# binary number for file 1:
#     00000000
#     00000000
# 0000000000000000
# 0000000000000000
# 0000000000000000
# 0000000000000000
# 0000000000000000
# 0000000000000000
# 0000000000000000
# 0000000000000000
#     00000000
#     00000000
# hex number:
# 000000000000000000000000FFF
    RANKS => [
        string_to_uint128('11111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000', 2),
        string_to_uint128('00000000111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000', 2),
        string_to_uint128('00000000000000001111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000', 2),
        string_to_uint128('00000000000000000000000000001111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000', 2),
        string_to_uint128('00000000000000000000000000000000000000001111111111110000000000000000000000000000000000000000000000000000000000000000000000000000', 2),
        string_to_uint128('00000000000000000000000000000000000000000000000000001111111111110000000000000000000000000000000000000000000000000000000000000000', 2),
        string_to_uint128('00000000000000000000000000000000000000000000000000000000000000001111111111110000000000000000000000000000000000000000000000000000', 2),
        string_to_uint128('00000000000000000000000000000000000000000000000000000000000000000000000000001111111111110000000000000000000000000000000000000000', 2),
        string_to_uint128('00000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111111110000000000000000000000000000', 2),
        string_to_uint128('00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111111110000000000000000', 2),
        string_to_uint128('00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111100000000', 2),
        string_to_uint128('00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111111', 2),
    ],
    RANKS_H => {
        '1'  => string_to_uint128('11111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000', 2),
        '2'  => string_to_uint128('00000000111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000', 2),
        '3'  => string_to_uint128('00000000000000001111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000', 2),
        '4'  => string_to_uint128('00000000000000000000000000001111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000', 2),
        '5'  => string_to_uint128('00000000000000000000000000000000000000001111111111110000000000000000000000000000000000000000000000000000000000000000000000000000', 2),
        '6'  => string_to_uint128('00000000000000000000000000000000000000000000000000001111111111110000000000000000000000000000000000000000000000000000000000000000', 2),
        '7'  => string_to_uint128('00000000000000000000000000000000000000000000000000000000000000001111111111110000000000000000000000000000000000000000000000000000', 2),
        '8'  => string_to_uint128('00000000000000000000000000000000000000000000000000000000000000000000000000001111111111110000000000000000000000000000000000000000', 2),
        '9'  => string_to_uint128('00000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111111110000000000000000000000000000', 2),
        '10' => string_to_uint128('00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111111110000000000000000', 2),
        '11' => string_to_uint128('00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111100000000', 2),
        '12' => string_to_uint128('00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111111', 2),
    },

    ### special number we need because we are using BigInt, so it goes on forever
    # TODO still needed for int128?
    MAX_BITBOARD => string_to_uint128('0x000000000000000000000000000000FF', 16) >> 144,

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

our @EXPORT_OK = qw(MOVE_NONE MOVE_NORMAL MOVE_PROMOTE MOVE_EN_PASSANT MOVE_CASTLE_OO MOVE_CASTLE_OOO MOVE_KNIGHT WHITE_PAWN WHITE_KNIGHT WHITE_ROOK WHITE_BISHOP WHITE_KING WHITE_QUEEN BLACK_PAWN BLACK_KNIGHT BLACK_ROOK BLACK_BISHOP BLACK_KING BLACK_QUEEN);

### these should be perfect hashes of all bitboard squares
my %whiteMoves = ();
my %blackMoves = ();
my $currentMoves = undef;

sub getCurrentMoves {
    return $currentMoves;
}
sub setCurrentMoves {
    $currentMoves = $_;
}

### 4way only, can't capture initial pawn setup
### to test simply & together fr and to and this
my $illegalPawnCaptures =
    FILES_H->{'c'} & RANKS_H->{'2'}  |
    FILES_H->{'b'} & RANKS_H->{'3'}  |

    FILES_H->{'j'} & RANKS_H->{'2'}  |
    FILES_H->{'k'} & RANKS_H->{'3'}  |

    FILES_H->{'c'} & RANKS_H->{'11'} |
    FILES_H->{'b'} & RANKS_H->{'10'} |

    FILES_H->{'j'} & RANKS_H->{'11'} |
    FILES_H->{'k'} & RANKS_H->{'10'} |

    FILES_H->{'k'} & RANKS_H->{'3'}  |
    FILES_H->{'j'} & RANKS_H->{'2'}  |

    FILES_H->{'k'} & RANKS_H->{'10'} |
    FILES_H->{'j'} & RANKS_H->{'11'} |

    FILES_H->{'b'} & RANKS_H->{'3'}  |
    FILES_H->{'c'} & RANKS_H->{'2'}  |

    FILES_H->{'b'} & RANKS_H->{'10'} |
    FILES_H->{'c'} & RANKS_H->{'11'} ;

### similar to stockfish we have multiple bitboards that we intersect
### to determine the position of things and state of things.
### init all bitboards to zero

### piece types
my $pawns    = string_to_uint128('0x00000000000000000000000000000000', 16);
my $knights  = string_to_uint128('0x00000000000000000000000000000000', 16);
my $bishops  = string_to_uint128('0x00000000000000000000000000000000', 16);
my $rooks    = string_to_uint128('0x00000000000000000000000000000000', 16);
my $queens   = string_to_uint128('0x00000000000000000000000000000000', 16);
my $kings    = string_to_uint128('0x00000000000000000000000000000000', 16);

### colors
my $white    = string_to_uint128('0x00000000000000000000000000000000', 16);
my $black    = string_to_uint128('0x00000000000000000000000000000000', 16);
my $red      = string_to_uint128('0x00000000000000000000000000000000', 16);
my $green    = string_to_uint128('0x00000000000000000000000000000000', 16);
my $occupied = string_to_uint128('0x00000000000000000000000000000000', 16);

my $enPassant = string_to_uint128('0x00000000000000000000000000000000', 16);

my $whiteCastleK  = RANKS_H->{1} & FILES_H->{'g'};
my $whiteCastleR  = RANKS_H->{1} & FILES_H->{'j'};
my $whiteCastleR_off  = RANKS_H->{1} & FILES_H->{'i'};
my $whiteQCastleR = RANKS_H->{1} & FILES_H->{'c'};
my $whiteQCastleR_off = RANKS_H->{1} & FILES_H->{'e'};
my $blackCastleK  = RANKS_H->{12} & FILES_H->{'g'};
my $blackCastleR  = RANKS_H->{12} & FILES_H->{'j'};
my $blackCastleR_off  = RANKS_H->{12} & FILES_H->{'i'};
my $blackQCastleR = RANKS_H->{12} & FILES_H->{'c'};
my $blackQCastleR_off = RANKS_H->{12} & FILES_H->{'e'};
my $redCastleK  = RANKS_H->{6} & FILES_H->{'a'};
my $redCastleR  = RANKS_H->{3} & FILES_H->{'a'};
my $redCastleR_off  = RANKS_H->{4} & FILES_H->{'a'};
my $redQCastleR = RANKS_H->{10} & FILES_H->{'a'};
my $redQCastleR_off = RANKS_H->{8} & FILES_H->{'a'};
my $greenCastleK  = RANKS_H->{6} & FILES_H->{'l'};
my $greenCastleR  = RANKS_H->{3} & FILES_H->{'l'};
my $greenCastleR_off  = RANKS_H->{4} & FILES_H->{'l'};
my $greenQCastleR = RANKS_H->{10} & FILES_H->{'l'};
my $greenQCastleR_off = RANKS_H->{8} & FILES_H->{'l'};

### frozen pieces, can't move
my $frozenBB = string_to_uint128('0x00000000000000000000000000000000', 16);
my $movingBB = string_to_uint128('0x00000000000000000000000000000000', 16);

### same as above but for ai to manipulate
my $ai_pawns    = string_to_uint128('0x00000000000000000000000000000000', 16);
my $ai_knights  = string_to_uint128('0x00000000000000000000000000000000', 16);
my $ai_bishops  = string_to_uint128('0x00000000000000000000000000000000', 16);
my $ai_rooks    = string_to_uint128('0x00000000000000000000000000000000', 16);
my $ai_queens   = string_to_uint128('0x00000000000000000000000000000000', 16);
my $ai_kings    = string_to_uint128('0x00000000000000000000000000000000', 16);

### colors
my $ai_white    = string_to_uint128('0x00000000000000000000000000000000', 16);
my $ai_black    = string_to_uint128('0x00000000000000000000000000000000', 16);
my $ai_red      = string_to_uint128('0x00000000000000000000000000000000', 16);
my $ai_green    = string_to_uint128('0x00000000000000000000000000000000', 16);

### players are converted to "white" (us) and "black" (them) to simplify
#   these boards are kept for true colors to track pawn direction
my $ai_white_true   = string_to_uint128('0x00000000000000000000000000000000', 16);
my $ai_black_true   = string_to_uint128('0x00000000000000000000000000000000', 16);
my $ai_red_true   = string_to_uint128('0x00000000000000000000000000000000', 16);
my $ai_green_true = string_to_uint128('0x00000000000000000000000000000000', 16);

my $ai_occupied = string_to_uint128('0x00000000000000000000000000000000', 16);
my $ai_enPassant = string_to_uint128('0x00000000000000000000000000000000', 16);
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

### for c++ 2way
sub setPosXS {

}

sub movingOppositeDirs {
    my ($a, $b) = @_;

    if ($a == NORTH) { return $b == SOUTH; }
    if ($a == SOUTH) { return $b == NORTH; }
    if ($a == EAST)  { return $b == WEST;  }
    if ($a == WEST)  { return $b == EAST;  }
    if ($a == NORTH_EAST)  { return $b == SOUTH_WEST;  }
    if ($a == SOUTH_EAST)  { return $b == NORTH_WEST;  }
    if ($a == NORTH_WEST)  { return $b == SOUTH_EAST;  }
    if ($a == SOUTH_WEST)  { return $b == NORTH_EAST;  }

    ### should get here
    return 0;
}

sub resetAiBoards {
    my $color = shift;

    $ai_pawns    = $pawns;
    $ai_knights  = $knights;
    $ai_bishops  = $bishops;
    $ai_rooks    = $rooks;
    $ai_queens   = $queens; 
    $ai_kings    = $kings;
    $ai_occupied  = $occupied;
    $ai_enPassant = $enPassant;

    if ($color) {
        if ($color == WHITE) {
            $ai_white    = $white;
            $ai_black    = $black | $red | $green;
        } elsif ($color == BLACK) {
            $ai_white    = $black;
            $ai_black    = $white | $red | $green;
        } elsif ($color == RED) {
            $ai_white    = $red;
            $ai_black    = $black | $white | $green;
        } elsif ($color == GREEN) {
            $ai_white    = $green;
            $ai_black    = $black | $red | $white;
        }
    } else {
        $ai_white    = $white;
        $ai_black    = $black;
        $ai_red      = $red;
        $ai_green    = $green;
    }
    $ai_white_true    = $white;
    $ai_black_true    = $black;
    $ai_red_true      = $red;
    $ai_green_true    = $green;
    # don't bother with castles
    #$ai_whiteCastleK  = $whiteCastleK ;
    #$ai_blackCastleK  = $blackCastleK ;
    #$ai_whiteCastleR  = $whiteCastleR ;
    #$ai_blackCastleR  = $blackCastleR ;
    #$ai_whiteQCastleR = $whiteQCastleR;
    #$ai_blackQCastleR = $blackQCastleR;

    #$ai_frozenBB = $frozenBB;
    $ai_frozenBB = 0;
    $ai_movingBB = $movingBB;

    ### if we are moving it FOR a color we clear our enemies frozen
    #if ($color && $color == WHITE) {
        #$ai_frozenBB &= ~$black;
    #} elsif ($color && $color == BLACK) {
        #$ai_frozenBB &= ~$white;
    #}
    ### clear the current moves. We don't search enough depth
    #   and the game is too fast paced to worry about the tree
    #   replacing the current moves, just have to redo it every time
    $currentMoves = undef;
}

sub setupInitialPosition {
    my $color = shift;
    #### white ####
    # rook 1
    if (! $color || $color eq 'white') {
    $occupied |= (FILES_H->{c} & RANKS_H->{1});
    $rooks    |= (FILES_H->{c} & RANKS_H->{1});
    $white    |= (FILES_H->{c} & RANKS_H->{1});
    # pawn 
    $occupied |= (FILES_H->{c} & RANKS_H->{2});
    $pawns    |= (FILES_H->{c} & RANKS_H->{2});
    $white    |= (FILES_H->{c} & RANKS_H->{2});
        
    # knight 1
    $occupied |= (FILES_H->{d} & RANKS_H->{1});
    $knights  |= (FILES_H->{d} & RANKS_H->{1});
    $white    |= (FILES_H->{d} & RANKS_H->{1});
    # pawn 
    $occupied |= (FILES_H->{d} & RANKS_H->{2});
    $pawns    |= (FILES_H->{d} & RANKS_H->{2});
    $white    |= (FILES_H->{d} & RANKS_H->{2});
        
    # bishop 1
    $occupied |= (FILES_H->{e} & RANKS_H->{1});
    $bishops  |= (FILES_H->{e} & RANKS_H->{1});
    $white    |= (FILES_H->{e} & RANKS_H->{1});
    # pawn 
    $occupied |= (FILES_H->{e} & RANKS_H->{2});
    $pawns    |= (FILES_H->{e} & RANKS_H->{2});
    $white    |= (FILES_H->{e} & RANKS_H->{2});
        
    # queen
    $occupied |= (FILES_H->{f} & RANKS_H->{1});
    $queens   |= (FILES_H->{f} & RANKS_H->{1});
    $white    |= (FILES_H->{f} & RANKS_H->{1});
    # pawn 
    $occupied |= (FILES_H->{f} & RANKS_H->{2});
    $pawns    |= (FILES_H->{f} & RANKS_H->{2});
    $white    |= (FILES_H->{f} & RANKS_H->{2});
        
    # king
    $occupied |= (FILES_H->{g} & RANKS_H->{1});
    $kings    |= (FILES_H->{g} & RANKS_H->{1});
    $white    |= (FILES_H->{g} & RANKS_H->{1});
    # pawn 
    $occupied |= (FILES_H->{g} & RANKS_H->{2});
    $pawns    |= (FILES_H->{g} & RANKS_H->{2});
    $white    |= (FILES_H->{g} & RANKS_H->{2});
        
    # bishop2
    $occupied |= (FILES_H->{h} & RANKS_H->{1});
    $bishops  |= (FILES_H->{h} & RANKS_H->{1});
    $white    |= (FILES_H->{h} & RANKS_H->{1});
    # pawn 
    $occupied |= (FILES_H->{h} & RANKS_H->{2});
    $pawns    |= (FILES_H->{h} & RANKS_H->{2});
    $white    |= (FILES_H->{h} & RANKS_H->{2});
        
    # knight2
    $occupied |= (FILES_H->{i} & RANKS_H->{1});
    $knights  |= (FILES_H->{i} & RANKS_H->{1});
    $white    |= (FILES_H->{i} & RANKS_H->{1});
    # pawn 
    $occupied |= (FILES_H->{i} & RANKS_H->{2});
    $pawns    |= (FILES_H->{i} & RANKS_H->{2});
    $white    |= (FILES_H->{i} & RANKS_H->{2});
        
    # rook2
    $occupied |= (FILES_H->{j} & RANKS_H->{1});
    $rooks    |= (FILES_H->{j} & RANKS_H->{1});
    $white    |= (FILES_H->{j} & RANKS_H->{1});
    # pawn 
    $occupied |= (FILES_H->{j} & RANKS_H->{2});
    $pawns    |= (FILES_H->{j} & RANKS_H->{2});
    $white    |= (FILES_H->{j} & RANKS_H->{2});
    }

    if (! $color || $color eq 'black') {
    #### black ####
    # rook 1
    $occupied |= (FILES_H->{c} & RANKS_H->{12});
    $rooks    |= (FILES_H->{c} & RANKS_H->{12});
    $black    |= (FILES_H->{c} & RANKS_H->{12});
    # pawn 
    $occupied |= (FILES_H->{c} & RANKS_H->{11});
    $pawns    |= (FILES_H->{c} & RANKS_H->{11});
    $black    |= (FILES_H->{c} & RANKS_H->{11});
        
    # knight 1
    $occupied |= (FILES_H->{d} & RANKS_H->{12});
    $knights  |= (FILES_H->{d} & RANKS_H->{12});
    $black    |= (FILES_H->{d} & RANKS_H->{12});
    # pawn 
    $occupied |= (FILES_H->{d} & RANKS_H->{11});
    $pawns    |= (FILES_H->{d} & RANKS_H->{11});
    $black    |= (FILES_H->{d} & RANKS_H->{11});
        
    # bishop 1
    $occupied |= (FILES_H->{e} & RANKS_H->{12});
    $bishops  |= (FILES_H->{e} & RANKS_H->{12});
    $black    |= (FILES_H->{e} & RANKS_H->{12});
    # pawn 
    $occupied |= (FILES_H->{e} & RANKS_H->{11});
    $pawns    |= (FILES_H->{e} & RANKS_H->{11});
    $black    |= (FILES_H->{e} & RANKS_H->{11});
        
    # queen
    $occupied |= (FILES_H->{f} & RANKS_H->{12});
    $queens   |= (FILES_H->{f} & RANKS_H->{12});
    $black    |= (FILES_H->{f} & RANKS_H->{12});
    # pawn 
    $occupied |= (FILES_H->{f} & RANKS_H->{11});
    $pawns    |= (FILES_H->{f} & RANKS_H->{11});
    $black    |= (FILES_H->{f} & RANKS_H->{11});
        
    # king
    $occupied |= (FILES_H->{g} & RANKS_H->{12});
    $kings    |= (FILES_H->{g} & RANKS_H->{12});
    $black    |= (FILES_H->{g} & RANKS_H->{12});
    # pawn 
    $occupied |= (FILES_H->{g} & RANKS_H->{11});
    $pawns    |= (FILES_H->{g} & RANKS_H->{11});
    $black    |= (FILES_H->{g} & RANKS_H->{11});
        
    # bishop2
    $occupied |= (FILES_H->{h} & RANKS_H->{12});
    $bishops  |= (FILES_H->{h} & RANKS_H->{12});
    $black    |= (FILES_H->{h} & RANKS_H->{12});
    # pawn 
    $occupied |= (FILES_H->{h} & RANKS_H->{11});
    $pawns    |= (FILES_H->{h} & RANKS_H->{11});
    $black    |= (FILES_H->{h} & RANKS_H->{11});
        
    # knight2
    $occupied |= (FILES_H->{i} & RANKS_H->{12});
    $knights  |= (FILES_H->{i} & RANKS_H->{12});
    $black    |= (FILES_H->{i} & RANKS_H->{12});
    # pawn 
    $occupied |= (FILES_H->{i} & RANKS_H->{11});
    $pawns    |= (FILES_H->{i} & RANKS_H->{11});
    $black    |= (FILES_H->{i} & RANKS_H->{11});
        
    # rook2
    $occupied |= (FILES_H->{j} & RANKS_H->{12});
    $rooks    |= (FILES_H->{j} & RANKS_H->{12});
    $black    |= (FILES_H->{j} & RANKS_H->{12});
    # pawn 
    $occupied |= (FILES_H->{j} & RANKS_H->{11});
    $pawns    |= (FILES_H->{j} & RANKS_H->{11});
    $black    |= (FILES_H->{j} & RANKS_H->{11});
    }

    if (! $color || $color eq 'red') {
    #### red ####
    # rook 1
    $occupied |= (FILES_H->{a} & RANKS_H->{10});
    $rooks    |= (FILES_H->{a} & RANKS_H->{10});
    $red      |= (FILES_H->{a} & RANKS_H->{10});
    # pawn 
    $occupied |= (FILES_H->{b} & RANKS_H->{10});
    $pawns    |= (FILES_H->{b} & RANKS_H->{10});
    $red      |= (FILES_H->{b} & RANKS_H->{10});
        
    # knight 1
    $occupied |= (FILES_H->{a} & RANKS_H->{9});
    $knights  |= (FILES_H->{a} & RANKS_H->{9});
    $red      |= (FILES_H->{a} & RANKS_H->{9});
    # pawn 
    $occupied |= (FILES_H->{b} & RANKS_H->{9});
    $pawns    |= (FILES_H->{b} & RANKS_H->{9});
    $red      |= (FILES_H->{b} & RANKS_H->{9});
        
    # bishop 1
    $occupied |= (FILES_H->{a} & RANKS_H->{8});
    $bishops  |= (FILES_H->{a} & RANKS_H->{8});
    $red      |= (FILES_H->{a} & RANKS_H->{8});
    # pawn 
    $occupied |= (FILES_H->{b} & RANKS_H->{8});
    $pawns    |= (FILES_H->{b} & RANKS_H->{8});
    $red      |= (FILES_H->{b} & RANKS_H->{8});
        
    # queen
    $occupied |= (FILES_H->{a} & RANKS_H->{7});
    $queens   |= (FILES_H->{a} & RANKS_H->{7});
    $red      |= (FILES_H->{a} & RANKS_H->{7});
    # pawn 
    $occupied |= (FILES_H->{b} & RANKS_H->{7});
    $pawns    |= (FILES_H->{b} & RANKS_H->{7});
    $red      |= (FILES_H->{b} & RANKS_H->{7});
        
    # king
    $occupied |= (FILES_H->{a} & RANKS_H->{6});
    $kings    |= (FILES_H->{a} & RANKS_H->{6});
    $red      |= (FILES_H->{a} & RANKS_H->{6});
    # pawn 
    $occupied |= (FILES_H->{b} & RANKS_H->{6});
    $pawns    |= (FILES_H->{b} & RANKS_H->{6});
    $red      |= (FILES_H->{b} & RANKS_H->{6});
        
    # bishop2
    $occupied |= (FILES_H->{a} & RANKS_H->{5});
    $bishops  |= (FILES_H->{a} & RANKS_H->{5});
    $red      |= (FILES_H->{a} & RANKS_H->{5});
    # pawn 
    $occupied |= (FILES_H->{b} & RANKS_H->{5});
    $pawns    |= (FILES_H->{b} & RANKS_H->{5});
    $red      |= (FILES_H->{b} & RANKS_H->{5});
        
    # knight2
    $occupied |= (FILES_H->{a} & RANKS_H->{4});
    $knights  |= (FILES_H->{a} & RANKS_H->{4});
    $red      |= (FILES_H->{a} & RANKS_H->{4});
    # pawn 
    $occupied |= (FILES_H->{b} & RANKS_H->{4});
    $pawns    |= (FILES_H->{b} & RANKS_H->{4});
    $red      |= (FILES_H->{b} & RANKS_H->{4});
        
    # rook2
    $occupied |= (FILES_H->{a} & RANKS_H->{3});
    $rooks    |= (FILES_H->{a} & RANKS_H->{3});
    $red      |= (FILES_H->{a} & RANKS_H->{3});
    # pawn 
    $occupied |= (FILES_H->{b} & RANKS_H->{3});
    $pawns    |= (FILES_H->{b} & RANKS_H->{3});
    $red      |= (FILES_H->{b} & RANKS_H->{3});
    }

    if (! $color || $color eq 'green') {
    #### green ####
    # rook 1
    $occupied |= (FILES_H->{l} & RANKS_H->{10});
    $rooks    |= (FILES_H->{l} & RANKS_H->{10});
    $green    |= (FILES_H->{l} & RANKS_H->{10});
    # pawn 
    $occupied |= (FILES_H->{k} & RANKS_H->{10});
    $pawns    |= (FILES_H->{k} & RANKS_H->{10});
    $green    |= (FILES_H->{k} & RANKS_H->{10});
        
    # knight 1
    $occupied |= (FILES_H->{l} & RANKS_H->{9});
    $knights  |= (FILES_H->{l} & RANKS_H->{9});
    $green    |= (FILES_H->{l} & RANKS_H->{9});
    # pawn 
    $occupied |= (FILES_H->{k} & RANKS_H->{9});
    $pawns    |= (FILES_H->{k} & RANKS_H->{9});
    $green    |= (FILES_H->{k} & RANKS_H->{9});
        
    # bishop 1
    $occupied |= (FILES_H->{l} & RANKS_H->{8});
    $bishops  |= (FILES_H->{l} & RANKS_H->{8});
    $green    |= (FILES_H->{l} & RANKS_H->{8});
    # pawn 
    $occupied |= (FILES_H->{k} & RANKS_H->{8});
    $pawns    |= (FILES_H->{k} & RANKS_H->{8});
    $green    |= (FILES_H->{k} & RANKS_H->{8});
        
    # queen
    $occupied |= (FILES_H->{l} & RANKS_H->{7});
    $queens   |= (FILES_H->{l} & RANKS_H->{7});
    $green    |= (FILES_H->{l} & RANKS_H->{7});
    # pawn 
    $occupied |= (FILES_H->{k} & RANKS_H->{7});
    $pawns    |= (FILES_H->{k} & RANKS_H->{7});
    $green    |= (FILES_H->{k} & RANKS_H->{7});
        
    # king
    $occupied |= (FILES_H->{l} & RANKS_H->{6});
    $kings    |= (FILES_H->{l} & RANKS_H->{6});
    $green    |= (FILES_H->{l} & RANKS_H->{6});
    # pawn 
    $occupied |= (FILES_H->{k} & RANKS_H->{6});
    $pawns    |= (FILES_H->{k} & RANKS_H->{6});
    $green    |= (FILES_H->{k} & RANKS_H->{6});
        
    # bishop2
    $occupied |= (FILES_H->{l} & RANKS_H->{5});
    $bishops  |= (FILES_H->{l} & RANKS_H->{5});
    $green    |= (FILES_H->{l} & RANKS_H->{5});
    # pawn 
    $occupied |= (FILES_H->{k} & RANKS_H->{5});
    $pawns    |= (FILES_H->{k} & RANKS_H->{5});
    $green    |= (FILES_H->{k} & RANKS_H->{5});
        
    # knight2
    $occupied |= (FILES_H->{l} & RANKS_H->{4});
    $knights  |= (FILES_H->{l} & RANKS_H->{4});
    $green    |= (FILES_H->{l} & RANKS_H->{4});
    # pawn 
    $occupied |= (FILES_H->{k} & RANKS_H->{4});
    $pawns    |= (FILES_H->{k} & RANKS_H->{4});
    $green    |= (FILES_H->{k} & RANKS_H->{4});
        
    # rook2
    $occupied |= (FILES_H->{l} & RANKS_H->{3});
    $rooks    |= (FILES_H->{l} & RANKS_H->{3});
    $green    |= (FILES_H->{l} & RANKS_H->{3});
    # pawn 
    $occupied |= (FILES_H->{k} & RANKS_H->{3});
    $pawns    |= (FILES_H->{k} & RANKS_H->{3});
    $green    |= (FILES_H->{k} & RANKS_H->{3});
    }
}

### copied from shift function in Stockfish
#sub shift_BB {
    #my ($bb, $direction) = @_;
    ##if ($direction == NORTH && $bb | RANKS->[0]) {
    #if (($direction == NORTH || $direction == NORTH_WEST || $direction == NORTH_EAST) && $bb | RANKS->[0]) {
        #return 0;
    #}
    #return  $direction == NORTH      ?  $bb                <<12   : $direction == SOUTH      ?  $bb                >>12
          #: $direction == NORTH+NORTH?  $bb                <<24   : $direction == SOUTH+SOUTH?  $bb                >>24
          #: $direction == EAST       ? ($bb & ~FILES_H->{a}) << 1 : $direction == WEST       ? ($bb & ~FILES_H->{l}) >> 1
          #: $direction == NORTH_EAST ? ($bb & ~FILES_H->{a}) <<13 : $direction == NORTH_WEST ? ($bb & ~FILES_H->{l}) <<11
          #: $direction == SOUTH_EAST ? ($bb & ~FILES_H->{a}) >>11 : $direction == SOUTH_WEST ? ($bb & ~FILES_H->{l}) >>13
          #: 0;
#}
#   00000000
#   00000000
# 000000000000
# 000000000000
# 000000000000
# 000000000000
# 000000000000
# 000000000000
# 000000000000
# 000000000000
#   00000000
#   00000000

my $cantGoNorth = RANKS->[11] | (RANKS->[9] & (FILES->[0] | FILES->[1] | FILES->[10] | FILES->[11]));
my $cantGoSouth = RANKS->[0]  | (RANKS->[2] & (FILES->[0] | FILES->[1] | FILES->[10] | FILES->[11]));

my $cantGoEast  = FILES->[11] | (FILES->[9] & (RANKS->[0] | RANKS->[1] | RANKS->[10] | RANKS->[11]));
my $cantGoWest  = FILES->[0]  | (FILES->[2] & (RANKS->[0] | RANKS->[1] | RANKS->[10] | RANKS->[11]));

sub shift_BB {
    #my ($bb, $direction) = @_;

    ### handle the custom cases were you have to shift less
    #   because the board is less wide at the top/bottom
    if ($_[1] == NORTH) {
        if ($_[0] & $cantGoNorth) {
            return 0;
        } elsif ($_[0] & (RANKS->[0] | RANKS->[10])) {
            return $_[0] >> 8;
        } elsif ($_[0] & (RANKS->[1] | RANKS->[9])) {
            return $_[0] >> 10;
        } else {
            return $_[0] >> 12;
        }
    }
    if ($_[1] == SOUTH) {
        if ($_[0] & $cantGoSouth) {
            return 0;
        } elsif ($_[0] & (RANKS->[11] | RANKS->[1])) {
            return $_[0] << 8;
        } elsif ($_[0] & (RANKS->[10] | RANKS->[2])) {
            return $_[0] << 10;
        } else {
            return $_[0] << 12;
        }
    }
    if ($_[1] == EAST) {
        if ($_[0] & $cantGoEast) {
            return 0;
        } else {
            return $_[0] >> 1;
        }
    }
    if ($_[1] == WEST) {
        if ($_[0] & $cantGoWest) {
            return 0;
        } else {
            return $_[0] << 1;
        }
    }

    ### we don't mess around with shortcuts just run it twice
    if ($_[1] == NORTH+NORTH) {
        return shift_BB(shift_BB($_[0], NORTH), NORTH);
    } elsif ($_[1] == SOUTH+SOUTH) {
        return shift_BB(shift_BB($_[0], SOUTH), SOUTH);
    } elsif ($_[1] == EAST+EAST) {
        return shift_BB(shift_BB($_[0], EAST), EAST);
    } elsif ($_[1] == WEST+WEST) {
        return shift_BB(shift_BB($_[0], WEST), WEST);
    } elsif ($_[1] == NORTH_WEST) {
        return shift_BB(shift_BB($_[0], NORTH), WEST);
    } elsif ($_[1] == NORTH_EAST) {
        return shift_BB(shift_BB($_[0], NORTH), EAST);
    } elsif ($_[1] == SOUTH_WEST) {
        return shift_BB(shift_BB($_[0], SOUTH), WEST);
    } elsif ($_[1] == SOUTH_EAST) {
        return shift_BB(shift_BB($_[0], SOUTH), EAST);
    }

    return 0;
    #return  $_[1] == NORTH      ?  $_[0]                << 8 : $_[1] == SOUTH      ?  $_[0]                >> 8
          #: $_[1] == NORTH+NORTH?  $_[0]                <<16 : $_[1] == SOUTH+SOUTH?  $_[0]                >>16
          #: $_[1] == EAST       ? ($_[0] & ~FILES->[15]) << 1 : $_[1] == WEST       ? ($_[0] & ~FILES->[0]) >> 1
          #: $_[1] == NORTH_EAST ? ($_[0] & ~FILES->[15]) << 9 : $_[1] == NORTH_WEST ? ($_[0] & ~FILES->[0]) << 7
          #: $_[1] == SOUTH_EAST ? ($_[0] & ~FILES->[15]) >> 7 : $_[1] == SOUTH_WEST ? ($_[0] & ~FILES->[0]) >> 9
          #: 0;
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

sub _removeColorByName {
    my $colorName = shift;
    if ($colorName eq 'white') {
        _removePiece($white);
    } elsif($colorName eq 'black') {
        _removePiece($black);
    } elsif($colorName eq 'red') {
        _removePiece($red);
    } elsif($colorName eq 'green') {
        _removePiece($green);
    }
}

sub _removeColorByPiece {
    my $piece = shift;

    if ($piece < 200) {
        _removePiece($white);
    } elsif ($piece < 300) {
        _removePiece($black);
    } elsif ($piece < 400) {
        _removePiece($red);
    } else {
        _removePiece($green);
    }
}

sub setFrozen {
    my $bb = shift;
    $frozenBB = $bb;
    $ai_frozenBB = $bb;
}
sub addFrozen {
    my $bb = shift;
    $frozenBB |= $bb;
    $ai_frozenBB |= $bb;
}
sub unsetFrozen {
    my $bb = shift;
    $frozenBB &= ~$bb;
    $ai_frozenBB &= ~$bb;
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
            if ($fromBB == 0)           { return 0; } ### of the board
            #if ($fromBB >  MAX_BITBOARD){ return 0; } ### of the board
            if ($fromBB & $blockingBB)  { return 0; }

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

    my $pawnDir;
    if ($white & $bb) {
        $pawnDir = NORTH;
    } elsif ($black & $bb) {
        $pawnDir = SOUTH;
    } elsif ($red & $bb) {
        $pawnDir = EAST;
    } elsif ($green & $bb) {
        $pawnDir = WEST;
    }
    return $pawnDir;
}

sub getReverseDir {
    my $dir = shift;
    if ($dir == NORTH) {
        return SOUTH;
    } elsif ($dir == SOUTH) {
        return NORTH;
    } elsif ($dir == EAST) {
        return WEST;
    } elsif ($dir == WEST) {
        return EAST;
    }
    return undef;
}

sub getEnPassantKills {
    my $fr_bb = shift;
    my $to_bb = shift;

    my @kill_bbs;
    if  ($to_bb & RANKS_H->{3})  { ### white
        if (shift_BB($to_bb, NORTH) & $pawns & $white) {
            push @kill_bbs, shift_BB($to_bb, NORTH);
        }
    }
    if ($to_bb & RANKS_H->{10})  { ### black
        if (shift_BB($to_bb, SOUTH) & $pawns & $black) {
            push @kill_bbs, shift_BB($to_bb, SOUTH);
        }
    }
    if ($to_bb & FILES_H->{'j'}) { ### green
        if (shift_BB($to_bb, EAST) & $pawns & $green) {
            push @kill_bbs, shift_BB($to_bb, EAST);
        }
    } 
    if ($to_bb & FILES_H->{'c'}) { ### red
        if (shift_BB($to_bb, WEST) & $pawns & $red) {
            push @kill_bbs, shift_BB($to_bb, WEST);
        }
    }

    return @kill_bbs;
}

sub clearEnPassant {
    my $fr_bb = shift;
    if (! ($fr_bb & $pawns) ) { return undef; }

    if  ($fr_bb & RANKS_H->{4})  { ### white
       $enPassant &= ~shift_BB($fr_bb, SOUTH);
    }
    if ($fr_bb & RANKS_H->{9})  { ### black
       $enPassant &= ~shift_BB($fr_bb, NORTH);
    }
    if ($fr_bb & FILES_H->{'i'}) { ### green
       $enPassant &= ~shift_BB($fr_bb, WEST);
    } 
    if ($fr_bb & FILES_H->{'d'}) { ### red
       $enPassant &= ~shift_BB($fr_bb, EAST);
    }
}

sub isLegalMove {
    my ($fr_bb, $to_bb, $fr_rank, $fr_file, $to_rank, $to_file) = @_;

    ### TODO can probably figure a faster way to do this
    if (! defined($fr_rank)) {
        for (0 .. 11) {
            if (RANKS->[$_] & $fr_bb) {
                $fr_rank = RANKS->[$_];
                last;
            } 
        }
    }
    if (! defined($to_rank)) {
        for (0 .. 11) {
            if (RANKS->[$_] & $to_bb) {
                $to_rank = RANKS->[$_];
                last;
            } 
        }
    }
    if (! defined($fr_file)) {
        for (0 .. 11) {
            if (FILES->[$_] & $fr_bb) {
                $fr_file = FILES->[$_];
                last;
            } 
        }
    }
    if (! defined($to_file)) {
        for (0 .. 11) {
            if (FILES->[$_] & $to_bb) {
                $to_file = FILES->[$_];
                last;
            } 
        }
    }

    my @noMove = (NO_COLOR, MOVE_NONE, DIR_NONE, $fr_bb, $to_bb);

    my $checkBlockers = 0;

    if (! ($occupied & $fr_bb) ) {
        #print "from not occupied\n";
        return @noMove;
    }

    my $color   = ($white & $fr_bb ? WHITE : $black & $fr_bb ? BLACK :
                     $red & $fr_bb ? RED   : $green & $fr_bb ? GREEN : 0);
    my $pawnDir = getPawnDir($fr_bb);

    ### castles go before checking same color on to_bb
    if ($fr_bb & $kings) {
        my ($bbK, $bbR, $bbQR, $bbR_off, $bbQR_off);
        my ($kingDir, $rookDir);
        if ($color == WHITE) {
            $bbK      = $whiteCastleK;
            $bbR      = $whiteCastleR;
            $bbR_off  = $whiteCastleR_off;
            $bbQR     = $whiteQCastleR;
            $bbQR_off = $whiteQCastleR_off;
            $kingDir = EAST;
            $rookDir = WEST;
        } elsif ($color == BLACK) {
            $bbK      = $blackCastleK;
            $bbR      = $blackCastleR;
            $bbR_off  = $blackCastleR_off;
            $bbQR     = $blackQCastleR;
            $bbQR_off = $blackQCastleR_off;
            $kingDir = EAST;
            $rookDir = WEST;
        } elsif ($color == RED) {
            $bbK      = $redCastleK;
            $bbR      = $redCastleR;
            $bbR_off  = $redCastleR_off;
            $bbQR     = $redQCastleR;
            $bbQR_off = $redQCastleR_off;
            $kingDir = SOUTH;
            $rookDir = NORTH;
        } elsif ($color == GREEN) {
            $bbK      = $greenCastleK;
            $bbR      = $greenCastleR;
            $bbR_off  = $greenCastleR_off;
            $bbQR     = $greenQCastleR;
            $bbQR_off = $greenQCastleR_off;
            $kingDir = SOUTH;
            $rookDir = NORTH;
        }

        if ($fr_bb & $bbK){ 
            ### if they are moving to the "off" square we assume they are attempting to castle
            if ($to_bb & $bbR_off)  { $to_bb = $bbR ; } 
            if ($to_bb & $bbQR_off) { $to_bb = $bbQR; } 
            if ($to_bb & $bbR) { 
                if (blockers(_piecesUs($color), $kingDir, $fr_bb, shift_BB($to_bb, $rookDir)) ){
                    return ($color, MOVE_CASTLE_OO, DIR_NONE, $fr_bb, $to_bb);
                } else {
                    return @noMove;
                }
            }
            if ($to_bb & $bbQR) { 
                if (blockers(_piecesUs($color), $rookDir, $fr_bb, shift_BB($to_bb, $kingDir)) ){
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
        if ($pawnDir == NORTH || $pawnDir == SOUTH) {
            if ($to_bb & RANKS_H->{'1'} || $to_bb & RANKS_H->{'12'}) {
                $pawnMoveType = MOVE_PROMOTE;
            }
        } else {
            if ($to_bb & FILES_H->{'a'} || $to_bb & FILES_H->{'l'}) {
                $pawnMoveType = MOVE_PROMOTE;
            }
        }
        if (shift_BB($fr_bb, $pawnDir) & $to_bb) {
            if ($to_bb & $occupied) { 
                return @noMove;
            }
            return ($color, $pawnMoveType, $pawnDir, $fr_bb, $to_bb);
        }

        # we dont worry about color for ranks because you can't move two that way anyway
        if ($pawnDir == NORTH || $pawnDir == SOUTH) {
            if ((shift_BB($fr_bb, $pawnDir + $pawnDir) & $to_bb) && ($fr_bb & (RANKS_H->{'2'} | RANKS_H->{'11'}) ) ){
                if ($to_bb & $occupied) {
                    return @noMove;
                }
                # piece between
                if (shift_BB($fr_bb, $pawnDir) & $occupied) {
                    return @noMove;
                }
                # activate en_passant bb, warning:
                # this activates on checking for legal move only.
                # in the app we are expected to moveIfLegal so fine?
                # GameServer is expected to clear this when timer runs out.
                $enPassant |= shift_BB($to_bb, getReverseDir($pawnDir));

                return ($color, $pawnMoveType, $pawnDir, $fr_bb, $to_bb);
            }
        } else { ### east / west
            if ((shift_BB(shift_BB($fr_bb, $pawnDir), $pawnDir) & $to_bb) && ($fr_bb & (FILES_H->{'b'} | FILES_H->{'k'}) ) ){
                if ($to_bb & $occupied) {
                    return @noMove;
                }
                # piece between
                if (shift_BB($fr_bb, $pawnDir) & $occupied) {
                    return @noMove;
                }
                # activate en_passant bb, warning:
                # this activates on checking for legal move only.
                # in the app we are expected to moveIfLegal so fine?
                # GameServer is expected to clear this when timer runs out.
                $enPassant |= shift_BB($to_bb, getReverseDir($pawnDir));

                return ($color, $pawnMoveType, $pawnDir, $fr_bb, $to_bb);
            }
        }
        if ($to_bb & (_piecesThem($color) | $enPassant) ){

            ### 4way only, corners cant capture on init setup
            if (($fr_bb & $illegalPawnCaptures) && ($to_bb & $illegalPawnCaptures)) {
                return @noMove;
            }
            
            my $offOne = ($pawnDir == NORTH || $pawnDir == SOUTH) ? EAST : NORTH;
            my $offTwo = ($pawnDir == NORTH || $pawnDir == SOUTH) ? WEST : SOUTH;
            my $enemyCapturesE = shift_BB($to_bb, $offOne);
            my $enemyCapturesW = shift_BB($to_bb, $offTwo);
            if ($to_bb & $enPassant){
                $pawnMoveType = MOVE_EN_PASSANT;
            }
            my $enemyCapturesE = shift_BB($to_bb, $offOne);
            my $enemyCapturesW = shift_BB($to_bb, $offTwo);

            if      (shift_BB($fr_bb, $pawnDir) & $enemyCapturesW){
                return ($color, $pawnMoveType, $pawnDir + $offOne, $fr_bb, $to_bb);
            } elsif (shift_BB($fr_bb, $pawnDir) & $enemyCapturesE){
                return ($color, $pawnMoveType, $pawnDir + $offTwo, $fr_bb, $to_bb);
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
            if ($to_bb & _piecesUs($color)) {
                return @noMove;
            }
            ### it's always one space so we don't bother with dir
            return ($color, MOVE_NORMAL, DIR_NONE, $fr_bb, $to_bb);
        }
        return @noMove;
    }
    return @noMove;
}

### gt and lt signs are flipped for some reason on 4way.
sub _legalRooks {
    my ($fr_rank, $fr_file, $to_rank, $to_file, $fr_bb, $to_bb, $color) = @_;

    my $dir = 0;
    if (!($fr_file & $to_file) && $fr_rank & $to_rank) {
        ### for 4way we can't determine the direction in advance easily
        ### for east/west due to weird board layout that isnt a square
        if (blockers(_piecesUs($color), EAST, $fr_bb, $to_bb, 1) ){
            return ($color, MOVE_NORMAL, EAST, $fr_bb, $to_bb);
        }
        if (blockers(_piecesUs($color), WEST, $fr_bb, $to_bb, 1) ){
            return ($color, MOVE_NORMAL, WEST, $fr_bb, $to_bb);
        }
    } elsif ($fr_file & $to_file  && !($fr_rank & $to_rank)) {
        if ($fr_rank > $to_rank) {
            $dir = NORTH;
        } else {
            $dir = SOUTH;
        }
    if (blockers(_piecesUs($color), $dir, $fr_bb, $to_bb, 1) ){
        return ($color, MOVE_NORMAL, $dir, $fr_bb, $to_bb);
    }
    } else { # from and to were not on a parallel rank or file
        return (NO_COLOR, MOVE_NONE, DIR_NONE, $fr_bb, $to_bb);
    }
    return (NO_COLOR, MOVE_NONE, DIR_NONE, $fr_bb, $to_bb);
}

sub _legalBishops {
    my ($fr_rank, $fr_file, $to_rank, $to_file, $fr_bb, $to_bb, $color) = @_;

    if ($fr_rank == $to_rank || $fr_file == $to_file) {
        return (NO_COLOR, MOVE_NONE, DIR_NONE, $fr_bb, $to_bb);
    }

    ### for 4way we can't determine the direction in advance easily
    if (blockers(_piecesUs($color), SOUTH_EAST, $fr_bb, $to_bb, 1) ){
        return ($color, MOVE_NORMAL, SOUTH_EAST, $fr_bb, $to_bb);
    }
    if (blockers(_piecesUs($color), SOUTH_WEST, $fr_bb, $to_bb, 1) ){
        return ($color, MOVE_NORMAL, SOUTH_WEST, $fr_bb, $to_bb);
    }
    if (blockers(_piecesUs($color), NORTH_EAST, $fr_bb, $to_bb, 1) ){
        return ($color, MOVE_NORMAL, NORTH_EAST, $fr_bb, $to_bb);
    }
    if (blockers(_piecesUs($color), NORTH_WEST, $fr_bb, $to_bb, 1) ){
        return ($color, MOVE_NORMAL, NORTH_WEST, $fr_bb, $to_bb);
    }
    return (NO_COLOR, MOVE_NONE, DIR_NONE, $fr_bb, $to_bb);
}

sub _piecesUs {
    if ($_[0] == WHITE) { return $white; }
    if ($_[0] == BLACK) { return $black; }
    if ($_[0] == RED)   { return $red; }
    if ($_[0] == GREEN) { return $green; }
    return 0;
}
sub _piecesThem {
    if ($_[0] == WHITE) { return $black | $green | $red; }
    if ($_[0] == BLACK) { return $white | $green | $red; }
    if ($_[0] == RED)   { return $white | $black | $green; }
    if ($_[0] == GREEN) { return $white | $black | $red; }
    return 0;
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

### TODO make this more static in a hash or something
sub _getBBsForPiece {
    my $piece = shift;
    my @return = (\$occupied);
    if ($piece > 400) {
        push @return, \$green;
    } elsif ($piece > 300) {
        push @return, \$red;
    } elsif ($piece > 200) {
        push @return, \$black;
    } else {
        push @return, \$white;
    }

    if ($piece % 100 == PAWN) {
        push @return, \$pawns;
    } elsif ($piece % 100 == ROOK) {
        push @return, \$rooks;
    } elsif ($piece % 100 == BISHOP) {
        push @return, \$bishops;
    } elsif ($piece % 100 == KNIGHT) {
        push @return, \$knights;
    } elsif ($piece % 100 == QUEEN) {
        push @return, \$queens;
    } elsif ($piece % 100 == KING) {
        push @return, \$kings;
    }
    return @return;
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
    if ($red   & $squareBB) {
        return ($chr + 200);
    }
    if ($green & $squareBB) {
        return ($chr + 300);
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
    } elsif ( $bb & $red ) {
        return RED
    } elsif ( $bb & $green ) {
        return GREEN
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

### returns 1 for normal, 0 for killed
sub move {
    my ($fr_bb, $to_bb) = @_;

    strToInt($fr_bb);
    strToInt($to_bb);

    if (! ($fr_bb & $occupied)) {
        return 0;
    }
    ### clear castle opportunities
    if ($whiteCastleK && ($to_bb | $fr_bb) & $whiteCastleK) {
        $whiteCastleK = 0;
    }
    if ($whiteCastleR && ($to_bb | $fr_bb) & $whiteCastleR) {
        $whiteCastleR = 0;
    }
    if ($blackCastleK && ($to_bb | $fr_bb) & $blackCastleK) {
        $blackCastleK = 0;
    }
    if ($blackCastleR && ($to_bb | $fr_bb) & $blackCastleR) {
        $blackCastleR = 0;
    }
    if ($redCastleK && ($to_bb | $fr_bb) & $redCastleK) {
        $redCastleK = 0;
    }
    if ($redCastleR && ($to_bb | $fr_bb) & $redCastleR) {
        $redCastleR = 0;
    }
    if ($greenCastleK && ($to_bb | $fr_bb) & $greenCastleK) {
        $greenCastleK = 0;
    }
    if ($greenCastleR && ($to_bb | $fr_bb) & $greenCastleR) {
        $greenCastleR = 0;
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
    if ($piece > 200) {
        $color =  "\033[90m";
    }
    if ($piece > 300) {
        $color =  "\033[31m";
    }
    if ($piece > 400) {
        $color =  "\033[32m";
    }
    my $normal = "\033[0m";
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

sub pretty {
    my $board = '';
    $board .= "\n    +---+---+---+---+---+---+---+---+---+---+---+---+\n";
    foreach my $i ( 0 .. 11 ) {
        my $r = 11-$i;
        foreach my $f ( 0 .. 11 ) {
            if ($f == 0){ $board .= " " . sprintf('%2s | ', $r + 1); }
            
            my $chr = getPieceDisplay(_getPieceXY($f, $r));
            $board .= "$chr | ";
        }
        $board .= "\n    +---+---+---+---+---+---+---+---+---+---+---+---+\n";
    }
    $board .= "      a   b   c   d   e   f   g   h   i   j   k   l\n";
    return $board;
}

sub pretty_ai {
    my $board = '';
    $board .= "\n    +---+---+---+---+---+---+---+---+---+---+---+---+\n";
    foreach my $i ( 0 .. 11 ) {
        my $r = 11-$i;
        foreach my $f ( 0 .. 11 ) {
            if ($f == 0){ $board .= " " . sprintf('%2s | ', $r + 1); }
            
            my $chr = getPieceDisplay(_getPieceXY_ai($f, $r));
            $board .= "$chr | ";
        }
        $board .= "\n    +---+---+---+---+---+---+---+---+---+---+---+---+\n";
    }
    $board .= "      a   b   c   d   e   f   g   h   i   j   k   l\n";
    return $board;
}


sub prettyMoving {
    return prettyBoard($movingBB);
}
sub prettyOccupied {
    return prettyBoard($occupied);
}
sub prettyBoardTest {
    #my $bb = FILES_H->{'a'};
    #my $bb = RANKS_H->{'1'};
    my $bb = RANKS_H->{'1'} & FILES_H->{'c'};
    #my $bb = RANKS_H->{'2'} | FILES_H->{'c'};
    my $str = prettyBoard($occupied);
    #my $bb2 = shift_BB($bb, NORTH);
    return $str;
}
sub printAllBitboards {
    my $BB = shift;
    foreach my $r ( qw(12 11 10 9 8 7 6 5 4 3 2 1) ) {
        foreach my $f ( 'a' .. 'l' ) {
            my $rf = RANKS_H->{$r} & FILES_H->{$f};
        }
    }
}

sub prettyBoard {
    my $BB = shift;
    my $board = "BB: " . $BB . "\n";;
    my $bin = string_to_uint128($BB, 16);
    #my $bin = $bin->as_bin();
    $bin =~ s/^0b//;
    $bin = sprintf('%b', $bin);
    while ($bin =~ m/.{12}/g) {
        print "$&\n";
    }
    $board .= "\n   +---+---+---+---+---+---+---+---+---+---+---+---\n";
    foreach my $i ( 0 .. 11 ) {
        my $r = 11-$i;
        foreach my $f ( 0 .. 11 ) {
            if ($f eq 0){ $board .= sprintf('%2s | ', $r + 1); }
                my $rf = RANKS->[$r] & FILES->[$f];
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

################------------------------------------------ AI below
my $isEndgame = 0;
sub S {
    return $isEndgame ? $_[0]->[1] : $_[0]->[0];
}
sub setIsEndgame {
    $isEndgame = $_[0];
}
sub getIsEndgame {
    return $isEndgame;
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

########################## for AI only ###########################
#
# copied from stockfish, only the "middlegame" numbers for now
# black must flip this
my $SQ_BONUS = [
    [], # all
    [   # pawn
      [ [  2, -8], [  4, -6], [ 11,  9], [ 18,  5], [ 18,  5], , [ 18,  5], [ 16, 16], [ 16, 16], [ 16, 16], [ 21,  6], [  9, -6], [ -3,-18] ],
      [ [ -9, -9], [-15, -7], [ 11,-10], [ 15,  5], [ 15,  5], , [ 15,  5], [ 31,  2], [ 31,  2], [ 31,  2], [ 23,  3], [  6, -8], [-20, -5] ],
      [ [ -9, -9], [-15, -7], [ 11,-10], [ 15,  5], [ 15,  5], , [ 15,  5], [ 31,  2], [ 31,  2], [ 31,  2], [ 23,  3], [  6, -8], [-20, -5] ],
      [ [ -3,  7], [-20,  1], [  8, -8], [ 19, -2], [ 19, -2], , [ 19, -2], [ 39,-14], [ 39,-14], [ 39,-14], [ 17,-13], [  2,-11], [ -5, -6] ],
      [ [ -3,  7], [-20,  1], [  8, -8], [ 19, -2], [ 19, -2], , [ 19, -2], [ 39,-14], [ 39,-14], [ 39,-14], [ 17,-13], [  2,-11], [ -5, -6] ],
      [ [ 11, 12], [ -4,  6], [-11,  2], [  2, -6], [  2, -6], , [  2, -6], [ 11, -5], [ 11, -5], [ 11, -5], [  0, -4], [-12, 14], [  5,  9] ],
      [ [ 11, 12], [ -4,  6], [-11,  2], [  2, -6], [  2, -6], , [  2, -6], [ 11, -5], [ 11, -5], [ 11, -5], [  0, -4], [-12, 14], [  5,  9] ],
      [ [  3, 27], [-11, 18], [ -6, 19], [ 22, 29], [ 22, 29], , [ 22, 29], [ -8, 30], [ -8, 30], [ -8, 30], [ -5,  9], [-14,  8], [-11, 14] ],
      [ [ -7, -1], [  6,-14], [ -2, 13], [-11, 22], [-11, 22], , [-11, 22], [  4, 24], [  4, 24], [  4, 24], [-14, 17], [ 10,  7], [ -9,  7] ],
      [ [ -7, -1], [  6,-14], [ -2, 13], [-11, 22], [-11, 22], , [-11, 22], [  4, 24], [  4, 24], [  4, 24], [-14, 17], [ 10,  7], [ -9,  7] ],
    [] ### pawn shouldn't fuckin be here
    ],
    [ # Knight
      [ [-175, -96], [-92,-65], [-74,-49], [-73,-21], [-73,-21], [-73,-21], [-73,-21], [-73,-21], [-74,-49], [-92,-65], [-175, -96]],
      [ [ -77, -67], [-41,-54], [-27,-18], [-15,  8], [-15,  8], [-15,  8], [-15,  8], [-15,  8], [-27,-18], [-41,-54], [ -77, -67]],
      [ [ -77, -67], [-41,-54], [-27,-18], [-15,  8], [-15,  8], [-15,  8], [-15,  8], [-15,  8], [-27,-18], [-41,-54], [ -77, -67]],
      [ [ -61, -40], [-17,-27], [  6, -8], [ 12, 29], [ 12, 29], [ 12, 29], [ 12, 29], [ 12, 29], [  6, -8], [-17,-27], [ -61, -40]],
      [ [ -35, -35], [  8, -2], [ 40, 13], [ 49, 28], [ 49, 28], [ 49, 28], [ 49, 28], [ 49, 28], [ 40, 13], [  8, -2], [ -35, -35]],
      [ [ -35, -35], [  8, -2], [ 40, 13], [ 49, 28], [ 49, 28], [ 49, 28], [ 49, 28], [ 49, 28], [ 40, 13], [  8, -2], [ -35, -35]],
      [ [ -34, -45], [ 13,-16], [ 44,  9], [ 51, 39], [ 51, 39], [ 51, 39], [ 51, 39], [ 51, 39], [ 44,  9], [ 13,-16], [ -34, -45]],
      [ [ -34, -45], [ 13,-16], [ 44,  9], [ 51, 39], [ 51, 39], [ 51, 39], [ 51, 39], [ 51, 39], [ 44,  9], [ 13,-16], [ -34, -45]],
      [ [  -9, -51], [ 22,-44], [ 58,-16], [ 53, 17], [ 53, 17], [ 53, 17], [ 53, 17], [ 53, 17], [ 58,-16], [ 22,-44], [  -9, -51]],
      [ [ -67, -69], [-27,-50], [  4,-51], [ 37, 12], [ 37, 12], [ 37, 12], [ 37, 12], [ 37, 12], [  4,-51], [-27,-50], [ -67, -69]],
      [ [ -67, -69], [-27,-50], [  4,-51], [ 37, 12], [ 37, 12], [ 37, 12], [ 37, 12], [ 37, 12], [  4,-51], [-27,-50], [ -67, -69]],
      [ [-201,-100], [-83,-88], [-56,-56], [-26,-17], [-26,-17], [-26,-17], [-26,-17], [-26,-17], [-56,-56], [-83,-88], [-201,-100]]
    ],
    [ # Bishop
      [ [-37,-40], [-4 ,-21], [ -6,-26], [-16, -8], [-16, -8], [-16, -8], [-16, -8], [-16, -8], [ -6,-26], [-4 ,-21], [-37,-40]],
      [ [-11,-26], [  6, -9], [ 13,-12], [  3,  1], [  3,  1], [  3,  1], [  3,  1], [  3,  1], [ 13,-12], [  6, -9], [-11,-26]],
      [ [-11,-26], [  6, -9], [ 13,-12], [  3,  1], [  3,  1], [  3,  1], [  3,  1], [  3,  1], [ 13,-12], [  6, -9], [-11,-26]],
      [ [-5 ,-11], [ 15, -1], [ -4, -1], [ 12,  7], [ 12,  7], [ 12,  7], [ 12,  7], [ 12,  7], [ -4, -1], [ 15, -1], [-5 ,-11]],
      [ [-4 ,-14], [  8, -4], [ 18,  0], [ 27, 12], [ 27, 12], [ 27, 12], [ 27, 12], [ 27, 12], [ 18,  0], [  8, -4], [-4 ,-14]],
      [ [-4 ,-14], [  8, -4], [ 18,  0], [ 27, 12], [ 27, 12], [ 27, 12], [ 27, 12], [ 27, 12], [ 18,  0], [  8, -4], [-4 ,-14]],
      [ [-8 ,-12], [ 20, -1], [ 15,-10], [ 22, 11], [ 22, 11], [ 22, 11], [ 22, 11], [ 22, 11], [ 15,-10], [ 20, -1], [-8 ,-12]],
      [ [-8 ,-12], [ 20, -1], [ 15,-10], [ 22, 11], [ 22, 11], [ 22, 11], [ 22, 11], [ 22, 11], [ 15,-10], [ 20, -1], [-8 ,-12]],
      [ [-11,-21], [  4,  4], [  1,  3], [  8,  4], [  8,  4], [  8,  4], [  8,  4], [  8,  4], [  1,  3], [  4,  4], [-11,-21]],
      [ [-12,-22], [-10,-14], [  4, -1], [  0,  1], [  0,  1], [  0,  1], [  0,  1], [  0,  1], [  4, -1], [-10,-14], [-12,-22]],
      [ [-12,-22], [-10,-14], [  4, -1], [  0,  1], [  0,  1], [  0,  1], [  0,  1], [  0,  1], [  4, -1], [-10,-14], [-12,-22]],
      [ [-34,-32], [  1,-29], [-10,-26], [-16,-17], [-16,-17], [-16,-17], [-16,-17], [-16,-17], [-10,-26], [  1,-29], [-34,-32]]
    ],
    [ # Rook
      [ [-31, -9], [-20,-13], [-14,-10], [-5, -9], [-5, -9], [-5, -9], [-5, -9], [-5, -9], [-14,-10], [-20,-13], [-31, -9]],
      [ [-21,-12], [-13, -9], [ -8, -1], [ 6, -2], [ 6, -2], [ 6, -2], [ 6, -2], [ 6, -2], [ -8, -1], [-13, -9], [-21,-12]],
      [ [-21,-12], [-13, -9], [ -8, -1], [ 6, -2], [ 6, -2], [ 6, -2], [ 6, -2], [ 6, -2], [ -8, -1], [-13, -9], [-21,-12]],
      [ [-25,  6], [-11, -8], [ -1, -2], [ 3, -6], [ 3, -6], [ 3, -6], [ 3, -6], [ 3, -6], [ -1, -2], [-11, -8], [-25,  6]],
      [ [-13, -6], [ -5,  1], [ -4, -9], [-6,  7], [-6,  7], [-6,  7], [-6,  7], [-6,  7], [ -4, -9], [ -5,  1], [-13, -6]],
      [ [-13, -6], [ -5,  1], [ -4, -9], [-6,  7], [-6,  7], [-6,  7], [-6,  7], [-6,  7], [ -4, -9], [ -5,  1], [-13, -6]],
      [ [-27, -5], [-15,  8], [ -4,  7], [ 3, -6], [ 3, -6], [ 3, -6], [ 3, -6], [ 3, -6], [ -4,  7], [-15,  8], [-27, -5]],
      [ [-27, -5], [-15,  8], [ -4,  7], [ 3, -6], [ 3, -6], [ 3, -6], [ 3, -6], [ 3, -6], [ -4,  7], [-15,  8], [-27, -5]],
      [ [-22,  6], [ -2,  1], [  6, -7], [12, 10], [12, 10], [12, 10], [12, 10], [12, 10], [  6, -7], [ -2,  1], [-22,  6]],
      [ [ -2,  4], [ 12,  5], [ 16, 20], [18, -5], [18, -5], [18, -5], [18, -5], [18, -5], [ 16, 20], [ 12,  5], [ -2,  4]],
      [ [ -2,  4], [ 12,  5], [ 16, 20], [18, -5], [18, -5], [18, -5], [18, -5], [18, -5], [ 16, 20], [ 12,  5], [ -2,  4]],
      [ [-17, 18], [-19,  0], [ -1, 19], [ 9, 13], [ 9, 13], [ 9, 13], [ 9, 13], [ 9, 13], [ -1, 19], [-19,  0], [-17, 18]]
    ],
    [ # Queen
      [ [ 3,-69], [-5,-57], [-5,-47], [ 4,-26], [ 4,-26], [ 4,-26], [ 4,-26], [ 4,-26], [-5,-47], [-5,-57], [ 3,-69]],
      [ [-3,-54], [ 5,-31], [ 8,-22], [12, -4], [12, -4], [12, -4], [12, -4], [12, -4], [ 8,-22], [ 5,-31], [-3,-54]],
      [ [-3,-54], [ 5,-31], [ 8,-22], [12, -4], [12, -4], [12, -4], [12, -4], [12, -4], [ 8,-22], [ 5,-31], [-3,-54]],
      [ [-3,-39], [ 6,-18], [13, -9], [ 7,  3], [ 7,  3], [ 7,  3], [ 7,  3], [ 7,  3], [13, -9], [ 6,-18], [-3,-39]],
      [ [ 4,-23], [ 5, -3], [ 9, 13], [ 8, 24], [ 8, 24], [ 8, 24], [ 8, 24], [ 8, 24], [ 9, 13], [ 5, -3], [ 4,-23]],
      [ [ 4,-23], [ 5, -3], [ 9, 13], [ 8, 24], [ 8, 24], [ 8, 24], [ 8, 24], [ 8, 24], [ 9, 13], [ 5, -3], [ 4,-23]],
      [ [ 0,-29], [14, -6], [12,  9], [ 5, 21], [ 5, 21], [ 5, 21], [ 5, 21], [ 5, 21], [12,  9], [14, -6], [ 0,-29]],
      [ [ 0,-29], [14, -6], [12,  9], [ 5, 21], [ 5, 21], [ 5, 21], [ 5, 21], [ 5, 21], [12,  9], [14, -6], [ 0,-29]],
      [ [-4,-38], [10,-18], [ 6,-11], [ 8,  1], [ 8,  1], [ 8,  1], [ 8,  1], [ 8,  1], [ 6,-11], [10,-18], [-4,-38]],
      [ [-5,-50], [ 6,-27], [10,-24], [ 8, -8], [ 8, -8], [ 8, -8], [ 8, -8], [ 8, -8], [10,-24], [ 6,-27], [-5,-50]],
      [ [-5,-50], [ 6,-27], [10,-24], [ 8, -8], [ 8, -8], [ 8, -8], [ 8, -8], [ 8, -8], [10,-24], [ 6,-27], [-5,-50]],
      [ [-2,-74], [-2,-52], [ 1,-43], [-2,-34], [-2,-34], [-2,-34], [-2,-34], [-2,-34], [ 1,-43], [-2,-52], [-2,-74]]
    ],
    [ # King
      [ [271,  1], [327, 45], [271, 85], [198, 76], [198, 76], [198, 76], [198, 76], [198, 76], [271, 85], [327, 45], [271,  1]],
      [ [278, 53], [303,100], [234,133], [179,135], [179,135], [179,135], [179,135], [179,135], [234,133], [303,100], [278, 53]],
      [ [278, 53], [303,100], [234,133], [179,135], [179,135], [179,135], [179,135], [179,135], [234,133], [303,100], [278, 53]],
      [ [195, 88], [258,130], [169,169], [120,175], [120,175], [120,175], [120,175], [120,175], [169,169], [258,130], [195, 88]],
      [ [164,103], [190,156], [138,172], [ 98,172], [ 98,172], [ 98,172], [ 98,172], [ 98,172], [138,172], [190,156], [164,103]],
      [ [164,103], [190,156], [138,172], [ 98,172], [ 98,172], [ 98,172], [ 98,172], [ 98,172], [138,172], [190,156], [164,103]],
      [ [154, 96], [179,166], [105,199], [ 70,199], [ 70,199], [ 70,199], [ 70,199], [ 70,199], [105,199], [179,166], [154, 96]],
      [ [154, 96], [179,166], [105,199], [ 70,199], [ 70,199], [ 70,199], [ 70,199], [ 70,199], [105,199], [179,166], [154, 96]],
      [ [123, 92], [145,172], [ 81,184], [ 31,191], [ 31,191], [ 31,191], [ 31,191], [ 31,191], [ 81,184], [145,172], [123, 92]],
      [ [ 88, 47], [120,121], [ 65,116], [ 33,131], [ 33,131], [ 33,131], [ 33,131], [ 33,131], [ 65,116], [120,121], [ 88, 47]],
      [ [ 88, 47], [120,121], [ 65,116], [ 33,131], [ 33,131], [ 33,131], [ 33,131], [ 33,131], [ 65,116], [120,121], [ 88, 47]],
      [ [ 59, 11], [ 89, 59], [ 45, 73], [ -1, 78], [ -1, 78], [ -1, 78], [ -1, 78], [ -1, 78], [ 45, 73], [ 89, 59], [ 59, 11]]
    ]
];

### evaluate a single board position staticly, returns the score and moves
sub evaluate {
    ### for 4way we evaluate from the perspective of a certain color, i.e. 3 v 1
    #my $forColor = shift;

    my $score = 0;
    my @moves = (
        [], # no color
        [], # white
        [], # black
        [], # red
        []  # green
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
    my @threats = (
        0,
        0,
        0
    );
    my @attackedBy = (
        [ 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0 ], 
        [ 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0 ],  # white
        [ 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0 ],  # black
    );

    ### gaurded by two pieces, we don't care about individual pieces
    my @attackedBy2 = (
        0,
        0,
        0
    );
    my @attackedByFrozen = (
        [ 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0 ], 
        [ 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0 ],  # white
        [ 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0 ],  # black
    );
    my @attackedByUnFrozen = (
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

    my $occupiedBB = $occupied;
    ### TODO reset all eval vars here
    ### TODO build an array of all squares at the start

    #print "here\n";
    #my $bb_pop = $ai_white;
    #while (my $bb = pop_lsb($bb_pop)) {
        #print "bb: $bb\n";

    #}
    my $pieceCount = 0;
    foreach my $r ( 0 .. 15 ) {
        foreach my $f ( 0 .. 15 ) {
            my $fr = RANKS->[$r] & FILES->[$f];
            #if ($fr & $ai_frozenBB) { print "$r$f next;\n"; next; }
            my $piece = _getPieceBB_ai($fr);
            next if (! defined($piece));

            $pieceCount++;
            my $frozen = ($fr & $ai_frozenBB);

            ### begin evaluating a piece
            my $pieceType = $piece % 100;
            my $color = WHITE;
            if ($piece > 400) {
                $color = GREEN;
            } elsif ($piece > 300) {
                $color = RED;
            } elsif ($piece > 200) {
                $color = BLACK;
            }
            ### bitboard of us and them
            my $us       ;
            my $them     ;
            my $pawnDir  ;

            if ($fr & $ai_white_true) {
                $pawnDir = NORTH;
            } elsif ($fr & $ai_black_true) {
                $pawnDir = SOUTH;
            } elsif ($fr & $ai_red_true) {
                $pawnDir = EAST;
            } else {
                $pawnDir = WEST;
            }

            if ($color == WHITE) {
                $us = $ai_white;
                $them  = $ai_black | $ai_red   | $ai_green;
            } elsif ($color == BLACK) {
                $us = $ai_black;
                $them  = $ai_white | $ai_red   | $ai_green;
            } elsif ($color == RED)   {
                $us = $ai_red;
                $them  = $ai_black | $ai_white | $ai_green;
            } elsif ($color == GREEN)   {
                $us = $ai_green;
                $them  = $ai_black | $ai_red   | $ai_white;
            }

            my $pieceAttackingBB     = 0x0;
            my $pieceAttackingXrayBB = 0x0;

            ### tracks all the pieces for calulating bonuses
            push @{$pieces[$color]->[$pieceType]}, $fr;

            my $moveS = KungFuChess::BBHash::getSquareFromBB($fr);
            ### for square bonuses
            ### TODO rotate for red/green
            my $sq_f = $f;
            my $sq_r = $color == WHITE ? $r : 11 - $r;
            my $sq_f;
            my $sq_r;

            if ($color == WHITE) {
                $sq_f = $f;
                $sq_r = $r;
            } elsif ($color == BLACK) {
                $sq_f = $f;
                $sq_r = 11 - $r;
            } elsif ($color == RED) {
                $sq_f = 11 - $r;
                $sq_r = 11 - $f;
            } elsif ($color == GREEN) {
                $sq_f = $r;
                $sq_r = $f;
            }

            $squareBonus[$color] += S($SQ_BONUS->[$pieceType]->[$sq_r]->[$sq_f]);

            if ($pieceType == KING) {
                $material[$color] += 10000;
                foreach my $shift (@MOVES_Q) {
                    my $to = $fr;
                    $to = shift_BB($to, $shift);
                    $kingRing[$color] |= $to;
                    if ($to != 0 && !($to & $us) && !($to & $ai_movingBB) ){
                        if (! $frozen) {
                            push @{$moves[$color]}, [
                                $fr,
                                $to,
                                undef, # score
                                1,
                                undef, # children moves
                                undef, # attackedBy
                            ];
                        }
                        $attackedBy[$color]->[$pieceType] |= $to;
                        $attackedBy[$color]->[ALL_PIECES]      |= $to;
                        $attackedBy2[$color] |= ($to & $attackedBy[$color]->[ALL_PIECES]);
                        if ($frozen) {
                            $attackedByFrozen[$color]->[$pieceType] |= $to;
                            $attackedByFrozen[$color]->[ALL_PIECES] |= $to;
                        } else {
                            $attackedByUnFrozen[$color]->[$pieceType] |= $to;
                            $attackedByUnFrozen[$color]->[ALL_PIECES] |= $to;
                        }
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
                foreach my $shift (@pmoves) {
                    my $inXray = 0;
                    my $to = $fr;
                    $to = shift_BB($to, $shift);
                    my $distance = 0;
                    while ($to != 0) {
                        $distance++;
                        $attackedBy[$color]->[$pieceType] |= $to;
                        $attackedBy[$color]->[ALL_PIECES] |= $to;
                        $attackedBy2[$color] |= ($to & $attackedBy[$color]->[ALL_PIECES]);
                        if ($frozen) {
                            $attackedByFrozen[$color]->[$pieceType] |= $to;
                            $attackedByFrozen[$color]->[ALL_PIECES] |= $to;
                        } else {
                            $attackedByUnFrozen[$color]->[$pieceType] |= $to;
                            $attackedByUnFrozen[$color]->[ALL_PIECES] |= $to;
                        }
                        if ($to & $us){ # we ran into ourselves
                            $inXray = 1;
                            # no xrays for 4way to save moves
                            $to = 0;
                            next;
                        }
                        ### we ran into a currently moving piece, best to forget it
                        #if ($to & $ai_movingBB) {
                            #$to = 0;
                            #next;
                        #}
                        if ($inXray == 0) {
                            $mobilityBonus[$color] += 5;
                            if (! $frozen) {
                                push @{$moves[$color]}, [
                                    $fr,
                                    $to,
                                    undef, # score
                                    $distance,
                                    undef, # children moves
                                    undef, # attackedBy
                                ];
                            }
                        }
                        ### we still want this move so we can capture
                        if ($to & $them){
                            $to = 0;
                            next;
                        }
                        $to = shift_BB($to, $shift);
                    }
                }
            } elsif ($pieceType == KNIGHT) {
                $material[$color] += 300;
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
                    if (($to != 0) && !($to & $ai_movingBB) ) {
                        $attackedBy[$color]->[$pieceType] |= $to;
                        $attackedBy[$color]->[ALL_PIECES]      |= $to;
                        $attackedBy2[$color] |= ($to & $attackedBy[$color]->[ALL_PIECES]);
                        if ($frozen) {
                            $attackedByFrozen[$color]->[$pieceType] |= $to;
                            $attackedByFrozen[$color]->[ALL_PIECES] |= $to;
                        } else {
                            $attackedByUnFrozen[$color]->[$pieceType] |= $to;
                            $attackedByUnFrozen[$color]->[ALL_PIECES] |= $to;
                        }
                        $mobilityBonus[$color] += 15;
                        if (! ($to & $us) && ! $frozen) {
                            push @{$moves[$color]}, [
                                $fr,
                                $to,
                                undef, # score
                                2.5,
                                undef, # children moves
                                undef, # attackedBy
                            ];
                        }
                    }
                }
            } elsif ($pieceType == PAWN) {
                $material[$color] += 100;
                my $to = (shift_BB($fr, $pawnDir));
                if (! ($to & $us) && ! ($to & $them) && ! $frozen) {
                    push @{$moves[$color]}, [
                        $fr,
                        $to,
                        undef, # score
                        1,
                        undef, # children moves
                        undef, # attackedBy
                    ];
                }
                $to = shift_BB($fr, $pawnDir + ($pawnDir == NORTH || $pawnDir == SOUTH ? WEST : NORTH));
                ### 4way only, corners cant capture on init setup
                ### ! $to shows up on corner cases sometimes too
                if ((($fr & $illegalPawnCaptures) && ($to & $illegalPawnCaptures)) || ! $to) {
                    next;
                }

                $attackedBy[$color]->[$pieceType] |= $to;
                $attackedBy[$color]->[ALL_PIECES] |= $to;
                $attackedBy2[$color] |= ($to & $attackedBy[$color]->[ALL_PIECES]);
                if ($frozen) {
                    $attackedByFrozen[$color]->[$pieceType] |= $to;
                    $attackedByFrozen[$color]->[ALL_PIECES] |= $to;
                } else {
                    $attackedByUnFrozen[$color]->[$pieceType] |= $to;
                    $attackedByUnFrozen[$color]->[ALL_PIECES] |= $to;
                }
                if (($to & $them) && ! $frozen) {
                    push @{$moves[$color]}, [
                        $fr,
                        $to,
                        undef, # score
                        1,
                        undef, # children moves
                        undef, # attackedBy
                    ];
                }
                $to = shift_BB($fr, $pawnDir + ($pawnDir == NORTH || $pawnDir == SOUTH ? EAST : SOUTH));
                if ((($fr & $illegalPawnCaptures) && ($to & $illegalPawnCaptures)) || ! $to) {
                    next;
                }
                $attackedBy[$color]->[$pieceType] |= $to;
                $attackedBy[$color]->[ALL_PIECES]      |= $to;
                $attackedBy2[$color] |= ($to & $attackedBy[$color]->[ALL_PIECES]);
                if ($frozen) {
                    $attackedByFrozen[$color]->[$pieceType] |= $to;
                    $attackedByFrozen[$color]->[ALL_PIECES]      |= $to;
                } else {
                    $attackedByUnFrozen[$color]->[$pieceType] |= $to;
                    $attackedByUnFrozen[$color]->[ALL_PIECES]      |= $to;
                }
                if (($to & $them) && ! $frozen && !($to & $ai_movingBB) ) {
                    push @{$moves[$color]}, [
                        $fr,
                        $to,
                        undef, # score
                        1,
                        undef, # children moves
                        undef, # attackedBy
                    ];
                }
            }
        }
    }

    if ($pieceCount < 17) {
        setIsEndgame(1);
    }

    #********************** position is now set up and we begin the evaulation ********
    
    #// Early exit if score is high
    #auto lazy_skip = [&](Value lazyThreshold) {
        #return abs(mg_value(score) + eg_value(score)) >   lazyThreshold
                                                        #+ std::abs(pos.this_thread()->bestValue) * 5 / 4
                                                        #+ pos.non_pawn_material() / 32;
    #};


    my $pcount = 0;
    foreach my $color (1 .. 2) {
        my $us   = ($color == WHITE ? WHITE : BLACK);
        my $them = ($color == WHITE ? BLACK : WHITE);

        ###*********** first we more or less copy the threats() function from stockfish
        my $threatScore = 0;
        my $occupiedThem = ($them == WHITE ? $ai_occupied & $ai_white : $ai_occupied & $ai_black);

        my $nonPawnEnemies = $occupiedThem & ~$ai_pawns;

        # Protected or unattacked squares
        my $safeBB = ~$attackedByUnFrozen[$them][ALL_PIECES] | $attackedByUnFrozen[$us][ALL_PIECES];

        ### **************** now bonuses for individual pieces
        foreach my $pType (1 .. 7) {
            foreach my $bb (@{$pieces[$color]->[$pType]}) {
                $pcount++;
                my $meFrozen = $bb & $ai_frozenBB;
                my $safe = ($safeBB & $bb);
                if ($pType == PAWN) {
                    ### chaining pawns is good yo
                    if ($attackedBy[$us][PAWN] & $bb) {
                        $additionalBonus[$color] += 20;
                    }
                    if ($safe) {
                        $additionalBonus[$color] += 20;
                    }
                } elsif ($pType == BISHOP || $pType == KNIGHT) {
                    if ($safe) {
                        $additionalBonus[$color] += 40;
                    }
                    if ($attackedByUnFrozen[$them][PAWN] & $bb) {
                        $threats[$color] += ($meFrozen ? 200 : 100);
                    }
                ### knight and rook "safe" checks all knights all rooks
                } elsif ($pType == ROOK) {
                    if ($safe) {
                        $additionalBonus[$color] += 40;
                    }
                    if ($attackedByUnFrozen[$them][PAWN] & $bb) {
                        $threats[$color] += ($meFrozen ? 400 : 120);
                    }
                } elsif ($pType == QUEEN) {
                    if ($safe) {
                        $additionalBonus[$color] += 20;
                    }
                    if ($attackedByUnFrozen[$them][PAWN] & $bb) {
                        $threats[$color] += ($meFrozen ? 600 : 250);
                    }
                    if (($attackedByUnFrozen[$them][QUEEN] & $bb)) {
                        if ($safe) {
                            $queenDangerPenalty[$us] += 200;
                        } else {
                            $queenDangerPenalty[$us] += ($meFrozen ? 400 : 130);
                        }
                    }
                    if (($attackedByUnFrozen[$them][ROOK] & $bb)) {
                        if ($safe) {
                            $queenDangerPenalty[$us] += 400;
                        } else {
                            $queenDangerPenalty[$us] += ($meFrozen ? 500 : 110);
                        }
                    }
                    if (
                        ($attackedByUnFrozen[$them][KNIGHT] & $bb) ||
                        ($attackedByUnFrozen[$them][BISHOP] & $bb)
                    ) {
                        if ($safe) {
                            $queenDangerPenalty[$us] += 500;
                        } else {
                            $queenDangerPenalty[$us] += ($meFrozen ? 500 : 110);
                        }
                    }
                } elsif ($pType == KING) {
                    if ($attackedByUnFrozen[$them][ALL_PIECES] & $bb) {
                        $kingDangerPenalty[$color] += ($meFrozen ? 1500 : 500);
                    }
                    if ($attackedByFrozen[$them][ALL_PIECES] & $bb) {
                        $kingDangerPenalty[$color] += ($meFrozen ? 200 : 50);
                    }
                    if ($attackedByUnFrozen[$them][ALL_PIECES] & $kingRing[$us]) {
                        $kingDangerPenalty[$color] += ($meFrozen ? 100 : 50);
                    }
                    if ($attackedByFrozen[$them][ALL_PIECES] & $kingRing[$us]) {
                        $kingDangerPenalty[$color] += ($meFrozen ? 20 : 10);
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
        - ($threats[1]  - $threats[2] )
    ;

    if ($aiDebug > 1) {
        print "piece count: $pcount
mater     ($material[1] - $material[2] )
square  + ($squareBonus[1] - $squareBonus[2] )
mobil   + ($mobilityBonus[1] - $mobilityBonus[2] )
addit   + ($additionalBonus[1] - $additionalBonus[2] )
kingD   - ($kingDangerPenalty[1] - $kingDangerPenalty[2] )
queenD  - ($queenDangerPenalty[1] - $queenDangerPenalty[2])
thtreat - ($threats[1] - $threats[2] )
        ";
    }
    $aiDebugEvalCount++;

    ### flip the scores for ease if we are black
    if (defined($aiColor) && $aiColor == BLACK) {
        $score = 0 - $score;
    }

    my $totalMaterial = $material[1] + $material[2];

    #return ($score + rand($aiRandomness), \@moves);
    return ($score, \@moves, $totalMaterial, \@attackedBy);
}

sub clearAiMoves {
    $currentMoves = undef;
}

sub getCurrentScore {
    return $aiScore;
}

sub aiThink {
    my ($depth, $timeToThink, $color) = @_;
    print "thinking ... $depth, $timeToThink, $color\n";

    ### global
    $aiColor = $color;
    my $aiAlpha = AI_NEG_INFINITY; 
    my $aiBeta  = AI_INFINITY; 
    my $totalMaterial = 0;
    my $attackedBy = [];

    $aiDebugEvalCount = 0;
    if (! $currentMoves) {
        ($aiScore, $currentMoves, $totalMaterial, $attackedBy) = evaluate();
    }

    my $currentDepth = $depth;
    my $state = undef;
    #my ($color, $depth, $turnDepth, $stopTime, $moves, $alpha, $beta, $maximizingPlayer, $moveString) = @_;
    ($aiScore, $currentMoves, $state) = evaluateTree(
        $color,
        $depth,                 ### the depth we are at
        1,                      ### the depth we are at for our color
        time() + $timeToThink,  
        undef,
        $aiAlpha,
        $aiBeta,
        1,
        ''
    );

    print "AiEvalCount  : $aiDebugEvalCount\n";
    print "aiScore : $aiScore\n";

    return ($aiScore, $currentMoves, $totalMaterial, $attackedBy);
}

sub aiRecommendMoves {
    my $color = shift;
    my $maxMovesBreadth  = shift // 1;
    my $maxMovesDepth    = shift // 1;
    my $randomSkipChance = shift // 0; ### to sometimes select worse moves

    if (! $currentMoves) { return undef; }

    my @myMoves = ();

    foreach my $breadth (0 .. $maxMovesBreadth) {
        if (rand() < $randomSkipChance) { $maxMovesBreadth++; next; }

        my $move = $currentMoves->[$color][$breadth];
        if (! defined($move)) { last; }
        if (! defined($move->[MOVE_SCORE])) { next; }
        push @myMoves, [ $move->[MOVE_FR], $move->[MOVE_TO], 0, 0, $move->[MOVE_SCORE] ];

        foreach my $depth (0 .. $maxMovesDepth) {
            my $moveSelect = 0;
            while (rand() < $randomSkipChance && $moveSelect < 5) {
                $moveSelect++;
            }
            if (! defined($move->[MOVE_NEXT_MOVES])){ last; }
            $move = $move->[MOVE_NEXT_MOVES]->[$color]->[$moveSelect];

            if (! defined($move)) { last; }
            if (! defined($move->[MOVE_SCORE])) { last; }

            push @myMoves, [ $move->[MOVE_FR], $move->[MOVE_TO], 0, 0, $move->[MOVE_SCORE] ];
        }
    }

    return \@myMoves;
}

### tries to find a move that reacts to an enemy piece moving to a specified BB
#   we either try to dodge away from that square, or attack it.
sub recommendMoveForBB {
    my $bb = shift;
    my $color = shift;
    my $currentAttackedBy = shift;
    my $distance = shift; ### how far does the enemy have to move? TODO implement this
    my $best_to = 0;

    my $distancePenalty = 5;

    my $occupiedColor = occupiedColor(strToInt($bb));
    ### dodge
    if ($color == $occupiedColor) {
        my $bestScore = ($color == $aiColor ? AI_NEG_INFINITY : AI_INFINITY);
        foreach my $move (@{$currentMoves->[$color]}) {
            if ($move->[MOVE_FR] == $bb && defined($move->[MOVE_SCORE])) {
                if ($color == $aiColor) {
                    if ($move->[MOVE_SCORE] > $bestScore) {
                        $bestScore = $move->[MOVE_SCORE] - ($move->[MOVE_DISTANCE] * $distancePenalty);
                        $best_to = $move->[MOVE_TO];
                    }
                } else {
                    if ($move->[MOVE_SCORE] < $bestScore) {
                        $bestScore = $move->[MOVE_SCORE];
                        $best_to = $move->[MOVE_TO];
                    }
                }
            }
        }

        return ($best_to, $bestScore);
    }
    return undef;
}

# return $score, [] $moves;
sub evaluateTree {
    my ($color, $depth, $turnDepth, $stopTime, $moves, $alpha, $beta, $maximizingPlayer, $moveString, $moveAttackedBy, $moveMaterial) = @_;

    $depth--;

    my $score = 0;
    #if (! $moves) {
        ($score, $moves, $moveMaterial, $moveAttackedBy) = evaluate($color);
    #}

    if ($depth == 0) {
        return ($score, $moves, undef, 0);
    }
    if (time() > $stopTime) {
        return ($score, $moves, undef, 0);
    }

    if ($aiDebug) {
        $| = 1;
        print "\n";
        print "  " x (5 - $depth);
        print "v---start evalutateTree for $moveString, depth: $depth eval score:  $score -----\n";
    }

    my $finished = 1;
    my $bestMove = undef;
    my $newColor = $color;
    my $newMaximizingPlayer = $maximizingPlayer;
    my $maxEval = AI_NEG_INFINITY;
    my $minEval = AI_INFINITY;

    foreach my $move (@{$moves->[$color]}) {
        my $moveS = "";
        if ($aiDebug) {
            print "  " x (5 - $depth);
            print ($color == WHITE ? 'w' : 'b');
            print "$depth move: ";
            $moveS = KungFuChess::BBHash::getSquareFromBB($move->[MOVE_FR]) . KungFuChess::BBHash::getSquareFromBB($move->[MOVE_TO]);
            print "$moveString+$moveS ";
            print '(' . ($move->[MOVE_SCORE] // '') . ')';
            print "\n";
            print "  " x (5 - $depth);
            if ($aiDebug > 1) {
                print pretty_ai();
                print prettyBoard($ai_frozenBB);
            }
        }
        ### because we are frozen in this line we don't consider future moves
        #   other pieces have the opportunity to move first
        next if ($move->[MOVE_FR] & $ai_frozenBB);

        my $undoPiece;
        ### TODO unfreeze enemy pieces?
        my $frozenUndo = $ai_frozenBB;
        $undoPiece = do_move_ai($move->[MOVE_FR], $move->[MOVE_TO]);
        if ($turnDepth >= $aiMovesPerTurn) {
            $newColor = ($color == WHITE ? BLACK : WHITE);
            $turnDepth = 0;
            # switch to minimizing player
            $newMaximizingPlayer = $maximizingPlayer ? 0 : 1;
        }
        ### args:
        # $color, $depth, $turnDepth, $stopTime, $moves, $alpha, $beta, $maximizingPlayer, $moveString) = @_;
        my ($newScore, $newMoves, $nextMoveAttackedBy) = evaluateTree($newColor, $depth, $turnDepth + 1, $stopTime, $move->[MOVE_NEXT_MOVES], $alpha, $beta, $newMaximizingPlayer, $moveString . $moveS . " ");
        undo_move_ai($move->[MOVE_FR], $move->[MOVE_TO], $undoPiece);
        $ai_frozenBB = $frozenUndo;

        if ($newMoves) {
            $move->[MOVE_NEXT_MOVES] = $newMoves;
        }
        if ($nextMoveAttackedBy) {
            $move->[MOVE_ATTACKS] = $nextMoveAttackedBy;
        }

        if (defined($newScore)) {
            $move->[MOVE_SCORE] = $newScore;
        } else {
            print "undef newScore\n";
        }

        ### alpha beta pruning
        if ($maximizingPlayer) {
            $maxEval = ($newScore > $maxEval ? $newScore : $maxEval);
            $alpha   = ($newScore > $alpha   ? $newScore : $alpha);
            if ($maxEval > $beta) {
                last;
            }
            $alpha = $newScore;
        } elsif (! $maximizingPlayer) {
            $minEval = ($newScore < $minEval ? $newScore : $minEval);
            $beta    = ($newScore < $beta   ? $newScore : $beta);
            if ($minEval < $alpha) {
                last;
            }
        }

        if ($aiDebug) {
            print "  " x (5 - $depth);
            print "is_max: $maximizingPlayer:$newMaximizingPlayer, eval score: $score vs $newScore, max: $maxEval, min:$minEval\n";
        }

        if ($aiDebug > 1) {
            print "unsetting frozenUndo: " . $ai_frozenBB . "\n";
            $ai_frozenBB += 0;
            print "ai_frozen unset: " . $ai_frozenBB . "\n";
            $ai_frozenBB += 0;
        }

        if (! defined($newScore)) {
            $finished = 0;
            last;
        }
    }
    $ai_frozenBB += 0;

    # TODO figure out how to do this without the extra variables
    if ($aiColor == WHITE) {
        my @w = sort { $b->[MOVE_SCORE] <=> $a->[MOVE_SCORE] } @{$moves->[WHITE]};
        my @b = sort { $a->[MOVE_SCORE] <=> $b->[MOVE_SCORE] } @{$moves->[BLACK]};

        $moves->[WHITE] = \@w;
        $moves->[BLACK] = \@b;
    } else { ### sort by positive from our point of view (we are always maximizing)
        my @w = sort { $a->[MOVE_SCORE] <=> $b->[MOVE_SCORE] } @{$moves->[WHITE]};
        my @b = sort { $b->[MOVE_SCORE] <=> $a->[MOVE_SCORE] } @{$moves->[BLACK]};

        $moves->[WHITE] = \@w;
        $moves->[BLACK] = \@b;
    }
    
    if ($maximizingPlayer) {
        if ($aiDebug) {
            print "  " x (5 - $depth);
            print "^--depth: $depth $moveString MAX $maxEval, min $minEval vs eval: $score, isMaxer: $maximizingPlayer\n";
        }
        return (($maxEval == AI_NEG_INFINITY ? $score : $maxEval) , $moves, $moveAttackedBy);
    } else {
        if ($aiDebug) {
            print "  " x (5 - $depth);
            print "^--depth: $depth $moveString max $maxEval, MIN $minEval vs eval: $score, isMaxer: $maximizingPlayer\n";
        }
        return (($minEval == AI_INFINITY ? $score : $minEval), $moves, $moveAttackedBy);
    }
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
    if ($ai_red & $_[0]) {
        return ($chr + 200); 
    }
    if ($ai_green & $_[0]) {
        return ($chr + 300); 
    }
    return $chr;
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
        my $bb = _getBBat('a', (8 - $colCount));
        for ($rowCount = 0; $rowCount < 8; $rowCount++) {

            my $piece = _getPieceBB($bb);
            if ($piece) {
                if ($colGapCount > 0){
                    $fenString .= $colGapCount;
                    $colGapCount = 0;
                }
                $fenString .= getPieceDisplayFEN($piece);
            } else {
                $colGapCount ++;
            }
            $bb = shift_BB($bb, EAST);
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

sub getPieceDisplayFEN {
    my $piece = shift;
    if ($piece % 100 == PAWN) {
        return ($piece > 200 ? 'p' : 'P');
    }
    if ($piece % 100 == ROOK) {
        return ($piece > 200 ? 'r' : 'P');
    }
    if ($piece % 100 == BISHOP) {
        return ($piece > 200 ? 'b' : 'B');
    }
    if ($piece % 100 == KNIGHT) {
        return ($piece > 200 ? 'n' : 'N');
    }
    if ($piece % 100 == QUEEN) {
        return ($piece > 200 ? 'q' : 'Q');
    }
    if ($piece % 100 == KING) {
        return ($piece > 200 ? 'k' : 'K');
    }
    return ' ';
}

### ONLY for loading fen strings don't use for speed
sub getPieceFromFENchr {
    my $p = shift;
    my %chrs = (
        'p' => BLACK_PAWN,
        'P' => WHITE_PAWN,
        'n' => BLACK_KNIGHT,
        'N' => WHITE_KNIGHT,
        'b' => BLACK_BISHOP,
        'B' => WHITE_BISHOP,
        'r' => BLACK_ROOK,
        'R' => WHITE_ROOK,
        'q' => BLACK_QUEEN,
        'Q' => WHITE_QUEEN,
        'k' => BLACK_KING,
        'K' => WHITE_KING
    );
    return $chrs{$p};
}

sub debug {
    #return _getPiece('a', '1');
    print "NORTH:\n";
    print prettyBoard($cantGoNorth);
    print "\n\n\nSOUTH:\n";
    print prettyBoard($cantGoSouth);
    print "\n\n\nEAST\n";
    print prettyBoard($cantGoEast );
    print "\n\n\nWEST:\n";
    print prettyBoard($cantGoWest );
    #my $fr = RANKS_H->{'12'} & FILES_H->{'i'};
    #print prettyBoard($fr);
    #my $bb = shift_BB($fr, EAST);
    #print prettyBoard($bb);
    #print prettyBoard(shift_BB($bb, SOUTH_EAST));
    #foreach my $to (
        #shift_BB(shift_BB($fr, EAST) , SOUTH_EAST),
    #) {
        #if (($to != 0)) {
            ##print prettyBoard($fr | $to);
        #}
    #}
}
sub debugNorth {
    my $bb = RANKS->[0] & FILES->[4];
    print prettyBoard($bb);
    while ($bb = shift_BB($bb, NORTH)) {
        print prettyBoard($bb);
    }
    $bb = RANKS->[2] & FILES->[0];
    print prettyBoard($bb);
    while ($bb = shift_BB($bb, NORTH)) {
        print prettyBoard($bb);
    }
}
sub debugSouth {
    my $bb = RANKS->[11] & FILES->[4];
    print prettyBoard($bb);
    while ($bb = shift_BB($bb, SOUTH)) {
        print prettyBoard($bb);
    }
    $bb = RANKS->[2] & FILES->[0];
    print prettyBoard($bb);
    while ($bb = shift_BB($bb, NORTH)) {
        print prettyBoard($bb);
    }
}
sub debugEast {
    my $bb = RANKS->[4] & FILES->[0];
    #return _getPiece('a', '1');
    #print prettyBoard($occupied);
    print prettyBoard($bb);
    while ($bb = shift_BB($bb, EAST)) {
        print prettyBoard($bb);
    }
}
sub debugWest {
    my $bb = RANKS->[4] & FILES->[11];
    #return _getPiece('a', '1');
    #print prettyBoard($occupied);
    print prettyBoard($bb);
    while ($bb = shift_BB($bb, WEST)) {
        print prettyBoard($bb);
    }
}

### returns to piece for normal, 0 for from not occupied (failure)
### for ai we need to the toPiece to undo the move
### warning! does not check if the move is legal
sub do_move_ai {
    my ($fr_bb, $to_bb) = @_;

    if ($aiDebug) {

        ### should NOT happen. Moving piece that doesn't exist
        if (! ($fr_bb & $ai_occupied)) {
            print "NULL do_move_ai\n";
            return 0;
        }
    }

    my $piece = _getPieceBB_ai($fr_bb);
    my $toPiece = _getPieceBB_ai($to_bb);

    _removePiece_ai($fr_bb | $to_bb);
    _putPiece_ai($piece, $to_bb);

    $ai_frozenBB |= $to_bb;

    return $toPiece;
}
### return 1 for success, 0 for failure (no piece on to_bb)
### warning! unfreezes no matter what, you should not ai move
### frozen pieces
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
    $ai_frozenBB &= ~$to_bb;
    return 1;
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

sub _putPiece_ai {
    my $p  = shift;
    my $BB = shift;

    strToInt($BB);

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


sub pop_lsb {
    my $s = $_[0];
    $_[0] &= $_[0] - 1;
    $s &= ~$_[0];
    return $s;
}

sub printBBSquares {
    foreach my $i ( 0 .. 11 ) {
        my $r = 11-$i;
        foreach my $f ( 0 .. 11 ) {
            my $bb = RANKS->[$r] & FILES->[$f];
            if ($bb != 0) {
                print "'";
                print $bb;
                print "'";
                print " : ";
                print "'";
                print chr($f + 97);
                print ($r + 1) . "'";
                print "'";
                print ",";
                print "\n";
            }
        }
    }
}

### ensures messages passed in are ints
#
sub strToInt {
    $_[0] = uint128($_[0]);
}

1;
