#!/usr/bin/perl
use strict; use warnings;

use KungFuChess;

my $gameKey = shift;
my $authKey = shift;
my $speed = shift;

print "init game..\n";
my $kfc = KungFuChess->new($gameKey, $authKey, $speed);
