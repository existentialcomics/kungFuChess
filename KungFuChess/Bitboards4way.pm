#!/usr/bin/perl

use strict;
#use warnings;

### same package name as Bitboards so the server doesn't have to know which it is using
package KungFuChess::Bitboards;
use Math::BigInt;
use base 'Exporter';

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
    #### white ####
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

    #### red ####
    # rook 1
    $occupied |= (FILES->{a} & RANKS->{10});
    $rooks    |= (FILES->{a} & RANKS->{10});
    $red      |= (FILES->{a} & RANKS->{10});
    # pawn 
    $occupied |= (FILES->{b} & RANKS->{10});
    $pawns    |= (FILES->{b} & RANKS->{10});
    $red      |= (FILES->{b} & RANKS->{10});
        
    # knight 1
    $occupied |= (FILES->{a} & RANKS->{9});
    $knights  |= (FILES->{a} & RANKS->{9});
    $red      |= (FILES->{a} & RANKS->{9});
    # pawn 
    $occupied |= (FILES->{b} & RANKS->{9});
    $pawns    |= (FILES->{b} & RANKS->{9});
    $red      |= (FILES->{b} & RANKS->{9});
        
    # bishop 1
    $occupied |= (FILES->{a} & RANKS->{8});
    $bishops  |= (FILES->{a} & RANKS->{8});
    $red      |= (FILES->{a} & RANKS->{8});
    # pawn 
    $occupied |= (FILES->{b} & RANKS->{8});
    $pawns    |= (FILES->{b} & RANKS->{8});
    $red      |= (FILES->{b} & RANKS->{8});
        
    # queen
    $occupied |= (FILES->{a} & RANKS->{7});
    $queens   |= (FILES->{a} & RANKS->{7});
    $red      |= (FILES->{a} & RANKS->{7});
    # pawn 
    $occupied |= (FILES->{b} & RANKS->{7});
    $pawns    |= (FILES->{b} & RANKS->{7});
    $red      |= (FILES->{b} & RANKS->{7});
        
    # king
    $occupied |= (FILES->{a} & RANKS->{6});
    $kings    |= (FILES->{a} & RANKS->{6});
    $red      |= (FILES->{a} & RANKS->{6});
    # pawn 
    $occupied |= (FILES->{b} & RANKS->{6});
    $pawns    |= (FILES->{b} & RANKS->{6});
    $red      |= (FILES->{b} & RANKS->{6});
        
    # bishop2
    $occupied |= (FILES->{a} & RANKS->{5});
    $bishops  |= (FILES->{a} & RANKS->{5});
    $red      |= (FILES->{a} & RANKS->{5});
    # pawn 
    $occupied |= (FILES->{b} & RANKS->{5});
    $pawns    |= (FILES->{b} & RANKS->{5});
    $red      |= (FILES->{b} & RANKS->{5});
        
    # knight2
    $occupied |= (FILES->{a} & RANKS->{4});
    $knights  |= (FILES->{a} & RANKS->{4});
    $red      |= (FILES->{a} & RANKS->{4});
    # pawn 
    $occupied |= (FILES->{b} & RANKS->{4});
    $pawns    |= (FILES->{b} & RANKS->{4});
    $red      |= (FILES->{b} & RANKS->{4});
        
    # rook2
    $occupied |= (FILES->{a} & RANKS->{3});
    $rooks    |= (FILES->{a} & RANKS->{3});
    $red      |= (FILES->{a} & RANKS->{3});
    # pawn 
    $occupied |= (FILES->{b} & RANKS->{3});
    $pawns    |= (FILES->{b} & RANKS->{3});
    $red      |= (FILES->{b} & RANKS->{3});

    #### green ####
    # rook 1
    $occupied |= (FILES->{l} & RANKS->{10});
    $rooks    |= (FILES->{l} & RANKS->{10});
    $green    |= (FILES->{l} & RANKS->{10});
    # pawn 
    $occupied |= (FILES->{k} & RANKS->{10});
    $pawns    |= (FILES->{k} & RANKS->{10});
    $green    |= (FILES->{k} & RANKS->{10});
        
    # knight 1
    $occupied |= (FILES->{l} & RANKS->{9});
    $knights  |= (FILES->{l} & RANKS->{9});
    $green    |= (FILES->{l} & RANKS->{9});
    # pawn 
    $occupied |= (FILES->{k} & RANKS->{9});
    $pawns    |= (FILES->{k} & RANKS->{9});
    $green    |= (FILES->{k} & RANKS->{9});
        
    # bishop 1
    $occupied |= (FILES->{l} & RANKS->{8});
    $bishops  |= (FILES->{l} & RANKS->{8});
    $green    |= (FILES->{l} & RANKS->{8});
    # pawn 
    $occupied |= (FILES->{k} & RANKS->{8});
    $pawns    |= (FILES->{k} & RANKS->{8});
    $green    |= (FILES->{k} & RANKS->{8});
        
    # queen
    $occupied |= (FILES->{l} & RANKS->{7});
    $queens   |= (FILES->{l} & RANKS->{7});
    $green    |= (FILES->{l} & RANKS->{7});
    # pawn 
    $occupied |= (FILES->{k} & RANKS->{7});
    $pawns    |= (FILES->{k} & RANKS->{7});
    $green    |= (FILES->{k} & RANKS->{7});
        
    # king
    $occupied |= (FILES->{l} & RANKS->{6});
    $kings    |= (FILES->{l} & RANKS->{6});
    $green    |= (FILES->{l} & RANKS->{6});
    # pawn 
    $occupied |= (FILES->{k} & RANKS->{6});
    $pawns    |= (FILES->{k} & RANKS->{6});
    $green    |= (FILES->{k} & RANKS->{6});
        
    # bishop2
    $occupied |= (FILES->{l} & RANKS->{5});
    $bishops  |= (FILES->{l} & RANKS->{5});
    $green    |= (FILES->{l} & RANKS->{5});
    # pawn 
    $occupied |= (FILES->{k} & RANKS->{5});
    $pawns    |= (FILES->{k} & RANKS->{5});
    $green    |= (FILES->{k} & RANKS->{5});
        
    # knight2
    $occupied |= (FILES->{l} & RANKS->{4});
    $knights  |= (FILES->{l} & RANKS->{4});
    $green    |= (FILES->{l} & RANKS->{4});
    # pawn 
    $occupied |= (FILES->{k} & RANKS->{4});
    $pawns    |= (FILES->{k} & RANKS->{4});
    $green    |= (FILES->{k} & RANKS->{4});
        
    # rook2
    $occupied |= (FILES->{l} & RANKS->{3});
    $rooks    |= (FILES->{l} & RANKS->{3});
    $green    |= (FILES->{l} & RANKS->{3});
    # pawn 
    $occupied |= (FILES->{k} & RANKS->{3});
    $pawns    |= (FILES->{k} & RANKS->{3});
    $green    |= (FILES->{k} & RANKS->{3});
}

