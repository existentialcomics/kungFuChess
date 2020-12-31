#!/usr/bin/perl

use Test::More;
use strict;
use warnings;

#BEGIN { use_ok('KungFuChess::Bitboards4way', qw(MOVE_NONE MOVE_NORMAL MOVE_PROMOTE MOVE_EN_PASSANT MOVE_CASTLE_OO MOVE_CASTLE_OOO MOVE_KNIGHT WHITE_PAWN WHITE_KNIGHT WHITE_ROOK WHITE_BISHOP WHITE_KING WHITE_QUEEN BLACK_PAWN BLACK_KNIGHT BLACK_ROOK BLACK_BISHOP BLACK_KING BLACK_QUEEN)) }

BEGIN {
    require_ok "KungFuChess::Bitboards4way";
    KungFuChess::Bitboards->import(qw(MOVE_NONE MOVE_NORMAL MOVE_PROMOTE MOVE_EN_PASSANT MOVE_CASTLE_OO MOVE_CASTLE_OOO MOVE_KNIGHT WHITE_PAWN WHITE_KNIGHT WHITE_ROOK WHITE_BISHOP WHITE_KING WHITE_QUEEN BLACK_PAWN BLACK_KNIGHT BLACK_ROOK BLACK_BISHOP BLACK_KING BLACK_QUEEN));
}

#KungFuChess::Bitboards::setupInitialPosition();

### ROOK
testPutPiece(WHITE_ROOK, 'a', '5');
testMoveOk('a5a6', MOVE_NORMAL);
testMoveOk('a6h6', MOVE_NORMAL);
testMoveOk('h6h1', MOVE_NORMAL);
testMoveOk('h1e2', MOVE_NONE);
testMoveOk('h1h8', MOVE_NORMAL);
testMoveOk('h8a8', MOVE_NORMAL);
testMoveOk('a8b7', MOVE_NONE);
testRemovePiece('a', '8');

#### KNIGHT
testPutPiece(WHITE_KNIGHT, 'd', '4');
testMoveOk('d4e6', MOVE_KNIGHT);
testMoveOk('e6c7', MOVE_KNIGHT);
testMoveOk('c7c5', MOVE_NONE);
testMoveOk('c7d5', MOVE_KNIGHT);
testMoveOk('d5c7', MOVE_KNIGHT);
testMoveOk('c7b7', MOVE_NONE);
testMoveOk('c7b5', MOVE_KNIGHT);
testMoveOk('b5a3', MOVE_KNIGHT);
testRemovePiece('a', '3');

#### BISHOP
testPutPiece(WHITE_BISHOP, 'a', '1');
testMoveOk('a1c3', MOVE_NORMAL);
testMoveOk('c3e1', MOVE_NORMAL);
testMoveOk('e1d3', MOVE_NONE);
testMoveOk('e1d2', MOVE_NORMAL);
testMoveOk('d2b4', MOVE_NORMAL);
testMoveOk('b4a3', MOVE_NORMAL);
testMoveOk('a3b3', MOVE_NONE);
testMoveOk('a3c1', MOVE_NORMAL);
testRemovePiece('c', '1');

#### QUEEN
testPutPiece(WHITE_QUEEN, 'a', '1');
## queen bishop moves
testMoveOk('a1c3', MOVE_NORMAL);
testMoveOk('c3e1', MOVE_NORMAL);
testMoveOk('e1d3', MOVE_NONE);
testMoveOk('e1d2', MOVE_NORMAL);
testMoveOk('d2b4', MOVE_NORMAL);
testMoveOk('b4a3', MOVE_NORMAL);
#my $bb = KungFuChess::Bitboards::_getBBat('a', '3');
#$bb = KungFuChess::Bitboards::shift_BB($bb, 11);
#diag( KungFuChess::Bitboards::prettyBoard($bb) );
testMoveOk('a3b5', MOVE_NONE);
diag( KungFuChess::Bitboards::pretty() );
testMoveOk('a3c3', MOVE_NORMAL);
testMoveOk('c3a5', MOVE_NORMAL);

## queen rook moves
testMoveOk('a5a6', MOVE_NORMAL);
testMoveOk('a6h6', MOVE_NORMAL);
testMoveOk('h6h1', MOVE_NORMAL);
testMoveOk('h1e2', MOVE_NONE);
testMoveOk('h1h8', MOVE_NORMAL);
testMoveOk('h8a8', MOVE_NORMAL);
testMoveOk('a8b5', MOVE_NONE);
testRemovePiece('a', '8');

