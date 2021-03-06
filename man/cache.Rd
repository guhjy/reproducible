% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/cache.R
\docType{methods}
\name{Cache}
\alias{Cache}
\alias{Cache,ANY-method}
\title{Cache method that accommodates environments, S4 methods, Rasters}
\usage{
Cache(FUN, ..., notOlderThan = NULL, objects = NULL, outputObjects = NULL,
  algo = "xxhash64", cacheRepo = NULL, compareRasterFileLength = 1e+06,
  userTags = c(), digestPathContent = FALSE, omitArgs = NULL,
  classOptions = list(), debugCache = character(), sideEffect = FALSE,
  makeCopy = FALSE, quick = FALSE)

\S4method{Cache}{ANY}(FUN, ..., notOlderThan = NULL, objects = NULL,
  outputObjects = NULL, algo = "xxhash64", cacheRepo = NULL,
  compareRasterFileLength = 1e+06, userTags = c(),
  digestPathContent = FALSE, omitArgs = NULL, classOptions = list(),
  debugCache = character(), sideEffect = FALSE, makeCopy = FALSE,
  quick = FALSE)
}
\arguments{
\item{FUN}{A function to be called.}

\item{...}{Arguments of \code{FUN} function .}

\item{notOlderThan}{load an artifact from the database only if it was created after notOlderThan.}

\item{objects}{Character vector of objects to be digested. This is only applicable
if there is a list, environment or simList with named objects
within it. Only this/these objects will be considered for caching,
i.e., only use a subset of
the list, environment or simList objects.}

\item{outputObjects}{Optional character vector indicating which objects to
return. This is only relevant for \code{simList} objects}

\item{algo}{The algorithms to be used; currently available choices are
    \code{md5}, which is also the default, \code{sha1}, \code{crc32},
    \code{sha256}, \code{sha512}, \code{xxhash32}, \code{xxhash64} and
    \code{murmur32}.}

\item{cacheRepo}{A repository used for storing cached objects.
This is optional if \code{Cache} is used inside a SpaDES module.}

\item{compareRasterFileLength}{Numeric. Optional. When there are Rasters, that
have file-backed storage, this is passed to the length arg in \code{digest}
when determining if the Raster file is already in the database.
Note: uses \code{\link[digest]{digest}} for file-backed Raster.
Default 1e6. Passed to \code{.prepareFileBackedRaster}.}

\item{userTags}{A character vector with Tags. These Tags will be added to the repository along with the artifact.}

\item{digestPathContent}{Logical. Should arguments that are of class \code{Path}
(see examples below) have their name digested
(\code{FALSE}; default), or their file contents (\code{TRUE}).}

\item{omitArgs}{Optional character string of arguments in the FUN to omit from the digest.}

\item{classOptions}{Optional list. This will pass into \code{.robustDigest} for
specific classes. Should be options that the \code{.robustDigest} knows what
to do with.}

\item{debugCache}{Character or Logical. Either \code{"complete"} or \code{"quick"} (uses
partial matching, so "c" or "q" work). \code{TRUE} is
equivalent to \code{"complete"}.
If \code{"complete"}, then the returned object from the Cache
function will have two attributes, \code{debugCache1} and \code{debugCache2},
which are the entire \code{list(...)} and that same object, but after all
\code{.robustDigest} calls, at the moment that it is digested using
\code{fastdigest}, respectively. This \code{attr(mySimOut, "debugCache2")}
can then be compared to a subsequent call and individual items within
the object \code{attr(mySimOut, "debugCache1")} can be compared.
If \code{"quick"}, then it will return the same two objects directly,
without evalutating the \code{FUN(...)}.}

\item{sideEffect}{Logical. Check if files to be downloaded are found locally
in the \code{cacheRepo} prior to download and try to recover from a copy
(\code{makeCopy} must have been set to \code{TRUE} the first time \code{Cache}
was run). Default is \code{FALSE}.
\emph{NOTE: this argument is experimental and may change in future releases.}}

\item{makeCopy}{Logical. If \code{sideEffect = TRUE}, and \code{makeCopy = TRUE},
a copy of the downloaded files will be made and stored in the \code{cacheRepo}
to speed up subsequent file recovery in the case where the original copy
of the downloaded files are corrupted or missing. Currently only works when
set to \code{TRUE} during the first run of \code{Cache}. Default is \code{FALSE}.
\emph{NOTE: this argument is experimental and may change in future releases.}}

\item{quick}{Logical. If \code{sideEffect = TRUE}, setting this to \code{TRUE},
will hash the file's metadata (i.e., filename and file size) instead of
hashing the contents of the file(s). If set to \code{FALSE} (default),
the contents of the file(s) are hashed.
\emph{NOTE: this argument is experimental and may change in future releases.}}
}
\value{
As with \code{\link[archivist]{cache}}, returns the value of the
function call or the cached version (i.e., the result from a previous call
to this same cached function with identical arguments).
}
\description{
Cache method that accommodates environments, S4 methods, Rasters
}
\details{
Caching R objects using \code{\link[archivist]{cache}} has four important limitations:
\enumerate{
  \item the \code{archivist} package detects different environments as different;
  \item it also does not detect S4 methods correctly due to method inheritance;
  \item it does not detect objects that have file-base storage of information
        (specifically \code{\link[raster]{RasterLayer-class}} objects);
  \item the default hashing algorithm is relatively slow.
}
This version of the \code{Cache} function accommodates those four special,
though quite common, cases by:
\enumerate{
  \item converting any environments into list equivalents;
  \item identifying the dispatched S4 method (including those made through
        inheritance) before hashing so the correct method is being cached;
  \item by hashing the linked file, rather than the Raster object.
        Currently, only file-backed \code{Raster*} objects are digested
        (e.g., not \code{ff} objects, or any other R object where the data
        are on disk instead of in RAM);
  \item using \code{\link[fastdigest]{fastdigest}} internally when the object
        is in RAM, which can be up to ten times faster than
        \code{\link[digest]{digest}}. Note that file-backed objects are still
        hashed using \code{\link[digest]{digest}}.
}

If \code{Cache} is called within a SpaDES module, then the cached entry will automatically
get 3 extra \code{userTags}: \code{eventTime}, \code{eventType}, and \code{moduleName}.
These can then be used in \code{clearCache} to selectively remove cached objects
by \code{eventTime}, \code{eventType} or \code{moduleName}.

\code{Cache} will add a tag to the artifact in the database called \code{accessed},
which will assign the time that it was accessed, either read or write.
That way, artifacts can be shown (using \code{showCache}) or removed (using
\code{clearCache}) selectively, based on their access dates, rather than only
by their creation dates. See example in \code{\link{clearCache}}.
\code{Cache} (uppercase C) is used here so that it is not confused with, and does
not mask, the \code{archivist::cache} function.
}
\note{
As indicated above, several objects require pre-treatment before
caching will work as expected. The function \code{.robustDigest} accommodates this.
It is an S4 generic, meaning that developers can produce their own methods for
different classes of objects. Currently, there are methods for several types
of classes. See \code{\link{.robustDigest}}.

See \code{\link{.robustDigest}} for other specifics for other classes.
}
\section{Filepaths}{

If a function has a path argument, there is some ambiguity about what should be
done. Possibilities include:
\enumerate{
  \item hash the string as is (this will be very system specific, meaning a
        \code{Cache} call will not work if copied between systems or directories);
  \item hash the \code{basename(path)};
  \item hash the contents of the file.
}
If paths are passed in as is (i.e,. character string), the result will not be predictable.
Instead, one should use the wrapper function \code{asPath(path)}, which sets the
class of the string to a \code{Path}, and one should decide whether one wants
to digest the content of the file (using \code{digestPathContent = TRUE}),
or just the filename (\code{(digestPathContent = FALSE)}). See examples.
}

