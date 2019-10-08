#!/usr/bin/env Rscript

#' # Preprocessing of mass spec data
#' Objective: Extract an abundance matrix to be used as input for limma.
#'
#' Created by: `r system("whoami", intern=T)`
#'
#' Created at: `r format(Sys.Date(), format="%B %d %Y")`

#-----------------------------------------------------------------------------------------------------------------------

#+ include=FALSE
suppressMessages(require(docopt))

doc = '
Prepare mass spec data for differential abundance analysis
Usage: mpi_cbg_data_prep.R [options] <ms_data_folder> <design_file>

Options:
--renaming_scheme <file>    Table with two columns with the "old" and "new" names
--data_type <data_type>    Which data type (i.e. raw or lfq) to use for the analysis [default: lfq]
--design <design>     Column of the design_file with describes the variable of interest for summarizing the identification type information [default: condition]
'


opts = docopt(doc, commandArgs(TRUE))

#-----------------------------------------------------------------------------------------------------------------------
devtools::source_url("https://git.mpi-cbg.de/bioinfo/datautils/raw/v1.49/R/core_commons.R")
library(knitr)
library(gridExtra)


is_control = function(protein_ids){
    str_detect(protein_ids, "^CON__") | str_detect(protein_ids, "^REV__") | str_detect(protein_ids, fixed("ST|RTSTANDARD"))
}

newNames <- function(oldN) {
    renamingScheme[which(renamingScheme$old == oldN),]$new
}

impute_some = function(data, fun=mean, max_na=0.4) if(sum(is.na(data))/length(data)<=max_na)  Hmisc::impute(data, fun=fun) else data


#-----------------------------------------------------------------------------------------------------------------------
results_prefix="data_prep"


## load data and export information on file names
ms_data_folder <- opts$ms_data_folder
renaming_scheme <- opts$renaming_scheme
design_file <- opts$design_file
data_type <- opts$data_type
design <- opts$design


## read in MaxQuant output files (for analysis on protein level: "proteinGroups.txt") and reformat the data
mqTxtFiles = list.files(ms_data_folder, "proteinGroups", full=TRUE)

perBatch = mqTxtFiles %>%
    map(~ read_tsv(.x) %>% pretty_columns() %>%
        select(protein_ids, fasta_headers, matches("^lfq_intensity"), matches("^identification_type"), matches("^intensity_"))) %>%
    setNames(basename(mqTxtFiles))



## load renaming scheme
if (is.null(renaming_scheme)){
    orig_names <- perBatch %>% map(~select(.x, starts_with("lfq_intensity")) %>% colnames()) %>% unlist(use.names = FALSE) %>% str_replace(., "lfq_intensity_", "")
    renamingScheme <- data.frame(old = orig_names, new = orig_names)
} else {
    if (str_detect(renaming_scheme, ".xls")) {
        renamingScheme <- read_xlsx(renaming_scheme)
    } else {
        renamingScheme <- read_tsv(renaming_scheme)
    }
}



## load design_file
expDesign <- read_tsv(design_file)
if (all(expDesign$replicate != renamingScheme$new)) {stop("ATTENTION: replicates of contrast and design file do not match")}


# list input arguments
vec_as_df(unlist(opts)) %>%
    filter(! str_detect(name, "^[<-]")) %>%
    rbind(c("input_file_num", length(mqTxtFiles))) %>%
    kable()


#'
#' <br>
#'
#' renaming scheme:

if (is.null(renaming_scheme)){ print("Original naming kept; renaming scheme was not provided") }
renamingScheme %>% setNames(c("old names", "new names")) %>% kable()




# sort protein IDs
perBatch %<>% map(~ rowwise(.x) %>% mutate(old_protein_ids = protein_ids, protein_ids = paste(sort(unlist(str_split(protein_ids, ";"))), collapse = ";")))

# export information on whether protein groups order was changed or not (only keep information on any newly ordered protein group irrespective of the sample)
perBatch %>% map_df(~ filter(.x, protein_ids != old_protein_ids), .id = 'GROUP') %>%
    distinct(protein_ids) %>% mutate(reordered = TRUE) %>%
    write_tsv(paste0(results_prefix, ".reorder_information.txt"))


#'
#' <br>
#'
#' ## File level information

perBatch %>% map_df(~ select(.x, starts_with("LFQ_intensity")) %$% paste0(str_replace(colnames(.), "lfq_intensity_", ""), collapse = "; ")) %>% gather(file, samples) %>% kable()


