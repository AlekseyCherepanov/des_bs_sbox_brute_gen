#! /usr/bin/perl -l
# Runner for des.pl

# Copyright © 2012 Aleksey Cherepanov <lyosha@openwall.com>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted.

my $threads = int shift @ARGV;
# Numbers of gates
my $gates_from = int shift @ARGV;
my $gates_to = int shift @ARGV;

use strict;
use warnings;

# TODO: call des.pl with -1 and get number from there.
my $pieces = 80;

# Compile everything
my @binaries;
for ($gates_from .. $gates_to) {
    system "$^X ./des.pl $_ > t$_.c && gcc -O3 t$_.c -o t$_.bin"
        and die "bad compilation";
    push @binaries, "t$_.bin";
}
warn "compiled\n";

my @pieces = map {
    my $b = $_;
    map { "./$b $_ > ${b}_$_.out" } 0 .. $pieces - 1;
} @binaries;

my $grep_condition = join " ", map { "-e $_" } @binaries;
my $thread_counter = "ps -A | grep $grep_condition | grep -v grep | wc -l";
while (@pieces) {
    my $c = `$thread_counter`;
    for ($c .. $threads - 1) {
        last unless @pieces;
        my $p = shift @pieces;
        system "$p &";
    }
    sleep $gates_from;
}
