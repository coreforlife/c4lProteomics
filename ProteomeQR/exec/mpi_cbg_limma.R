#!/usr/bin/env Rscript

#' # Differential abundance analysis
#'
#' Created by: `r system("whoami", intern=T)`
#'
#' Created at: `r format(Sys.Date(), format="%B %d %Y")`


#-----------------------------------------------------------------------------------------------------------------------
#+ include=FALSE
suppressMessages(require(docopt))

doc = '
Perform a differential gene expression analysis using limma and edgeR
Usage: mpi_cbg_limma.R [options] <count_matrix> <design_matrix> <data_prep_folder>

Options:
--contrasts=<tab_delim_table>   Table with sample pairs for which dge analysis should be performed
--design <formula>              Design fomula [default: condition]
--qcutoff <qcutoff>             Specify q-value cutoff [default: 0.01]
--pcutoff <pcutoff>             Override q-value filter and filter by set p-value instead
--out <name_prefix>             Name to prefix all generated result files [default: ]
--lfc <lfc_cutoff>              Just report genes with abs(lfc) > lfc_cutoff as hits [default: 1.0]
'

opts = docopt(doc, commandArgs(TRUE))

#-----------------------------------------------------------------------------------------------------------------------
devtools::source_url("https://git.mpi-cbg.de/bioinfo/datautils/raw/v1.49/R/core_commons.R")
devtools::source_url("https://git.mpi-cbg.de/bioinfo/datautils/raw/v1.49/R/ggplot_commons.R")
devtools::source_url("https://git.mpi-cbg.de/bioinfo/ngs_tools/raw/v10/dge_workflow/diffex_commons.R")
install_package("cummeRbund")
load_pack(knitr)
load_pack(gridExtra)
load_pack(limma)
load_pack(edgeR)
load_pack(GGally)
load_pack(corrplot)
load_pack(d3heatmap)
load_pack(limma)
load_pack(edgeR)


#-----------------------------------------------------------------------------------------------------------------------
results_prefix = "limma"


## process input arguments
count_matrix_file = opts$count_matrix
design_matrix_file = opts$design_matrix
contrasts_file = opts$contrasts
protein_info_file = opts$protein_info
ms_data_infos = opts$data_prep_folder
assert(is.null(protein_info_file) || file.exists(protein_info_file), "invalid protein_info_file")


designFormula = opts$design
assert(str_detect(designFormula, "^condition.*")) ## make sure that the condition comes before all batch factors


if (!is.null(opts$out)){  results_prefix = opts$out }

pcutoff = if (is.null(opts$pcutoff))NULL else as.numeric(opts$pcutoff)
qcutoff = if (is.numeric(pcutoff))NULL else as.numeric(opts$qcutoff)
if (is.numeric(pcutoff))opts$qcutoff = NULL

lfc_cutoff = if (is.null(opts$lfc))0 else as.numeric(opts$lfc)


#' Run configuration was
vec_as_df(unlist(opts)) %>%
    filter(! str_detect(name, "^[<-]")) %>%
    kable()

#'
#' <br><br>
#'
#-----------------------------------------------------------------
#' ## Data Preparation

#'
#' <br>
#'
#' experimental design:
expDesign = read_tsv(design_matrix_file)
kable(expDesign)

#'
#' <br><br>
#'
#'  count matrix:
countData = read_tsv(count_matrix_file) %T>% glimpse

if(!str_detect(expDesign$replicate, paste0(colnames(countData), sep = "|"))) { stop("ATTENTION: sample names of the count matrix and exp_design do not match") }


# import protein information
prot_info <- file.path(ms_data_infos, "data_prep.feature_information.txt")
if (file.exists(prot_info)) {
    protein_info <- read_tsv(prot_info)
} else {
    protein_info = distinct(countData, protein_ids)
}

