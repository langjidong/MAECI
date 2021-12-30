#!/usr/bin/perl -w
use strict;
use File::Basename;
use Getopt::Long;
use FindBin qw/$Bin/;

sub USAGE
{
    my $usage=<<USAGE;

===============================================
Edit by Jidong Lang; E-mail: langjidong\@hotmail.com;
===============================================

Option
        -fq	<Input File>	Input *.fq file
        -path1	<Assembly Method 1>	The path of assembly method/software, default: /usr/bin/canu
	-path2  <Assembly Method 2>     The path of assembly method/software, default: /usr/bin/flye
	-path3  <Assembly Method 3>     The path of assembly method/software, default: /usr/bin/wtdbg2
        -path4	<Correction Method>	The path of self-correction method/software, default: /usr/bin/racon
	-genome_size	<Estimated Genome Size>	Estimated genome size, the unit is mb
        -ngs_polishing	<yes:1|no:0>	Whether need NGS data for polishing, default: 0
	-ngs_file1	<NGS Fastq file1>	The ngs fastq file, such as read_1.fq.gz
	-ngs_file2	<NGS Fastq file2>	The ngs fastq file, such as read_2.fq.gz
	-outputdir	<Output Dir>	The output results pathdir
	-reference	<Reference Genome>	The reference genome of similar species
        -process	<Number of process used>	N processes to use, default is 1
        -help	print HELP message

Example:

perl $0 -fq nanopore.fq -path1 canu -path2 flye -path3 wtdbg2 -path4 racon -genome_size 1m -ngs_polishing 1 -ngs_file1 read_1.fq.gz -ngs_file2 read_2.fq.gz -outputdir ./outputdir -reference reference.fasta -process 8

Note: There are other options for assembling methods/softwares, and theoretically one method is also possible. But we suggest that should better choose at least 3 methods. If you want to change the assembly methods, please modify the command line (Line 75-87) in this script.

USAGE
}

unless(@ARGV>7)
{
    die USAGE;
    exit 0;
}


my ($fq,$path1,$path2,$path3,$path4,$genome_size,$ngs_polishing,$ngs_file1,$ngs_file2,$outputdir,$reference,$process);
GetOptions
(
    'fq=s'=>\$fq,
    'path1=s'=>\$path1,
    'path2=s'=>\$path2,
    'path3=s'=>\$path3,
    'path4=s'=>\$path4,
    'genome_size=s'=>\$genome_size,
    'ngs_polishing=i'=>\$ngs_polishing,
    'ngs_file1=s'=>\$ngs_file1,
    'ngs_file2=s'=>\$ngs_file2,
    'outputdir=s'=>\$outputdir,
    'reference=s'=>\$reference,
    'process=i'=>\$process,
    'help'=>\&USAGE,
);

$ngs_polishing ||=0;
$process ||=1;

my $basename=basename($fq);
$basename=~s/(.*).fq/$1/g;

####Data Pre-processing####
`mkdir $outputdir/clean_data`;
`porechop -t $process -i $fq -o $outputdir/clean_data/$basename.fq`;
#`NanoFilt -q 5 -l 100 < $outputdir/clean_data/$basename.fq.gz > $outputdir/clean_data/$basename.clean.fq.gz`;

####Data Assembly####
`mkdir $outputdir/Assemble-1`;
`$path1 -p $basename -d $outputdir/Assemble-1 genomeSize=$genome_size -nanopore $outputdir/clean_data/$basename.fq`;

`mkdir $outputdir/Assemble-2`;
`$path2 --nano-raw $outputdir/clean_data/$basename.fq --out-dir $outputdir/Assemble-2 --genome-size $genome_size --threads $process --iterations 3`;

