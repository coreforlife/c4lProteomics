#!/usr/bin/env bash


## set up required tool ------------------------------------------------------------------------------------------------

## download and set up shall-wrapper for rmarkdown::render (https://git.mpi-cbg.de/bioinfo/datautils/tree/master/tools/rendr)
targetDirectory=`pwd`
mkdir -p $targetDirectory
#wget -NP $targetDirectory --no-check-certificate https://git.mpi-cbg.de/bioinfo/datautils/raw/master/tools/rendr/rend.R
chmod +x $targetDirectory/rend.R
#echo 'export PATH='"$targetDirectory"':$PATH' >> ~/.bash_profile



## define directories --------------------------------------------------------------------------------------------------

#TODO: define location of the c4lProteomics repository and data folder where you would like to store the output

export REPO_FOLDER=~/__checkouts/c4lProteomics/
export RESULTS_FOLDER=~/__checkouts/c4lProteomics/ProteomeQR/exec/outout


export PRJ_DATA="${REPO_FOLDER}/ProteomeQR/inst/extdata/mpi-cbg"
export PRJ_SCRIPTS="${REPO_FOLDER}/ProteomeQR/R"

ls "${PRJ_DATA}" "${PRJ_SCRIPTS}" >/dev/null || { echo "not all project resources are well defined" 1>&2; exit 1; }





## ms data pre-processing ----------------------------------------------------------------------------------------------

mkdir ${RESULTS_FOLDER} && cd "$_"


## create experimental design file
Rscript - <<"EOF"
devtools::source_url("https://git.mpi-cbg.de/bioinfo/datautils/raw/v1.49/R/core_commons.R")

data <- read_tsv(file.path(Sys.getenv("PRJ_DATA"), "proteinGroups.txt")) %>% pretty_columns() %>% as.data.frame() %>%
    select(starts_with("lfq_intensity_"))


design <- data.frame(replicate = str_replace(colnames(data), "lfq_intensity_", "")) %>%
    transmute(condition = str_replace(replicate, "_r[1-3]$", ""), replicate)

write_tsv(design, "exp_design.txt")
EOF


## run data pre-processing step
## required input: path to the folder which contains the proteinGroups.txt file and the experimental design file
set -x 
~/__checkouts/c4lProteomics/ProteomeQR/exec/rend.R -e --toc ${PRJ_SCRIPTS}/mpi_cbg_data_prep.R ${PRJ_DATA} exp_design.txt
set +x


## run differential abundance analysis
mkdir limma && cd "$_"

## required input: imputed intensities (output from the pre-processing), the experimental design file and the path to the pre-processing output
~/__checkouts/c4lProteomics/ProteomeQR/exec/rend.R -e --toc ${PRJ_SCRIPTS}/mpi_cbg_limma.R --lfc 0 ../data_prep.intens_imputed.txt ../exp_design.txt ../