#'
#' <br><br>
#'
#' contrasts
## set contrast with comparison of each condition against each if not specified otherwise:
if (! is.null(contrasts_file)) {
    contrasts = read_tsv(contrasts_file)
}else {
    contrasts = select(expDesign, condition) %>% distinct %>%
        merge(., ., suffixes = c("_1", "_2"), by = NULL) %>%
        filter(ac(condition_1) > ac(condition_2))
    # write_tsv(contrasts, paste(resultsBase, "contrasts.txt"))
}

kable(contrasts)

#'
#' <br><br>
#'
#-----------------------------------------------------------------
#' ## QC, Normalization and Preprocessing

## report sample features, i.e. total measurements > 0 and total LFQ intensities per sample

#' ### Sample statistics

cdLong = gather(countData, sample, expr, -protein_ids)

p1 <- cdLong %>% filter(expr > 0) %>%
    ggplot(aes(sample)) +
    geom_bar() +
    coord_flip() +
    geom_hline(yintercept = length(unique(cdLong$protein_ids)), color = "coral1") +
    ggtitle("measurements > 0 per samples")

p2 <- cdLong %>%
    group_by(sample) %>%
    summarize(total = sum(expr)) %>%
    ggplot(aes(sample, weight = total)) +
    geom_bar() +
    coord_flip() +
    ylab("total LFQ intensities") +
    ggtitle("total LFQ intensities per sample")

grid.arrange(p1, p2, nrow = 1)


# create abundance matrix and remove rows with missing values
expMatrix = countData %>%
    column_to_rownames("protein_ids") %>%
    as.matrix


# remove rows with rowSums == 0
# to remove non-zero rows slightly changes the results
all_rows <- expMatrix %>% nrow()
expMatrix <- expMatrix[rowSums(expMatrix) > 0, ]
non_zero_rows <- expMatrix %>% nrow()

if(all_rows != non_zero_rows){print(paste0(all_rows-non_zero_rows, " rows contained zero intensities across all samples and were removed"))}

expMatrix = expMatrix[complete.cases(expMatrix),]


#'
#' <br><br>
#'
#' ### Principal component analysis
group_labels = data_frame(replicate = colnames(expMatrix)) %>%
    left_join(expDesign) %>%
    pull(condition)
names(group_labels) = colnames(expMatrix)
makePcaPlot(t(expMatrix), color_by = group_labels, title = "PCA of quantifiable proteins in all conditions")

mydata.pca = prcomp(t(expMatrix), retx = TRUE, center = TRUE, scale. = FALSE)

data.frame(var = mydata.pca$sdev^2) %>%
    mutate(prop_var = 1/sum(mydata.pca$sdev^2)*var,
    pc_num = 1:n()) %>%
    ggplot(aes(pc_num, prop_var)) + geom_col() +
    xlab("principal component number") +
    ylab("proportion of explained variance") +
    ggtitle("proportion of variance explained by the individual components")


pcs = mydata.pca$x %>% as_df %>% rownames_to_column("sample")
my_dens <- function(data, mapping, ...) {
    ggplot(data = data, mapping=mapping) +
    geom_density(..., alpha = 0.7, color = NA)
}
pcs %>% GGally::ggpairs(columns=2:6, mapping=ggplot2::aes(fill=group_labels, color=group_labels), upper="blank", legend=c(3,3), diag = list(continuous = my_dens)) + theme(legend.position = "bottom") + theme(axis.text.x = element_text(angle = 45, hjust = 1))


#'
#' <br><br>
#'
#' ### Spearman correlation
correlation = cor(expMatrix, method = "spearman")
col<- colorRampPalette(c("coral1", "white", "cadetblue"))(20)
# col2<- colorRampPalette(c("coral1", "white", "cadetblue"))(20)
corrplot(correlation, col = col, title = "Spearman correlation between conditions", mar=c(0,0,2,0), tl.col="black")


#'
#' <br><br>
#'
#' ### Euclidean distance
#distMatrix %>% d3heatmap(xaxis_height=1, Colv = T, dendrogram="row")
distMatrix = as.matrix(dist(t(expMatrix)))
distMatrix %>% d3heatmap(xaxis_height = 1, color = col)

#'
#' <br><br>
#'
#-----------------------------------------------------
#' ## Data normalization

