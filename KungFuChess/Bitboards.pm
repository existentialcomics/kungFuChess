#!/usr/bin/perl

use strict;
#use warnings;

package XS;
use Inline CPP => config => typemaps => './typemap';
use Inline CPP => './xs.cpp' => namespace => 'xs';

package KungFuChess::Bitboards;
use Math::BigInt;
use Time::HiRes qw(time);
use Data::Dumper;
use KungFuChess::BBHash;
#use Algorithm::MinPerfHashTwoLevel;
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
    MOVE_DOUBLE_PAWN => 8,
    
    ### matches Stockfish
    ALL_PIECES => 000,
    PAWN   => 001,
    KNIGHT => 002,
    BISHOP => 003,
    ROOK   => 004,
    KING   => 005,
    QUEEN  => 006,

    ### array of a move for AI
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

my $bb_to_human = {
    '72057594037927936' => 'a8',
    '144115188075855872' => 'b8',
    '288230376151711744' => 'c8',
    '576460752303423488' => 'd8',
    '1152921504606846976' => 'e8',
    '2305843009213693952' => 'f8',
    '4611686018427387904' => 'g8',
    '9223372036854775808' => 'h8',
    '281474976710656' => 'a7',
    '562949953421312' => 'b7',
    '1125899906842624' => 'c7',
    '2251799813685248' => 'd7',
    '4503599627370496' => 'e7',
    '9007199254740992' => 'f7',
    '18014398509481984' => 'g7',
    '36028797018963968' => 'h7',
    '1099511627776' => 'a6',
    '2199023255552' => 'b6',
    '4398046511104' => 'c6',
    '8796093022208' => 'd6',
    '17592186044416' => 'e6',
    '35184372088832' => 'f6',
    '70368744177664' => 'g6',
    '140737488355328' => 'h6',
    '4294967296' => 'a5',
    '8589934592' => 'b5',
    '17179869184' => 'c5',
    '34359738368' => 'd5',
    '68719476736' => 'e5',
    '137438953472' => 'f5',
    '274877906944' => 'g5',
    '549755813888' => 'h5',
    '16777216' => 'a4',
    '33554432' => 'b4',
    '67108864' => 'c4',
    '134217728' => 'd4',
    '268435456' => 'e4',
    '536870912' => 'f4',
    '1073741824' => 'g4',
    '2147483648' => 'h4',
    '65536' => 'a3',
    '131072' => 'b3',
    '262144' => 'c3',
    '524288' => 'd3',
    '1048576' => 'e3',
    '2097152' => 'f3',
    '4194304' => 'g3',
    '8388608' => 'h3',
    '256' => 'a2',
    '512' => 'b2',
    '1024' => 'c2',
    '2048' => 'd2',
    '4096' => 'e2',
    '8192' => 'f2',
    '16384' => 'g2',
    '32768' => 'h2',
    '1' => 'a1',
    '2' => 'b1',
    '4' => 'c1',
    '8' => 'd1',
    '16' => 'e1',
    '32' => 'f1',
    '64' => 'g1',
    '128' => 'h1',
};

