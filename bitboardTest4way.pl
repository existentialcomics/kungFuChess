#!/usr/bin/perl
#
use strict; use warnings;

use Cwd qw( abs_path );
use File::Basename qw( dirname );
use lib dirname(abs_path($0));

use KungFuChess::Bitboards4way;

#KungFuChess::Bitboards::setupInitialPosition();

#print KungFuChess::Bitboards::pretty();
#print KungFuChess::Bitboards::printAllBitboards();
print KungFuChess::Bitboards::prettyBoardTest();
print KungFuChess::Bitboards::pretty();

my ($fr_bb, $to_bb, $fr_rank, $fr_file, $to_rank, $to_file) = 
KungFuChess::Bitboards::parseMove('g1c1');

print "to_bb:  $to_bb\n";
    my $putBB = KungFuChess::Bitboards::shift_BB($to_bb, KungFuChess::Bitboards::WEST);
print "put_bb: $putBB\n";

my $ret   = KungFuChess::Bitboards::_putPiece(101, $putBB);
my $ret   = KungFuChess::Bitboards::_putPiece(102, $to_bb);
print "done put\n";
print KungFuChess::Bitboards::prettyBoardTest();
print KungFuChess::Bitboards::pretty();

my $go = 1;
while ($go) {
    my $input = <STDIN>;
    chomp($input);

    if ($input =~ m/^[a-z][0-9][a-z][0-9]$/) {
        my ($color, $move, $dir, $fr_bb, $to_bb)
            = KungFuChess::Bitboards::isLegalMove(
                KungFuChess::Bitboards::parseMove($input));
        if ($move != 0) { # MOVE_NONE
            KungFuChess::Bitboards::move($fr_bb, $to_bb);
            print KungFuChess::Bitboards::pretty();
        } else {
            print "  $input not legal\n";
        }
    }
    if ($input eq 'q') {
        $go = 0;
    }
}
