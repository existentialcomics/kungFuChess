#!/usr/bin/perl
#
use strict; use warnings;

use Cwd qw( abs_path );
use File::Basename qw( dirname );
use lib dirname(abs_path($0));

use KungFuChess::Bitboards;

KungFuChess::Bitboards::setupInitialPosition();

print KungFuChess::Bitboards::pretty();

my $go = 1;
while ($go) {
    my $input = <STDIN>;
    chomp($input);

    if ($input =~ m/^[a-z][0-9][a-z][0-9]$/) {
        if (KungFuChess::Bitboards::isLegalMove($input)) {
            print KungFuChess::Bitboards::move($input);
        } else {
            print "  $input not legal\n";

        }
        print "\n\n";
        print KungFuChess::Bitboards::pretty();
    }
    if ($input eq 'q') {
        $go = 0;
    }
}