my $human_to_bb = {
    'a8' => '72057594037927936',
    'b8' => '144115188075855872',
    'c8' => '288230376151711744',
    'd8' => '576460752303423488',
    'e8' => '1152921504606846976',
    'f8' => '2305843009213693952',
    'g8' => '4611686018427387904',
    'h8' => '9223372036854775808',
    'a7' => '281474976710656',
    'b7' => '562949953421312',
    'c7' => '1125899906842624',
    'd7' => '2251799813685248',
    'e7' => '4503599627370496',
    'f7' => '9007199254740992',
    'g7' => '18014398509481984',
    'h7' => '36028797018963968',
    'a6' => '1099511627776',
    'b6' => '2199023255552',
    'c6' => '4398046511104',
    'd6' => '8796093022208',
    'e6' => '17592186044416',
    'f6' => '35184372088832',
    'g6' => '70368744177664',
    'h6' => '140737488355328',
    'a5' => '4294967296',
    'b5' => '8589934592',
    'c5' => '17179869184',
    'd5' => '34359738368',
    'e5' => '68719476736',
    'f5' => '137438953472',
    'g5' => '274877906944',
    'h5' => '549755813888',
    'a4' => '16777216',
    'b4' => '33554432',
    'c4' => '67108864',
    'd4' => '134217728',
    'e4' => '268435456',
    'f4' => '536870912',
    'g4' => '1073741824',
    'h4' => '2147483648',
    'a3' => '65536',
    'b3' => '131072',
    'c3' => '262144',
    'd3' => '524288',
    'e3' => '1048576',
    'f3' => '2097152',
    'g3' => '4194304',
    'h3' => '8388608',
    'a2' => '256',
    'b2' => '512',
    'c2' => '1024',
    'd2' => '2048',
    'e2' => '4096',
    'f2' => '8192',
    'g2' => '16384',
    'h2' => '32768',
    'a1' => '1',
    'b1' => '2',
    'c1' => '4',
    'd1' => '8',
    'e1' => '16',
    'f1' => '32',
    'g1' => '64',
    'h1' => '128',
};

sub getBBfromSquare {
    return strToInt($human_to_bb->{$_[0]});
}

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

