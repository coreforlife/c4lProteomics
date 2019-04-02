FROM rocker/r-ver:3.5.3		
MAINTAINER Christian Panse <cp@fgcz.ethz.ch>
RUN apt-get update  
RUN apt-get install apt-utils -y 
RUN apt-get install binutils curl apt-utils -y 
RUN install2.r --error \ 
  colorspace  \
  doParallel \
  knitr \
  shiny \
  testthat
RUN Rscript -e 'source("http://bioconductor.org/biocLite.R")' -e 'biocLite("biobroom")'
RUN Rscript -e 'source("http://bioconductor.org/biocLite.R")' -e 'biocLite("limma")'
RUN Rscript -e 'source("http://bioconductor.org/biocLite.R")' -e 'biocLite("vsn")'
#   tidyverse \
RUN apt-get install libghc-zlib-dev -y 
RUN Rscript -e 'source("http://bioconductor.org/biocLite.R")' -e 'biocLite("vsn")'
RUN apt-get install libnetcdf-dev -y 
RUN apt-get install libxml2-dev  -y 
RUN install2.r --error \ 
  XML
RUN Rscript -e 'source("http://bioconductor.org/biocLite.R")' -e 'biocLite("MSnbase")'
RUN install2.r --error \ 
  gplots ggplot2
RUN apt-get install openssl libssl-dev -y 
RUN install2.r --error \ 
  fdrtool httr tidyverse
RUN apt-get install pandoc pandoc-citeproc -y 
RUN cd /tmp \
 && curl -s https://codeload.github.com/coreforlife/c4lProteomics/zip/master \
 > c4lProteomics.zip && unzip c4lProteomics.zip 
RUN install2.r --error \ 
  devtools
RUN Rscript -e 'library(devtools); install_github("protViz/SRMService")'
RUN apt-get install texlive-full -y 
RUN cd /tmp/c4lProteomics-master \
 && R CMD build ProteomeQR  
RUN  cd /tmp/c4lProteomics-master && R CMD INSTALL ProteomeQR*.gz 
RUN apt-get install firefox-esr  -y 