`mkdir $outputdir/Assemble-3`;
`$path3 -i $outputdir/clean_data/$basename.fq -t $process -x ont,preset2 -g $genome_size -f -o $outputdir/Assemble-3/$basename`;
`wtpoa-cns -t $process -i $outputdir/Assemble-3/$basename.ctg.lay.gz -f -o $outputdir/Assemble-3/$basename.raw.fa`;
`minimap2 -t $process -a -x map-ont -r2k $outputdir/Assemble-3/$basename.raw.fa $outputdir/clean_data/$basename.fq | samtools sort -@ 4 > $outputdir/Assemble-3/$basename.bam`;
`samtools view -F0x900 $outputdir/Assemble-3/$basename.bam | wtpoa-cns -t $process -d $outputdir/Assemble-3/$basename.raw.fa -i - -f -o $outputdir/Assemble-3/$basename.cns.fa`;

####Self Correction####
`mkdir $outputdir/self-correction`;
`cp $outputdir/Assemble-1/$basename.contigs.fasta $outputdir/self-correction/canu.fasta`;
`cp $outputdir/Assemble-2/assembly.fasta $outputdir/self-correction/flye.fasta`;
`cp $outputdir/Assemble-3/$basename.cns.fa $outputdir/self-correction/wtdbg2.fasta`;
`ls $outputdir/self-correction/*.fasta > $outputdir/self-correction/tmp1`;
`less $outputdir/self-correction/tmp1|while read a;do less \${a}|grep \">\"|wc -l;done > $outputdir/self-correction/tmp2`;
`paste $outputdir/self-correction/tmp1 $outputdir/self-correction/tmp2|sort -rnk2 > $outputdir/self-correction/list`;
`rm $outputdir/self-correction/tmp1 $outputdir/self-correction/tmp2`;

open IN1, "$outputdir/self-correction/list" or die;
open OUT1, ">$outputdir/self-correction/list1" or die;
my (@tmp,@k1,@k2);
my ($i);
while(<IN1>)
{
	chomp;
	@tmp=split(/\s+/,$_,2);
	push @k1,$tmp[0];
	push @k2,$tmp[1];
}
for($i=0;$i<@k1;$i++)
{
	if($k2[$i]==$k2[$i+1] && $k2[$i+1]==$k2[$i+2])
	{
		print OUT1 "$outputdir/self-correction/canu.fasta\t$k2[$i]\n$outputdir/self-correction/wtdbg2.fasta\t$k2[$i]\n$outputdir/self-correction/flye.fasta\t$k2[$i]\n";
	}
	else
	{
		last;
		`cp $outputdir/self-correction/list $outputdir/self-correction/list1`;
	}
}
close IN1;
close OUT1;
#`mv $outputdir/self-correction/list1 $outputdir/self-correction/list`;

open IN2, "$outputdir/self-correction/list1" or die;
my (@tmp1,@t1);
while(<IN2>)
{
	chomp;
	@tmp1=split(/\s+/,$_,2);
	push @t1,$tmp1[0];
}

