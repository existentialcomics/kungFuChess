#!/usr/bin/perl
use strict; use warnings;

my $gameKey = shift;
my $authKey = shift;
my $pieceSpeed = shift;
my $pieceRecharge = shift;
my $speedAdj = shift;
my $difficulty = shift;
my $color = shift;
my $domain = shift;

use Cwd qw( abs_path );
use File::Basename qw( dirname );
use lib dirname(abs_path($0));

use KungFuChess::Bitboards;
use KungFuChess::GameAi;

print "init game ai... ($gameKey, $authKey, $pieceSpeed, $speedAdj, $difficulty, $color, $domain)\n";
my $kfcAi = KungFuChess::GameAi->new(
    $gameKey,
    $authKey,
    ($pieceRecharge > 3 ? 'standard' : 'lightning'),
    $pieceSpeed,
    $pieceRecharge,
    $speedAdj,
    '2way',
    $difficulty,
    $color,
    $domain
);
