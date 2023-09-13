# Bacterial genome annotation tutorial
This is primarily intended for single genomes, not metagenomes, although most of these tools have options for inputting metagenome sequences.

Basic steps are:
- trim sequences
- genome assembly (for this I will be doing de novo assembly, but you could also use a reference guided assembly)
- gene prediction and annotation
- downstream analysis (pangenome, AMR, GWAS, phage)
  
For this tutorial I am using 4 gonococcal sequences from the NCBI SRA, but this will work with any raw sequences. If you want to download these sequences to work along, I have included instructions under SRA_prefetch.md 
I have included links for all the tools below, as well as everything you will need to run them either on SciNet or on your computer
## Preparation 
We have to load some modules and make some directories on SciNet before we can begin. With that said, in theory none of these scripts should require SciNet, you should be able to run them on your local computer if you can install the tools.
```
module load CCEnv StdEnv/2020 gcc/9.3.0 fastp/0.23.4 spades/3.15.4 prokka/1.14.5 roary/3.13.0
mkdir acc_files trim report report/html report/json spades assemblies prokka annotated_gff 
```
We also need a text file with the names of all of our input files without extensions. In this case, our file is called acc.txt, using the same naming convention will make things smoother.
## Sequence QC and trimming using fastp
We will use fastp for trimming. You can also take a look with fastqc for more detailed output. The script for fastp is fastp.sh. I will go through how to call this below, as well as what the different options mean.
```
 parallel -a acc.txt bin/fastp.sh
```
This is going to trim out adapter sequences as well as remove low quality reads from our final assembly.
```
#!/bin/bash
  fastp \
    --in1 ./acc_files/$1_1.fastq \ #input files from paired end fastq reads
    --in2 ./acc_files/$1_2.fastq \
    --out1 ./trim/$1_1.fastq \ #our trimmed output files for downstream processing
    --out2 ./trim/$1_2.fastq \
    --qualified_quality_phred 20 \ #minimum phred base quality
    --unqualified_percent_limit 40 \ #miminum percent of bases in that position which must exceed the quality limit
    --cut_mean_quality 20 \ #the next few commands go through a sliding window of 5 bases from both 3' to 5' and back and trim reads with < 20 phred mean quality 
    --cut_window_size 5 \
    --cut_front \
    --cut_tail \
    --correction \
    --thread 4 \
    --html ./report/html/$1.html \ #generate reports
    --json ./report/json/$1.json
```
Most of these settings are default, you can take a look at the manual for [fastp](https://github.com/OpenGene/fastp) if you want to get granular. [Trimmomatic](https://github.com/usadellab/Trimmomatic) is another good option for base trimming.
## De novo genome assembly using SPAdes
Now we have to assemble our genomes from our trimmed reads. Like I briefly mentioned, we can do this with or without a reference sequence. I am not going to use a reference sequence because I am interested in plasmids and genes that aren't in the gonococcal reference sequence, but either way works. De novo assembly tends to be longer and less accurate, and if you are looking at SNVs or a phylogeny you should align to a reference genome. This is purely for genome annotation, and you could theoretically do this without knowing what species the genome belongs to (in which case I would recommend using [Kraken](https://ccb.jhu.edu/software/kraken2/) first to ID your isolate).

I am going to use [SPAdes](https://github.com/ablab/spades) because I've used it in the past and it works well on SciNet, but another good (maybe better) option is [Velvet](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC2952100/). We are just going to keep things simple and run spades with default options and the --isolate flag which is recommended for single isolate sequencing. Simply run the spades.sh script.
```
bash bin/spades.sh
```
The script just calls spades and feeds it the input files.
```
while IFS= read -r line
do
  spades.py \
    -1 trim/${line}_1.fastq \
    -2 trim/${line}_2.fastq \
    -o spades/${line}-sp \
    -t 80 \
    --isolate
done < acc.txt
```
One last thing before we move onto annotating, we have to get our scaffolds from the SPAdes output and put them in their own directory.
```
for d in spades/*; do cp $d/scaffolds.fasta assemblies/$(basename $d -sp).fasta; done
```
## Genome annotation with Prokka
Our next step is to annotate our assembled sequences. My preferred tool for this is [Prokka](https://github.com/tseemann/prokka). There are almost certainly other options, but this one has always worked well for me and you can customize it quite heavily to improve your results. For this tutorial we will pretty much run on basic settings, but if you go to the Prokka github you will see instructions for adding a custom protein database or pre-training the gene prediction model ([Prodigal](https://github.com/hyattpd/Prodigal)) to tailor your analysis to your particular isolate.

Again, running this on the command line is as simple as passing our script to parallel:
```
parallel -a acc.txt bin/prokka.sh {}
```
Going through the actual script we can see various options:
```
 prokka \
  --outdir ./prokka/$1 \
  --prefix $1 \
  --addgenes \
  --locustag $1 \ #name loci with our isolate ID
  --genus Neisseria \ #helps narrow our search
  --kingdom Bacteria \
  --force \ #overwrite previous files if they exist
  --cpus 40 \
  --centre X \ #no sequencing center ID
  --compliant \ #ensure gff/gbk files are compliant with Genbank format
  assemblies/$1.fasta
```
Like I said this barely scratches the surface of the options available so I strongly recommend going through the manual first if you are using this for real.
## Downstream analysis
Now that we have annotated genomes we can do whatever we want with them! I will go through a few examples of things and tools I have used, focusing on an in depth comparison of AMR genes in the 4 isolates. There are some links for additional tools I've used at the end as well.
### Pangenome analysis with Roary
[Roary](https://sanger-pathogens.github.io/Roary/) is a tool which works well with Prokka, and is designed to create a pangenome for your isolates. In essence, it is a wrapper around mafft and blast which assigns groups genes based on sequence similarity then tracks their presence or absence in your isolates. It isn't the only option, and it isn't perfect but it can be a good starting point!

Running roary is easy once you have finished your analysis from prokka. First we are going to copy all of the gff files from our prokka output into a new directory.
```
cp prokka/*/*.gff annotated_gff
```
Now we pass these to roary wtih a few options enabled.
```
roary -n -e -p 40 -f roary annotated_gff/*.gff
```
This tells roary to use PRANK and MAFFT to speed up our core genome alignment, assignes 40 threads, and directs the output to roary. Take a look at the manual for details on the output, but generally speaking the most interesting files are the gene_presence_absence files which will show you which genes are in which isolates. The other useful file is the pan_genome_reference.fa file which contains reference sequences for each gene identified. We will use this for some additional downstream annotation.
### eggNOG-mapper annotation
Prokka is good and useful for annotation, but [eggNOG-mapper](http://eggnog-mapper.embl.de/) has certain advantages, including more detailed descriptions, GO terms, integration with KEGG, PFAMs, etc... There is a command line version you can download and set up, but the database is huge so it is a bit of an undertaking getting it all working. I generally use the online tool as long as I fit in the limit.

For this tutorial I will feed in our set of reference genes from the pangenome analysis, but eggNOG-mapper can also be run on individual genomes prior to Prokka using Prodigal for gene discovery, so it is an entirely valid option for that function as well!

We are going to go to download our pan_genome_reference.fa file and feed it to [eggNOG-mapper](http://eggnog-mapper.embl.de/). Select CDs, upload your file and provide your fasta file. I would additionally recommend going to Advanced options -> Annotation options and change GO term annotation to "Transfer all annotations" or you will get very few GO terms. We can take a look at the annotations from the excel sheet and see the additional information.
### CARD RGI tool for AMR determinants
The [CARD RGI](https://card.mcmaster.ca/analyze/rgi) (Resitance Gene Identifier) is a tool from McMaster aimed at identifying resistance genes from genome sequences. Again, it can be downloaded and run through the command line, but it is easier for a small number of genomes to just use the online tool which is what we will do.

Let's start by getting the annotated genes from each isolate from the prokka output. We are looking for the .ffn files which contain individual gene sequences (although I believe you can also send in the assemblies or the whole genome sequence). We then upload those to the [RGI](https://card.mcmaster.ca/analyze/rgi) tool and we can check out the resulting annotations.
### Other downstream analysis tools
Obviously I can't go through every downstream tool here but I wanted to list a few options/resources here in case you wanted a place to start.
- Phage gene identification with [PhiSpy](https://github.com/linsalrob/PhiSpy)
- Bacterial pan-genome wide association studies with [Scoary](https://github.com/AdmiralenOla/Scoary) (designed to use Roary)
- Bacterial GWAS with [pyseer](https://pyseer.readthedocs.io/en/master/index.html)
- Sequence typing with [mlst](https://github.com/tseemann/mlst) (only for species in the database)
- AMR gene identification and typing with [Pathogenwatch](https://pathogen.watch/) (again, depends on the database)