# collect raw and lfq intensities of STANDARDs
contr_data <- perBatch %>% map_df(~ filter(.x, str_detect(protein_ids, "RTSTANDARD")), .id = 'GROUP') %>% select(-old_protein_ids)


# select intensities type, i.e. raw or lfq for further analysis
if (data_type == "lfq") {

    perBatch %<>% map(~ select(.x, -starts_with("intensity")))
    perBatch <- sapply(names(perBatch), function(x){
        data <- as.data.frame(perBatch[x])
        colnames(data) %<>% str_replace(., "lfq_", "")
        prot_col <- data %>% select(contains(".protein_ids")) %>% colnames()
        sample <- str_replace(prot_col, ".protein_ids", "")
        colnames(data) %<>% str_replace(., paste0(sample, "."), "")
        data %>% tbl_df()
    }, simplify = FALSE, USE.NAMES = TRUE)

} else if (data_type == "raw") {
    perBatch %<>% map(~ select(.x, -starts_with("lfq_intensity")))
} else {
    stop("ATTENTION: unknown data type requested; valid data types are raw and lfq")
}


#'
#' <br>
#'
#' ### Unique and ambiguous entries per file, i.e. one or multiple protein IDs
## collect information about lines per file and whether the entries are related to proteins, "scrap" and or unique or ambiguous entries
init_stat <- perBatch %>% map_df(~ mutate(.x,
    unique_entry = !str_detect(protein_ids, ";") & !str_detect(protein_ids, "CON__|REV__|RTSTANDARD"),
    ambiguous_entry = str_detect(protein_ids, ";") & !str_detect(protein_ids, "CON__|REV__|RTSTANDARD"),
    scrap_prop_unique = !str_detect(protein_ids, ";") & str_detect(protein_ids, "CON__|REV__|RTSTANDARD"),
    scrap_prop_ambiguous = str_detect(protein_ids, ";") & str_detect(protein_ids, "CON__|REV__|RTSTANDARD")
    ), .id = 'GROUP')


#' Examples for unique and ambiguous entries
init_stat %>% gather(feature, direction, unique_entry:scrap_prop_ambiguous) %>% filter(direction) %>% group_by(feature) %>% slice(1) %>% select(feature, protein_ids)


# extract information on protein IDs which shall be removed later
scrap_ids <- init_stat %>% gather(feature, direction, unique_entry:scrap_prop_ambiguous) %>% filter(direction) %>% filter(feature == "scrap_prop_unique" | feature == "scrap_prop_ambiguous") %>% select(protein_ids) %>% mutate(single_entries = str_split(protein_ids, ";")) %>% unnest(single_entries) %>%
    group_by(protein_ids) %>%
    mutate(all_scrap = sum(str_detect(single_entries, "CON__|REV__|RTSTANDARD")) == n()) %>%
    ungroup() %>%
    select(-single_entries) %>%
    distinct_all(protein_ids) %>%
    filter(all_scrap) %$% protein_ids


#'
#' <br>
#'
#' Summary of unique and ambiguous samples per input file
# export numeric summary as table
init_stat %>% group_by(., GROUP) %>% summarize(total_entries = n(), unique_entries = sum(unique_entry) + sum(scrap_prop_unique), ambiguous_entries = sum(ambiguous_entry) + sum(scrap_prop_ambiguous)) %>% kable()

init_stat %>% select(GROUP, unique_entry, ambiguous_entry, scrap_prop_unique, scrap_prop_ambiguous) %>% gather(feature, direction, -GROUP) %>%
        group_by(GROUP, feature) %>% summarize(count = sum(direction)) %>%
        ggplot(aes(GROUP, count, fill = feature)) +
            geom_col() +
            coord_flip() +
            theme(legend.title=element_blank()) + xlab("") +
            scale_fill_manual(values=c("coral3", "coral1", "cadetblue3", "cadetblue"))


# extract information on intensities for the different entry categories per sample
oldNames <- str_c(renamingScheme$old, collapse = "|")

init_stat_plot <- init_stat %>% select(GROUP, unique_entry, ambiguous_entry, scrap_prop_unique, scrap_prop_ambiguous, matches("intensity")) %>%
    gather(sample, intensity, -c(GROUP, unique_entry, ambiguous_entry, scrap_prop_unique, scrap_prop_ambiguous)) %>%
    gather(feature, direction, unique_entry, ambiguous_entry, scrap_prop_unique, scrap_prop_ambiguous) %>%
    filter(direction) %>%
    mutate(sample = str_replace(sample, "intensity_", "") %>% str_replace_all(., oldNames, newNames),
    GROUP = str_replace(GROUP, ".proteinGroups.txt", "") %>% str_replace_all(., oldNames, newNames)) %>%
    na.omit()

