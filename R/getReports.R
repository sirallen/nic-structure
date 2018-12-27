#' @import httr
#' @import data.table
#' @import dplyr
#' @import stringr
#' @import rvest
#' @importFrom xml2 read_html

getPdfName <- function(rssd, as_of_date) {
  paste0(PDF_DIR, rssd, '-', gsub('-', '', as_of_date), '.pdf')
}

pdf2txt <- function(file_name) {
  # Install xpdf from http://www.foolabs.com/xpdf/download.html
  # and add to system PATH
  system2(
    command = 'pdftotext',
    args = c('-raw', '-nopgbrk', file_name, '-'),
    stdout = TRUE
  )
}

txt2clean <- function(f, save_name) {
  txt <- data.table(V1 = f)
  
  # Drop this pattern: <br>------ Repeat at ####
  # Sometimes splits into multiple lines
  drop <- txt[, which(grepl('<br>', V1) & !grepl('at \\d+', V1)) + 1]
  if (length(drop) > 0) txt <- txt[-drop]
  
  # Careful -- txt[-v] drops all rows when v is empty
  paste.idx <- txt[, which(grepl('<br>', V1) & !grepl('^\\d+ -+\\*', V1))]
  txt[paste.idx - 1, V1:= paste(V1, txt[paste.idx, V1])]
  if (length(paste.idx) > 0) { txt <- txt[-paste.idx] }
  
  # Need to handle both of the following (how to use just one regex?):
  # "1915 -----* + ^ ARAMARK (3837841)<br>----- Repeat at 12171 1914 NEW YORK NY Domestic Entity Other"
  # "1915 -----* + ^ ARAMARK (3837841)<br>----- Repeat at"
  txt[, V1:= gsub(' ?<br>.*(?= \\d+ )', '', V1, perl = TRUE)]
  txt[, V1:= gsub(' ?<br>.*', '', V1)]
  
  # RowNum > 9999 split on two lines; paste
  # Most of the time, other info is on third line; but sometimes on second, so
  # do this in two steps
  paste.idx <- txt[, which(grepl('^\\d+{4}$', V1))]
  txt[paste.idx, V1:= paste0(V1, txt[paste.idx + 1, V1])]
  if (length(paste.idx) > 0) { txt <- txt[-(paste.idx + 1)] }
  
  paste.idx <- txt[, which(grepl('^\\d+{5}$', V1))]
  txt[paste.idx, V1:= paste(V1, txt[paste.idx + 1, V1])]
  if (length(paste.idx) > 0) { txt <- txt[-(paste.idx + 1)] }
  
  # Remove header/footer - vectorization "trick"
  txt[, V2:= cumsum( c(1, grepl('^\\d+ -+(\\*|[^ ])', V1[-1])) )]
  txt[, V3:= ifelse(grepl('^Report created', V1), V2, 0)]
  txt[, drop:= V2 - cummax(V3) == 0]
  
  txt <- txt[1:(grep('^Total Records', V1) - 1)][
    !as.logical(drop), .(V1, V2)][
      , paste(V1, collapse = ' '), by ='V2'][
        !duplicated(V1)][
          !grepl('Repeat', V1)]
  
  # manual fix (affects Goldman, Citigroup)
  txt[, V1:= sub('(SALVADOR)(Foreign|International|Finance)', '\\1 \\2', V1)]
  
  # Insert "~" delimiters, split
  txt[, V1:= V1 %>% str_replace('(\\d+) ', '\\1~') %>%
        str_replace('(~-*\\*?) ?', '\\1~') %>%
        str_replace('(.*)(~\\+?) ?', '\\1\\2~') %>%
        str_replace('(.*) \\((\\d{3,})\\) ?', '\\1~\\2~') %>%
        str_replace('(~\\d{3,}~\\d*) ?', '\\1~') %>%
        str_replace(' ([A-Z][a-z]+)', '~\\1')]
  
  dt <- txt[, tstrsplit(V1, '~', type.convert = TRUE)]
  
  setnames(dt, c('Idx','Level','Note','Name','Id_Rssd','Parent','Loc','Type'))
  
  dt[, Name:= gsub('^[ ^]+', '', Name)]
  dt[, Loc:= gsub(' *\\(OTHER\\)', '', Loc)]
  dt[, Tier:= str_count(Level, '-') + 1]
  dt[Note == '', Note:= NA_character_]
  dt[, Type:= ENTITY_TYPE_GROUPING$Type.code[match(Type, ENTITY_TYPE_GROUPING$domain)]]
  setnames(dt, 'Type', 'Type.code')
  
  stopifnot( all(dt$Parent < dt$Idx, na.rm = TRUE) )
  
  dt[, Level:= NULL]
  
  dt <- dt[!duplicated(Idx)]
  # An rssd has an entry for each of its parents; results
  # in having multiple Idx; each of its children has an entry
  # for each Idx, so there are duplicate links. Remove these.
  dt[, Parent:= Id_Rssd[match(Parent,Idx)]]
  dt[, Tier:= min(Tier), by=.(Id_Rssd, Parent)]
  dt = dt[!duplicated(dt[, .(Id_Rssd, Parent)])]
  
  fwrite(dt, save_name, quote = TRUE)
  
  return(NULL)
}


