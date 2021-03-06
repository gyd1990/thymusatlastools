% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/pseudotime_plotting.R
\name{heatmap_gene_clusters}
\alias{heatmap_gene_clusters}
\title{Draw heatmaps of gene clusters from output of `smooth_and_cluster_genes`.}
\usage{
heatmap_gene_clusters(dge, results_path, cluster_mod, smoothers,
  gap_size = NULL, genes_use = NULL, genes_to_label = NULL)
}
\arguments{
\item{dge}{Seurat object with raw data and pseudotime metadata used to train smoothers. 
If metadata `simple_branch` is present, function is hardwired to look for "mTEC", "cTEC", "branchpoint", and "progenitor"
and make a heatmap similar to figure 2 in http://dx.doi.org/10.1101/122531.}

\item{results_path}{Where to save plots and files.}

\item{cluster_mod}{K-means output with cluster labels for the genes in `smoothers` and also with cluster centers.}

\item{smoothers}{List of regression models for the genes in `cluster_mod` and `gene_stats`.}

\item{gap_size}{White bars separating clusters are formed by adding fake genes. gap_size is how many fake genes per bar.}

\item{genes_use}{Gene names or anything in `AvailableData(dge)`.}

\item{genes_to_label}{Subset of `genes_use` to write tick labels for.}
}
\description{
Draw heatmaps of gene clusters from output of `smooth_and_cluster_genes`.
}
