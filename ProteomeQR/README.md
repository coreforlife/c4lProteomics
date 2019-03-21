# Common Intrest 

- share running Rmd scripts and apply it on different data, e.g., EMBL TMT yeast, FGCZ 2grp,
(running means at least inside a Docker environment). The input can be a MaxQuant protein-groups.txt file.

## Download current R package

includes built vignettes

http://fgcz-ms.uzh.ch/~cpanse/ProteomeQR_0.0.1.tar.gz

or install it on your R environment

run R and type

```{r}
install.packages('http://fgcz-ms.uzh.ch/~cpanse/ProteomeQR_0.0.1.tar.gz', repo=NULL)
```

to browse the reports type:
```{r}
browseVignettes('ProteomeQR')
```


## Build the R package yourself

```
git clone https://github.com/coreforlife/c4lProteomics \
cd c4lProteomics \
&& R CMD build ProteomeQR 
```

or direct from Github

```{r}

if (!requireNamespace("BiocManager", quietly = TRUE))
    install.packages("BiocManager")

# wont build the vignettes
BiocManager::install("coreforlife/c4lProteomics/ProteomeQR")  
```
