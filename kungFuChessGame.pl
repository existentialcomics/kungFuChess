#!/usr/bin/perl
use strict; use warnings;

use KungFuChess;

my $gameKey = shift;
my $authKey = shift;

print "init game..\n";
my $kfc = KungFuChess->new($gameKey, $authKey);
