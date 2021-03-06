##' @name sre
##' @title Surface Range Envelope
##' @description 
##' Run a rectilinear surface range envelop (equivalent to BIOCLIM) using
##' the extreme percentiles as recommended by Nix or Busby.
##' The SRE performs a simple analysis of within which range of each
##' variable the data is recorded and renders predictions.
##' 
##' @param Response  a vector (resp. a matrix/data.frame, a 
##' SpatialPointsDataFrame or a RasterLayer ) giving your species'
##' presences and absences data
##' @param Explanatory a matrix (resp. a data.frame, a 
##' SpatialPointsDataFrame or a RasterStack ) containing the environmental
##' variables for the sites given in Response. It must have as many rows
##' as there are elements in Response.
##' @param NewData The data for which you want to render predictions with
##' the sre. It must be a matrix (resp. a data.frame, a 
##' SpatialPointsDataFrame or a RasterStack ) of the same type as the one
##' given in Explanatory and with precisely the same variable names.
##' @param Quant the value defines the most extreme values for each
##' variable not to be taken into account for determining the tolerance
##' boundaries for the considered species.
##' @param return_extremcond boolean, if TRUE a matrix containing extreme
##' conditions supported is returned
##' 
##' @details 
##' The more variables you put in, the more restrictive your model will 
##' be (if non-colinear variables).
##' 
##' This method is very much influenced by the data input, and more
##' specifically by the extremes.
##' 
##' Where a linear model can discriminate the extreme values from the main
##' tendency, the SRE considers it equal as any other data point which
##' leads to notable changes in predictions.
##' 
##' Note that, as a consequence of its functioning, the predictions are
##' directly given in binary, a site being either potentially suitable for
##' all the variables, either out of bounds for at least one variable and
##' therefore considered unsuitable. 
##' 
##' The quants argument determines the threshold at which the data will be
##' taken into account for calibration : the default of 0.05 induces that
##' the 5\% most extreme values will be avoided for each variable on each
##' side of its distribution along the gradient. So it in fact takes 5\%
##' away at each end of the variables distribution, giving a total of 10\%
##' of data not considered.
##' 
##' @return 
##' A vector (resp. a RasterLayer ) of the same length as there are rows
##' in NewData giving the prediction in binary (1=presence, 0=absence)
##' 
##' @author Wilfried Thuiller, Bruno Lafourcade, Damien Georges 
##' @seealso \code{\link[biomod2]{BIOMOD_Modeling}}, 
##' \code{\link[biomod2]{BIOMOD_ModelingOptions}}, 
##' \code{\link[biomod2]{BIOMOD_Projection}}
##' 
##' @keywords models
##' @keywords multivariate
##' 
##' @examples
##' require(raster)
##' ##' species occurrences
##' DataSpecies <- 
##'   read.csv(
##'     system.file("external/species/mammals_table.csv", package = "biomod2"), 
##'     row.names = 1
##'   )
##' head(DataSpecies)
##' 
##' ##' the name of studied species
##' myRespName <- 'GuloGulo'
##' 
##' ##' the presence/absences data for our species 
##' myResp <- as.numeric(DataSpecies[,myRespName])
##' 
##' ##' the XY coordinates of species data
##' myRespXY <- DataSpecies[which(myResp==1),c("X_WGS84","Y_WGS84")]
##' 
##' ##' Environmental variables extracted from BIOCLIM (bio_3, 
##' ##' bio_4, bio_7, bio_11 & bio_12)
##' myExpl <- 
##'   raster::stack(
##'     system.file("external/bioclim/current/bio3.grd", package = "biomod2"),
##'     system.file("external/bioclim/current/bio4.grd", package = "biomod2"),
##'     system.file("external/bioclim/current/bio7.grd", package = "biomod2"),
##'     system.file("external/bioclim/current/bio11.grd", package = "biomod2"),
##'     system.file("external/bioclim/current/bio12.grd", package = "biomod2")
##'   )

