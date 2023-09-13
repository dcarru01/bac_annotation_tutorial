#!/bin/bash

while IFS= read -r line
do
  spades.py \
    -1 trim/${line}_1.fastq \
    -2 trim/${line}_2.fastq \
    -o spades/${line}-sp \
    -t 80 \
    --isolate
done < acc.txt
