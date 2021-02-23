#!/usr/bin/perl
use strict; use warnings;

my $gameKey = shift;
my $authKey = shift;
my $speed = shift;
my $isAI = shift;

use Cwd qw( abs_path );
use File::Basename qw( dirname );
use lib dirname(abs_path($0));

use KungFuChess::Bitboards;
use KungFuChess::GameAi;

print "init game ai... ($gameKey, $authKey, $speed, $isAI)\n";
my $kfcAi = KungFuChess::GameAi->new($gameKey, $authKey, $speed, '2way', 1);
