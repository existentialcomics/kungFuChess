#!/usr/bin/perl
use strict; use warnings;

use IPC::Open2;
$| = 1;

my($cout, $cin);
my $pid = open2($cout, $cin, '/home/corey/stockfish-11-linux/Linux/stockfish_20011801_x64 | tee ~/stockfish.out');
$cout->blocking(0);

getStockfishMsgs($cout);
print $cin "uci\n";
sleep(10);
getStockfishMsgs($cout);
getStockfishMsgs($cout);
getStockfishMsgs($cout);
getStockfishMsgs($cout);
getStockfishMsgs($cout);
getStockfishMsgs($cout);

sub getStockfishMsgs {
    my $cout = shift;

    print "--- begin reading...\n";
    my $timeout = 0;
    while(my $line = <$cout>) {
        print "$line";
    }
    print "--- end reading\n";
}
