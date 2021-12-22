#!/usr/bin/perl
#
use strict; use warnings;

my $number = shift;
my $domain = shift;

for (1 .. $number) {
    print "perl kfc_ai.pl ai_bot_$_ 123456 $domain 1 standard 1 > ~/1 &\n";
    system("perl kfc_ai.pl ai_bot_$_ 123456 $domain 1 standard 1 > ~/1 &");
    sleep(1);
}