#'
#' <br><br>
#'
#' ### Intensities of unique and ambiguous entries per file
init_stat_plot %>%
    ggplot(aes(feature, intensity+1, fill = feature)) +
        geom_boxplot() +
        # geom_violin() +
        scale_y_log10() +
        ylab("intensities") +
        theme(axis.text.x=element_blank(),axis.ticks.x=element_blank()) +
        # ggtitle("intensities per category accross all samples") +
        scale_fill_manual(values=c("coral3", "coral1", "cadetblue3", "cadetblue")) +
        facet_wrap(~GROUP)

#'
#' <br><br>
#'
#' ### Intensities of unique and ambiguous entries per sample
init_stat_plot %>%
    ggplot(aes(feature, intensity+1, fill = feature)) +
    geom_boxplot() +
    scale_y_log10() +
    ylab("intensities") +
    theme(axis.text.x=element_blank(),axis.ticks.x=element_blank()) +
    scale_fill_manual(values=c("coral3", "coral1", "cadetblue3", "cadetblue")) +
    facet_wrap(~GROUP + sample)


#'
#' <br><br>
#'
#' ### Non-zero intensities of per sample
init_stat_plot %>% ggplot(aes(intensity, fill = feature, color = feature)) +
    geom_density(alpha = 0.2) +
    scale_x_log10() +
    xlab("intensities") +
    scale_fill_manual(values=c("coral3", "coral1", "cadetblue3", "cadetblue")) +
    scale_color_manual(values=c("coral3", "coral1", "cadetblue3", "cadetblue")) +
    facet_wrap(~GROUP + sample) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
    theme(panel.background = element_rect(fill = 'white', colour = 'grey'), panel.grid = element_line(color = "gray90"))


#'
#' <br><br>
#'
#' ### LFQ and raw intensities of STANDARDS on protein level
if (nrow(contr_data) > 0){

    contr_data %>% gather(sample, intensity, -c(GROUP, protein_ids, fasta_headers)) %>%
        mutate(feature = str_match(sample, "lfq_intensity|intensity")[,1],
            feature = case_when(feature == "intensity"~"raw intensity", feature == "lfq_intensity"~"lfq intensity"),
            sample = str_replace(sample, "lfq_intensity_|intensity_", ""),
            intensity = as.numeric(intensity)
        ) %>% ggplot(aes(feature, intensity)) + geom_boxplot()

} else {
    print("No standard information found")
}



#'
#' <br><br>
#'
#' ### LFQ and raw intensities of STANDARDS on peptide level
pepFiles <- list.files(ms_data_folder, pattern = "peptides.txt", full = TRUE)

if (!is_empty(pepFiles) & nrow(contr_data) > 0){

    std_info = pepFiles %>%
        map(~ read_tsv(.x) %>% pretty_columns() %>%
            select(proteins, sequence, matches("^intensity_"), matches("^intensity_")) %>%
            filter(str_detect(proteins, "STANDARD"))) %>%
        setNames(basename(pepFiles)) %>%
        map_df(~ gather(.x, feature, intensity, contains("intensity")) %>%
        separate(feature, c("type", "sample"), sep = "sity_"), .id = 'GROUP') %>%
        mutate(sample = str_replace_all(sample, oldNames, newNames), type = str_replace(type, "inten", "intensity"))

    print("STANDARD intensities on peptide level are available for the following samples:")
    unique(std_info$sample)


    std_info %>% ggplot(aes(sample, intensity, fill = type)) + geom_boxplot() + coord_flip()

    std_info %>%
        ggplot(aes(sample, sequence, fill = intensity)) + geom_tile() + facet_wrap(~type) +
        theme(axis.text.x = element_text(angle = 45, hjust = 1))

} else {
    print("Peptide level information were not provided or standard information were not found")
}




## extract all data in long table format, in case identification_type is know, add those information to the table and rename samples and export data for later annotation
sample_info <- perBatch %>% map_df(~ select(.x, -starts_with("identification_type")), .id = 'GROUP') %>% gather(sample, lfq, starts_with("intensity")) %>% mutate(sample = str_replace_all(sample, "intensity_", "")) %>% mutate(oldName = sample) %>% rename(file_name = GROUP) %>% mutate(gene_name = str_match(fasta_headers, "GN=([:alnum:]+)\\s+")[,2])