##' myResp <- 
##'   raster::reclassify(
##'     subset(myExpl, 1, drop = TRUE), c(-Inf, Inf, 0)
##'   )
##' myResp[cellFromXY(myResp,myRespXY)] <- 1
##' 
##' ##' Compute some SRE for several quantile values
##' sre.100 <- 
##'   sre(
##'     Response = myResp, 
##'     Explanatory = myExpl, 
##'     NewData=myExpl, 
##'     Quant = 0
##'   )
##'   
##' sre.095 <- 
##'   sre(
##'     Response = myResp, 
##'     Explanatory = myExpl, 
##'     NewData=myExpl, 
##'     Quant = 0.025
##'   )
##' 
##' sre.090 <- 
##'   sre(
##'     Response = myResp, 
##'     Explanatory = myExpl, 
##'     NewData=myExpl, 
##'     Quant = 0.05
##'   )
##'   
##' ##' visualise results
##' par(mfrow=c(2,2),mar=c(6, 5, 5, 3))
##' plot(myResp, main = paste(myRespName, "original distrib."))
##' plot(sre.100, main="full data calibration")
##' plot(sre.095, main="95 %")
##' plot(sre.090, main="90 %")
sre <- function(
  Response = NULL, 
  Explanatory = NULL, 
  NewData = NULL, 
  Quant = 0.025, 
  return_extremcond = FALSE
){

  # 1. Checking of input arguments validity
  args <- .check.params.sre(Response, Explanatory, NewData, Quant)

  Response <- args$Response
  Explanatory <- args$Explanatory
  NewData <- args$NewData
  Quant <- args$Quant
  rm("args")


  # 2. Determining suitables conditions and make the projection
  lout <- list()
  if(is.data.frame(Response) | is.matrix(Response)){
    nb.resp <- ncol(Response)
    resp.names <- colnames(Response)
    for(j in 1:nb.resp){
      occ.pts <- which(Response[,j]==1)
      extrem.cond <- t(apply(as.data.frame(Explanatory[occ.pts,]), 2,
                           quantile, probs = c(0 + Quant, 1 - Quant), na.rm = TRUE))

      if(!return_extremcond)
        lout[[j]] <- .sre.projection(NewData, extrem.cond)
    }
  }

  if(inherits(Response, 'Raster')){
    nb.resp <- nlayers(Response)
    resp.names <- names(Response)
    for(j in 1:nb.resp){
      occ.pts <- raster::subset(Response,j, drop=T)
      x.ooc.pts <- Which(occ.pts != 1, cells=TRUE, na.rm=T)
      occ.pts[x.ooc.pts] <- rep(NA, length(x.ooc.pts))
      extrem.cond <- quantile(raster::mask(Explanatory, occ.pts), probs = c(0 + Quant, 1 - Quant), na.rm = TRUE)

      if(!return_extremcond)
        lout[[j]] <- .sre.projection(NewData, extrem.cond)
    }
  }

  if(inherits(Response, 'SpatialPoints')){
    nb.resp <- ncol(Response@data)
    resp.names <- colnames(Response@data)
    for(j in 1:nb.resp){
      occ.pts <- which(Response@data[,j]==1)
      if(is.data.frame(Explanatory) | is.matrix(Explanatory)){
        extrem.cond <- t(apply(as.data.frame(Explanatory[occ.pts,]), 2,
                           quantile, probs = c(0 + Quant, 1 - Quant), na.rm = TRUE))
      } else { if(inherits(Explanatory, 'Raster')){
        maskTmp <- raster::subset(Explanatory,1, drop=T)
#         maskTmp <- reclassify(maskTmp, c(-Inf,Inf,NA))
        maskTmp[] <- NA
        maskTmp[cellFromXY(maskTmp, coordinates(Response)[occ.pts,])] <- 1
        extrem.cond <- quantile(raster::mask(Explanatory, maskTmp), probs = c(0 + Quant, 1 - Quant), na.rm = TRUE)
      } else { if(inherits(Explanatory, 'SpatialPoints')){
        ## May be good to check corespondances of Response and Explanatory variables
        extrem.cond <- t(apply(as.data.frame(Explanatory[occ.pts,]), 2,
                   quantile, probs = c(0 + Quant, 1 - Quant), na.rm = TRUE))
      } else { stop("Unsuported case!") } } }

      if(!return_extremcond)
        lout[[j]] <- .sre.projection(NewData, extrem.cond)
    }
  }

  if(return_extremcond){
    return(as.data.frame(extrem.cond))
  } else{
    # 3. Rearranging the lout object
    if(is.data.frame(NewData)){
      lout <- simplify2array(lout)
      colnames(lout) <- resp.names
    }

    if(inherits(NewData, 'Raster')){
      lout <- stack(lout)
      if(nlayers(lout)==1){
        lout <- raster::subset(lout,1,drop=TRUE)
      }
      names(lout) <- resp.names
    }

    return(lout)
  }
}

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #

