### hardcoded translation of BB squares to board squares

use strict; use warnings;
package KungFuChess::BBHash;
use Data::Dumper;

our %bitboardToSquare = (
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
);
use constant ({
    ### array of a move for AI
    MOVE_FR         => 0,
    MOVE_TO         => 1,
    MOVE_SCORE      => 2,
    MOVE_DISTANCE   => 3, 
    MOVE_NEXT_MOVES => 4,
    MOVE_ATTACKS    => 5,
});

sub getSquareFromBB {
    return $bitboardToSquare{$_[0]};
}

sub displayBestMoves {
    my $bestMoves = shift;
    my $color = shift;
    my $score = shift;
    my $ponder = shift;
    my $indent = shift;
    my $filter = shift;

    foreach my $bmove (@{$bestMoves}[$color]) {
        foreach my $move (@$bmove) {
            my ($fr_bb, $to_bb) = split('-', $move);
            print getSquareFromBB($fr_bb);
            print getSquareFromBB($to_bb);
            print "\n";
        }
    }
}

### raw moves no color passed in
sub displayMovesArray {
    my $suggestedMoves = shift;
    foreach my $move (@$suggestedMoves) {
        print getSquareFromBB($move->[MOVE_FR]) . getSquareFromBB($move->[MOVE_TO]);
        print ", scr: " . $move->[MOVE_SCORE] . "\n";
    }

    #foreach my $move (@$moves) {
        ##print Dumper($move);
        ##exit;
        #print ref $move;
        #print " $#$move\n";
        #print "$moves->[0]->[0]\n";
        #print "$moves->[1]\n";
        #print getSquareFromBB($moves->[0]) . getSquareFromBB($moves->[1]);
        #print "\n";

    #}
}

# 0 = fr_bb
# 1 = to_bb
# 2 = piece
# 3 = piece_type
# 4 = score
# 5 = child moves
sub displayMoves {
    my $moves = shift;
    my $color = shift;
    my $score = shift;
    my $ponder = shift;
    my $indent = shift;
    my $filter = shift;
    my $depth = shift // 0;
    $ponder = $ponder ? $ponder : '';
    $indent = $indent ? $indent : '';

    foreach my $move (@{$moves->[$color]}) {
        #print $k;
        my $moveS = getSquareFromBB($move->[MOVE_FR]) . getSquareFromBB($move->[MOVE_TO]);
        if (! $filter || ($moveS =~ m/^$filter/)) {
            print $indent;
            print $moveS;
            my $mScore = $move->[MOVE_SCORE];
            if ($mScore) {
                print ($mScore > $score ? " * " : "   ") ;
                print  $mScore;
            } else {
                print " NA ";
            }
            print "\n";
            if (($moveS eq $ponder) || $ponder eq 'all') {
                displayMoves(
                    $move->[MOVE_NEXT_MOVES],
                    #$color == 2 ? ($depth % 2 ? 1 : 2) : ($depth % 2 ? 2 : 1),
                    $color == 2 ? (0 ? 1 : 2) : (0 ? 2 : 1),
                    $mScore,
                    #$depth < 10 ? 'all' : '',
                    'all',
                    ' x ' x ($depth + 2),
                    $filter,
                    $depth+1
                );
            }
            if (($move eq $ponder) || $ponder eq 'all') {
                displayMoves(
                    $move->[MOVE_NEXT_MOVES],
                    $color,
                    $mScore,
                    '',
                    '   '
                );
            }
        }
        #last;
    }
}

1;