\section{Stochasticity}{

In general, it is expected that caching will only be used when stochasticity
is not relevant, or if a user has achieved sufficient stochasticity (e.g., via
sufficient number of calls to \code{experiment}) such that no new explorations
of stochastic outcomes are required. It will also be very useful in a
reproducible workflow.
}

\examples{
library(raster)

tmpDir <- file.path(tempdir(), "reproducible_examples", "Cache")

## Example 1: basic cache use
ranNumsA <- Cache(rnorm, 4, cacheRepo = tmpDir, userTags = "objectName:a")
ranNumsB <- Cache(runif, 4, cacheRepo = tmpDir, userTags = "objectName:b")

showCache(tmpDir, userTags = c("objectName"))
showCache(tmpDir, userTags = c("^a$")) # regular expression ... "a" exactly
showCache(tmpDir, userTags = c("runif")) # show only cached objects made during runif call

clearCache(tmpDir, userTags = c("runif")) # remove only cached objects made during runif call
showCache(tmpDir) # only those made during rnorm call

clearCache(tmpDir)

## Example 2: using the "accessed" tag
ranNumsA <- Cache(rnorm, 4, cacheRepo = tmpDir, userTags = "objectName:a")
ranNumsB <- Cache(runif, 4, cacheRepo = tmpDir, userTags = "objectName:b")

# access it again, but "later"
Sys.sleep(1)
ranNumsA <- Cache(rnorm, 4, cacheRepo = tmpDir, userTags = "objectName:a")
wholeCache <- showCache(tmpDir)

# keep only items accessed "recently" (i.e., only objectName:a)
onlyRecentlyAccessed <- showCache(tmpDir, userTags = max(wholeCache[tagKey == "accessed"]$tagValue))

# inverse join with 2 data.tables ... using: a[!b]
# i.e., return all of wholeCache that was not recently accessed
toRemove <- unique(wholeCache[!onlyRecentlyAccessed], by = "artifact")$artifact
clearCache(tmpDir, toRemove) # remove ones not recently accessed
showCache(tmpDir) # still has more recently accessed

clearCache(tmpDir)

## Example 3: using keepCache
ranNumsA <- Cache(rnorm, 4, cacheRepo = tmpDir, userTags = "objectName:a")
ranNumsB <- Cache(runif, 4, cacheRepo = tmpDir, userTags = "objectName:b")

# keep only those cached items from the last 24 hours
oneDay <- 60 * 60 * 24
keepCache(tmpDir, after = Sys.time() - oneDay)

# Keep all Cache items created with an rnorm() call
keepCache(tmpDir, userTags = "rnorm")

# Remove all Cache items that happened within a rnorm() call
clearCache(tmpDir, userTags = "rnorm")

showCache(tmpDir) ## empty

## Example 4: searching for multiple objects in the cache

# default userTags is "and" matching; for "or" matching use |
ranNumsA <- Cache(runif, 4, cacheRepo = tmpDir, userTags = "objectName:a")
ranNumsB <- Cache(rnorm, 4, cacheRepo = tmpDir, userTags = "objectName:b")

# show all objects (runif and rnorm in this case)
showCache(tmpDir)

# show objects that are both runif and rnorm
# (i.e., none in this case, because objecs are either or, not both)
showCache(tmpDir, userTags = c("runif", "rnorm")) ## empty

# show objects that are either runif or rnorm ("or" search)
showCache(tmpDir, userTags = "runif|rnorm")

# keep only objects that are either runif or rnorm ("or" search)
keepCache(tmpDir, userTags = "runif|rnorm")

clearCache(tmpDir)

## Example 5: using caching to speed up rerunning expensive computations
ras <- raster(extent(0, 100, 0, 100), res = 1,
              vals = sample(1:5, replace = TRUE, size = 1e4),
              crs = "+proj=lcc +lat_1=48 +lat_2=33 +lon_0=-100 +ellps=WGS84")

# A slow operation, like GIS operation
notCached <- suppressWarnings(
  # project raster generates warnings when run non-interactively
  projectRaster(ras, crs = crs(ras), res = 5, cacheRepo = tmpDir)
)

cached <- suppressWarnings(
  # project raster generates warnings when run non-interactively
  Cache(projectRaster, ras, crs = crs(ras), res = 5, cacheRepo = tmpDir)
)

# second time is much faster
reRun <- suppressWarnings(
  # project raster generates warnings when run non-interactively
  Cache(projectRaster, ras, crs = crs(ras), res = 5, cacheRepo = tmpDir)
)

# recovered cached version is same as non-cached version
all.equal(notCached, reRun) ## TRUE

## Example 6: working with file paths

# if passing a character string, it will take 2 complete passes to before
#  a cached copy is used when it is a save event (read or load is different)
obj <- 1:10
fname <- tempfile(fileext = ".RData")
Cache(saveRDS, obj, file = fname, cacheRepo = tmpDir)
Cache(saveRDS, obj, file = fname, cacheRepo = tmpDir)
Cache(saveRDS, obj, file = fname, cacheRepo = tmpDir) # cached copy is loaded

# however, using asPath(), cached version retrieved after being run once
fname1 <- tempfile(fileext = ".RData")
Cache(saveRDS, obj, file = asPath(fname1), cacheRepo = tmpDir)
Cache(saveRDS, obj, file = asPath(fname1), cacheRepo = tmpDir) # cached copy is loaded

clearCache(tmpDir)

## cleanup
unlink(c("filename.rda", "filename1.rda"))
unlink(dirname(tmpDir), recursive = TRUE)
}
\seealso{
\code{\link[archivist]{cache}}, \code{\link{.robustDigest}}
}
\author{
Eliot McIntire
}
