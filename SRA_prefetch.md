# Getting sequences from the NCBI Sequence Read Archive
If you want to follow along with the example genomes I provided with the acc.txt file, follow these steps to download the sequences from the NCBI SRA.

We will use the [sra-toolkit](https://github.com/ncbi/sra-tools) to first prefetch the accessions, then convert to fastq files.

On SciNet we can load the sra-toolkit:
```
module load CCEnv StdEnv/2020 gcc/9.3.0 sra-toolkit/3.0.0
```
The first step is to prefetch the accessions, which requires an internet connection so if you are doing this on SciNet you have to run it from a login node or a datamover node. 

Make a directory called SRA_prefetch and prefetch the accessions.
```
mkdir SRA_prefetch
parallel -j 4 -a acc.txt prefetch -O SRA_prefetch/ {}
```
We can then use fasterq-dump to get fastq files from the prefetched accessions. This doesn't require internet so you can run it in a job node if you want.
```
mkdir acc_files
parallel -j 4 -a acc.txt fasterq-dump -O acc_files SRA_prefetch/{}
```
By the end of this you should have paired end fastq reads with base quality scores for all of your genomes!