.check.params.sre <- function(Response = NULL, Explanatory = NULL, NewData = NULL, Quant = 0.025){
  # check quantile validity
  if (Quant >= 0.5 | Quant < 0){
    stop("\n settings in Quant should be a value between 0 and 0.5 ")
  }

  # check compatibility between response and explanatory
  if(is.vector(Response) | is.data.frame(Response) | is.matrix(Response) ){
    Response <- as.data.frame(Response)

    if(!is.vector(Explanatory) & !is.data.frame(Explanatory) & !is.matrix(Explanatory) & !inherits(Explanatory, 'SpatialPoints')){
      stop("If Response variable is a vector, a matrix or a data.frame then Explanatory must also be one")
    } else {
      if(inherits(Explanatory, 'SpatialPoints')){
        Explanatory <- as.data.frame(Explanatory@data)
      }
      Explanatory <- as.data.frame(Explanatory)
      nb.expl.vars <- ncol(Explanatory)
      names.expl.vars <- colnames(Explanatory)
      if(nrow(Response) != nrow(Explanatory)){
        stop("Response and Explanatory variables have not the same number of rows")
      }
    }
  }

  if(inherits(Explanatory, 'SpatialPoints')){
    Explanatory <- as.data.frame(Explanatory@data)
    nb.expl.vars <- ncol(Explanatory)
    names.expl.vars <- colnames(Explanatory)
  }

  if(inherits(Response, 'Raster')){
    if(!inherits(Explanatory, 'Raster')){
      stop("If Response variable is raster object then Explanatory must also be one")
    }
    nb.expl.vars <- nlayers(Explanatory)
    names.expl.vars <- names(Explanatory)
  }

  ## check explanatory variables class
  test_no_factorial_var <- TRUE
  if(is.data.frame(Explanatory)){
    if(any(unlist(lapply(Explanatory, is.factor)))){
      test_no_factorial_var <- FALSE
    }
  } else if (inherits(Explanatory, 'Raster')){
    if(any(is.factor(Explanatory))){
      test_no_factorial_var <- FALSE
    }
  }

  if(!test_no_factorial_var) stop("SRE algorithm does not handle factorial variables")


  # If no NewData given, projection will be done on Explanatory variables
  if(is.null(NewData)){
    NewData <- Explanatory
  } else {
    # check of compatible number of explanatories variable
    if(is.vector(NewData) | is.data.frame(NewData) | is.matrix(NewData)){
      NewData <- as.data.frame(NewData)
      if(sum(!(names.expl.vars %in% colnames(NewData))) > 0 ){
        stop("Explanatory variables names differs in the 2 dataset given")
      }
      NewData <- NewData[,names.expl.vars]
      if(ncol(NewData) != nb.expl.vars){
        stop("Incompatible number of variables in NewData objects")
      }
    } else if(!inherits(NewData, 'Raster')){
      NewData <- stack(NewData)
      if(sum(!(names.expl.vars %in% names(NewData))) > 0 ){
        stop("Explanatory variables names differs in the 2 dataset given")
      }
      NewData <- raster::subset(NewData, names.expl.vars)
      if(nlayers(NewData) != nb.expl.vars ){
        stop("Incompatible number of variables in NewData objects")
      }
    }
  }

  return(list(Response = Response,
              Explanatory = Explanatory,
              NewData = NewData,
              Quant = Quant))

}

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #

