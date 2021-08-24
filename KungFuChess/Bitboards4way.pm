#!/usr/bin/perl

use strict;
#use warnings;

### same package name as Bitboards so the server doesn't have to know which it is using
package KungFuChess::Bitboards;
use Math::BigInt;
use Data::Dumper;
use base 'Exporter';

use constant ({
    NO_COLOR => 0,
    WHITE    => 1,
    BLACK    => 2,
    RED      => 3,
    GREEN    => 4,

    DIR_NONE =>  0,
    NORTH =>  12,
    ### warning! I think EAST actually goes west and WEST goes east, fix it yourself it's open source lol
    # also these numbers correspond to the bitshifts but they aren't actually used like that.
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
    FILES => [
        Math::BigInt->new('0x800800800800800800800800800800800800'),
        Math::BigInt->new('0x800800800800800800800800800800800800') >> 1,
        Math::BigInt->new('0x800800800800800800800800800800800800') >> 2,
        Math::BigInt->new('0x800800800800800800800800800800800800') >> 3,
        Math::BigInt->new('0x800800800800800800800800800800800800') >> 4,
        Math::BigInt->new('0x800800800800800800800800800800800800') >> 5,
        Math::BigInt->new('0x800800800800800800800800800800800800') >> 6,
        Math::BigInt->new('0x800800800800800800800800800800800800') >> 7,
        Math::BigInt->new('0x800800800800800800800800800800800800') >> 8,
        Math::BigInt->new('0x800800800800800800800800800800800800') >> 9,
        Math::BigInt->new('0x800800800800800800800800800800800800') >> 10,
        Math::BigInt->new('0x800800800800800800800800800800800800') >> 11,
    ],
    FILES_H => {
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
    RANKS => [
        Math::BigInt->new('0x000000000000000000000000000000000FFF'),
        Math::BigInt->new('0x000000000000000000000000000000FFF000'),
        Math::BigInt->new('0x000000000000000000000000000FFF000000'),
        Math::BigInt->new('0x000000000000000000000000FFF000000000'),
        Math::BigInt->new('0x000000000000000000000FFF000000000000'),
        Math::BigInt->new('0x000000000000000000FFF000000000000000'),
        Math::BigInt->new('0x000000000000000FFF000000000000000000'),
        Math::BigInt->new('0x000000000000FFF000000000000000000000'),
        Math::BigInt->new('0x000000000FFF000000000000000000000000'),
        Math::BigInt->new('0x000000FFF000000000000000000000000000'),
        Math::BigInt->new('0x000FFF000000000000000000000000000000'),
        Math::BigInt->new('0xFFF000000000000000000000000000000000'),
    ],
    RANKS_H => {
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

    ### special number we need because we are using BigInt, so it goes on forever
    MAX_BITBOARD => Math::BigInt->new('0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'),

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

my $whiteCastleK  = RANKS_H->{1} & FILES_H->{'g'};
my $whiteCastleR  = RANKS_H->{1} & FILES_H->{'j'};
my $whiteCastleR_off  = RANKS_H->{1} & FILES_H->{'i'};
my $whiteQCastleR = RANKS_H->{1} & FILES_H->{'c'};
my $whiteQCastleR_off = RANKS_H->{1} & FILES_H->{'d'};
my $blackCastleK  = RANKS_H->{12} & FILES_H->{'g'};
my $blackCastleR  = RANKS_H->{12} & FILES_H->{'j'};
my $blackCastleR_off  = RANKS_H->{12} & FILES_H->{'i'};
my $blackQCastleR = RANKS_H->{12} & FILES_H->{'c'};
my $blackQCastleR_off = RANKS_H->{12} & FILES_H->{'d'};
my $redCastleK  = RANKS_H->{6} & FILES_H->{'a'};
my $redCastleR  = RANKS_H->{3} & FILES_H->{'a'};
my $redCastleR_off  = RANKS_H->{4} & FILES_H->{'a'};
my $redQCastleR = RANKS_H->{10} & FILES_H->{'a'};
my $redQCastleR_off = RANKS_H->{9} & FILES_H->{'a'};
my $greenCastleK  = RANKS_H->{6} & FILES_H->{'l'};
my $greenCastleR  = RANKS_H->{3} & FILES_H->{'l'};
my $greenCastleR_off  = RANKS_H->{4} & FILES_H->{'l'};
my $greenQCastleR = RANKS_H->{10} & FILES_H->{'l'};
my $greenQCastleR_off = RANKS_H->{9} & FILES_H->{'l'};

### frozen pieces, can't move
my $frozenBB = Math::BigInt->new('0x00000000000000000000000000000000');
### pieces currently moving, don't attack these!
my $movingBB = Math::BigInt->new('0x00000000000000000000000000000000');

sub resetAiBoards {
}

sub setupInitialPosition {
    #### white ####
    # rook 1
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

### copied from shift function in Stockfish
sub shift_BB {
    my ($bb, $direction) = @_;
    return  $direction == NORTH      ?  $bb                <<12 : $direction == SOUTH      ?  $bb                >>12
          : $direction == NORTH+NORTH?  $bb                <<24 : $direction == SOUTH+SOUTH?  $bb                >>24
          : $direction == EAST       ? ($bb & ~FILES_H->{a}) << 1 : $direction == WEST       ? ($bb & ~FILES_H->{l}) >> 1
          : $direction == NORTH_EAST ? ($bb & ~FILES_H->{a}) <<13 : $direction == NORTH_WEST ? ($bb & ~FILES_H->{l}) <<11
          : $direction == SOUTH_EAST ? ($bb & ~FILES_H->{a}) >>11 : $direction == SOUTH_WEST ? ($bb & ~FILES_H->{l}) >>13
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

sub _removeColorByName {
    my $colorName = shift;
    print "remove by name $colorName\n";
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
            if ($fromBB == 0)           { return 0; } ### of the board
            if ($fromBB >  MAX_BITBOARD){ return 0; } ### of the board
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
        $pawnDir = WEST;
    } elsif ($green & $bb) {
        $pawnDir = EAST;
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

    ### todo can probably figure a faster way to do this
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

    my $color;
    my $pawnDir;
    if ($white & $fr_bb) {
        $color = WHITE;
        $pawnDir = NORTH;
    } elsif ($black & $fr_bb) {
        $color = BLACK;
        $pawnDir = SOUTH;
    } elsif ($red & $fr_bb) {
        $color = RED;
        $pawnDir = WEST;
    } elsif ($green & $fr_bb) {
        $color = GREEN;
        $pawnDir = EAST;
    }

    ### castles go before checking same color on to_bb
    if ($fr_bb & $kings) {
        my ($bbK, $bbR, $bbQR, $kingDir, $rookDir);
        if ($color == WHITE) {
            $bbK  = $whiteCastleK;
            $bbR  = $whiteCastleR;
            $bbQR = $whiteQCastleR;
            $kingDir = WEST;
            $rookDir = EAST;
        } elsif ($color == BLACK) {
            $bbK  = $blackCastleK;
            $bbR  = $blackCastleR;
            $bbQR = $blackQCastleR;
            $kingDir = WEST;
            $rookDir = EAST;
        } elsif ($color == RED) {
            $bbK  = $redCastleK;
            $bbR  = $redCastleR;
            $bbQR = $redQCastleR;
            $kingDir = SOUTH;
            $rookDir = NORTH;
        } elsif ($color == GREEN) {
            $bbK  = $greenCastleK;
            $bbR  = $greenCastleR;
            $bbQR = $greenQCastleR;
            $kingDir = SOUTH;
            $rookDir = NORTH;
        }
        ### if they are moving to the "off" square we assume they are attempting to castle
        if ($to_bb & $bbR_off)  { $to_bb = $bbR ; } 
        if ($to_bb & $bbQR_off) { $to_bb = $bbQR; } 

        if ($fr_bb & $bbK){ 
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
            if ((shift_BB($fr_bb, $pawnDir + $pawnDir) & $to_bb) && ($fr_bb & (RANKS_H->{2} | RANKS_H->{15})) ){
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
                print "enPassant- $enPassant\n";

                return ($color, $pawnMoveType, $pawnDir, $fr_bb, $to_bb);
            }
        } else {
            if ((shift_BB(shift_BB($fr_bb, $pawnDir), $pawnDir) & $to_bb) && ($fr_bb & (FILES_H->{'b'} | FILES_H->{'k'})) ){
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
                print "enPassant: $enPassant\n";

                return ($color, $pawnMoveType, $pawnDir, $fr_bb, $to_bb);
            }
        }
        if ($to_bb & (_piecesThem($color) | $enPassant) ){
            if (($fr_bb & (FILES_H->{'c'} & RANKS_H->{'2'}))
                && $to_bb & (FILES_H->{'b'} & RANKS_H->{'3'}) 
            ) {
                return @noMove;
            }
            if (($fr_bb & (FILES_H->{'j'} & RANKS_H->{'2'}))
                && $to_bb & (FILES_H->{'k'} & RANKS_H->{'3'}) 
            ) {
                return @noMove;
            }

            if (($fr_bb & (FILES_H->{'c'} & RANKS_H->{'11'}))
                && $to_bb & (FILES_H->{'b'} & RANKS_H->{'10'}) 
            ) {
                return @noMove;
            }
            if (($fr_bb & (FILES_H->{'j'} & RANKS_H->{'11'}))
                && $to_bb & (FILES_H->{'k'} & RANKS_H->{'10'}) 
            ) {
                return @noMove;
            }

            if (($fr_bb & (FILES_H->{'k'} & RANKS_H->{'3'}))
                && $to_bb & (FILES_H->{'j'} & RANKS_H->{'2'}) 
            ) {
                return @noMove;
            }
            if (($fr_bb & (FILES_H->{'k'} & RANKS_H->{'10'}))
                && $to_bb & (FILES_H->{'j'} & RANKS_H->{'11'}) 
            ) {
                return @noMove;
            }

            if (($fr_bb & (FILES_H->{'b'} & RANKS_H->{'3'}))
                && $to_bb & (FILES_H->{'c'} & RANKS_H->{'2'}) 
            ) {
                return @noMove;
            }
            if (($fr_bb & (FILES_H->{'b'} & RANKS_H->{'10'}))
                && $to_bb & (FILES_H->{'c'} & RANKS_H->{'11'}) 
            ) {
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
    return (NO_COLOR, MOVE_NONE, $dir, $fr_bb, $to_bb);
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
    return (NO_COLOR, MOVE_NONE, $dir, $fr_bb, $to_bb);
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

    if (! ($fr_bb & $occupied)) {
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
    if ($redCastleK && ($to_bb | $fr_bb) & $redCastleK) {
        $redCastleK = 0;
    }
    if ($redCastleR && ($to_bb | $fr_bb) & $redCastleK) {
        $redCastleR = 0;
    }
    if ($greenCastleK && ($to_bb | $fr_bb) & $greenCastleK) {
        $greenCastleK = 0;
    }
    if ($greenCastleR && ($to_bb | $fr_bb) & $greenCastleK) {
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
    my $bin = Math::BigInt->new($BB);
    my $bin = $bin->as_bin();
    $bin =~ s/^0b//;
    $bin = sprintf('%0144s', $bin);
    while ($bin =~ m/.{12}/g) {
        print "$&\n";
    }
    $board .= "\n   +---+---+---+---+---+---+---+---+---+---+---+---\n";
    foreach my $r ( 11 .. 0 ) {
        foreach my $f ( 0 .. 11 ) {
            if ($f eq 0){ $board .= sprintf('%2s | ', $r); }
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

1;
