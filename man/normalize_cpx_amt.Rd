% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/data_handling.R
\name{normalize_cpx_amt}
\alias{normalize_cpx_amt}
\title{Rescale every cell to a certain amount of UMIs, where
that amount is selected by rounding up the median UMI count up to the next power of 10.}
\usage{
normalize_cpx_amt(dge, results_path = NULL, do.plot = T)
}
\description{
Rescale every cell to a certain amount of UMIs, where
that amount is selected by rounding up the median UMI count up to the next power of 10.
}
