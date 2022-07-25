#!/usr/bin/perl

use strict;
#use warnings;

use Inline CPP => config => typemaps => '/home/corey/kungFuChess/typemap';
use Inline CPP => '/home/corey/kungFuChess/xs.cpp' => namespace => 'xs';

xs::initialise_all_databases();
print "done initialise_all_databases()\n";
xs::setBBs(
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0
);
print "done setBBs()\n";
print "setAllMoves()\n";
xs::setAllMoves();
print "evalusateXS\n";
return xs::evaluate();