orderMatcheExpDesign = data_frame(replicate = colnames(expMatrix)) %>%
    mutate(col_index = row_number()) %>%
    right_join(expDesign, by = "replicate") %>%
    arrange(col_index)

#' Build design matrix
#' > A key strength of limma’s linear modelling approach, is the ability accommodate arbitrary experimental complexity. Simple designs, such as the one in this workflow, with cell type and batch, through to more complicated factorial designs and models with interaction terms can be handled relatively easily
#'
#' Make sure that non of the batch-factors  is confounded with treatment (condition). See https://support.bioconductor.org/p/39385/ for a discussion
#' References
#' * https://f1000research.com/articles/5-1408/v1

# design <- orderMatcheExpDesign %$% model.matrix(~ 0 +  condition + prep_day)
design = orderMatcheExpDesign %$% model.matrix(formula(as.formula(paste("~0+", designFormula))))
rownames(design) <- orderMatcheExpDesign$replicate


## create a DGEList object:
exp_study = DGEList(counts = expMatrix, group = orderMatcheExpDesign$condition)

# par(mfrow=c(1,2)) ## 2panel plot for mean-var relationship before and after boom

# Removing heteroscedasticity from count data
## transform count data to log2 CPM, estimate the mean-variance relationship and compute appropiate observational-level weights with voom:
voomNorm <- voom(exp_study, design, plot = FALSE, save.plot = TRUE)
# str(voomNorm)
# exp_study$counts is equilvaent to voomNorm$E see https://www.bioconductor.org/help/workflows/RNAseq123/


# identical (names(voomNorm$voom.xy$x), names(voomNorm$voom.xy$y))
voom_before <- data.frame(protein_ids = names(voomNorm$voom.xy$x), x = unname(voomNorm$voom.xy$x), y = unname(voomNorm$voom.xy$y),
    line_x = voomNorm$voom.line$x, line_y = voomNorm$voom.line$y)

voom_before %>% ggplot(aes(x, y)) +
    geom_point(size = 1) +
    geom_line(aes(line_x, line_y), color = "red") +
    ggtitle("voom: mean-variance trend") +
    xlab("log2(count + 0.5)") +
    ylab("sqrt(standard deviation)")

if (is.null(protein_info_file)){
    voom_before %<>%
        select(x, y, protein_ids) %>%
        arrange(x,y)
    # voom_before %>% DT::datatable()
    voom_before %>% table_browser()
} else {
    voom_before %<>%
        left_join(protein_info, by = "protein_ids") %>%
        select(x, y, gene_name, protein_acc) %>%
        arrange(x,y)
    # voom_before %>% DT::datatable()
    voom_before %>% table_browser()
}


## get log2 normalized expression values
voomMat = voomNorm$E
group_labels = data_frame(replicate = colnames(voomMat)) %>%
    left_join(expDesign) %>%
    pull(condition)
names(group_labels) = colnames(voomMat)
makePcaPlot(t(voomMat), color_by = group_labels, title = "Normalized PCA of quantifiable proteins in all conditions")


#' Corrleate normalized data with raw expression
inner_join(expr_matrix_to_df(expMatrix) , expr_matrix_to_df(voomNorm$E), suffix = c("_raw", "_voom"), by = c("gene_id", "replicate")) %>%
    sample_frac(0.1) %>%
    ggplot(aes(expression_raw, expression_voom)) +
    geom_point() +
    scale_x_log10() +
    ggtitle("voom vs raw")


contr.matrix = makeContrasts(contrasts = with(contrasts, paste0("condition", condition_1, "-", "condition", condition_2)), levels = colnames(design))


#' ## Model Fitting & Moderated t-test

#' Linear modelling in limma is carried out using the lmFit and contrasts.fit functions originally written for application to microarrays. The functions can be used for both microarray and RNA-seq data and fit a separate model to the expression values for each gene. Next, empirical Bayes moderation is carried out by borrowing information across all the genes to obtain more precise estimates of gene-wise variability  (source: RNAseq123)
vfit <- lmFit(voomNorm, design)
vfit <- contrasts.fit(vfit, contrasts = contr.matrix)
efit <- eBayes(vfit)
#TODO: check for alternatives, e.g. linear-mixed models (https://bioconductor.org/packages/release/bioc/vignettes/variancePartition/inst/doc/dream.html)

