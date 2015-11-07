#! /usr/bin/perl -l
# Handler for output from des.pl, prints results

# Copyright © 2012,2015 Aleksey Cherepanov <lyosha@openwall.com>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted.

my $number_of_gates = int shift @ARGV;

use strict;
use warnings;

# TODO: 32-bit platforms support.
my $vtype = 'unsigned long';
my $sizeofvtype = 8;

my $all_pieces = 1;

my (@vvars, @vars);

my $inputs = 6;

my %h;

sub nsort {
    sort { $a <=> $b } @_
}

# DES s-boxes borrowed from DES_std.c of John the Ripper.
my @S = (
    [
        [14, 4, 13, 1, 2, 15, 11, 8, 3, 10, 6, 12, 5, 9, 0, 7],
        [0, 15, 7, 4, 14, 2, 13, 1, 10, 6, 12, 11, 9, 5, 3, 8],
        [4, 1, 14, 8, 13, 6, 2, 11, 15, 12, 9, 7, 3, 10, 5, 0],
        [15, 12, 8, 2, 4, 9, 1, 7, 5, 11, 3, 14, 10, 0, 6, 13]
    ], [
        [15, 1, 8, 14, 6, 11, 3, 4, 9, 7, 2, 13, 12, 0, 5, 10],
        [3, 13, 4, 7, 15, 2, 8, 14, 12, 0, 1, 10, 6, 9, 11, 5],
        [0, 14, 7, 11, 10, 4, 13, 1, 5, 8, 12, 6, 9, 3, 2, 15],
        [13, 8, 10, 1, 3, 15, 4, 2, 11, 6, 7, 12, 0, 5, 14, 9]
    ], [
        [10, 0, 9, 14, 6, 3, 15, 5, 1, 13, 12, 7, 11, 4, 2, 8],
        [13, 7, 0, 9, 3, 4, 6, 10, 2, 8, 5, 14, 12, 11, 15, 1],
        [13, 6, 4, 9, 8, 15, 3, 0, 11, 1, 2, 12, 5, 10, 14, 7],
        [1, 10, 13, 0, 6, 9, 8, 7, 4, 15, 14, 3, 11, 5, 2, 12]
    ], [
        [7, 13, 14, 3, 0, 6, 9, 10, 1, 2, 8, 5, 11, 12, 4, 15],
        [13, 8, 11, 5, 6, 15, 0, 3, 4, 7, 2, 12, 1, 10, 14, 9],
        [10, 6, 9, 0, 12, 11, 7, 13, 15, 1, 3, 14, 5, 2, 8, 4],
        [3, 15, 0, 6, 10, 1, 13, 8, 9, 4, 5, 11, 12, 7, 2, 14]
    ], [
        [2, 12, 4, 1, 7, 10, 11, 6, 8, 5, 3, 15, 13, 0, 14, 9],
        [14, 11, 2, 12, 4, 7, 13, 1, 5, 0, 15, 10, 3, 9, 8, 6],
        [4, 2, 1, 11, 10, 13, 7, 8, 15, 9, 12, 5, 6, 3, 0, 14],
        [11, 8, 12, 7, 1, 14, 2, 13, 6, 15, 0, 9, 10, 4, 5, 3]
    ], [
        [12, 1, 10, 15, 9, 2, 6, 8, 0, 13, 3, 4, 14, 7, 5, 11],
        [10, 15, 4, 2, 7, 12, 9, 5, 6, 1, 13, 14, 0, 11, 3, 8],
        [9, 14, 15, 5, 2, 8, 12, 3, 7, 0, 4, 10, 1, 13, 11, 6],
        [4, 3, 2, 12, 9, 5, 15, 10, 11, 14, 1, 7, 6, 0, 8, 13]
    ], [
        [4, 11, 2, 14, 15, 0, 8, 13, 3, 12, 9, 7, 5, 10, 6, 1],
        [13, 0, 11, 7, 4, 9, 1, 10, 14, 3, 5, 12, 2, 15, 8, 6],
        [1, 4, 11, 13, 12, 3, 7, 14, 10, 15, 6, 8, 0, 5, 9, 2],
        [6, 11, 13, 8, 1, 4, 10, 7, 9, 5, 0, 15, 14, 2, 3, 12]
    ], [
        [13, 2, 8, 4, 6, 15, 11, 1, 10, 9, 3, 14, 5, 0, 12, 7],
        [1, 15, 13, 8, 10, 3, 7, 4, 12, 5, 6, 11, 0, 14, 9, 2],
        [7, 11, 4, 1, 9, 12, 14, 2, 0, 6, 10, 13, 15, 3, 5, 8],
        [2, 1, 14, 7, 4, 10, 8, 13, 15, 12, 9, 0, 3, 5, 6, 11]
    ]
);

