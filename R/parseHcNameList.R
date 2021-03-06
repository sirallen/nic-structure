# Download historical BHC list here:
# https://www.chicagofed.org/banking/financial-institution-reports/bhc-name-list
# Is there an easier way to do this??
#' @import data.table
#' @import stringr

parseHcNameList <- function() {
  
  # Install xpdf from http://www.foolabs.com/xpdf/download.html
  # and add to system PATH
  hcs <- data.table(V1 = system2('pdftotext', args = c(
    '-layout', '-nopgbrk', 'data/hc-name-list-pdf.pdf', '-'), stdout = TRUE))
  
  # Each page is fixed-width, but needs adjustments
  # Remove extraneous rows, split by page num
  hcs <- hcs[V1 != '']
  hcs <- hcs[!grepl('^ *(Pg|Holding)', V1)]
  hcs[, pg:= cumsum(grepl('^.*ID_RSSD', V1))]
  hcs <- split(hcs, by = 'pg', keep.by = FALSE)
  
  hcs <- lapply(hcs, function(z) {
    # drop header text
    z <- z[-1]
    # z[, `:=`(V2 = str_extract(V1, FED_NAMES_RX),
    #          V1 = sub(FED_NAMES_RX, '', V1))]
    # Add an extra space after ID_RSSD or at beginning in lines without
    z[, V1:= sub('( *\\d{6,})?', '\\1  ', V1)]
    # Add an extra space after a Date (or last instance of two spaces, if
    # there is no Date), before Reg District
    #z[, V1:= gsub('(.*(?<=\\d{8}| {2}))(.*)', '\\1  \\2', V1, perl = TRUE)]
    z[, V1:= sub(paste0('( *', FED_NAMES_RX, ' *)$'), '   \\1', V1)]
    # Pad the end with a space
    z[, V1:= str_pad(V1, max(nchar(z$V1)) + 1, 'right')]
  })
  
  # Manual fixes
  # old - 156
  #hcs[[156]][, V1:= gsub('(.*)(BEMIDJI|BERRYVILLE)  ', '\\1 \\2 ', V1)]
  # new
  hcs[[100]][38:.N, V1:= sub('(\\d{8})  ', '  \\1', V1)]
  hcs[[141]][37:.N, V1:= sub('(\\d{8})  ', '  \\1', V1)]
  hcs[[225]][39:.N, V1:= sub('(\\d{8})  ', '  \\1', V1)]
  hcs[[262]][31:.N, V1:= sub('(\\d{8})  ', '  \\1', V1)]
  hcs[[357]][, V1:= sub('(^.{86})(.*$)', '\\1  \\2', V1)]
  
  pg <- 0
  hcs <- lapply(hcs, function(z) {
    pg <<- pg + 1
    # Compute widths for each page
    all_sp <- Reduce(intersect, lapply(str_locate_all(z$V1, ' '), '[', , 1))
    d_all_sp <- diff(c(0, all_sp))
    widths <- all_sp[d_all_sp > 1 & shift(d_all_sp, 1, 1, 'lead') == 1]
    
    if (length(widths) < 8) {
      widths <- all_sp[d_all_sp > 1]
    }
    
    stopifnot(length(widths) == 8)
    
    widths <- diff(c(0, widths))
    z.Con <- textConnection(z$V1)
    z.df  <- read.fwf(z.Con, widths, comment.char = '')
    close(z.Con)
    z.df
  })
  
  hcs <- rbindlist(hcs)
  hcs[] <- lapply(hcs, str_trim)
  
  # paste entries that were split into two rows
  paste.idx <- hcs[, which(is.na(V1))]
  
  if (length(paste.idx) > 0) {
    # Check that none were split into > 2 rows
    stopifnot(all(diff(paste.idx) != 1))
    
    hcs[paste.idx - 1, `:=`(
      V3 = str_trim(paste(V3, hcs[paste.idx, V3])),
      V4 = str_trim(paste(V4, hcs[paste.idx, V4])),
      V5 = str_trim(paste(V5, hcs[paste.idx, V5])))]
    
    hcs <- hcs[-paste.idx]
  }
  
  rm(paste.idx)
  hcs[, c('V1','V6','V7'):= lapply(.SD, as.integer), .SDcols = c('V1','V6','V7')]
  
  setnames(hcs, c('ID_RSSD','ENTITY_TYPE','NAME','CITY','ST/COUNTRY','DATE_OPEN',
                  'NAME_END_DATE','REGULATORY_DISTRICT'))
  
  fwrite(hcs, 'data/hc-name-list.txt', quote = TRUE)
  
  # Note that there are duplicate Id_Rssds when a BHC changed its name,
  # and duplicate Names if Id_Rssd/EntityType/Location changed
  
  return(NULL)
}


checkBhcNameListCoverage <- function() {
  # Check to see if all HCs in txt/ files are in hc-name-list
  hcNameList <- fread('data/hc-name-list.txt')
  setnames(hcNameList, 'ID_RSSD', 'Id_Rssd')
  hcNameList <- hcNameList[!duplicated(Id_Rssd)]
  txtFiles <- dir(TXT_DIR, full.names = TRUE)
  
  allHcs <- rbindlist(
    lapply(txtFiles, function(z) {
      da <- fread(z, select = c('Id_Rssd', 'Type.code', 'Tier', 'Name'))
      top_rssd_name <- da[1, Name]
      da <- da[Type.code %in% HC_TYPES]
      da[, `:=`(yearqtr = str_extract(z, '(?<=-)\\d{8}'),
                top_rssd = str_extract(z, '\\d+'),
                top_rssd_name = top_rssd_name)]
    })
  )
  
  setkey(allHcs, Id_Rssd, yearqtr)
  allHcs <- unique(allHcs)
  
  allHcs[, sum(Id_Rssd %in% hcNameList$Id_Rssd) / .N]
  
  #View( allHcs[!Id_Rssd %in% hcNameList$Id_Rssd] )
}


# Likewise, check that all HCs in FR Y-9Cs are in hc-name-list
