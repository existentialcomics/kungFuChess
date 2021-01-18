#!/usr/bin/perl
#
use strict; use warnings;

use Cwd qw( abs_path );
use File::Basename qw( dirname );
use lib dirname(abs_path($0));
use Data::Dumper;

use KungFuChess::Bitboards;

KungFuChess::Bitboards::setupInitialPosition();
#print KungFuChess::Bitboards::debug();

#print KungFuChess::Bitboards::pretty();
print KungFuChess::Bitboards::pretty_ai();
#my ($score, $moves) = KungFuChess::Bitboards::evaluate();
#KungFuChess::Bitboards::aiThink(0.5, 1);

my $go = 1;
while ($go) {
    print "enter move or white/black (for ai)\n";
    my $input = <STDIN>;
    chomp($input);

    if ($input =~ m/^[a-z][0-9][a-z][0-9]$/) {
        my ($color, $move, $dir, $fr_bb, $to_bb)
            = KungFuChess::Bitboards::isLegalMove($input);
        if ($move != 0) { # MOVE_NONE
            print KungFuChess::Bitboards::do_move_ai($fr_bb, $to_bb);
        } else {
            print "  $input not legal\n";
        }
        print "\n\n";
        print KungFuChess::Bitboards::pretty_ai();
        #my @moves = KungFuChess::Bitboards::evaluate();
        #my ($score, $moves) = KungFuChess::Bitboards::evaluate();
        #print "score: $score\n";
        #print "moves:\n";
        #print Dumper(@moves);
    } elsif ($input =~ m/^white|black$/) {
        my $bestMoves = KungFuChess::Bitboards::aiThink(1);
        if ($input eq 'white') {
            foreach my $move (@{ $bestMoves->[1] }) {


            }
        } else {

        }

    }
    if ($input eq 'q') {
        $go = 0;
    }
}
