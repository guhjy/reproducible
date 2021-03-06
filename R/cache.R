if (getRversion() >= "3.1.0") {
  utils::globalVariables(c(".", "artifact", "createdDate", "tagKey", "tagValue"))
}

################################################################################
#' Cache method that accommodates environments, S4 methods, Rasters
#'
#' @details
#' Caching R objects using \code{\link[archivist]{cache}} has four important limitations:
#' \enumerate{
#'   \item the \code{archivist} package detects different environments as different;
#'   \item it also does not detect S4 methods correctly due to method inheritance;
#'   \item it does not detect objects that have file-base storage of information
#'         (specifically \code{\link[raster]{RasterLayer-class}} objects);
#'   \item the default hashing algorithm is relatively slow.
#' }
#' This version of the \code{Cache} function accommodates those four special,
#' though quite common, cases by:
#' \enumerate{
#'   \item converting any environments into list equivalents;
#'   \item identifying the dispatched S4 method (including those made through
#'         inheritance) before hashing so the correct method is being cached;
#'   \item by hashing the linked file, rather than the Raster object.
#'         Currently, only file-backed \code{Raster*} objects are digested
#'         (e.g., not \code{ff} objects, or any other R object where the data
#'         are on disk instead of in RAM);
#'   \item using \code{\link[fastdigest]{fastdigest}} internally when the object
#'         is in RAM, which can be up to ten times faster than
#'         \code{\link[digest]{digest}}. Note that file-backed objects are still
#'         hashed using \code{\link[digest]{digest}}.
#' }
#'
#' If \code{Cache} is called within a SpaDES module, then the cached entry will automatically
#' get 3 extra \code{userTags}: \code{eventTime}, \code{eventType}, and \code{moduleName}.
#' These can then be used in \code{clearCache} to selectively remove cached objects
#' by \code{eventTime}, \code{eventType} or \code{moduleName}.
#'
#' \code{Cache} will add a tag to the artifact in the database called \code{accessed},
#' which will assign the time that it was accessed, either read or write.
#' That way, artifacts can be shown (using \code{showCache}) or removed (using
#' \code{clearCache}) selectively, based on their access dates, rather than only
#' by their creation dates. See example in \code{\link{clearCache}}.
#' \code{Cache} (uppercase C) is used here so that it is not confused with, and does
#' not mask, the \code{archivist::cache} function.
#'
#' @section Filepaths:
#' If a function has a path argument, there is some ambiguity about what should be
#' done. Possibilities include:
#' \enumerate{
#'   \item hash the string as is (this will be very system specific, meaning a
#'         \code{Cache} call will not work if copied between systems or directories);
#'   \item hash the \code{basename(path)};
#'   \item hash the contents of the file.
#' }
#' If paths are passed in as is (i.e,. character string), the result will not be predictable.
#' Instead, one should use the wrapper function \code{asPath(path)}, which sets the
#' class of the string to a \code{Path}, and one should decide whether one wants
#' to digest the content of the file (using \code{digestPathContent = TRUE}),
#' or just the filename (\code{(digestPathContent = FALSE)}). See examples.
#'
#' @section Stochasticity:
#' In general, it is expected that caching will only be used when stochasticity
#' is not relevant, or if a user has achieved sufficient stochasticity (e.g., via
#' sufficient number of calls to \code{experiment}) such that no new explorations
#' of stochastic outcomes are required. It will also be very useful in a
#' reproducible workflow.
#'
#' @note As indicated above, several objects require pre-treatment before
#' caching will work as expected. The function \code{.robustDigest} accommodates this.
#' It is an S4 generic, meaning that developers can produce their own methods for
#' different classes of objects. Currently, there are methods for several types
#' of classes. See \code{\link{.robustDigest}}.
#'
#' See \code{\link{.robustDigest}} for other specifics for other classes.
#'
#' @inheritParams archivist::cache
#' @inheritParams archivist::saveToLocalRepo
#' @include cache-helpers.R
#' @include robustDigest.R
#'
#' @param objects Character vector of objects to be digested. This is only applicable
#'                if there is a list, environment or simList with named objects
#'                within it. Only this/these objects will be considered for caching,
#'                i.e., only use a subset of
#'                the list, environment or simList objects.
#'
#' @param outputObjects Optional character vector indicating which objects to
#'                      return. This is only relevant for \code{simList} objects
#'
#' @param cacheRepo A repository used for storing cached objects.
#'                  This is optional if \code{Cache} is used inside a SpaDES module.
#'
#' @param compareRasterFileLength Numeric. Optional. When there are Rasters, that
#'        have file-backed storage, this is passed to the length arg in \code{digest}
#'        when determining if the Raster file is already in the database.
#'        Note: uses \code{\link[digest]{digest}} for file-backed Raster.
#'        Default 1e6. Passed to \code{.prepareFileBackedRaster}.
#'
#' @param omitArgs Optional character string of arguments in the FUN to omit from the digest.
#'
#' @param classOptions Optional list. This will pass into \code{.robustDigest} for
#'        specific classes. Should be options that the \code{.robustDigest} knows what
#'        to do with.
#'
#' @param debugCache Character or Logical. Either \code{"complete"} or \code{"quick"} (uses
#'        partial matching, so "c" or "q" work). \code{TRUE} is
#'        equivalent to \code{"complete"}.
#'        If \code{"complete"}, then the returned object from the Cache
#'        function will have two attributes, \code{debugCache1} and \code{debugCache2},
#'        which are the entire \code{list(...)} and that same object, but after all
#'        \code{.robustDigest} calls, at the moment that it is digested using
#'        \code{fastdigest}, respectively. This \code{attr(mySimOut, "debugCache2")}
#'        can then be compared to a subsequent call and individual items within
#'        the object \code{attr(mySimOut, "debugCache1")} can be compared.
#'        If \code{"quick"}, then it will return the same two objects directly,
#'        without evalutating the \code{FUN(...)}.
#'
#' @param sideEffect Logical. Check if files to be downloaded are found locally
#'        in the \code{cacheRepo} prior to download and try to recover from a copy
#'        (\code{makeCopy} must have been set to \code{TRUE} the first time \code{Cache}
#'        was run). Default is \code{FALSE}.
#'        \emph{NOTE: this argument is experimental and may change in future releases.}
#'
#' @param makeCopy Logical. If \code{sideEffect = TRUE}, and \code{makeCopy = TRUE},
#'        a copy of the downloaded files will be made and stored in the \code{cacheRepo}
#'        to speed up subsequent file recovery in the case where the original copy
#'        of the downloaded files are corrupted or missing. Currently only works when
#'        set to \code{TRUE} during the first run of \code{Cache}. Default is \code{FALSE}.
#'        \emph{NOTE: this argument is experimental and may change in future releases.}
#'
#' @param quick Logical. If \code{sideEffect = TRUE}, setting this to \code{TRUE},
#'        will hash the file's metadata (i.e., filename and file size) instead of
#'        hashing the contents of the file(s). If set to \code{FALSE} (default),
#'        the contents of the file(s) are hashed.
#'        \emph{NOTE: this argument is experimental and may change in future releases.}
#'
#' @inheritParams digest::digest
#'
#' @param digestPathContent Logical. Should arguments that are of class \code{Path}
#'                          (see examples below) have their name digested
#'                          (\code{FALSE}; default), or their file contents (\code{TRUE}).
#'
#' @return As with \code{\link[archivist]{cache}}, returns the value of the
#' function call or the cached version (i.e., the result from a previous call
#' to this same cached function with identical arguments).
#'
#' @seealso \code{\link[archivist]{cache}}, \code{\link{.robustDigest}}
#'
#' @author Eliot McIntire
#' @export
#' @importClassesFrom raster RasterBrick
#' @importClassesFrom raster RasterLayer
#' @importClassesFrom raster RasterLayerSparse
#' @importClassesFrom raster RasterStack
#' @importClassesFrom sp Spatial
#' @importClassesFrom sp SpatialLines
#' @importClassesFrom sp SpatialLinesDataFrame
#' @importClassesFrom sp SpatialPixels
#' @importClassesFrom sp SpatialPixelsDataFrame
#' @importClassesFrom sp SpatialPoints
#' @importClassesFrom sp SpatialPointsDataFrame
#' @importClassesFrom sp SpatialPolygons
#' @importClassesFrom sp SpatialPolygonsDataFrame
#' @importFrom archivist cache loadFromLocalRepo saveToLocalRepo showLocalRepo
#' @importFrom digest digest
#' @importFrom fastdigest fastdigest
#' @importFrom magrittr %>%
#' @importFrom stats na.omit
#' @importFrom utils object.size
#' @rdname cache
#'
#' @example inst/examples/example_Cache.R
#'
setGeneric(
  "Cache", signature = "...",
  function(FUN, ..., notOlderThan = NULL, objects = NULL, outputObjects = NULL, # nolint
           algo = "xxhash64", cacheRepo = NULL, compareRasterFileLength = 1e6,
           userTags = c(), digestPathContent = FALSE, omitArgs = NULL,
           classOptions = list(),
           debugCache = character(),
           sideEffect = FALSE, makeCopy = FALSE, quick = FALSE) {
    archivist::cache(cacheRepo, FUN, ..., notOlderThan, algo, userTags = userTags)
})

