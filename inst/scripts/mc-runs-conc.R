library(hector)
library(hectorcal)
library(metrosamp)
library(doParallel)
library(ggplot2)
library(magrittr)


hfyear <- 2100
hfexpt <- 'rcp85'

#### Definition of runid:
### Bits 0-3: Serial number (used to give each run of the same configuration a
###           unique RNG seed
### Bit 4: Use pcs flag.  If false, we use the outputs directly
### Bit 5: Use heat flux flag.
### Bit 6: Mean calibrtion flag
### Bit 7: Debug flag

### To use a restart file, specify the file stem up through the number of samples
### For example, 'testrun-1000'.  Everything including and after the runid will be
### added automatically.

mc_run_conc <- function(runid, nsamp, filestem='hectorcal',
                        plotfile=TRUE, npc=10, restart=NULL, warmup=1000)
{
    runid <- as.integer(runid)
    serialnumber <- bitwAnd(runid, 15)
    pcsflag <- as.logical(bitwAnd(runid, 16))
    hfflag <- as.logical(bitwAnd(runid, 32))
    meanflag <- as.logical(bitwAnd(runid, 64))
    debugflag <- as.logical(bitwAnd(runid, 128))


    ## input files for hector initialization
    rcps <- c('rcp26', 'rcp45', 'rcp60', 'rcp85')
    inputfiles <- file.path('input', sprintf('hector_%s_constrained.ini', rcps))
    inputfiles <- system.file(inputfiles, package='hector', mustWork = TRUE)
    names(inputfiles) <- rcps

    ## get the comparison data we will be using
    if(pcsflag) {
        ## Drop principal components for which there is no variation in the comparison data.
        nkeep <- npc+1                  # Number of requested PCs, plus the
                                        # heatflux row.
        compdata <- conc_pc_comparison[1:nkeep,]
        pcs <- pc_conc
    }
    else  {
        ## We have all the heat flux for this one, so we need to drop the
        ## years we won't be using.  Also drop the emissions driven runs
        compdata <- dplyr::filter(esm_comparison,
                                  !grepl('^esm', experiment) &
                                      (variable != 'heatflux' | (year==hfyear &
                                                                     experiment==hfexpt)))
        ## We also need to filter out data that doesn't belong, like RCP scenario
        ## data prior to 2006 or co2 data (which doesn't belong in concentration driven runs)
        compdata <- dplyr::filter(compdata,
                                  (experiment=='historical' & year > 1860 & year < 2006) |
                                    (experiment!='historical' & year > 2005 & year <= 2100)) %>%
            dplyr::filter(variable != 'co2')
        pcs <- NULL
    }



    ## if the heat flux flag is cleared, then drop the heatflux value
    if(!hfflag) {
        compdata <- dplyr::filter(compdata, variable != 'heatflux')
    }

    ## Create the log-posterior function
    lpf <- build_mcmc_post(compdata, inputfiles, pcs, cal_mean = meanflag,
                           hflux_year = hfyear, hflux_expt_regex = hfexpt)

    ## initial parameters
    if(is.null(restart)) {
        p0 <- c(3.0, 2.3, 1.0, 1.0)
    }
    else {
        restartfile <- paste(restart, runid, 'mcrslt.rds', sep='-')
        p0 <- readRDS(restartfile)
    }
    scale <- c(0.75, 1.25, 0.5, 0.5)    # based on some experimentation with short runs
    pnames <- c(ECS(), DIFFUSIVITY(), AERO_SCALE(), VOLCANIC_SCALE())
    if(meanflag) {
        ## Add sigma parameters for mean calibration
        if(pcsflag) {
            if(is.null(restart)) {
                p0 <- c(p0, 0.05)
            }
            sclfac <- c(scale/2, 0.1)
            scale <- diag(nrow=length(sclfac), ncol=length(sclfac))
            scale[1,2] <- scale[2,1] <- 0.85
            scale <- cor2cov(scale, sclfac)
            pnames <- c(pnames, 'sigp')
        }
        else {
            if(is.null(restart)) {
                p0 <- c(p0, 0.05)
            }
            tempscl <- 1e-4
            sclfac <- c(scale/20, tempscl)
            ## S and kappa distributions are very narrow, so that step needs to be small
            sclfac[1] <- sclfac[1] / 10
            sclfac[2] <- sclfac[2] / 10
            scale <- diag(nrow=length(sclfac), ncol=length(sclfac))
            ## many of the parameters turn out to be highly correlated in this case.
            scale[1,2] <- scale[2,1] <- 0.95
            scale[1,3] <- scale[3,1] <- -0.7
            scale[1,4] <- scale[4,1] <- 0.3
            scale[2,3] <- scale[3,2] <- -0.7
            scale[2,4] <- scale[4,2] <- 0.3
            scale[3,4] <- scale[4,3] <- -0.25
            scale[1,5] <- scale[5,1] <- -0.3
            scale[2,5] <- scale[5,2] <- -0.3
            scale <- cor2cov(scale, sclfac)
            pnames <- c(pnames, 'sigt')
        }

        if(hfflag) {
            if(is.null(restart)) {
                p0 <- c(p0, 5.0)
            }
            hfscl <- 1e-1
            if(is.matrix(scale)) {
                newscale <- matrix(0, nrow=nrow(scale)+1, ncol=ncol(scale)+1)
                newscale[1:nrow(scale), 1:ncol(scale)] <- scale
                scale <- newscale
                scale[nrow(scale),ncol(scale)] <- hfscl
            }
            else {
                scale <- c(scale, hfscl)
            }
            pnames <- c(pnames, 'sighf')
        }
    }
    else {
        ## Envelope calibration: Add the sigma parameter for the mesa function.
        if(is.null(restart)) {
            p0 <- c(p0, 0.1)
        }
        pnames <- c(pnames, 'sigm')
        scale <- c(scale, 0.05)
    }
    if(is.null(restart)) {
        names(p0) <- pnames
    }
    if(is.vector(scale)) {
        names(scale) <- pnames
    }
    else {
        rownames(scale) <- colnames(scale) <- pnames
    }


    ## Run monte carlo
    registerDoParallel(cores=4)
    set.seed(867-5309 + serialnumber)

    if(warmup > 0 && is.null(restart)) {
        ## Perform warmup samples if requested.  Ignore if continuing from
        ## a previous run
        p0 <- metrosamp(lpf, p0, warmup, 1, scale, debug=debugflag)
    }
    ms <- metrosamp(lpf, p0, nsamp, 1, scale, debug=debugflag)

    ## save output and make some diagnostic plots
    cat('Runid:\n')
    print(runid)
    cat('output file stem:\n')
    print(filestem)
    cat('Acceptance fraction:\n')
    print(ms$accept)
    cat('Effective number of samples:\n')
    print(neff(ms$samples))

    if(nsamp < 10000) {
        plotfilename <- paste(filestem, runid, 'diagplot.png', sep='-')
        msc <- metrosamp2coda(list(ms))
        if(plotfile) {
            png(plotfilename, 1024, 1024)
        }
        plot(msc)
        if(plotfile) {
            dev.off()
        }
    }
    savefilename <- paste(filestem, runid, 'mcrslt.rds', sep='-')

    saveRDS(ms, savefilename, compress='xz')

    invisible(ms)
}