.sre.projection <- function(NewData, ExtremCond){

  if(is.data.frame(NewData)|is.matrix(NewData)){
    out <- rep(1,nrow(NewData))
    for(j in 1:ncol(NewData)){
      out <- out * as.numeric(NewData[,j] >= ExtremCond[j,1] &  NewData[,j] <= ExtremCond[j,2])
    }
  }

  if(inherits(NewData, "Raster")){
    out <- reclassify(raster::subset(NewData,1,drop=TRUE), c(-Inf, Inf, 1))
    for(j in 1:nlayers(NewData)){
      out <- out * ( raster::subset(NewData,j,drop=TRUE) >= ExtremCond[j,1] ) * ( raster::subset(NewData,j,drop=TRUE) <= ExtremCond[j,2] )
    }
    out <- raster::subset(out,1,drop=TRUE)
  }

  return(out)
}

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #

#
#
# sre <- function (Response = NULL, Explanatory = NULL, NewData = NULL, Quant = 0.025)
# {
#   # check quantile validity
#   if (Quant >= 0.5 | Quant < 0){
#     stop("\n settings in Quant should be a value between 0 and 0.5 ")
#   }
#   quants <- c(0 + Quant, 1 - Quant)
#
#   # puting response in an appropriate form if necessary
#   if(inherits(Response, 'Raster')){
#     stop("Response raster stack not suported yet!")
#   } else {
#     Response <- as.data.frame(Response)
#   }
#
#   if(!inherits(NewData, 'Raster')){
#
#   }
#
#
#   if (class(Explanatory)[1] != "RasterStack") {
#
#     if (is.vector(Explanatory)){
#       Explanatory <- as.data.frame(Explanatory)
#       NewData <- as.data.frame(NewData)
#       names(Explanatory) <- names(NewData) <- "VarTmp"
#     }
#     NbVar <- ncol(Explanatory)
#   }
#       if (class(NewData)[1] != "RasterStack"){
#         Pred <- as.data.frame(matrix(0,
#                                      nr = nrow(NewData),
#                                      nc = ncol(Response),
#                                      dimnames = list(seq(nrow(NewData)), colnames(Response))))
#       }
#
#       for (i in 1:ncol(Response)){
#           ref <- as.data.frame(Explanatory[Response[, i] == 1, ])
#           if(ncol(ref)==1){ names(ref) <- names(Explanatory)}
#           if (class(NewData)[1] == "RasterStack") {
#             # select a lone layer
#             TF <- subset(NewData, 1)
#             # put all cell at 1
#             TF <- TF >= TF@data@min
#           }
#           else TF <- rep(1, nrow(NewData))
#
#           for (j in 1:NbVar) {
#               capQ <- quantile(ref[, j], probs = quants, na.rm = TRUE)
#               if (class(NewData)[1] != "RasterStack") {
#                 TF <- TF * (NewData[, names(ref)[j]] >= capQ[1])
#                 TF <- TF * (NewData[, names(ref)[j]] <= capQ[2])
#               }
#               else {
#                 TFmin <- NewData@layers[[which(NewData@layernames ==
#                   names(ref)[j])]] >= capQ[1]
#                 TFmax <- NewData@layers[[which(NewData@layernames ==
#                   names(ref)[j])]] <= capQ[2]
#                 TF <- TF * TFmin * TFmax
#               }
#           }
#           if (class(TF)[1] != "RasterLayer")
#               Pred[, i] <- TF
#           else Pred <- TF
#       }
#   } else{
#
#   }
#
#   if (class(NewData)[1] != "RasterStack" & ncol(Response) == 1)
#   	Pred <- Pred[[1]]
#
#   return(Pred)
#
# }
#
#
#
