#!/usr/bin/perl
use strict; use warnings;

my $gameKey = shift;
my $authKey = shift;
my $speed = shift;
my $difficulty = shift;

use Cwd qw( abs_path );
use File::Basename qw( dirname );
use lib dirname(abs_path($0));

use KungFuChess::Bitboards;
use KungFuChess::GameAi;

print "init game ai... ($gameKey, $authKey, $speed, $difficulty)\n";
my $kfcAi = KungFuChess::GameAi->new($gameKey, $authKey, $speed, '2way', $difficulty);
