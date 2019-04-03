FROM rocker/r-ver:3.5.3		
MAINTAINER Christian Panse <cp@fgcz.ethz.ch>
RUN apt-get update  
RUN apt-get install \
  apt-utils \
  binutils curl \
  firefox-esr \
  libghc-zlib-dev \
  libnetcdf-dev \
  libssl-dev \
  libxml2-dev \
  openssl \
  pandoc-citeproc \
  texlive-full \
  -y 
RUN install2.r --error \ 
  colorspace  \
  doParallel \
  knitr \
  testthat \
  gplots \
  ggplot2 \
  fdrtool \
  httr \
  tidyverse \
  devtools \
  shiny \
  XML
RUN Rscript -e 'source("http://bioconductor.org/biocLite.R")' \
  -e 'biocLite("biobroom")' \
  -e 'biocLite("limma")' \
  -e 'biocLite("vsn")' \
  -e 'biocLite("MSnbase")'
RUN Rscript -e 'library(devtools); install_github("protViz/SRMService")'
RUN cd /tmp \
 && curl -s https://codeload.github.com/coreforlife/c4lProteomics/zip/master \
 > c4lProteomics.zip && unzip c4lProteomics.zip 
RUN cd /tmp/c4lProteomics-master \
 && R CMD build ProteomeQR  \
 && R CMD INSTALL ProteomeQR*.gz 
