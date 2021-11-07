#!/usr/bin/perl
use strict; use warnings;

my $gameKey = shift;
my $authKey = shift;
my $speed = shift;
my $speedAdj = shift;
my $isAI = shift;

use Cwd qw( abs_path );
use File::Basename qw( dirname );
use lib dirname(abs_path($0));

use KungFuChess::Bitboards4way;
use KungFuChess::GameServer;

print "init game... ($gameKey, $authKey, $speed, 4way, $isAI)\n";
my $kfc = KungFuChess::GameServer->new($gameKey, $authKey, $speed, $speedAdj, '4way', $isAI);
