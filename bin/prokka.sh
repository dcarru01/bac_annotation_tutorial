#!/bin/bash

 prokka \
  --outdir ./prokka/$1 \
  --prefix $1 \
  --addgenes \
  --locustag $1 \
  --genus Neisseria \
  --kingdom Bacteria \
  --force \
  --cpus 40 \
  --centre X \
  --compliant \
  assemblies/$1.fasta
