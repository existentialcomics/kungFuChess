#!/usr/bin/perl
#
use strict; use warnings;

use Cwd qw( abs_path );
use File::Basename qw( dirname );
use lib dirname(abs_path($0));
use Data::Dumper;

use KungFuChess::Bitboards;
use KungFuChess::BBHash;

KungFuChess::Bitboards::setupInitialPosition();
#print KungFuChess::Bitboards::debug();

#print KungFuChess::Bitboards::pretty();
print KungFuChess::Bitboards::pretty_ai();
#my ($score, $moves) = KungFuChess::Bitboards::evaluate();
#KungFuChess::Bitboards::aiThink(0.5, 1);
my ($score, $bestMoves, $moves) = (0.0, [], []);

my $go = 1;
while ($go) {
    print "enter move or white/black (for ai)\n";
    my $input = <STDIN>;
    chomp($input);

    if ($input =~ m/^[a-z][0-9][a-z][0-9]$/) {
        my ($color, $move, $dir, $fr_bb, $to_bb)
            = KungFuChess::Bitboards::isLegalMove(
                KungFuChess::Bitboards::parseMove($input)
            );
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
    } elsif ($input =~ m/^eval$/) {
        my ($eval, $moves) = KungFuChess::Bitboards::evaluate();
        print "eval: $eval\n";
    } elsif ($input =~ m/^eval (white|black)\s?(.*?)?$/) {
        my $cIn = $1;
        my $ponder = $2;
        print "PONDER: $ponder\n";
        my $color = ($cIn =~ 'white' ? 1 : 2);
        ($score, $bestMoves, $moves) = 
            KungFuChess::Bitboards::aiThink(2, 0.5);
        print "score: $score\n";
        print Dumper($bestMoves);
        KungFuChess::BBHash::displayMoves($moves, $color, $score, $ponder);
    } elsif ($input =~ m/^white|black$/) {
        my $color = ($input =~ 'white' ? 1 : 2);
        print "thinking $input $color...\n";

        ($score, $bestMoves, $moves) = 
            KungFuChess::Bitboards::aiThinkAndMove(2, 0.5, $color);
        print "score: $score\n";
        print KungFuChess::Bitboards::pretty_ai();
    }
    if ($input eq 'q') {
        $go = 0;
    }
}