sub bitslice {
    # TODO: more than 64 bits in value.
    # NOTE: vectors full of zero bits are dropped.
    reverse grep { $_ } map {
        my $t = 0;
        my $bit = $_;
        $t |= ($_[$_] & (1 << $bit) ? 1 : 0) << $_ for 0 .. $#_;
        $t
    } 0 .. 63;
}

# We pack all possible inputs and respective results into vectors and
# use them to check results of sequences of operations.
my @inputs = 0 .. 2 ** $inputs - 1;
my @bitsliced_inputs = bitslice @inputs;
sub shuffled {
    my $value = shift;
    my $r = 0;
    $r |= (($value >> shift) & 1) << shift while @_;
    $r
}
# my $t = (13 << 1) + 1;
# my ($a, $b) = (shuffled($t, 5, 1, 0, 0), shuffled($t, qw/4 3 3 2 2 1 1 0/));
# print "[$a][$b] $S[0][$a][$b]";
# die;
my @outputs = map {
    my @sbox = @$_;
    [map { $sbox[shuffled($_, 5, 1, 0, 0)][shuffled($_, qw/4 3 3 2 2 1 1 0/)] } @inputs];
} @S;
#print $$_[0] for @outputs; die;

# TODO: group outputs by s-boxes.
my @bitsliced_outputs = map { [bitslice @$_] } @outputs;
# printf "%016x\n", $_ for @{$bitsliced_outputs[$ARGV[0]]}; die;

# Split 6x1 into 2 5x1 using "select bit" to merge halves back. Any
# bit could be dropped so.
# TODO: Currently we do not reduce number of inputs. Reduction would
#       improve speed.

my %H;
for (<t*out>) {
    open my $f, '<', $_;
    while (<$f>) {
        # Eats all memory
        # push @{$H{substr $_, 0, 16}}, $_;
        $H{substr $_, 0, 16} = 1;
    }
    close $f;
}

my @T;
for (0 .. $#bitsliced_outputs) {
    my $S = $_;
    my @t = @{$bitsliced_outputs[$_]};
    for (0 .. $#bitsliced_inputs) {
        my ($a, $b, $s);
        $a = $bitsliced_inputs[$_];
        $b = ~$a;
        $s = 2 ** ($#bitsliced_inputs - $_);
        # printf "%016x %016x %016x\n", $a, $b, $a >> $s;
        die "unexpected input shift" unless $a >> $s == $b;
        # We copy the first half into the second and alternatively the
        # second half into the first.
        my $i = 0;
        my $B = $_;
        for (@t) {
            if ($H{sprintf("%016x", (($_ & $a) >> $s) | ($_ & $a))} &&
                    $H{sprintf("%016x", (($_ & $b) << $s) | ($_ & $b))}) {
                warn "S$S, $i  ($B)\n";
                # Print outputs
                warn sprintf("  output %016x half1 %016x half2 %016x\n", $_, (($_ & $a) >> $s) | ($_ & $a), (($_ & $b) << $s) | ($_ & $b));
            }
            $i++;
        }
    }
}