### copied from shift function in Stockfish
sub shift_BB {
    my ($bb, $direction) = @_;
    return  $direction == NORTH      ?  $bb                <<12 : $direction == SOUTH      ?  $bb                >>12
          : $direction == NORTH+NORTH?  $bb                <<24 : $direction == SOUTH+SOUTH?  $bb                >>24
          : $direction == EAST       ? ($bb & ~FILES->{a}) << 1 : $direction == WEST       ? ($bb & ~FILES->{l}) >> 1
          : $direction == NORTH_EAST ? ($bb & ~FILES->{a}) <<13 : $direction == NORTH_WEST ? ($bb & ~FILES->{l}) <<11
          : $direction == SOUTH_EAST ? ($bb & ~FILES->{a}) >>11 : $direction == SOUTH_WEST ? ($bb & ~FILES->{l}) >>13
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
            if ($fromBB == 0)           { return 0; } ### of the board
            if ($fromBB >  MAX_BITBOARD){ return 0; } ### of the board
            if ($fromBB & $blockingBB)  { return 0; }
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
    my $fr_bb = Math::BigInt->new($fr_rank & $fr_file);
    my $to_bb = Math::BigInt->new($to_rank & $to_file);

    my $checkBlockers = 0;

    my @noMove = (NO_COLOR, MOVE_NONE, DIR_NONE, $fr_bb, $to_bb);

    if (! ($occupied & $fr_bb) ) {
        #print "from not occupied\n";
        return @noMove;
    }
    my $color   = ($white & $fr_bb ? WHITE : $black & BLACK);
    my $pawnDir = ($white & $fr_bb ? NORTH : SOUTH);

    my $color, $pawnDir;
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
    if (blockers(_piecesUs($color), $dir, $fr_bb, $to_bb) ){
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

### returns 1 for normal, 0 for killed
sub move {
    my ($fr_bb, $to_bb) = @_;

    if (! ($fr_bb & $occupied)) {
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
    if ($piece > 200) {
        $color =  "\033[31m";
    }
    if ($piece > 300) {
        $color =  "\033[32m";
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
    $board .= "\n   +---+---+---+---+---+---+---+---+---+---+---+---+\n";
    foreach my $r ( qw(12 11 10 9 8 7 6 5 4 3 2 1) ) {
        foreach my $f ( 'a' .. 'l' ) {
            if ($f eq 'a'){ $board .= sprintf('%2s | ', $r); }
            my $chr = getPieceDisplay(_getPiece($f, $r));
            $board .= "$chr | ";
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
    #my $bb = RANKS->{'1'};
    my $bb = RANKS->{'1'} & FILES->{'c'};
    #my $bb = RANKS->{'2'} | FILES->{'c'};
    my $str = prettyBoard($bb);
    my $bb2 = shift_BB($bb, NORTH);
    $str .= prettyBoard($bb2);
    return $str;
}
sub printAllBitboards {
    my $BB = shift;
    foreach my $r ( qw(12 11 10 9 8 7 6 5 4 3 2 1) ) {
        foreach my $f ( 'a' .. 'l' ) {
            my $rf = RANKS->{$r} & FILES->{$f};
            print "   '$rf' : '$f$r',\n";
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