if (any(map(perBatch, ~colnames(.x) %>% str_detect(., "identification_type")) %>% unlist())) {
    sample_info <- perBatch %>% map_df(~ select(.x, -starts_with("intensity")), .id = 'GROUP') %>% gather(sample, identification_type, starts_with("identification_type")) %>% mutate(sample = str_replace_all(sample, "identification_type_", "")) %>% mutate(oldName = sample) %>% rename(file_name = GROUP) %>%
    right_join(sample_info, by = c("sample", "file_name", "oldName", "protein_ids", "old_protein_ids", "fasta_headers"))
    ident_types <- TRUE
}


sample_info$sample %<>% str_replace_all(., oldNames, newNames)
write_tsv(sample_info, paste0(results_prefix, ".feature_sample_information.txt"))

protein_info <- sample_info %>% distinct(protein_ids, fasta_headers) %>% group_by(protein_ids) %>%
    filter(max(nchar(fasta_headers))==nchar(fasta_headers)) %>% slice(1) %>% ungroup() %>%
    rowwise() %>%
    mutate(gene_name = paste(unlist(str_extract_all(fasta_headers, "GN=([:alnum:]+\\-?[:alnum:]?\\-?[:alnum:]?)")), collapse = "; ") %>% str_replace_all(., "GN=", ""),
        protein_acc = paste(unlist(str_extract_all(protein_ids, "[trsp]+\\|([:alnum:]+\\-?[:alnum:]?\\-?[:alnum:]?)")), collapse = "; ") %>% str_replace_all(., "sp|tr|[|]", ""))

write_tsv(protein_info, paste0(results_prefix, ".feature_information.txt"))


#'
#' <br><br>
#'
#' ### Number of reordered protein IDs of ambiguous entries
print("Number of ambiguous protein IDs with re-arranged order:")
perBatch %>% map_df(~ count(.x, protein_ids != old_protein_ids) %>% setNames(c("new_order", "count")) %>% spread(new_order, count),.id = 'GROUP') %>% kable()



## combine individual files by protein_ids, protein_acc and scrap only
msData = perBatch %>%
    map(~ select(.x, protein_ids, matches("^intensity"))) %>%
    purrr::reduce(full_join, by="protein_ids")

sample_num <- ncol(msData)-1

## rename samples
names(msData) %<>% str_replace_all(., oldNames, newNames)

#'
#' <br><br>
#'
#' ## Sample level
#'
#' In case multiple input files are analysed, the tables are now merged and further processed as one table. To merge the tables the protein IDs were used and thus NAs will be reported if the input tables do not have all protein IDs in common.
#'
#' <br>
#'
#' ### Missing values per sample
## plot NA proportion based on the DataExplorer function profile_missing()
load_pack(DataExplorer)
plot_missing(msData[, which(colnames(msData) != "protein_ids")])

na_prop <- msData %>% gather(sample, intensity, -protein_ids) %$% { sum(is.na(intensity)/length(intensity))}


if (na_prop > 0) {
    msData %>% select(protein_ids, contains("intensity")) %>% gather(sample, intensity, -protein_ids) %>%
        group_by(protein_ids) %>%
        summarize(num_na=sum(is.na(intensity)), num_meas=n(), na_prop=num_na/n()) %>%
        mutate(na_prop = MASS::fractions(na_prop)) %>%
        ggplot(aes(na_prop)) +
        geom_bar(fill = "lightcyan4") +
        xlab("NA proportion") + ggtitle("Protein ID specific NA proportion across all samples")
}

#'
#' <br><br>
#'
#' ### Zero values across all samples
msData %>% select(protein_ids, contains("intensity")) %>% gather(sample, intensity, -protein_ids) %>%
    group_by(protein_ids) %>%
    summarize(num_zero=sum(intensity == 0), num_meas=n(), zero_prop=num_zero/n()) %>%
    ggplot(aes(zero_prop)) + geom_bar(fill = "lightcyan4") + xlab("Proportion of zeros") + ggtitle("Protein ID specific proportion of zeros across all samples")


names(msData) %<>% str_replace("intensity_", "")


# #' retain only proteins with na proportion less than 75%


#'
#' <br><br>
#'
#' ### Contaminations removal
#' In this step, unique CON__ REV__ and STANDARD entries are removed. So far, ambiguous entries with simultaneous CON__ and protein accessions are kept.
# protein_info %>% mutate(sep_ids = str_split(protein_ids, ";")) %>% unnest(sep_ids) %>%
#     mutate(sep_prot = str_match(sep_ids, "[trsp]+\\|([:alnum:]+)")[,2]) %>%
#     na.omit() %>%
#     group_by(protein_ids) %>%
#     distinct(protein_ids, fasta_headers, protein_acc, gene_name) %>% ungroup()