getReport <- function(rssd, dt_end = 99991231, as_of_date,
                      params = HTTR_POST_PARAMS, redownload = FALSE) {
  # as_of_date: yyyy-mm-dd
  file_name <- getPdfName(rssd, as_of_date)
  
  if (!file.exists(file_name) | redownload) {
    url <- paste0(SEARCH_FORM_URL, '?parID_RSSD=', rssd, '&parDT_END=', dt_end )
    
    html <- GET(url)
    
    viewstate <- sub('.*id="__VIEWSTATE" value="([0-9a-zA-Z+/=]*).*', '\\1', html)
    event <- sub('.*id="__EVENTVALIDATION" value="([0-9a-zA-Z+/=]*).*', '\\1', html)
    params[['__VIEWSTATE']] <- viewstate
    params[['__EVENTVALIDATION']] <- event
    params[['txtAsOfDate']] <- format.Date(as_of_date, '%m/%d/%Y')
    
    POST(url, body = params, write_disk(file_name, overwrite = TRUE))
    
    txt2clean( pdf2txt(file_name), save_name = gsub('pdf', 'txt', file_name) )
  }
  
  return(NULL)
}

# http://r.789695.n4.nabble.com/writing-binary-data-from-RCurl-and-postForm-td4710802.html
# http://stackoverflow.com/questions/41357811/passing-correct-params-to-rcurl-postform


getInstHistory <- function(rssd, dt_end = 99991231) {
  url <- paste0(INST_HISTORY_URL, '?parID_RSSD=', rssd, '&parDT_END=', dt_end )
  
  table <- read_html(url) %>%
    html_nodes(xpath = '//table[@class="datagrid"]') %>%
    .[[1]] %>%
    html_table(header = TRUE)
  
  table$Id_Rssd <- rssd
  table
}


getInstPrimaryActivity <- function(rssd, dt_end = 99991231) {
  url <- paste0(INST_PROFILE_URL, '?parID_RSSD=', rssd, '&parDT_END=', dt_end )
  
  table <- read_html(url) %>%
    html_nodes(xpath = '//table[@id="Table2"]') %>%
    .[[1]] %>%
    html_table(fill = TRUE) %>%
    setDT()
  
  table <- table[grepl('Activity:', X1), gsub('Activity:\\s', '', X1)]
  data.table(Id_Rssd = rssd, Activity = table)
}


getBhcParent <- function(rssd, dtend = 99991231) {
  url <- paste0(SEARCH_FORM_URL, '?parID_RSSD=', rssd, '&parDT_END=', dt_end )
  
  nodes <- read_html(url) %>%
    html_nodes(xpath = '//select[@id="lbTopHolders"]/option')
  
  if (length(nodes) > 0) {
    parents <- sapply(nodes, html_attr, 'value')
  }
}


getBhcInstHistories <- function() {
  bhcNameList <- fread('data/hc-name-list.txt', key = 'ID_RSSD')
  bhcHistories_file <- 'data/bhc-institution-histories.txt'
  bhcHistories_done <- if (file.exists(bhcHistories_file)) {
    fread(bhcHistories_file) } else NULL
  
  # Include large IHCs -- Credit Suisse USA, UBS Americas, BNP Paribas
  hc10bnRssds <- fread('data/app/HC10bn.csv')$`RSSD ID`
  rssdList <- union(bhcNameList$ID_RSSD, hc10bnRssds)
  rssdList <- setdiff(rssdList, bhcHistories_done$Id_Rssd)
  
  bhcHistories <- list()
  
  i <- 0
  for (rssd in rssdList) {
    i <- i + 1
    if (i %% 50 == 0) cat(i, ' of ', length(rssdList), '\n')
    j <- as.character(rssd)
    
    # Will miss those that became inactive since hc-name-list updated
    tryCatch({
      dt_end <- bhcNameList[J(rssd), NAME_END_DATE[.N]]
      bhcHistories[[j]] <- getInstHistory(
        rssd, dt_end = if (!is.na(dt_end)) dt_end else 99991231)
      },
      error = function(e) message(e)
    )
  }
  
  bhcHistories <- rbindlist(bhcHistories)
  setcolorder(bhcHistories, c('Id_Rssd', 'Event Date', 'Historical Event'))
  
  bhcHistories_done <- rbind(bhcHistories_done, bhcHistories)
  
  setkey(bhcHistories_done, Id_Rssd, `Event Date`)
  fwrite(bhcHistories_done, bhcHistories_file, quote = TRUE)
  
  return(NULL)
  
}


getRssdPrimaryActivities <- function(rssdsList) {
  rssdActivities <- list()
  
  i <- 0
  for (rssd in rssdsList) {
    i <- i + 1
    if (i %% 100 == 0) cat(i, ' of ', length(rssdsList), '\n')
    j <- as.character(rssd)
    
    tryCatch({
      rssdActivities[[j]] <- getInstPrimaryActivity(rssd)
      },
      error = function(e) NULL,
      warning = function(w) NULL
    )
  }
  
  rssdActivities <- rbindlist(rssdActivities)
  
  fwrite(rssdActivities, 'data/rssd-primary-activities.txt', quote = TRUE)
  
  return(NULL)
}