########################## for AI only ###########################
#
# copied from stockfish, only the "middlegame" numbers for now
# black must flip this
my $SQ_BONUS = [
    [], # all
    [   # pawn
      [ [  2, -8], [  4, -6], [ 11,  9], [ 18,  5], [ 16, 16], [ 21,  6], [  9, -6], [ -3,-18] ],
      [ [ -9, -9], [-15, -7], [ 11,-10], [ 15,  5], [ 31,  2], [ 23,  3], [  6, -8], [-20, -5] ],
      [ [ -3,  7], [-20,  1], [  8, -8], [ 19, -2], [ 39,-14], [ 17,-13], [  2,-11], [ -5, -6] ],
      [ [ 11, 12], [ -4,  6], [-11,  2], [  2, -6], [ 11, -5], [  0, -4], [-12, 14], [  5,  9] ],
      [ [  3, 27], [-11, 18], [ -6, 19], [ 22, 29], [ -8, 30], [ -5,  9], [-14,  8], [-11, 14] ],
      [ [ -7, -1], [  6,-14], [ -2, 13], [-11, 22], [  4, 24], [-14, 17], [ 10,  7], [ -9,  7] ],
    [] ### pawn shouldn't fuckin be here
    ],
    [ # Knight
      [ [-175, -96], [-92,-65], [-74,-49], [-73,-21], [-73,-21], [-74,-49], [-92,-65], [-175, -96]],
      [ [ -77, -67], [-41,-54], [-27,-18], [-15,  8], [-15,  8], [-27,-18], [-41,-54], [ -77, -67]],
      [ [ -61, -40], [-17,-27], [  6, -8], [ 12, 29], [ 12, 29], [  6, -8], [-17,-27], [ -61, -40]],
      [ [ -35, -35], [  8, -2], [ 40, 13], [ 49, 28], [ 49, 28], [ 40, 13], [  8, -2], [ -35, -35]],
      [ [ -34, -45], [ 13,-16], [ 44,  9], [ 51, 39], [ 51, 39], [ 44,  9], [ 13,-16], [ -34, -45]],
      [ [  -9, -51], [ 22,-44], [ 58,-16], [ 53, 17], [ 53, 17], [ 58,-16], [ 22,-44], [  -9, -51]],
      [ [ -67, -69], [-27,-50], [  4,-51], [ 37, 12], [ 37, 12], [  4,-51], [-27,-50], [ -67, -69]],
      [ [-201,-100], [-83,-88], [-56,-56], [-26,-17], [-26,-17], [-56,-56], [-83,-88], [-201,-100]]
    ],
    [ # Bishop
      [ [-37,-40], [-4 ,-21], [ -6,-26], [-16, -8], [-16, -8], [ -6,-26], [-4 ,-21], [-37,-40]],
      [ [-11,-26], [  6, -9], [ 13,-12], [  3,  1], [  3,  1], [ 13,-12], [  6, -9], [-11,-26]],
      [ [-5 ,-11], [ 15, -1], [ -4, -1], [ 12,  7], [ 12,  7], [ -4, -1], [ 15, -1], [-5 ,-11]],
      [ [-4 ,-14], [  8, -4], [ 18,  0], [ 27, 12], [ 27, 12], [ 18,  0], [  8, -4], [-4 ,-14]],
      [ [-8 ,-12], [ 20, -1], [ 15,-10], [ 22, 11], [ 22, 11], [ 15,-10], [ 20, -1], [-8 ,-12]],
      [ [-11,-21], [  4,  4], [  1,  3], [  8,  4], [  8,  4], [  1,  3], [  4,  4], [-11,-21]],
      [ [-12,-22], [-10,-14], [  4, -1], [  0,  1], [  0,  1], [  4, -1], [-10,-14], [-12,-22]],
      [ [-34,-32], [  1,-29], [-10,-26], [-16,-17], [-16,-17], [-10,-26], [  1,-29], [-34,-32]]
    ],
    [ # Rook
      [ [-31, -9], [-20,-13], [-14,-10], [-5, -9], [-5, -9], [-14,-10], [-20,-13], [-31, -9]],
      [ [-21,-12], [-13, -9], [ -8, -1], [ 6, -2], [ 6, -2], [ -8, -1], [-13, -9], [-21,-12]],
      [ [-25,  6], [-11, -8], [ -1, -2], [ 3, -6], [ 3, -6], [ -1, -2], [-11, -8], [-25,  6]],
      [ [-13, -6], [ -5,  1], [ -4, -9], [-6,  7], [-6,  7], [ -4, -9], [ -5,  1], [-13, -6]],
      [ [-27, -5], [-15,  8], [ -4,  7], [ 3, -6], [ 3, -6], [ -4,  7], [-15,  8], [-27, -5]],
      [ [-22,  6], [ -2,  1], [  6, -7], [12, 10], [12, 10], [  6, -7], [ -2,  1], [-22,  6]],
      [ [ -2,  4], [ 12,  5], [ 16, 20], [18, -5], [18, -5], [ 16, 20], [ 12,  5], [ -2,  4]],
      [ [-17, 18], [-19,  0], [ -1, 19], [ 9, 13], [ 9, 13], [ -1, 19], [-19,  0], [-17, 18]]
    ],
    [ # Queen
      [ [ 3,-69], [-5,-57], [-5,-47], [ 4,-26], [ 4,-26], [-5,-47], [-5,-57], [ 3,-69]],
      [ [-3,-54], [ 5,-31], [ 8,-22], [12, -4], [12, -4], [ 8,-22], [ 5,-31], [-3,-54]],
      [ [-3,-39], [ 6,-18], [13, -9], [ 7,  3], [ 7,  3], [13, -9], [ 6,-18], [-3,-39]],
      [ [ 4,-23], [ 5, -3], [ 9, 13], [ 8, 24], [ 8, 24], [ 9, 13], [ 5, -3], [ 4,-23]],
      [ [ 0,-29], [14, -6], [12,  9], [ 5, 21], [ 5, 21], [12,  9], [14, -6], [ 0,-29]],
      [ [-4,-38], [10,-18], [ 6,-11], [ 8,  1], [ 8,  1], [ 6,-11], [10,-18], [-4,-38]],
      [ [-5,-50], [ 6,-27], [10,-24], [ 8, -8], [ 8, -8], [10,-24], [ 6,-27], [-5,-50]],
      [ [-2,-74], [-2,-52], [ 1,-43], [-2,-34], [-2,-34], [ 1,-43], [-2,-52], [-2,-74]]
    ],
    [ # King
      [ [271,  1], [327, 45], [271, 85], [198, 76], [198, 76], [271, 85], [327, 45], [271,  1]],
      [ [278, 53], [303,100], [234,133], [179,135], [179,135], [234,133], [303,100], [278, 53]],
      [ [195, 88], [258,130], [169,169], [120,175], [120,175], [169,169], [258,130], [195, 88]],
      [ [164,103], [190,156], [138,172], [ 98,172], [ 98,172], [138,172], [190,156], [164,103]],
      [ [154, 96], [179,166], [105,199], [ 70,199], [ 70,199], [105,199], [179,166], [154, 96]],
      [ [123, 92], [145,172], [ 81,184], [ 31,191], [ 31,191], [ 81,184], [145,172], [123, 92]],
      [ [ 88, 47], [120,121], [ 65,116], [ 33,131], [ 33,131], [ 65,116], [120,121], [ 88, 47]],
      [ [ 59, 11], [ 89, 59], [ 45, 73], [ -1, 78], [ -1, 78], [ 45, 73], [ 89, 59], [ 59, 11]]
    ]
];

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