voom_after <- data.frame(protein_ids = names(efit$Amean), x = unname(efit$Amean), y = sqrt(efit$sigma))

# plotSA(efit, main = "Final model: Mean−variance trend")
voom_after %>% ggplot(aes(x, y)) +
    geom_point(size = 1) +
    geom_hline(yintercept = sqrt(sqrt(efit$s2.prior)), color = "red") +
    ggtitle("final model: mean-variance trend") +
    xlab("average log-abundance") +
    ylab("sqrt(sigma)")


if (is.null(protein_info_file)){
    voom_after %<>%
        select(x, y, protein_ids) %>%
        arrange(x,y)
    # voom_after %>% DT::datatable()
    voom_after %>% table_browser()
} else {
    voom_after %<>%
        left_join(protein_info, by = "protein_ids") %>%
        select(x, y, gene_name, protein_acc) %>%
        arrange(x,y)
    # voom_after %>% DT::datatable()
    voom_after %>% table_browser()
}



#'
#' <br><br>
#'
#' ### Differential abundance results without lfc cutoff (adjusted p-value cutoff = 0.05)
summary(decideTests(efit)) %>% as_df %>% kable

#'
#' <br><br>
#'
#' ### Differential abundance results with lfc cutoff (adjusted p-value cutoff = 0.05)
#' Some studies require more than an adjusted p-value cut-off. For a stricter definition on significance, one may require log-fold-changes (log-FCs) to be above a minimum value. The treat method (McCarthy and Smyth 2009) can be used to calculate p-values from empirical Bayes moderated t-statistics with a minimum log-FC requirement.


tfit <- treat(vfit, lfc = lfc_cutoff)
dt <- decideTests(tfit)
summary(dt) %>% as_df %>% kable


#' plot MA per contrast
numContrasts = length(colnames(tfit))
par(mfrow=c(1,1))
# par(mfrow = c(4, numContrasts)) ## 2panel plot for mean-var relationship before and after boom
# colnames(tfit) %>% iwalk(~ plotMD(tfit, column=.y, status=dt[,.y], main=.x, xlim=c(-8,13)))
colnames(tfit) %>% iwalk(~ plotMD(tfit, column = .y, status = dt[, .y], main = .x, col = c("coral1", "cadetblue")))



# basal.vs.lp <- topTreat(tfit, coef=2, n=Inf)
deResults = colnames(contr.matrix) %>%
    imap(function(contrast, cIndex){
        #DEBUG contrast="conditione12-conditione16"; cIndex=1
        topTreat(tfit, coef = cIndex, n = Inf) %>%
            as.data.frame() %>%
            rownames_to_column("protein_ids") %>%
            mutate(contrast = str_replace_all(contrast, "condition", "")) %>%
            separate(contrast, c("condition_1", "condition_2"), "-") %>%
        # push_left("contrast") %>%
            pretty_columns
    }) %>%
    bind_rows()



## calculate sample means
# https://support.bioconductor.org/p/62541/

sampleMeans = voomNorm$E %>%
    as_df %>%
    rownames_to_column("protein_ids") %>%
    tbl_df %>%
    gather(replicate, norm_count, -protein_ids) %>%
    left_join(expDesign) %>%
    group_by(protein_ids, condition) %>%
    summarize(mean_expr = mean(norm_count, na.rm = T)) %>%
    ungroup() %>%
    inner_join(., ., by = "protein_ids", suffix = c("_1", "_2")) #%>%


deResults %<>% left_join(sampleMeans)



if (! is.null(qcutoff)) {
    echo("Using q-value cutoff of", qcutoff)
}else {
    echo("Using p-value cutoff of", pcutoff)
}



# report hit criterion
#+ results='asis'
if (! is.null(qcutoff)) {
    deResults %<>% transform(is_hit = adj_p_val <= qcutoff)
}else {
    deResults %<>% transform(is_hit = p_value <= pcutoff)
}


