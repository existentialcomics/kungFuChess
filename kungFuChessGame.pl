#!/usr/bin/perl
use strict; use warnings;

use KungFuChess::GameServer;

my $gameKey = shift;
my $authKey = shift;
my $speed = shift;
my $isAI = shift;

print "init game..\n";
my $kfc = KungFuChess::GameServer->new($gameKey, $authKey, $speed, $isAI);
