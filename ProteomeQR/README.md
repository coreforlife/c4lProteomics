# Common Intrest 

- share running scripts Rmd scripts (MaxQuant LFQ) and apply it on different data, e.g., embl TMT yeast.
(running means at least in a Docker enviroment)

## Compose R package

https://github.com/coreforlife/c4lProteomics/tree/master/ProteomeQR

```{r}
R CMD build ProteomeQR
R CMD INSTALL ProteomeQR_0.0.1.tar.gz 
```

or direct from github
```{r}

if (!requireNamespace("BiocManager", quietly = TRUE))
    install.packages("BiocManager")

# wont build the vignettes
BiocManager::install("coreforlife/c4lProteomics/ProteomeQR")  
```

run R and type

```{r}
browseVignettes('ProteomeQR')
```
