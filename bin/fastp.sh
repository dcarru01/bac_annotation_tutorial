#!/bin/bash
  fastp \
		--in1 ./acc_files/$1_1.fastq \
    --in2 ./acc_files/$1_2.fastq \
    --out1 ./trim/$1_1.fastq \
    --out2 ./trim/$1_2.fastq \
    --qualified_quality_phred 20 \
    --unqualified_percent_limit 40 \
    --cut_mean_quality 20 \
    --cut_window_size 5 \
    --cut_front \
    --cut_tail \
    --correction \
    --thread 4 \
    --html ./report/html/$1.html \
    --json ./report/json/$1.json 