#' @export
#' @rdname cache
setMethod(
  "Cache",
  definition = function(FUN, ..., notOlderThan, objects, outputObjects,  # nolint
                        algo, cacheRepo, compareRasterFileLength, userTags,
                        digestPathContent, omitArgs, classOptions,
                        debugCache, sideEffect, makeCopy, quick) {
    tmpl <- list(...)

    if (!is(FUN, "function")) {
      stop("Can't understand the function provided to Cache.\n",
           "Did you write it in the form: ",
           "Cache(function, functionArguments)?")
    }

    if (missing(notOlderThan)) notOlderThan <- NULL

    # if a simList is in ...
    # userTags added based on object class
    userTags <- c(userTags, unlist(lapply(tmpl, .tagsByClass)))

    # get cacheRepo if not supplied
    if (is.null(cacheRepo)) {
      cacheRepo <- .checkCacheRepo(tmpl, create = TRUE)
    } else {
      cacheRepo <- checkPath(cacheRepo, create = TRUE)
    }

    if (is(try(archivist::showLocalRepo(cacheRepo), silent = TRUE), "try-error")) {
      suppressWarnings(archivist::createLocalRepo(cacheRepo))
    }

    # List file prior to cache
    if (sideEffect) {
      priorRepo <-  file.path(cacheRepo, list.files(cacheRepo))
    }

    # get function name and convert the contents to text so digestible
    functionDetails <- getFunctionName(FUN, ...)
    tmpl$.FUN <- functionDetails$.FUN # put in tmpl for digesting  # nolint

    # remove things in the Cache call that are not relevant to Caching
    if (!is.null(tmpl$progress)) if (!is.na(tmpl$progress)) tmpl$progress <- NULL

    # Do the digesting
    preDigestByClass <- lapply(seq_along(tmpl), function(x) .preDigestByClass(tmpl[[x]]))
    preDigest <- lapply(tmpl, .robustDigest, objects = objects,
                        compareRasterFileLength = compareRasterFileLength,
                        algo = algo,
                        digestPathContent = digestPathContent,
                        classOptions = classOptions)

    if (!is.null(omitArgs)) {
      preDigest <- preDigest[!(names(preDigest) %in% omitArgs)]
    }

    if (length(debugCache)) {
      if (!is.na(pmatch(debugCache, "quick")))
        return(list(hash = preDigest, content = list(...)))
    }

    outputHash <- fastdigest(preDigest)

    # compare outputHash to existing Cache record
    localTags <- showLocalRepo(cacheRepo, "tags")
    isInRepo <- localTags[localTags$tag == paste0("cacheId:", outputHash), , drop = FALSE] # nolint

    # If it is in the existing record:
    if (NROW(isInRepo) > 0) {
      lastEntry <- max(isInRepo$createdDate)
      lastOne <- order(isInRepo$createdDate, decreasing = TRUE)[1]

      # make sure the notOlderThan is valid, if not, exit this loop
      if (is.null(notOlderThan) || (notOlderThan < lastEntry)) {
        output <- loadFromLocalRepo(isInRepo$artifact[lastOne],
                                 repoDir = cacheRepo, value = TRUE)
        # Class-specific message
        .cacheMessage(output, functionDetails$functionName)

        suppressWarnings(
          archivist::addTagsRepo(isInRepo$artifact[lastOne],
                                 repoDir = cacheRepo,
                                 tags = paste0("accessed:", Sys.time()))
        )

        if (sideEffect) {
          needDwd <- logical(0)
          fromCopy <- character(0)
          cachedChcksum <- attributes(output)$chcksumFiles

          if (!is.null(cachedChcksum)) {
            for (x in cachedChcksum) {
              chcksumName <- sub(":.*", "", x)
              chcksumPath <- file.path(cacheRepo, basename(chcksumName))

              if (file.exists(chcksumPath)) {
                checkDigest <- TRUE
              } else {
                checkCopy <- file.path(cacheRepo, "gallery", basename(chcksumName))
                if (file.exists(checkCopy)) {
                  chcksumPath <- checkCopy
                  checkDigest <- TRUE
                  fromCopy <- c(fromCopy, basename(chcksumName))
                } else {
                  checkDigest <- FALSE
                  needDwd <- c(needDwd, TRUE)
                }
              }

              if (checkDigest) {
                if (quick) {
                  sizeCurrent <- lapply(chcksumPath, function(z) {
                    list(basename(z), file.size(z))
                  })
                  chcksumFls <- lapply(sizeCurrent, function(z) {
                    digest::digest(z, algo = algo)
                  })
                } else {
                  chcksumFls <- lapply(chcksumPath, function(z) {
                    digest::digest(file = z, algo = algo)
                  })
                }
                # Format checksum from current file as cached checksum
                currentChcksum <- paste0(chcksumName, ":", chcksumFls)

                # List current files with divergent checksum (or checksum missing)
                if (!currentChcksum %in% cachedChcksum) {
                  needDwd <- c(needDwd, TRUE)
                } else {
                  needDwd <- c(needDwd, FALSE)
                }
              }
            }
          }
          if (any(needDwd)) {
            do.call(FUN, list(...))
          }

          if (NROW(fromCopy)) {
            repoTo <- file.path(cacheRepo, "gallery")
            lapply(fromCopy, function(x) {
              file.copy(from = file.path(repoTo, basename(x)),
                        to = file.path(cacheRepo), recursive = TRUE)
            })
          }
        }

        # This allows for any class specific things
        output <- .prepareOutput(output, cacheRepo, ...)

        if (length(debugCache)) {
          if (!is.na(pmatch(debugCache, "complete")) | isTRUE(debugCache))
            output <- .debugCache(output, preDigest, ...)
        }
        return(output)
      }
    }

    # RUN the function call
    output <- do.call(FUN, list(...))

    # Delete previous version if notOlderThan violated --
    #   but do this AFTER new run on previous line, in case function call
    #   makes it crash, or user interrupts long function call and wants
    #   a previous version
    if (nrow(isInRepo) > 0) {
      # flush it if notOlderThan is violated
      if (notOlderThan >= lastEntry) {
        suppressWarnings(rmFromLocalRepo(isInRepo$artifact[lastOne], repoDir = cacheRepo))
      }
    }

    # need something to attach tags to if it is actually NULL
    isNullOutput <- if (is.null(output)) TRUE else FALSE
    if (isNullOutput) output <- "NULL"

    attr(output, "tags") <- paste0("cacheId:", outputHash)
    attr(output, "call") <- ""

    if (sideEffect) {
      postRepo <- file.path(cacheRepo, list.files(cacheRepo))
      dwdFlst <- setdiff(postRepo, priorRepo)
      if (length(dwdFlst > 0)) {
        if (quick) {
          sizecurFlst <- lapply(dwdFlst, function(x) {
            list(basename(x), file.size(file.path(x)))
          })
          cachecurFlst <- lapply(sizecurFlst, function(x) {
            digest::digest(x, algo = algo)
          })
        } else {
          cachecurFlst <- lapply(dwdFlst, function(x) {
            digest::digest(file = x, algo = algo)
          })
        }
        cacheName <- file.path(basename(cacheRepo), basename(dwdFlst), fsep = "/")
        attr(output, "chcksumFiles") <- paste0(cacheName, ":", cachecurFlst)

        if (makeCopy) {
          repoTo <- file.path(cacheRepo, "gallery")
          lapply(dwdFlst, function(x) {
            file.copy(from = file.path(cacheRepo, basename(x)),
                      to = file.path(repoTo), recursive = TRUE)
          })
        }
      }
    }

    if (isS4(FUN)) attr(output, "function") <- FUN@generic

    # Can make new methods by class to add tags to outputs
    outputToSave <- .addTagsToOutput(output, outputObjects, FUN,
                                     preDigestByClass)

    # This is for write conflicts to the SQLite database
    #   (i.e., keep trying until it is written)
    written <- FALSE
    outputToSaveIsList <- is.list(outputToSave)
    if (outputToSaveIsList) {
      rasters <- unlist(lapply(outputToSave, is, "Raster"))
    } else {
      rasters <- is(outputToSave, "Raster")
    }
    if (any(rasters)) {
      if (outputToSaveIsList) {
        outputToSave[rasters] <- lapply(outputToSave[rasters], function(x)
          .prepareFileBackedRaster(x, repoDir = cacheRepo))
      } else {
        outputToSave <- .prepareFileBackedRaster(outputToSave, repoDir = cacheRepo)
      }
      attr(outputToSave, "tags") <- attr(output, "tags")
      attr(outputToSave, "call") <- attr(output, "call")
      if (isS4(FUN))
        attr(outputToSave, "function") <- attr(output, "function")
      output <- outputToSave
    }
    if (length(debugCache)) {
      if (!is.na(pmatch(debugCache, "complete"))) {
        output <- .debugCache(output, preDigest, ...)
        outputToSave <- .debugCache(outputToSave, preDigest, ...)
      }
    }

    while (!written) {
      objSize <- .objSizeInclEnviros(outputToSave)
      userTags <- c(userTags,
                    paste0("function:", functionDetails$functionName),
                    paste0("object.size:", objSize),
                    paste0("accessed:", Sys.time()))
      saved <- suppressWarnings(try(
        saveToLocalRepo(outputToSave, repoDir = cacheRepo, artifactName = "Cache",
                        archiveData = FALSE, archiveSessionInfo = FALSE,
                        archiveMiniature = FALSE, rememberName = FALSE,
                        silent = TRUE, userTags = userTags),
        silent = TRUE
      ))

      # This is for simultaneous write conflicts. SQLite on Windows can't handle them.
      written <- if (is(saved, "try-error")) {
        Sys.sleep(0.05)
        FALSE
      } else {
        TRUE
      }
    }

    if (isNullOutput) return(NULL) else return(output)
})

#' Deprecated functions
#' @export
#' @importFrom archivist showLocalRepo rmFromLocalRepo
#' @inheritParams Cache
#' @rdname reproducible-deprecated
setGeneric("cache", signature = "...",
           function(cacheRepo = NULL, FUN, ..., notOlderThan = NULL,  # nolint
                    objects = NULL, outputObjects = NULL, algo = "xxhash64") {
             archivist::cache(cacheRepo, FUN, ..., notOlderThan, algo)
})

#' @export
#' @rdname reproducible-deprecated
setMethod(
  "cache",
  definition = function(cacheRepo, FUN, ..., notOlderThan, objects,  # nolint
                        outputObjects, algo) {
    .Deprecated("Cache", package = "reproducible",
                msg = paste0(
                  "cache from SpaDES and reproducible is deprecated.\n",
                  "Use Cache with capital C if you want the robust Cache function.\n",
                  "e.g., Cache(", getFunctionName(FUN, ..., overrideCall = "cache")$functionName,
                  ", ", paste(list(...), collapse = ", "), ")"
                )
    )
    Cache(FUN = FUN, ..., notOlderThan = notOlderThan, objects = objects,
          outputObjects = outputObjects, algo = algo, cacheRepo = cacheRepo)
})
