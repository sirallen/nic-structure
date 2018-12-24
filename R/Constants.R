#' @import data.table

PDF_DIR <- 'data/pdf/'
TXT_DIR <- 'data/txt/'
CSV_DIR <- 'E:/FR Y-9C/csv'
RDATA_DIR <- 'app/rdata/'

HTTR_POST_PARAMS <- list(
  rbRptFormatPDF = 'rbRptFormatPDF',
  lbTypeOfInstitution = '-99',
  grpInstitution = 'rbCurInst',
  grpHMDA = 'rbNonHMDA',
  btnSubmit = 'Submit'
)

SEARCH_FORM_URL <- 'https://www.ffiec.gov/nicpubweb/nicweb/OrgHierarchySearchForm.aspx'
INST_HISTORY_URL <- 'https://www.ffiec.gov/nicpubweb/nicweb/InstitutionHistory.aspx'
INST_PROFILE_URL <- 'https://www.ffiec.gov/nicpubweb/nicweb/InstitutionProfile.aspx'

STATES_RX <- paste0('(', paste(state.abb, collapse = '|'), '|DC)$')
HC_TYPES <- c('H','K','Q','R','Z','AB')

BHC_CATEGORIES <- c(
  `BHC` = 'Bank Holding Company',
  `FHC - Domestic` = 'Financial Holding Company - Domestic',
  `FHC - Foreign` = 'Financial Holding Company - Foreign',
  `SLHC` = 'Savings & Loan Holding Company',
  `IHC` = 'Intermediate Holding Companies',
  `FBO as BHC` = 'Foreign Banking Organization as a BHC'
  )

ENTITY_TYPE_GROUPING <- fread('app/entityTypeGrouping.csv')
HC_TYPES <- ENTITY_TYPE_GROUPING[group == 'Holding Company', Type.code]
COUNTRY_REGIONS <- fread('app/Country-regions_OFC.csv')
