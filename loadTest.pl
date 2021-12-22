#!/usr/bin/perl
#
use strict; use warnings;

my $number = shift;

for (1 .. $number) {
    system("perl kfc_ai.pl ai_bot_$_ 123456 https://www2.kungfuchess.org 1 standard 1 > ~/1 &");
    sleep(1);
}
