#!/usr/bin/perl
#
use strict; use warnings;

my $number = shift;
my $numberTo = shift;
my $domain = shift;

for ($number .. $numberTo) {
    print "perl kfc_ai.pl ai_bot_$_ 123456 $domain 1 standard 1 > ~/kfc_ai_$_ &2>1 &\n";
    system("perl kfc_ai.pl ai_bot_$_ 123456 $domain 1 standard 1 > ~/kfc_ai_$_ &2>1 &");
    sleep(1);
}