`minimap2 -d $t1[0] $t1[1]`;
`minimap2 -a -x map-ont $t1[0] $outputdir/clean_data/$basename.fq -t $process > $outputdir/self-correction/temp.sam`;
`racon -t $process $outputdir/clean_data/$basename.fq $outputdir/self-correction/temp.sam $t1[1] > $outputdir/self-correction/temp.fasta`;
`minimap2 -d $outputdir/self-correction/temp.fasta $t1[2]`;
`minimap2 -a -x map-ont $outputdir/self-correction/temp.fasta $outputdir/clean_data/$basename.fq -t $process > $outputdir/self-correction/temp.sam`;
`racon -t $process $outputdir/clean_data/$basename.fq $outputdir/self-correction/temp.sam $t1[2] > $outputdir/self-correction/racon.raw.fasta`;
`minimap2 -a -x map-ont $outputdir/self-correction/racon.raw.fasta $outputdir/clean_data/$basename.fq -t $process > $outputdir/self-correction/temp.sam`;
`racon -t $process $outputdir/clean_data/$basename.fq $outputdir/self-correction/temp.sam $outputdir/self-correction/racon.raw.fasta > $outputdir/self-correction/temp.fasta`;
`minimap2 -a -x map-ont $outputdir/self-correction/temp.fasta $outputdir/clean_data/$basename.fq -t $process > $outputdir/self-correction/temp.sam`;
`racon -t $process $outputdir/clean_data/$basename.fq $outputdir/self-correction/temp.sam $outputdir/self-correction/temp.fasta > $outputdir/self-correction/temp1.fasta`;
`minimap2 -a -x map-ont $outputdir/self-correction/temp1.fasta $outputdir/clean_data/$basename.fq -t $process > $outputdir/self-correction/temp.sam`;
`racon -t $process $outputdir/clean_data/$basename.fq $outputdir/self-correction/temp.sam $outputdir/self-correction/temp1.fasta > $outputdir/self-correction/racon.final.fasta`;
`rm -rf $outputdir/self-correction/temp.sam $outputdir/self-correction/temp.fasta $outputdir/self-correction/temp1.fasta $t1[0] $t1[1] $t1[2]`;
close IN2;

####Quality Control####
`mkdir $outputdir/QC`;
`perl $Bin/script/static_data.pl $outputdir/clean_data/$basename.fq $outputdir/QC/$basename.stat`;
`NanoPlot -t $process --fastq $outputdir/clean_data/$basename.fq --plots hex dot -o $outputdir/QC/ -p $basename`;
`quast -r $reference $outputdir/Assemble-1/$basename.contigs.fasta $outputdir/Assemble-2/assembly.fasta $outputdir/Assemble-3/$basename.cns.fa $outputdir/self-correction/racon.raw.fasta $outputdir/self-correction/racon.final.fasta -o $outputdir/QC`;

####NGS Polishibg####
if($ngs_polishing == 1)
{
	`mkdir $outputdir/NGS_Polishing`;
	`cp $outputdir/self-correction/racon.final.fasta $outputdir/NGS_Polishing/draft.fa`;
	`bwa index $outputdir/NGS_Polishing/draft.fa`;
	`bwa mem -t $process $outputdir/NGS_Polishing/draft.fa $ngs_file1 $ngs_file2 | samtools sort -@ $process -O bam -o $outputdir/NGS_Polishing/align.bam`;
	`/mnt/gvol/langjidong/miniconda3/envs/Python2/bin/sambamba markdup -t $process $outputdir/NGS_Polishing/align.bam $outputdir/NGS_Polishing/align_markdup.bam`;
	`samtools view -b -@ $process -q 30 $outputdir/NGS_Polishing/align_markdup.bam -o $outputdir/NGS_Polishing/align_filter.bam`;
	`samtools index -@ $process $outputdir/NGS_Polishing/align_filter.bam`;
	`rm -rf $outputdir/NGS_Polishing/align.bam $outputdir/NGS_Polishing/align_markdup.bam`;
	`pilon -Xmx4096m -XX:-UseGCOverheadLimit --genome $outputdir/NGS_Polishing/draft.fa --frags $outputdir/NGS_Polishing/align_filter.bam --output $outputdir/NGS_Polishing/racon.final.polishing --vcf`;
	`rm -rf $outputdir/NGS_Polishing/draft.fa $outputdir/NGS_Polishing/align_filter.bam $outputdir/NGS_Polishing/align_filter.bam.bai`;
	`quast -r $reference $outputdir/Assemble-1/$basename.contigs.fasta $outputdir/Assemble-2/assembly.fasta $outputdir/Assemble-3/$basename.cns.fa $outputdir/self-correction/racon.raw.fasta $outputdir/self-correction/racon.final.fasta $outputdir/NGS_Polishing/racon.final.polishing.fasta -o $outputdir/QC`;
}
else
{
	print "Complete! But we also suggest that the result should be polished by NGS data!\n";
}
