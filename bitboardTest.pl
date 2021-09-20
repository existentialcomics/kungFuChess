#!/usr/bin/perl
#
use strict; use warnings;

use Cwd qw( abs_path );
use File::Basename qw( dirname );
use Time::HiRes qw(utime time);
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
        #my ($color, $move, $dir, $fr_bb, $to_bb)
            #= KungFuChess::Bitboards::isLegalMove(
                #KungFuChess::Bitboards::parseMove($input)
            #);
        #if ($move != 0) { # MOVE_NONE
            #print KungFuChess::Bitboards::do_move_ai($fr_bb, $to_bb);
            #KungFuChess::Bitboards::clearAiFrozen();
        #} else {
            #print "  $input not legal\n";
        #}
        my ($fr_bb, $to_bb, $fr_rank, $fr_file, $to_rank, $to_file) = KungFuChess::Bitboards::parseMove($input);
        print KungFuChess::Bitboards::move($fr_bb, $to_bb);
        print "\n\n";
        print KungFuChess::Bitboards::pretty_ai();
        #my @moves = KungFuChess::Bitboards::evaluate();
        #my ($score, $moves) = KungFuChess::Bitboards::evaluate();
        #print "score: $score\n";
        #print "moves:\n";
        #print Dumper(@moves);
    } elsif ($input =~ m/^eval$/) {
        print KungFuChess::Bitboards::pretty_ai();
        my ($eval, $moves) = KungFuChess::Bitboards::evaluate(1);
        print "eval: $eval\n";
    } elsif ($input =~ m/^think (\d+) ([\d\.]+)$/) {
        my $time = $1;
        my $depth = $2;
        my $start = time();
        print KungFuChess::Bitboards::pretty_ai();
        my $moves = KungFuChess::Bitboards::aiThink($depth, $time);
        my $suggestedMoves = KungFuChess::Bitboards::aiRecommendMoves(2);

        KungFuChess::BBHash::displayMoves($moves, 2, $score, undef, undef, undef);
        print "eval: $eval\n";
        print "time elapsed: " . (time() - $start) . "\n";
    } elsif ($input =~ m/^ponder (white|black)\s?(\S+)?\s?(\S+?)$/) {
        my $cIn = $1;
        my $ponder = $2;
        my $filter = $3;
        my $mycolor = ($cIn =~ 'white' ? 1 : 2);
        my ($color, $move, $dir, $fr_bb, $to_bb);
        ($color, $move, $dir, $fr_bb, $to_bb) = KungFuChess::Bitboards::isLegalMove(
            KungFuChess::Bitboards::parseMove($ponder)
        );
        if ($move != 0) { # MOVE_NONE
            KungFuChess::Bitboards::do_move_ai($fr_bb, $to_bb);
        } else {
            print "  $input not legal\n";
        }
        ($score, $bestMoves, $moves) = 
            KungFuChess::Bitboards::aiThink(2, 1.5);

        if ($move != 0) { # MOVE_NONE
            KungFuChess::Bitboards::undo_move_ai($fr_bb, $to_bb);
        }

        print "displayMoves\n";
        KungFuChess::BBHash::displayMoves($moves, $mycolor, $score, $ponder, undef, $filter);
        print "---- best moves ----\n";
        KungFuChess::BBHash::displayBestMoves($bestMoves, $mycolor, $score, $ponder, undef, $filter);
    } elsif ($input =~ m/^moves (white|black)$/) {
        my $cIn = $1;
        my $color = ($cIn =~ 'white' ? 1 : 2);
        KungFuChess::Bitboards::aiRecommendMoves($color);
    } elsif ($input =~ m/^eval (white|black)\s?(\S+)?(?:\s(\S+?))?$/) {
        my $cIn = $1;
        my $ponder = $2;
        my $filter = $3;
        my $mycolor = ($cIn =~ 'white' ? 1 : 2);
        my ($color, $move, $dir, $fr_bb, $to_bb);
        ($score, $bestMoves, $moves) = 
            KungFuChess::Bitboards::aiThink(2, 1.5, 1);

        print "eval $cIn\n";
        print "displayMoves\n";
        print "PONDER: $ponder\n";
        print "FILTER: $filter\n";
        KungFuChess::BBHash::displayMoves($moves, $mycolor, $score, $ponder, undef, $filter);
        KungFuChess::BBHash::displayBestMoves($bestMoves, $mycolor, $score, $ponder, undef, $filter);
    } elsif ($input =~ m/^show (white|black)\s?(\S+)?$/) {
        my $cIn = $1;
        my $ponder = $2;
        my $filter = undef;
        my $mycolor = ($cIn =~ 'white' ? 1 : 2);

        my $moves = KungFuChess::Bitboards::getCurrentMoves($mycolor);
        KungFuChess::BBHash::displayMoves($moves, $mycolor, $score, $ponder, undef, $filter);
    }
    if ($input eq 'q') {
        $go = 0;
    }
}