msData %<>% mutate(is_scrap = protein_ids %in% scrap_ids) %>% left_join(protein_info, by = "protein_ids")

write_tsv(msData, path=add_prefix("intensities_incl_ctrls.txt"))

msData %>% filter(is_scrap) %>% select(protein_ids) %>% DT::datatable(caption="controls removed from data")

tribble(~intial_data, ~filtered_data, ~removed_rows,
    nrow(msData), nrow(filter(msData, !is_scrap)), nrow(filter(msData, is_scrap))) %>% kable()

msData %<>% filter(!is_scrap) %>% select(-is_scrap, -fasta_headers, -protein_acc, -gene_name)

stopifnot(nrow(filter(msData, str_length(protein_ids)==0)) ==0)


#'
#' <br><br>
#'
#' ### Protein abundance / intensities
#' List of the 25 most abundant proteins across all samples
msData %>% gather(sample, intensity, -protein_ids) %>% group_by(protein_ids) %>%
    summarize(sum_intensity=sum(intensity, na.rm=T)) %>%
    arrange(-sum_intensity) %>% slice(1:25) %>%
    # left_join(sample_info %>% distinct(protein_ids, protein_acc, gene_name, fasta_headers), by = "protein_ids") %>%
    left_join(protein_info, by = "protein_ids") %>%
    transmute(protein_ids, gene_name, sum_intensity, fasta_headers) %>%
    table_browser()


#'
#' <br><br>
#'
#' ## Data Normalization
#'
#' How do the intensities look like?
protsData = gather(msData, sample, intensity, -protein_ids) %>% mutate(sample = str_replace(sample, "intensity_", "")) %T>% glimpse

p1 <- protsData %>% ggplot(aes(intensity)) + geom_histogram(fill = "lightcyan4") + scale_x_log10() + ggtitle("intensities across all samples")
p2 <- protsData %>% ggplot(aes(sample, weight=intensity)) +
    geom_bar(fill = "lightcyan4") + coord_flip() + ggtitle("intensity totals per sample")

grid.arrange(p1, p2, nrow = 1)

protsData %>% ggplot(aes(intensity)) + geom_histogram(fill = "lightcyan4") + scale_x_log10() + ggtitle("intensities") + facet_wrap(~sample)


protsData %>% ggplot(aes(sample, intensity+1)) + geom_boxplot(fill = "lightcyan4") + ggtitle("intensities") + scale_y_log10() + coord_flip() + ylab("intensity")

## when using linear scale, we discard 0s to avoid biases means
protsData %>% filter(intensity>0) %>% ggplot(aes(sample, intensity)) +
    geom_boxplot(fill = "lightcyan4") +
    ggtitle("intensities > 0") +
    scale_y_continuous(limits=c(0, 5E6)) +
    coord_flip()


## also compare top10 intensities per sample
heg_data <- protsData %>%
    group_by(sample) %>%
    top_n(10, intensity) %>%
    left_join(sample_info, by = c("sample", "protein_ids", "intensity" = "lfq")) %>%
    ungroup() %>%
    arrange(sample, intensity) %>%
    mutate(order = row_number(), unique_protein = !str_detect(protein_ids, ";"))

d1 <- ggplot(heg_data, aes(order, intensity, fill = unique_protein)) + geom_col(stat = "identity") + coord_flip() + xlab("") + scale_x_continuous(breaks = heg_data$order, labels = heg_data$gene_name, expand = c(0,0)) + scale_fill_manual(values=c("coral1", "cadetblue")) +
    ylab("") +
    theme(legend.position = "bottom") +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))

if("identification_type" %in% colnames(heg_data) == FALSE){
    d2 <- d1 + facet_wrap(~sample, scales="free_y", ncol = 2) + ggtitle("intensities of top 10 proteins per sample - same scale")
    d3 <- d1 + facet_wrap(~sample, scales="free", ncol = 2) + ggtitle("intensities of top 10 proteins per sample - different scale")
} else {
    d2 <- d1 + geom_point(aes(order, intensity, shape = identification_type), fill = "black") + scale_shape_manual(values=c(20, 1)) + facet_wrap(~sample, scales="free_y", ncol = 2) + ggtitle("intensities of top 10 proteins per sample - same scale")
    d3 <- d1 + geom_point(aes(order, intensity, shape = identification_type), fill = "black") + scale_shape_manual(values=c(20, 1)) + facet_wrap(~sample, scales="free", ncol = 2) + ggtitle("intensities of top 10 proteins per sample - different scale")
}

