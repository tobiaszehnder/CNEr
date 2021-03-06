### -----------------------------------------------------------------
### Compare two DNAStringSet. Match is TRUE, Mismatch is FALSE.
### Not used, exported so far.
compDNAStringSet <- function(DNAStringSet1, DNAStringSet2){
  tmp <- cbind(strsplit(as.character(DNAStringSet1), ""), 
               strsplit(as.character(DNAStringSet2), ""))
  apply(tmp, 1, function(x){x[[1]] == x[[2]]})
}
#system.time(foo<-compDNAStringSet(targetSeqs(myAxt), querySeqs(myAxt)))
#system.time(foo1<-RleList(foo))


### -----------------------------------------------------------------
### For a GRanges object of filter, make the revered GRanges. 
### chromSize needs to be known.
### Not used, exported so far.
makeReversedFilter <- function(qFilter, chromSizes){
  revFilterBed <- GRanges(seqnames=seqnames(qFilter),
                          ranges=IRanges(start=chromSizes[
                                         as.character(seqnames(qFilter))] - 
                                         end(qFilter),
                                         end=chromSizes[
                                         as.character(seqnames(qFilter))] - 
                                         start(qFilter)
                                         ),
                          strand=Rle("-"))
  return(revFilterBed)
}

### -----------------------------------------------------------------
### Generate a translation from sequence index to alignment index.
### Not used, exported so far.
seqToAlignment <- function(DNAStringSet){
  foo <- strsplit(as.character(DNAStringSet), "")
  foo <- lapply(foo, function(x){grep("-", x, invert=TRUE)})
  return(foo)
}

### -----------------------------------------------------------------
### rever the cigar string. i.e. 20M15I10D will be reversed to 10D15I20M.
### EXPORTED!
reverseCigar <- function(cigar, ops=CIGAR_OPS){
  cigarOps <- lapply(explodeCigarOps(cigar, ops=ops), rev)
  cigarOpsLengths <- lapply(explodeCigarOpLengths(cigar, ops=ops), rev)
  cigar <- mapply(paste0, cigarOpsLengths, cigarOps, collapse="")
  return(cigar)
}

### -----------------------------------------------------------------
### Better system interface
### Not exported.
my.system <- function(cmd, echo=TRUE, intern=FALSE, ...){
  if (echo){
    message(cmd)
  }
  res <- system(cmd, intern=intern, ...)
  if (!intern){
    stopifnot(res == 0)
  }
  return(res)
}


### -----------------------------------------------------------------
### Return the bin number that should be assigned to 
### a feature spanning the given range. * USE THIS WHEN CREATING A DB *
### Exported!
.validateBinRanges <- function(starts, ends){
  if(length(starts) != length(ends)){
    stop("starts and ends must be same length!")
  }
  if(any(ends <= 0 | starts <= 0)){
    stop("starts and ends must be positive integers!")
  }
  if(any(ends >= 2^30 | starts >= 2^30)){
    stop("starts and ends out of range (max is 2Gb)")
  }
  if(any(starts > ends)){
    stop("starts must be equal or smaller than ends!")
  }
  return(TRUE) 
}

binFromCoordRange <- function(starts, ends){
  .validateBinRanges(starts, ends)
  bins <- .Call2("bin_from_coord_range", as.integer(starts), 
                 as.integer(ends), PACKAGE="CNEr")
  return(bins)
}

### -----------------------------------------------------------------
### Return the set of bin ranges that overlap a given coordinate range. 
### It is usually more convenient to use bin_restriction string 
### than to use this method directly.
### EXPORTED!
binRangesFromCoordRange <- function(start, end){
  stopifnot(length(start) == 1 && length(end) == 1)
  .validateBinRanges(start, end)
  binRanges <- .Call2("bin_ranges_from_coord_range", 
                      as.integer(start), as.integer(end), PACKAGE="CNEr")
  return(binRanges)
}

### -----------------------------------------------------------------
### Given a coordinate range, return a string to be used in the WHERE 
### section of a SQL SELECT statement that is to 
### select features overlapping a certain range. * USE THIS WHEN QUERYING A DB *
### EXPORTED!
.singleBinRestrictionString <- function(start, end, field="bin"){
  binRanges <- binRangesFromCoordRange(start, end)
  cmdString <- mapply(function(x,y, field){
    if(x==y){
      paste(field, "=", x)
    }else{
      paste(field, ">=", x, "and", field, "<=", y)
    }
  }, binRanges[ ,1], binRanges[ ,2], field=field
  )
  cmdString <- paste(cmdString, collapse=") or (")
  cmdString <- paste0("((", cmdString, "))")
  return(cmdString)
}

binRestrictionString <- function(start, end, field="bin"){
  stopifnot(length(start) == length(end))
  ans <- mapply(.singleBinRestrictionString, start, end,
                MoreArgs=list(field=field), SIMPLIFY=TRUE)
  return(ans)
}