#### KING
testPutPiece(WHITE_KING, 'c', '4');
testMoveOk('c4d5', MOVE_NORMAL);
testMoveOk('d5c4', MOVE_NORMAL);
testMoveOk('c4c5', MOVE_NORMAL);
testMoveOk('c5c4', MOVE_NORMAL);
testMoveOk('c4b5', MOVE_NORMAL);
testMoveOk('b5c4', MOVE_NORMAL);
testMoveOk('c4b4', MOVE_NORMAL);
testMoveOk('b4c4', MOVE_NORMAL);
testMoveOk('c4b3', MOVE_NORMAL);
testMoveOk('b3c4', MOVE_NORMAL);
testMoveOk('c4b4', MOVE_NORMAL);
testMoveOk('b4c4', MOVE_NORMAL);
testMoveOk('c4b4', MOVE_NORMAL);
testMoveOk('b4c4', MOVE_NORMAL);
testMoveOk('c4b5', MOVE_NORMAL);
testMoveOk('b5c4', MOVE_NORMAL);
testMoveOk('c4b6', MOVE_NONE);
testMoveOk('c4b1', MOVE_NONE);
testMoveOk('c4c1', MOVE_NONE);
testRemovePiece('c', '4');

#### PAWN
testPutPiece(WHITE_PAWN, 'c', '2');
testPutPiece(WHITE_PAWN, 'e', '2');
testPutPiece(BLACK_PAWN, 'c', '7');
testPutPiece(BLACK_PAWN, 'd', '7');
testMoveOk('c2b3', MOVE_NONE);
testMoveOk('e7f6', MOVE_NONE);
testMoveOk('e2e6', MOVE_NONE);
# wrong way
testMoveOk('c2c1', MOVE_NONE);
testMoveOk('d7d8', MOVE_NONE);

testMoveOk('c2c4', MOVE_NORMAL);
testMoveOk('d7d5', MOVE_NORMAL);
# capture
testMoveOk('c4d5', MOVE_NORMAL);
testMoveOk('c7c6', MOVE_NORMAL);
# capture black
testMoveOk('c6d5', MOVE_NORMAL);
# move to promote both 
testMoveOk('d5d4', MOVE_NORMAL);
testMoveOk('d4d3', MOVE_NORMAL);
testMoveOk('d3d2', MOVE_NORMAL);
testMoveOk('d2d1', MOVE_PROMOTE);

testMoveOk('e2e4', MOVE_NORMAL);
testMoveOk('e4e5', MOVE_NORMAL);
testMoveOk('e5e6', MOVE_NORMAL);
testMoveOk('e6e7', MOVE_NORMAL);
testMoveOk('e7e8', MOVE_PROMOTE);

testRemovePiece('e', '8');
testRemovePiece('d', '1');

#diag( KungFuChess::Bitboards4way::pretty() );

sub testMoveOk {
    my $move = shift;
    my $expect = shift;
    my ($color, $moveType, $dir, $fr_bb, $to_bb) = KungFuChess::Bitboards::isLegalMove($move);
    #diag("move $move: $color, $moveType, $dir, $fr_bb, $to_bb");
    ok(defined($moveType)) or diag("undefined moveType for $move");
    ok($moveType == $expect) or diag("$moveType != $expect isLegalMove() $move");
    if ($expect == MOVE_NONE){ return 1; }

    my ($r1, $f1, $r2, $f2);
    if ($move =~ m/^([a-z])([0-9]{1,2})([a-z])([0-9]{1,2})$/) {
        ($r1, $f1, $r2, $f2) = ($1, $2, $3, $4);
    } else {
        ok(1 == 2) or diag("bad move $move");
    }
    my $bb_fr = KungFuChess::Bitboards::_getBBat($r1, $f1);
    my $bb_to = KungFuChess::Bitboards::_getBBat($r2, $f2);
    my $p     = KungFuChess::Bitboards::_getPieceBB($bb_fr);
    ok(defined($p), 'From piece empty on move test');
    KungFuChess::Bitboards::move($bb_fr, $bb_to);
    testPieceAtBB(undef, $bb_fr);
    testPieceAtBB($p, $bb_to);
}

sub testPieceAtBB {
    my ($p, $bb) = @_;
    my $p_at  = KungFuChess::Bitboards::_getPieceBB($bb);
    return is($p_at, $p, "piece at bb is what we expect");
}

sub testPutPiece {
    my ($p, $r, $f) = @_;
    my $bb = KungFuChess::Bitboards::_getBBat($r, $f);
    KungFuChess::Bitboards::_putPiece($p, $bb);
    my $getPiece   = KungFuChess::Bitboards::_getPiece($r, $f);
    my $getPieceBB = KungFuChess::Bitboards::_getPieceBB($bb);
    is($p, $getPiece, "put piece $p at $r$f eq $getPiece");
    is($p, $getPieceBB, "put piece $p at $r$f eq $getPieceBB");
}

sub testRemovePiece {
    my ($r, $f) = @_;
    my $bb = KungFuChess::Bitboards::_getBBat($r, $f);
    KungFuChess::Bitboards::_removePiece($bb);
    my $getPiece   = KungFuChess::Bitboards::_getPiece($r, $f);
    my $getPieceBB = KungFuChess::Bitboards::_getPieceBB($bb);
    is($getPiece, undef, "getPiece is undef");
    is($getPieceBB, undef, "getPieceBB is undef");
}

done_testing();