write_tsv(heg_data, path=add_prefix("top10_highest_intensities.txt"))

#+ fig.height=length(unique(heg_data$sample))/2+5, eval=length(unique(heg_data$sample))>0
d2

#+ fig.height=length(unique(heg_data$sample))/2+8, eval=length(unique(heg_data$sample))>0
d3

#'
#' <br><br>
#'
#' ## Comparison model and design file

normData = protsData

#' design

expDesign %>% kable()

lapply(colnames(expDesign)[which(colnames(expDesign) != "replicate")], function(x){
    expDesign[,which(colnames(expDesign) == x)] %>%
        setNames("feature") %>%
        ggplot(aes(as.factor(feature))) +
        geom_bar(fill = "lightcyan4") +
        ggtitle(paste0("samples per ", x)) +
        xlab("") +
        theme(axis.text.x = element_text(angle = 45, hjust = 1))
}) %>% grid.arrange(grobs = ., ncol=3)




#'
#' <br><br>
#'
#' ### Identification types information
if(exists("ident_types")) {


    identType <- perBatch %>%
            map(~ select(.x, protein_ids, matches("identification_type"))) %>%
            reduce(full_join, by = "protein_ids")

    names(identType) %<>% str_replace_all(., oldNames, newNames) %>% str_replace_all( "identification_type_", "")

    design_info <- expDesign
    colnames(design_info)[colnames(design_info) == design] <- "coi"
    rep_num <- group_by(design_info, coi) %>% summarize(rep_num = n())


    identSummary <- identType %>% gather(sample, ident_status, -protein_ids) %>%
        left_join(design_info, by = c("sample" = "replicate")) %>%
        group_by(protein_ids, coi, ident_status) %>%
        count() %>% ungroup() %>%
        filter(str_detect(ident_status, "MS")) %>%
        left_join(rep_num, by = "coi") %>%
        transmute(protein_ids, coi, ms_ms_prop = n/rep_num)

    ident_plot <- identSummary %>% ggplot(aes(as.factor(round(ms_ms_prop, 2)))) + geom_bar(position = "dodge", fill = "lightcyan4") + facet_wrap(~coi) +
        xlab("proportion of MS/MS hits per condition")


    write_tsv(identSummary, path=add_prefix("ident_types_summary.txt"))

} else {
    print("No identification type information found")
}

if(exists("ident_plot")) {ident_plot}


#'
#' <br><br>
#'
#' ## Abundance matrix imputation


if (na_prop > 0) {
    normData %>%
        left_join(expDesign, by=c("sample"="replicate")) %>%
        group_by(condition, protein_ids) %>%
        summarize(num_vals=n(), na_prop=(sum(is.na(intensity))/length(intensity) )%>% round(3)) %>%
        ggplot(aes(as.factor(na_prop))) + geom_bar() + facet_wrap(~num_vals, scales="free_x") + ggtitle("na proportions by number of replicates per condition") + xlab("NA proportion")
}

#' In the following, missing intensities are imputated if intensities were reported for more than 60% of provided replicates. All remaining NA values will be set to zero.

imputeData = normData %>%
    left_join(expDesign, by=c("sample"="replicate")) %>%
    group_by(condition, protein_ids) %>%
    mutate(intensity_imp=impute_some(intensity)) %>%
    ungroup()

imputeData %>% mutate(is_imputed = intensity != intensity_imp) %>%
    write_tsv(path=add_prefix("imputation_info.txt"))

print(paste0(nrow(anti_join(imputeData, normData)), " entries changed due to imputation"))

finalData <- imputeData %>% select(protein_ids, sample, intensity_imp) %>%
    spread(sample, intensity_imp)
if (sample_num != ncol(finalData)-1) {stop("ATTENTION: Final intensities matrix does not contain all input samples")}


# after zero-imputing of all remaining NAs
finalData %<>% mutate_if(is.numeric, funs(replace(., is.na(.), 0)))
write_tsv(finalData, path=add_prefix("intens_imputed.txt"))


#-----------------------------------------------------------------------------------------------------------------------
# get R version and package infos
writeLines(capture.output(devtools::session_info()), ".sessionInfo.txt")

session::save.session(".ms_data_prep.R.dat")
# session::restore.session(".ms_data_prep.R.dat")
