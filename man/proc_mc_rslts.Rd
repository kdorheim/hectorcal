% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/mc-helpers.R
\name{proc_mc_rslts}
\alias{proc_mc_rslts}
\title{Read in results from Monte Carlo runs}
\usage{
proc_mc_rslts(dir = ".", filestem = "hectorcal", codasize = 2500)
}
\arguments{
\item{dir}{Filesystem directory in which to look for results.}

\item{filestem}{Base name used to construct the names of the input files.}

\item{codasize}{Size of the \code{\link[coda]{mcmc.list}} objects returned.  The MCMC
results will be thinned to this size for easier plotting and analysis.  If
\code{codasize} is specified as \code{NA}, then the output coda objects will not be
thinned at all.}
}
\value{
A list of structures.
\describe{
\item{runstats}{Run statistics such as acceptance rate and effective number of samples.
These apply to the merged set of runs for the configuration.}
\item{mcobjs}{List of lists of \code{metrosamp} objects.  Each list in the top level
corresponds to a configuration; the elements in the second-level list are the objects
for the individual runs in the configuration.}
\item{codaobjs}{\code{\link[coda]{mcmc.list}} object for each configuration.  These objects
represent the merged results of all of the runs in a configuration in a form that can be used
with the utilities in the coda package.}
}
}
\description{
This function searches a directory for Monte Carlo outputs and loads them.
Individual runs from a single configuration are gathered together into lists
and named according to the runid for that configuration with serial number 0.
}
