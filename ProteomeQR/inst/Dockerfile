FROM rocker/rstudio-stable
MAINTAINER Christian Panse <cp@fgcz.ethz.ch>
RUN install2.r --error \ 
  colorspace  \
  doParallel \
  knitr \
  shiny \
  tidyverse \
  testthat 
RUN Rscript -e 'source("http://bioconductor.org/biocLite.R")' -e 'biocLite("biobroom")'
RUN Rscript -e 'source("http://bioconductor.org/biocLite.R")' -e 'biocLite("limma")'
RUN Rscript -e 'source("http://bioconductor.org/biocLite.R")' -e 'biocLite("vsn")'
RUN apt-get install curl && cd /tmp \
 && curl -s https://codeload.github.com/coreforlife/c4lProteomics/zip/master \
 > c4lProteomics.zip && unzip c4lProteomics.zip \
 && c4lProteomics-master \
 && R CMD build ProteomeQR  \
 && R CMD INSTALL ProteomeQR*.gz 
