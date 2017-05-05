library(httr)
library(data.table)
library(stringr)

params = list(
  rbRptFormatPDF = 'rbRptFormatPDF',
  lbTypeOfInstitution = '-99',
  grpInstitution = 'rbCurInst',
  grpHMDA = 'rbNonHMDA',
  btnSubmit = 'Submit'
)

pdf2txt = function(file_name) {
  
  system2('pdftotext', args=c('-raw','-nopgbrk',file_name,'-'), stdout=T)

}

txt2clean = function(f, save_name) {
  txt = data.table(V1 = f)
  
  # Drop this pattern: <br>------ Repeat at ####
  # Sometimes splits into multiple lines
  txt = txt[-(which(grepl('<br>', V1) & !grepl('at \\d+', V1)) + 1)]
  
  # Careful -- txt[-v] drops all rows when v is empty
  paste.idx = txt[, which(grepl('<br>', V1) & !grepl('^\\d+ -+\\*', V1))]
  txt[paste.idx-1, V1:= paste(V1, txt[paste.idx, V1])]
  if (length(paste.idx) > 0) { txt = txt[-paste.idx] }
  
  # Need to handle both of the following (how to use just one regex?):
  # "1915 -----* + ^ ARAMARK (3837841)<br>----- Repeat at 12171 1914 NEW YORK NY Domestic Entity Other"
  # "1915 -----* + ^ ARAMARK (3837841)<br>----- Repeat at"
  txt[, V1:= gsub(' ?<br>.*(?= \\d+ )', '', V1, perl=T)]
  txt[, V1:= gsub(' ?<br>.*', '', V1)]
  
  # RowNum > 9999 split on two lines; paste
  # Most of the time, other info is on third line; but sometimes on second, so
  # do this in two steps
  paste.idx = txt[, which(grepl('^\\d+{4}$', V1))]
  txt[paste.idx, V1:= paste0(V1, txt[paste.idx+1, V1])]
  if (length(paste.idx) > 0) { txt = txt[-(paste.idx + 1)] }
  
  paste.idx = txt[, which(grepl('^\\d+{5}$', V1))]
  txt[paste.idx, V1:= paste(V1, txt[paste.idx+1, V1])]
  if (length(paste.idx) > 0) { txt = txt[-(paste.idx + 1)] }
  
  # Remove header/footer - vectorization "trick"
  txt[, V2:= cumsum( c(1, grepl('^\\d+ -+(\\*|[A-Z])', V1[-1])) )]
  txt[, V3:= ifelse(grepl('^Report created', V1), V2, 0)]
  txt[, drop:= V2 - cummax(V3) == 0]
  
  txt = txt[1:(grep('^Total Records', V1)-1)][!as.logical(drop), .(V1,V2)]
  
  txt = txt[, paste(V1, collapse=' '), by='V2']
  
  txt = txt[!duplicated(V1)][!grepl('Repeat', V1)]
  
  # Insert "~" delimiters, split
  txt[, V1:= sub('(\\d+) ', '\\1~', V1)]
  txt[, V1:= sub('(~-*\\*?) ?', '\\1~', V1)]
  txt[, V1:= sub('(.*)(~\\+?) ?', '\\1\\2~', V1)]
  txt[, V1:= sub('(.*) \\((\\d{3,})\\) ?', '\\1~\\2~', V1)]
  txt[, V1:= sub('(~\\d{3,}~\\d*) ?', '\\1~', V1)]
  txt[, V1:= sub(' ([A-Z][a-z]+)', '~\\1', V1)]
  
  dt = txt[, tstrsplit(V1, '~', type.convert=T)]
  
  setnames(dt, c('Idx','Level','Note','Name','Id_Rssd','Parent','Loc','Type'))
  
  dt[, Name:= gsub('^[ ^]+', '', Name)]
  dt[, Loc:= gsub(' *\\(OTHER\\)', '', Loc)]
  dt[, Tier:= str_count(Level, '-') + 1]
  dt[Note=='', Note:= NA_character_]
  
  stopifnot( all(dt$Parent < dt$Idx, na.rm=T) )
  
  dt[, Level:= NULL]
  
  dt = dt[!duplicated(Idx)]
  
  fwrite(dt, save_name, quote=T)
  
}


getReport = function(rssd, dt_end, as_of_date) {
  # as_of_date: yyyy-mm-dd
  file_name = paste0('pdf/', rssd, '-', gsub('-','',as_of_date), '.pdf')
  
  if (!file.exists(file_name)) {
    url = paste0(
      'https://www.ffiec.gov/nicpubweb/nicweb/OrgHierarchySearchForm.aspx',
      '?parID_RSSD=', rssd, '&parDT_END=', dt_end )
    
    html = GET(url)
    
    viewstate = sub('.*id="__VIEWSTATE" value="([0-9a-zA-Z+/=]*).*', '\\1', html)
    event = sub('.*id="__EVENTVALIDATION" value="([0-9a-zA-Z+/=]*).*', '\\1', html)
    params[['__VIEWSTATE']] = viewstate
    params[['__EVENTVALIDATION']] = event
    params[['txtAsOfDate']] = format.Date(as_of_date, '%m/%d/%Y')
    
    POST(url, body=params, write_disk(file_name, overwrite=T))
  }
  
  txt2clean( pdf2txt(file_name), paste0('app/',gsub('pdf','txt', file_name)) )
}

# http://r.789695.n4.nabble.com/writing-binary-data-from-RCurl-and-postForm-td4710802.html
# http://stackoverflow.com/questions/41357811/passing-correct-params-to-rcurl-postform

# last day of quarter
# as_of_dates = seq.Date(as.Date('2009-04-01'), as.Date('2016-10-01'), by='3 months') - 1
# mapply(getReport, rssd=2380443, dt_end=99991231, as_of_date=as_of_dates)




