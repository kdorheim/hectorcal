% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/util.R
\name{load_matching_mcout}
\alias{load_matching_mcout}
\title{Load all outputs matching specified runids}
\usage{
load_matching_mcout(runid, dir = ".", filestem = "hectorcal",
  niter = NA)
}
\arguments{
\item{runid}{Runid values to match}

\item{dir}{Directory to load files from}

\item{filestem}{Stem of the data file names}

\item{niter}{Number of iterations. If NA, match all iteration counts}
}
\description{
Generally it's only useful to load runs that represent different chains for
the same config.  Therefore, this should usually only be called from
\code{\link{load_mc_output}}, which knows how to construct a sensible list of
runids.
}
\keyword{internal}