#xs::initialise_all_databases();

### similar to stockfish we have multiple bitboards that we intersect
### to determine the position of things and state of things.
### init all bitboards to zero

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
my $whiteQCastleR_off = RANKS->[0] & FILES->[2]; # if you moved next to the rook that's still a castle attempt
my $blackCastleK      = RANKS->[7] & FILES->[4];
my $blackCastleR      = RANKS->[7] & FILES->[7];
my $blackCastleR_off  = RANKS->[7] & FILES->[6]; # if you moved next to the rook that's still a castle attempt
my $blackQCastleR     = RANKS->[7] & FILES->[0];
my $blackQCastleR_off = RANKS->[7] & FILES->[2]; # if you moved next to the rook that's still a castle attempt

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

# set the ai boards back to the current real position;
sub resetAiBoards {
    my $color = shift;

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

    #$ai_frozenBB = $frozenBB;
    $ai_frozenBB = 0;
    $ai_movingBB = $movingBB;

    ### if we are moving it FOR a color we clear our enemies frozen
    if ($color && $color == WHITE) {
        $ai_frozenBB &= ~$black;
    } elsif ($color && $color == BLACK) {
        $ai_frozenBB &= ~$white;
    }
    ### clear the current moves. We don't search enough depth
    #   and the game is too fast paced to worry about the tree
    #   replacing the current moves, just have to redo it every time
    $currentMoves = undef;
}

sub saveState {
    return [
      $ai_pawns    ,
      $ai_knights  ,
      $ai_bishops  ,
      $ai_rooks    ,
      $ai_queens   ,
      $ai_kings    ,
      $ai_white     ,
      $ai_black     ,
      $ai_occupied  ,
      $ai_enPassant ,
      $ai_whiteCastleK  ,
      $ai_blackCastleK  ,
      $ai_whiteCastleR  ,
      $ai_blackCastleR  ,
      $ai_whiteQCastleR ,
      $ai_blackQCastleR ,
      $ai_frozenBB ,
      $ai_movingBB
    ];
}

