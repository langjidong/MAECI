# MAECI
MAECI: A Tool For Integrating Multiple Assemblies Into A Consensus Sequence Base On Nanopore Sequencing Data

Usage:
===============================================
Edit by Jidong Lang; E-mail: langjidong@hotmail.com;
===============================================

Option
        -fq     <Input File>    Input *.fq file
        -path1  <Assembly Method 1>     The path of assembly method/software, default: /usr/bin/canu
        -path2  <Assembly Method 2>     The path of assembly method/software, default: /usr/bin/flye
        -path3  <Assembly Method 3>     The path of assembly method/software, default: /usr/bin/wtdbg2
        -path4  <Correction Method>     The path of self-correction method/software, default: /usr/bin/racon
        -genome_size    <Estimated Genome Size> Estimated genome size, the unit is mb
        -ngs_polishing  <yes:1|no:0>    Whether need NGS data for polishing, default: 0
        -ngs_file1      <NGS Fastq file1>       The ngs fastq file, such as read_1.fq.gz
        -ngs_file2      <NGS Fastq file2>       The ngs fastq file, such as read_2.fq.gz
        -outputdir      <Output Dir>    The output results pathdir
        -reference      <Reference Genome>      The reference genome of similar species
        -process        <Number of process used>        N processes to use, default is 1
        -help   print HELP message

Example:

perl /mnt/nas/bioinfo/langjidong/PERL/software/Third-Generation/Pipeline/Multiple-Assembly-Integration/Multiple-Assembly-Integration.pl -fq nanopore.fq -path1 canu -path2 flye -path3 wtdbg2 -path4 racon -genome_size 1m -ngs_polishing 1 -ngs_file1 read_1.fq.gz -ngs_file2 read_2.fq.gz -outputdir ./outputdir -reference reference.fasta -process 8

Note: There are other options for assembling methods/softwares, and theoretically one method is also possible. But we suggest that should better choose at least 3 methods. If you want to change the assembly methods, please modify the command line (Line 75-87) in this script.
