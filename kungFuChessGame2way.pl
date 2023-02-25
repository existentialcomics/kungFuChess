#!/usr/bin/perl
use strict; use warnings;

my $gameKey = shift;
my $authKey = shift;
my $pieceSpeed = shift;
my $pieceRecharge = shift;
my $speedAdj = shift;
my $fen = shift;

use Cwd qw( abs_path );
use File::Basename qw( dirname );
use lib dirname(abs_path($0));

use KungFuChess::Bitboards;

print "init game... ($gameKey, $authKey, $pieceSpeed)\n";
use KungFuChess::GameServer;
my $kfc = KungFuChess::GameServer->new(
    $gameKey,
    $authKey,
    $pieceSpeed,
    $pieceRecharge,
    $speedAdj,
    '2way',
    $fen
);