sub applyState {
  $ai_pawns    = $_[0];
  $ai_knights  = $_[1];
  $ai_bishops  = $_[2];
  $ai_rooks    = $_[3];
  $ai_queens   = $_[4]; 
  $ai_kings    = $_[5];
  $ai_white     = $_[6];
  $ai_black     = $_[7];
  $ai_occupied  = $_[8];
  $ai_enPassant = $_[9];
  $ai_whiteCastleK  = $_[10] ;
  $ai_blackCastleK  = $_[11] ;
  $ai_whiteCastleR  = $_[12] ;
  $ai_blackCastleR  = $_[12] ;
  $ai_whiteQCastleR = $_[13];
  $ai_blackQCastleR = $_[14];
  $ai_frozenBB = $_[15];
  $ai_movingBB = $_[16];
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
    my $color = shift;

    $pawns    = 0x0000000000000000;
    $knights  = 0x0000000000000000;
    $bishops  = 0x0000000000000000;
    $rooks    = 0x0000000000000000;
    $queens   = 0x0000000000000000;
    $kings    = 0x0000000000000000;
    $white     = 0x0000000000000000;
    $black     = 0x0000000000000000;
    $occupied  = 0x0000000000000000;
    $enPassant = 0x0000000000000000;

    if (! $color || $color eq 'white') {
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
    }

    #### black ####
    if (! $color || $color eq 'black') {
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
    }

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
sub isMoving {
    my $bb = shift;
    return $movingBB & $bb;
}

sub blockers {
    my ($blockingBB, $dirBB, $fromBB, $toBB, $depth) = @_;

    while ($fromBB != $toBB) {
        $fromBB = shift_BB($fromBB, $dirBB);
        #if (! ($fromBB & $movingBB) ){
            if ($fromBB == 0)         { return 0; } ### off the board
            if ($fromBB & $blockingBB){ return 0; }

            ### we may want to only have the piece immediately in front block
            if (defined($depth) ){
                $depth--;
                if ($depth == 0) { $blockingBB = 0; }
            }
        #}
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
            # set attackedBy this square
        }
    }
    return $blockingBB;
}

