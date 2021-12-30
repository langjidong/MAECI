#!usr/bin/perl -w
use strict;
unless (@ARGV==2)
{
    die "perl $0 <fastq_file> <OUT>\n";
}
open IN, "$ARGV[0]" or die;
open OUT, ">$ARGV[1]" or die;
my $length3 = 0;
my $GC_num3 = 0;
my $N_num3 = 0;
my $q20_num3 = 0;
my $read_num3 = 0;

while (<IN>)
{
    chomp;
    if ($_ =~ s/^@//)
    {
        $read_num3+=1;
        my $seq3=<IN>;
        chomp $seq3;
        $length3 += length($seq3);
        $GC_num3 += ($seq3=~ s/[GC]//gi);
        $N_num3 += ($seq3=~s/N//gi);
        <IN>;
        my $qual3 = <IN>;
        chomp $qual3;
        $q20_num3 += ($qual3=~s/[\(\)\*\+\,\-\.\/0123456789\:\;\<\=\>\?\@ABCDEFGHIJK]//g);
    }   
}

my $N_rate = $N_num3/$length3;
my $GC_rate = $GC_num3/$length3;
my $q20_rate = $q20_num3/$length3;
my $read_total = $read_num3;
my $length_total = $length3;
print OUT "GC_rate\t$GC_rate\n";
print OUT "N_rate\t$N_rate\n";
print OUT "Q20_rate\t$q20_rate\n";
print OUT "Reads_total\t$read_total\n";
print OUT "Bases_total\t$length_total\n";
