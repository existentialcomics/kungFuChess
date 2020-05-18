#!/usr/bin/perl
#
use strict; use warnings;

use Cwd qw( abs_path );
use File::Basename qw( dirname );
use lib dirname(abs_path($0));

use KungFuChess::Bitboards;

KungFuChess::Bitboards::setupInitialPosition();

print KungFuChess::Bitboards::pretty();

    foreach my $r ( qw(8 7 6 5 4 3 2 1) ) {
        foreach my $f ( 'a' .. 'h' ) {
            my $bb = KungFuChess::Bitboards::_getBBat($f . $r);
            print "    '$bb' : '$f$r',\n";
        }
    }