sub parseSquare {
    my $square = shift;

    my ($fr_f, $fr_r);
    if ($square =~ m/^([a-z])([0-9]{1,2})$/) {
        ($fr_f, $fr_r) = ($1, $2);
    } else {
        warn "bad square $square!\n";
        return MOVE_NONE;
    }

    my $fr_rank = RANKS_H->{$fr_r};
    my $fr_file = FILES_H->{$fr_f};

    my $fr_bb = $fr_rank & $fr_file;
    return $fr_bb;
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
            $pawnMoveType = MOVE_DOUBLE_PAWN;
            # it can be occupied for double moves
            #if ($to_bb & $occupied) {
                #return @noMove;
            #}
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
    if ($whiteCastleR && ($to_bb | $fr_bb) & $whiteCastleR) {
        $whiteCastleR = 0;
    }
    if ($blackCastleK && ($to_bb | $fr_bb) & $blackCastleK) {
        $blackCastleK = 0;
    }
    if ($blackCastleR && ($to_bb | $fr_bb) & $blackCastleR) {
        $blackCastleR = 0;
    }

    my $piece = _getPieceBB($fr_bb);

    _removePiece($fr_bb);
    _removePiece($to_bb);
    _putPiece($piece, $to_bb);
    resetAiBoards($fr_bb, $to_bb);
    return 1;
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

### for display purpose only
sub getPieceDisplay {
    my $piece = shift;
    if (! defined($piece)) {
        return ' ';
    }
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

sub setPosXS {
    xs::setBBs(
        $pawns   ,
        $knights ,
        $bishops ,
        $rooks   ,
        $queens  ,
        $kings   ,
        $white   ,
        $black   ,
        $frozenBB ,
        $movingBB
    );
    print "done setBBs()\n";
}

sub initXS {
    xs::initialise_bitboard();
}

sub evaluateXS {
    return xs::evaluate();
}

sub getMovesXS {
    my @moves;
    while(my $move = xs::getNextMove()) {
        push @moves, $move;
    }
    return @moves;
}

### evaluate a single board position staticly, returns the score and moves
sub evaluate {
    my $score = 0;
    my @moves = (
        [], # no color
        [], # white
        []  # black
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

    ### TODO reset all eval vars here
    ### TODO build an array of all squares at the start
    foreach my $r ( 0 .. 7 ) {
        foreach my $f ( 0 .. 7 ) {
            my $fr = RANKS->[$r] & FILES->[$f];
            #if ($fr & $ai_frozenBB) { print "$r$f next;\n"; next; }
            my $piece = _getPieceBB_ai($fr);
            next if (! defined($piece));

            my $frozen = ($fr & $ai_frozenBB);

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
            push @{$pieces[$color]->[$pieceType]}, $fr;

            ### for square bonuses
            my $sq_f = $f;
            my $sq_r = $color == WHITE ? $r : 7 - $r;
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
                            $attackedByFrozen[$color]->[ALL_PIECES]      |= $to;
                        } else {
                            $attackedByUnFrozen[$color]->[$pieceType] |= $to;
                            $attackedByUnFrozen[$color]->[ALL_PIECES]      |= $to;
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
                        $attackedBy[$color]->[ALL_PIECES]      |= $to;
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
                            # no xrays with frozen pieces
                            if ($to & $ai_frozenBB) {
                                $to = 0;
                                next;
                            }
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
                $to = shift_BB($fr, $pawnDir + WEST);
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
                $to = shift_BB($fr, $pawnDir + EAST);
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

    #********************** position is now set up and we begin the evaulation ********
    
    #// Early exit if score is high
    #auto lazy_skip = [&](Value lazyThreshold) {
        #return abs(mg_value(score) + eg_value(score)) >   lazyThreshold
                                                        #+ std::abs(pos.this_thread()->bestValue) * 5 / 4
                                                        #+ pos.non_pawn_material() / 32;
    #};

    #Bitboard b, weak, defended, nonPawnEnemies, stronglyProtected, safe;
    

    my $pcount = 0;
    foreach my $color (1 .. 2) {
        my $us   = ($color == WHITE ? WHITE : BLACK);
        my $them = ($color == WHITE ? BLACK : WHITE);

        ###*********** first we more or less copy the threats() function from stockfish
        my $threatScore = 0;
        my $occupiedThem = ($them == WHITE ? $ai_occupied & $ai_white : $ai_occupied & $ai_black);

        #// Squares strongly protected by the enemy, either because they defend the
        #// square with a pawn, or because they defend the square twice and we don't.
        #stronglyProtected =  attackedBy[Them][PAWN]
                           #| (attackedBy2[Them] & ~attackedBy2[Us]);
        my $stronglyProtected = $attackedBy[$them][PAWN]
                           | ($attackedBy[$them] & ~$attackedBy2[$us]);

        my $nonPawnEnemies = $occupiedThem & ~$ai_pawns;

        #// Non-pawn enemies, strongly protected
        my $defended = $nonPawnEnemies & $stronglyProtected;

        # Protected or unattacked squares
        my $safeBB = ~$attackedByUnFrozen[$them][ALL_PIECES] | $attackedByUnFrozen[$us][ALL_PIECES];

        # Enemies not strongly protected and under our attack
        my $weak = ($occupiedThem & ~$stronglyProtected & $attackedBy[$us][ALL_PIECES]);

        # Bonus according to the kind of attacking pieces
        if ($defended | $weak) {
            my $bb = 0;
            $bb = ($defended | $weak) & ($attackedBy[$us][KNIGHT] | $attackedBy[$us][BISHOP]);
            #while ($bb) {
                #$threatScore += ThreatByMinor[type_of(pos.piece_on(pop_lsb(b)))];
            #}

            #b = weak & attackedBy[Us][ROOK];
            #while (b)
                #score += ThreatByRook[type_of(pos.piece_on(pop_lsb(b)))];

            #if (weak & attackedBy[Us][KING])
                #score += ThreatByKing;

            #b =  ~attackedBy[Them][ALL_PIECES]
               #| (nonPawnEnemies & attackedBy2[Us]);
            #score += Hanging * popcount(weak & b);

            #// Additional bonus if weak piece is only protected by a queen
            #score += WeakQueenProtection * popcount(weak & attackedBy[Them][QUEEN]);
        }


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
        #print "doing eval\n";
        ($aiScore, $currentMoves, $totalMaterial, $attackedBy) = evaluate();
        #print "eval score: $aiScore\n";
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
    } else { ### look for attacks on the square
        # we are already attacking them with a pawn
        if ($currentAttackedBy->[$color]->[PAWN] & $bb) {
            return undef, undef;
        }

        ### look for pawn attacks in moves
        foreach my $move (@{$currentMoves->[$color]}) {
            if ($move->[MOVE_ATTACKS]->[$color]->[PAWN] & $bb) {
                return ($move->[MOVE_TO], $move->[MOVE_SCORE]);
            }
        }

        # we are attacking but not with a pawn.
        if ($currentAttackedBy->[$color]->[ALL_PIECES]) {
        }
        foreach my $move (@{$currentMoves->[$color]}) {


        }
    }
    return undef;
}

# return $score, [] $moves;
sub evaluateTree {
    my ($color, $depth, $turnDepth, $stopTime, $moves, $alpha, $beta, $maximizingPlayer, $moveString, $moveAttackedBy, $moveMaterial) = @_;

    $depth--;

    my $score = 0;
    #if (! $moves) {
        ($score, $moves, $moveMaterial, $moveAttackedBy) = evaluate();
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
            #my $chr = getPieceDisplayFEN(_getPieceXY_ai($f, $r));
            $board .= "$chr | ";
        }
        $board .= "\n   +---+---+---+---+---+---+---+----\n";
    }
    $board .= "     a   b   c   d   e   f   g   h  \n";
    return $board;
}

sub clearAiFrozen {
    $ai_frozenBB = 0;
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
            if ($f eq 0){ $board .= " " . ($r + 1) . " | "; }
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

sub prettyFrozen {
    return prettyBoard($ai_frozenBB);
}

sub debug {
    #return _getPiece('a', '1');
    #print prettyBoard($occupied);
    return prettyBoard($ai_bishops);
}

sub debug2 {
    my $sq = pop_lsb($ai_bishops);
    #return _getPiece('a', '1');
    #print prettyBoard($occupied);
    return prettyBoard($ai_bishops) . prettyBoard($sq);
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

### for ai debugging only
sub loadFENstring {
    my $FEN = shift;

    #### reset all boards
    $pawns    = 0x0000000000000000;
    $knights  = 0x0000000000000000;
    $bishops  = 0x0000000000000000;
    $rooks    = 0x0000000000000000;
    $queens   = 0x0000000000000000;
    $kings    = 0x0000000000000000;
    $white     = 0x0000000000000000;
    $black     = 0x0000000000000000;
    $occupied  = 0x0000000000000000;
    $enPassant = 0x0000000000000000;
    $whiteCastleK  = RANKS->[0] & FILES->[4];
    $blackCastleK  = RANKS->[7] & FILES->[4];
    $whiteCastleR  = RANKS->[0] & FILES->[7];
    $blackCastleR  = RANKS->[7] & FILES->[7];
    $whiteQCastleR = RANKS->[0] & FILES->[0];
    $blackQCastleR = RANKS->[7] & FILES->[0];
    $frozenBB = 0x0000000000000000;
    $movingBB = 0x0000000000000000;

    my $col = 7;
    my $row = 0;
    foreach my $chr (split '', $FEN) {
        if ($chr =~ m/\d+/){
            $row += $chr;
        } elsif ($chr eq '/') {
            $col--;
            $row = 0;
        } elsif ($chr eq ' '){
            last;
        } else {  ### assume we get a piece here
            my $piece = getPieceFromFENchr($chr);
            my $bb = RANKS->[$col] & FILES->[$row];
            _putPiece($piece, $bb);
            $row ++;
        }
    }

    resetAiBoards();
}

#/// pop_lsb() finds and clears the least significant bit in a non-zero bitboard
#inline Square pop_lsb(Bitboard& b) {
  #assert(b);
  #const Square s = lsb(b);
  #b &= b - 1;
  #return s;
#}

sub pop_lsb {
    my $s = $_[0];
    $_[0] &= $_[0] - 1;
    $s &= ~$_[0];
    return $s;
}

### ensures messages passed in are ints
#
sub strToInt {
    $_[0] += 0;
}


1;
