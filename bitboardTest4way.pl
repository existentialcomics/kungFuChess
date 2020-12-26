#!/usr/bin/perl
#
use strict; use warnings;

use Cwd qw( abs_path );
use File::Basename qw( dirname );
use lib dirname(abs_path($0));

use KungFuChess::Bitboards4way;

KungFuChess::Bitboards4way::setupInitialPosition();

print KungFuChess::Bitboards4way::pretty();
#print KungFuChess::Bitboards4way::prettyBoardTest();

my $go = 1;
while ($go) {
    my $input = <STDIN>;
    chomp($input);

    if ($input =~ m/^[a-z][0-9][a-z][0-9]$/) {
        my ($color, $move, $dir, $fr_bb, $to_bb)
            = KungFuChess::Bitboards4way::isLegalMove($input);
        if ($move != 0) { # MOVE_NONE
            KungFuChess::Bitboards4way::move($fr_bb, $to_bb);
            print KungFuChess::Bitboards4way::pretty();
        } else {
            print "  $input not legal\n";
        }
    }
    if ($input eq 'q') {
        $go = 0;
    }
}