#+
deResults %<>% mutate(c1_overex = logfc > 0)

deResults %>%
    count(condition_1, condition_2, is_hit) %>%
    filter(is_hit)

## Annotate results
deAnnot = deResults %>% left_join(protein_info, by = "protein_ids")

order_info <- file.path(ms_data_infos, "data_prep.reorder_information.txt")
if (file.exists(order_info)) {
    od <- read_tsv(order_info)
    deAnnot %<>% mutate(reordered = protein_ids %in% od$protein_ids)
}

ident_info <- file.path(ms_data_infos, "data_prep.ident_types_summary.txt")
if (file.exists(ident_info)) {
    ident <- read_tsv(ident_info)
    if (any(!expDesign$condition %in% ident$coi)) { stop("ATTENTION: conditions of the provided exp_design do not match with conditions of the identification type information") }
    deAnnot %<>%
    left_join(ident %>% rename(c1_ident = ms_ms_prop), by = c("protein_ids", "condition_1" = "coi")) %>%
    left_join(ident %>% rename(c2_ident = ms_ms_prop), by = c("protein_ids", "condition_2" = "coi")) %>%
        mutate(c1_ident = ifelse(is.na(c1_ident), 0, c1_ident) %>% round(., 2), c2_ident = ifelse(is.na(c2_ident), 0, c2_ident) %>% round(., 2))
}



## Extract hits from deseq results
degs = deAnnot %>% filter(is_hit)

#' ### Differential abundance results with lfc and adjusted p-value cutoff
if(nrow(degs)>0){
    degs %>%
        count(condition_1, condition_2, c1_overex) %>%
        mutate(c1_overex = ifelse(c1_overex, ("Up in condition_1"), "Down in condition_1")) %>%
        spread(c1_overex, n) %>%
        kable()
} else {
    print("no differentially abundant proteins found")
}

#'
#'<br>
#'
imp_info <- file.path(ms_data_infos, "data_prep.imputation_info.txt")
if (file.exists(ident_info)) {
    imp <- read_tsv(imp_info)

    # extract which condition is reported in the de_results
    d <- gather(imp, feature, value, -intensity) %>% filter(value %in% unique(deAnnot$condition_1)) %$% feature %>% unique()

    imp <- imp[,colnames(imp) %in% c("protein_ids", "is_imputed", d)] %>%
    push_left(c("protein_ids", "is_imputed"))
    colnames(imp)[3] <- "condition"

    imp %<>% group_by(protein_ids, condition) %>%
        summarize(is_imputed = any(is_imputed == TRUE))

    deAnnot %<>%
        left_join(imp %>% rename(c1_imp = is_imputed), by = c("protein_ids", "condition_1" = "condition")) %>%
        left_join(imp %>% rename(c2_imp = is_imputed), by = c("protein_ids", "condition_2" = "condition"))
}


########################################################################################################################
#' ## Results & Discussion



#' Are log2 distributions symmetric around 0 (because of globally we'd expect no change in abundance)
deResults %>% ggplot(aes(logfc)) +
    geom_histogram() +
    facet_grid(condition_1 ~ condition_2) +
    geom_vline(xintercept = 0, color = "blue") +
# xlim(-2,2) +
    ggtitle("condition_1 over condition_2 logFC ")


if (nrow(degs) > 0){
    ggplot(degs, aes(paste(condition_1, "vs", condition_2), fill = (c1_overex))) +
        geom_bar() +
        xlab(NULL) +
        ylab("No. of differentially abundant proteins") +
        ggtitle("Results by contrast") +
        coord_flip() +
        scale_fill_manual(values=c("coral1", "cadetblue"))
}


#with(degs, as.data.frame(table(condition_1, condition_2, c1_overex))) %>% filter(Freq >0) %>% kable()

maxX = quantile(deResults$logfc, c(0.005, 0.99), na.rm = TRUE) %>%
    abs %>%
    max
