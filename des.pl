#! /usr/bin/perl -l
# Code generator for exhaustive search of DES s-boxes
# Be aware: it creates files in current directory!
# TODO: Currently or/xor/and/not/andnot only.

# Copyright © 2012 Aleksey Cherepanov <lyosha@openwall.com>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted.

my $number_of_gates = int shift @ARGV;

use strict;
use warnings;

# TODO: 32-bit platforms support.
my $vtype = 'unsigned long';
my $sizeofvtype = 8;

my (@vvars, @vars);

my $inputs = 6;

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
my @bitsliced_outputs = map { bitslice @$_ } @outputs;
#printf "%016x\n", $_ for @bitsliced_inputs, @bitsliced_outputs; die;

# Split 6x1 into 2 5x1 using "select bit" to merge halves back. Any
# bit could be dropped so.
# TODO: Currently we not reduce number of inputs. Reduction would
#       improve speed.
my @t = @bitsliced_outputs;
for (0 .. $#bitsliced_inputs) {
    my ($a, $b, $s);
    $a = $bitsliced_inputs[$_];
    $b = ~$a;
    $s = 2 ** ($#bitsliced_inputs - $_);
    # printf "%016x %016x %016x\n", $a, $b, $a >> $s;
    die "unexpected input shift" unless $a >> $s == $b;
    # We copy the first half into the second and alternatively the
    # second half into the first.
    for (@t) {
        push @bitsliced_outputs, (($_ & $a) >> $s) | ($_ & $a);
        push @bitsliced_outputs, (($_ & $b) << $s) | ($_ & $b);
    }
}
# printf "%016x\n", $_ for @bitsliced_outputs; die;

my $i;

my $body = '';
sub c {
    $body .= "$_[0]\n";
}

$i = 0;
for (@bitsliced_inputs) {
    c "res[$i] = ${_}U;";
    $i++;
}

# TODO: Use malloc to allow big look-up tables.
# It is faster without this look-up table. Hence it is commented out.
# Though when there are more gates it may (or may not) be possible to
# get performance improvement.
my $res_lookup_bits = 22;
my $res_lookup_size = 2 ** $res_lookup_bits;
my $res_lookup_mask = $res_lookup_size - 1;
my $res_lookup_enabled = 0;
my ($lc0, $rc0) = $res_lookup_enabled ? ("", "") : qw(/* */);
c <<EOT;
    $lc0
    for (i = 0; i < $inputs; i++) {
        res_lookup[res[i] & $res_lookup_mask] = 1;
    }
    $rc0
EOT

# TODO: Hash table? Some tree? Ordered array for binary search?
# This is the other case of look-up table. It is read-only table and
# works faster than pure direct checks. Choice of 16 bits seems to be
# good for 32 outputs (of original 8 6x4 DES s-boxes). For bigger
# amount of outputs greater value are better.
my $output_lookup_bits = 20;
my $output_lookup_shift = 64 - $output_lookup_bits;
my $output_lookup_size = 2 ** $output_lookup_bits;
my $output_lookup_mask = $output_lookup_size - 1;
my %pairs;
my $pair_code = 0;
for (@bitsliced_outputs) {
    my ($a, $b) = ($_ & $output_lookup_mask, $_ >> $output_lookup_shift);
    if (!defined $pairs{$a}) {
        # TODO: Maybe small speed up is possible with better code assignment.
        # push @{$pairs{$a}}, int rand(255) + 1, $b;
        push @{$pairs{$a}}, $pair_code++ % 255 + 1, $b;
    } else {
        push @{$pairs{$a}}, $b;
    }
}
for my $a (keys %pairs) {
    my $c = shift @{$pairs{$a}};
    for my $b (@{$pairs{$a}}) {
        c "output_lookup[$a] = output_lookup2[$b] = $c;";
    }
}


# push @bitsliced_outputs, ~$bitsliced_inputs[0];
# warn sprintf "%016x\n", $bitsliced_outputs[$#bitsliced_outputs];

my @gate_numbers = 0 .. $number_of_gates - 1;
for (@gate_numbers) {
    for my $v (split //, 'gabre') {
        push @vars, "$v$_";
    }
    # TODO: Tweak order of this array. Reverse?
    my $already_found = join ") || (", map { "res[$_] == res[$i]" } 0 .. $i - 1;
    $already_found = "($already_found)";
    my ($gs, $as, $bs, $once);
    if ($_) {
        my $p = $_ - 1;
        # my $pi = $i - 1;
        # my $ppi = $pi - 1;
        $as = "a$p";
        $gs = "a$_ == a$p ? g$p : 0";
        $bs = "a$_ == a$p && g$_ == g$p ? b$p : 0";
        $once = '';
    } else {
        $as = 0;
        $gs = 0;
        $bs = 0;
        # TODO: count time.
        $once = <<EOT;
top_tried++;
if (top_tried < piece || piece < 0)
    continue;
if (top_tried > piece) {
    printf("finished $number_of_gates %d: %lu %lu\\n", piece, tried, good);
    fprintf(stderr, "finished $number_of_gates %d: %lu %lu\\n", piece, tried, good);
    return 0;
}
EOT
    }
    # NOTE: andnot is asymmetric so we split it into left and right
    #       because our optimization cuts right part.
    # TODO: Does 2 variations of andnot bring new duplicates?
    # NOTE: We assume that we could not find more than 255 outputs
    #       with the same position in look-up table.
    c <<EOT;
for (a$_ = $as; a$_ < $i; a$_++) {
    for (g$_ = $gs; g$_ < 6; g$_++) {
        for (b$_ = $bs, e$_ = g$_ == 0 ? 1 : a$_; b$_ < e$_; b$_++) {
$once
            res[$i] = g$_ == 0 ? ~res[a$_]
                : g$_ == 1 ? res[a$_] | res[b$_]
                : g$_ == 2 ? res[a$_] & res[b$_]
                : g$_ == 3 ? res[a$_] ^ res[b$_]
                : g$_ == 4 ? res[a$_] & ~res[b$_]
                : ~res[a$_] & res[b$_];
            $lc0 r$_ = res[$i] & $res_lookup_mask; $rc0
            if ($lc0 res_lookup[r$_] && $rc0 ($already_found))
                continue;
            $lc0 res_lookup[r$_]++; $rc0
            tried++;
EOT
    $i++;
}
# Get back to last gate.
$i--;

# c "if (/*output_lookup[res[$i] & $output_lookup_mask] &&*/ ((" . (join ") || (", map { "${_}U == res[$i]" } @bitsliced_outputs) . "))) {\n"
#     . "good++;"
#     # TODO: Is %lx portable?
#     . "printf(\"%016lx  " . "%d %d %d  " x $number_of_gates . "\\n\", res[$i], "
#     . (join ", ", map { "g$_, a$_, b$_" } @gate_numbers) . ");\n"
# . "}";

push @vars, qw/l1 l2/;
c "l1 = output_lookup[res[$i] & $output_lookup_mask];";
c "if (l1) {";
c "    l2 = output_lookup2[res[$i] >> $output_lookup_shift];";
c "    if (l2)";
# TODO: This check is slow. So our sophisticated init is not needed.
#c "    if (l1 == l2)";
c "    switch (res[$i]) {";
# TODO: There are duplicates. It's interesting.
my %h;
$h{$_} = 1 for @bitsliced_outputs;
for (sort keys %h) {
    c "case ${_}U:";
}
c   "good++;"
    # TODO: Is %lx portable?
    . "printf(\"%016lx  " . "%d %d %d  " x $number_of_gates . "\\n\", res[$i], "
    . (join ", ", map { "g$_, a$_, b$_" } @gate_numbers) . ");\n";
c "    }";
c "}";

for (reverse @gate_numbers) {
    c <<EOT;
            $lc0 res_lookup[r$_]--; $rc0
        }
    }
}
EOT
}

my $vvars = join ", ", @vvars;
my $vars = join ", ", @vars;

# NOTE: "tried" shows nodes (including roots of dropped branches).
print <<EOT;
#include <stdio.h>
#include <stdlib.h>

$lc0 static unsigned char res_lookup[$res_lookup_size] = { 0 }; $rc0
static char output_lookup[$output_lookup_size] = { 0 };
static char output_lookup2[$output_lookup_size] = { 0 };

int main(int argc, char *argv[])
{
    $vtype res[$inputs + $number_of_gates];
    /*$vtype $vvars;*/
    int $vars;
    unsigned long tried = 0, good = 0;
    int top_tried = -1, piece = 0;
    int i;
    if (sizeof($vtype) != $sizeofvtype) {
        fprintf(stderr, "$vtype is not 64-bit, abort\\n");
        return 1;
    }
    if (argc != 2) {
        fprintf(stderr, "need a number of work piece as argument\\n");
        return 2;
    }
    piece = atoi(argv[1]);
    $body
    fprintf(stderr, "max top_tried reached: %d (nothing was done)\\n", top_tried);
    return 3;
}
EOT

__END__
