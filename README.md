# c4lProteomics


## Goal

- collect `bash` or `R` code snippets of interest for all [c4l](https://coreforlife.eu/) sites, e.g., instrument queue generator and future hackathons

## Design policy for R code snippets /  packages

- comes with documentation how to use and integrate into the system
- tiny example data
- should pass `R CMD check ProteomeQR` with 0 NOTES, WARNINGS and ERRORS
- if possible import is minimalistic, no Bioconductor or long chains of package dependencies 