maxY = quantile(log10(deResults$p_value), c(0.005, 0.99), na.rm = TRUE) %>%
    abs %>%
    max

hitCounts = filter(deResults, is_hit) %>%
    count(condition_1, condition_2, c1_overex) %>%
    rename(hits = n) %>%
    merge(data.frame(c1_overex = c(F, T), x_pos = c(- maxX * 0.9, maxX * 0.9)))



de_plot <- deResults %>% ggplot(aes(logfc, - log10(p_value), color = is_hit)) +
    geom_jitter(alpha = 0.2, position = position_jitter(height = 0.2)) +
#    theme_bw() +
    xlim(- 3, 3) +
    scale_color_manual(values = c("TRUE" = "coral1", "FALSE" = "black")) +
#    ggtitle("Insm1/Ctrl") +
## http://stackoverflow.com/questions/19764968/remove-point-transparency-in-ggplot2-legend
    guides(colour = guide_legend(override.aes = list(alpha = 1))) +
## tweak axis labels
    xlab(expression(log[2]("condition_1/condition_2"))) +
    ylab(expression(- log[10]("p value"))) +
    xlim(- maxX, maxX) +
    ylim(0, maxY)


#+ fig.width=16, fig.height=14
if (nrow(degs) == 0){
    de_plot +
    facet_grid(condition_1 ~ condition_2)
} else {
    ## add hit couts
    de_plot + geom_text(aes(label = hits, x = x_pos), y = maxY * 0.9, color = "coral1", size = 10, data = hitCounts) +
    facet_grid(condition_1 ~ condition_2)
}



########################################################################################################################
#' ## Export results

write_tsv(deAnnot, path = add_prefix("da_results.txt"))

if (nrow(degs) > 0) {
    deAnnot %>% filter(is_hit) %>% write_tsv(add_prefix("diff_proteins.txt"))

    deAnnot %>% filter(is_hit) %>%
        transmute(protein_ids, contrast = paste(condition_1, "vs", condition_2)) %>%
        write_tsv(add_prefix("daps_by_contrast.txt"))

    deAnnot %>% filter(is_hit) %>%
        transmute(protein_ids, contrast = paste(condition_1, if_else(c1_overex, ">", "<"), condition_2)) %>%
        write_tsv(add_prefix("daps_by_contrast_directed.txt"))
}


#' Export voom normalization scores per replicate
voomNorm$E %>%
    as_df %>%
    rownames_to_column("protein_ids") %>%
    left_join(protein_info) %>%
# push_left(c("gene_name", "gene_description")) %>%
    write_tsv(add_prefix("norm_abundance_by_replicate.txt"))


# Also average voom normalized expression scores per condition and export
voomNorm$E %>%
    as_df %>%
    rownames_to_column("protein_ids") %>%
    gather(replicate, norm_expr, - protein_ids) %>%
    inner_join(expDesign, by = "replicate") %>%
    group_by(condition, protein_ids) %>%
    summarize(mean_norm_expr = mean(norm_expr)) %>%
    left_join(protein_info) %>%
# push_left(c("gene_name", "gene_description")) %>%
    write_tsv(add_prefix("norm_abundance_by_condition.txt"))

left_join(voom_before %>% rename(x_voom = x, y_voom = y),
    voom_after %>% rename(x_final = x, y_final = y)) %>%
    push_left(c("x_final", "y_final")) %>%
    write_tsv("model_prot_positions.txt")


#' | File | Description |
#' |------|------|
#' | [limma.diff_proteins.txt](limma.diff_proteins.txt) | list of all differentially abundant protein groups from the limma analysis - That's the file you are most likely looking for! |
#' | [limma.da_results.txt](limma.da_results.txt) | list of all protein groups from the limma analysis |
#' | [limma.geneInfo.txt](limma.geneInfo.txt) | general gene information  |
#'

#-----------------------------------------------------------------------------------------------------------------------
# get R version and package infos
writeLines(capture.output(devtools::session_info()), ".sessionInfo.txt")

session::save.session(".ms_limma.R.dat");
# session::restore.session(".ms_limma.R.dat")

