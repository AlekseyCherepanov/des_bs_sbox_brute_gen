# Dumb generator of bitsliced implementations of DES S-boxes

This repo contains scripts to find bitslice implementations of DES S-boxes using brute force (deterministic exhaustive search). This project was not successful and did not produce anything practically usable. But intermediate results are available for investigation.

The goal is to find optimal implementations of DES S-boxes using common sets of gates. Currently only traditional gates plus andnot are supported (not, and, or, xor, andnot).

To perform search, a program in C is generated by scripts. Code generation is used to make nested "for" loops. A few optimizations are applied to the search: some schemes (or circuits) are skipped if they are equivalent to tried (only differ by rotation of arguments).

## Output files

Bruteforcers write its finding into .out files. It writes a value and implementation on 1 line:

```
a965569aa965569a  1 1 0  2 4 2  5 4 3  3 8 7  3 9 5  3 10 1  
```

The value represents full bit vector for all possible input values.

Numbers then are implementation: 2 spaces separate gates, 1 space separates parts of gate: #1 is type of gate, #2 and #3 are indexes of arguments. Indexes goes from 0 and refer to inputs and then results of previous gates: 0-5 are for inputs, 6-... are for results of gates (subtract 6 to get index of gate).

Types of gates (number of type and formula with a for left argument and b for right argument):
```
0 ~a
1 a | b
2 a & b
3 a ^ b
4 a & ~b
5 ~a & b
```

Type 0 means "not", the second argument is ignored (most probably it is 0 everywhere). Other types are binary. Types 4 and 5 represent "andnot" gate, because the gate is not symmetric and we need to try really all variants.

## Current results

3 weeks (24 hours a days) using 24 threads were needed to try all circuits with up to 8 gates. Bruteforcer saves results for all possible valid outputs and for all halves. At size 8, 2 pairs of halves for different sboxes were found: so for these sbox, it is possible to compose a circuit that produces 1 output bit correctly.

(Halves can combined into full output using bitselect operation.)

Unpacked size of the results is 22 GB. Packed size is 328 MB:
https://github.com/AlekseyCherepanov/des_bs_sbox_brute_gen/releases/download/v1.0/des_bs_sbox_brute_gen.results.7z

## Files in repo

The scripts and files:
  * `des.pl` - the main script: code generator,
  * `des_run.pl` - runner for the code generator: populates code, compiles and runs it in several threads, arguments: number of threads, minimal number of gates, maximal number of gates to try
  * `des_print.pl` - tool to research results, currently it finds pairs of halves.
  * `outputs.txt` - list of full outputs, so you could do: `grep -f outputs.txt *out | head -n 1`

NOTE: `des_run.pl` populates code in current directory, results go there too.

NOTE: populated bruteforcers rely onto 64-bit integers.

## Examples

The following examples assume that you have scripts and .out files in one directory and this directory is current working directory.

To search for full outputs (gives nothing on 1-8 gates):

```
$ grep -f outputs.txt *out
```

To search for pairs of halves:

```
$ perl des_print.pl
S1, 1  (5)
  output 68f93c169346c3e9 half1 3cfc3c03c303c3fc half2 c0f33c3c33ccc3c3
S6, 0  (0)
  output 92c761f82c96d966 half1 92c761f892c761f8 half2 2c96d9662c96d966
```

To count implementations for the halves above:

```
$ grep 3cfc3c03c303c3fc *out | wc -l
3541516
$ grep c0f33c3c33ccc3c3 *out | wc -l
231
```

To get 1 implementation for c0f33c3c33ccc3c3:

```
$ grep c0f33c3c33ccc3c3 *out | head -n 1
t8.bin_0.out:c0f33c3c33ccc3c3  0 0 0  3 3 2  2 4 0  3 4 3  5 8 7  3 9 6  5 10 1  3 12 11
```

To understand if piece of work is finished, you need to check last line of .out file: if there is "finished ..." then the piece is finished, otherwise bruteforcer is still working (or unexpectedly ended in the middle):

```
$ tail -n 1 des_bs_sbox_brute_gen.results/t6.bin_2.out
finished 6 2: 5223610430 66
```

Also there some stats in the last line: in example above, 6 is the number of gates, 2 is the number of piece of work, 5223610430 is the number of tried variants, 66 is the number of interesting implementations found (halves or full outputs).

TBD: example how to start bruteforce.

## License

The license on code is written in each file and states the following:

`Redistribution and use in source and binary forms, with or without modification, are permitted.`

Results (.out files) are not protected by copyright due to their nature.

## Links

Optimizing bitslice DES S-box expressions
http://www.openwall.info/wiki/sbox-opt/des