#get_cne_ranges_in_region = function(CNE, whichAssembly=c(1,2), 
#                                    chr, CNEstart, CNEend, min_length){
#  ## This CNE data.frame does not have the bin column yet. 
#  ## I am not sure whether it is necessary to add this column in R since 
#  ## it's quiet fast to select the cnes which meet the criteria (~0.005 second).
#  if(whichAssembly == 1)
#    res = subset(CNE, chr1==chr & start1>=CNEstart & end1<=CNEend & 
#                 end1-start1+1>=min_length & end2-start2+1>=min_length, 
#                 select=c("start1", "end1"))
#  else if(whichAssembly == 2)
#    res = subset(CNE, chr2==chr & start2>=CNEstart & end2<=CNEend & 
#                 end1-start1+1>=min_length & end2-start2+1>=min_length, 
#                 select=c("start2", "end2"))
#  else
#    stop("whichAssembly should be 1 or 2")
#  # Here we return a IRanges object to store the start and end
#  res = IRanges(start=res[ ,1], end=res[ ,2])
#  return(res)
#}
#
#
#get_cne_ranges_in_region_partitioned_by_other_chr = 
#  function(CNE, whichAssembly=c(1,2), chr, CNEstart, CNEend, min_length){
#  if(whichAssembly == 1)
#    res = subset(CNE, chr1==chr & start1>=CNEstart & end1<=CNEend & 
#                 end1-start1+1>=min_length & end2-start2+1>=min_length, 
#                 select=c("chr2", "start1", "end1"))
#  else if(whichAssembly == 1)
#    res = subset(CNE, chr2==chr & start2>=CNEstart & end2<=CNEend & 
#                 end1-start1+1>=min_length & end2-start2+1>=min_length, 
#                 select=c("chr1", "start2", "end2"))
#  else
#    stop("whichAssembly should be 1 or 2")
#  # Here we return a GRanges object.
#  res = GRanges(seqnames=res[ ,1], 
#                ranges=IRanges(start=res[ ,2], end=res[ ,3]))
#  return(res)
#}

queryAnnotationSQLite <- function(dbname, tablename, chr, start, end){
  con <- dbConnect(SQLite(), dbname=dbname)
  query <- paste("SELECT * from", tablename, "WHERE", 
                binRestrictionString(start, end, "bin"), "AND", 
                "chromosome=", paste0("'", chr, "'"), 
                "AND start >=", start, "AND end <=", end)
  ans <- dbGetQuery(con, query)
  ans <- ans[ ,c("chromosome", "start", "end", "strand", 
                "transcript", "gene", "symbol")]
}

###------------------------------------------------------------------
### fetchChromSizes fetches the chromosome sizes.
### Exported!
fetchChromSizes <- function(assembly){
  # UCSC
  message("Trying UCSC...")
  goldenPath <- "http://hgdownload.cse.ucsc.edu/goldenPath/"
  targetURL <- paste0(goldenPath, assembly, "/database/chromInfo.txt.gz")
  targetFile <- tempfile(pattern = "chromSize", tmpdir = tempdir(), fileext = "")
  download <- try(download.file(url=targetURL, destfile=targetFile, 
                                method="auto", quiet=TRUE)
  )
  if(class(download) != "try-error"){
    ans <- read.table(targetFile, header=FALSE, stringsAsFactors=FALSE)
    unlink(targetFile)
    ans <- Seqinfo(seqnames=ans$V1, seqlengths=ans$V2, genome=assembly)
    return(ans)
  }
  # other sources? Add later
  return(NULL)
}

### -----------------------------------------------------------------
### seqlengthsNA: check if any seqlength is NA, then TRUE; otherwise FALSE.
### not exported!
seqlengthsNA <- function(x){
  if(is(x, "GRanges")){
    if(any(is.na(seqlengths(x))))
      return(TRUE)
  }else if(is(x, "GRangePairs")){
    if(any(is.na(seqlengths(first(x)))))
      return(TRUE)
    if(any(is.na(seqlengths(second(x)))))
      return(TRUE)
  }else{
    stop("`x`  must be a `GRanges` or `GRangePairs` object!")
  }
  return(FALSE)
}

### -----------------------------------------------------------------
### savefig: ‘savefig’ saves figures to files with minimal surrounding white
### space, suitable for inclusion in books and reports. ‘savefig’ is
### especially good for including plots in LaTeX. File formats
### supported are eps, pdf and jpg. Default file format for ‘savefig’
### is eps. The other functions are wrappers for saving specific file
### formats.
### Based on the unofficially released package "monash" from Rob J Hyndman
### Not Exported!
savefig <- function (filename, height=10, width = (1 + sqrt(5))/2*height,
                     type=c("eps","pdf","jpg","png"), pointsize = 10,
                     family = "Helvetica", sublines = 0, toplines = 0, 
                     leftlines = 0, res=300,
                     colormodel=c("srgb", "srgb+gray", "rgb", "rgb-nogray",
                                  "gray", "grey", "cmyk"))
{
  type <- match.arg(type)
  filename <- paste(filename, ".", type, sep = "")
  if(type=="eps")
  {
    postscript(file = filename, horizontal = FALSE,
               width = width/2.54, height = height/2.54, pointsize = pointsize,
               family = family, onefile = FALSE, print.it = FALSE,
               colormodel=colormodel)
  }
  else if(type=="pdf")
  {
    pdf(file = filename, width=width/2.54, height=height/2.54,
        pointsize=pointsize,
        family=family, onefile=TRUE, colormodel=colormodel)
  }
  else if(type=="jpg")
  {
    jpeg(filename=filename, width=width, height=height, res=res,quality=100,
         units="cm")#, pointsize=pointsize*50)
  }
  else if(type=="png")
  {
    png(filename=filename, width=width, height=height, res=res, units="cm")
    #, pointsize=pointsize*50)
  }
  else
    stop("Unknown file type")
  par(mgp = c(2.2, 0.45, 0), tcl = -0.4, 
      mar = c(3.2 + sublines + 0.25 * (sublines > 0),
              3.5 + leftlines, 1 + toplines, 1) + 0.1)
  par(pch = 1)
  invisible()
}
