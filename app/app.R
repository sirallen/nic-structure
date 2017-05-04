library(shiny)
library(shinyjs)
library(data.table)
library(networkD3)
library(stringr)
library(rjson)
source('_functions.R')

load('bhcList.RData')

cc = fread('colorcode.csv')

ColorScale = paste0(
  'd3.scaleOrdinal().domain([',quoteStr(cc$domain),'])',
  '.range([',quoteStr(cc$range),'])')

ui = fluidPage(
  shinyjs::useShinyjs(),
  
  tags$head(
    tags$link(rel='shortcut icon', href=''),
    includeScript('www/math.min.js'),
    includeScript('colorbrewer.js'),
    # var countries
    includeScript('ne_50m_admin.json'),

    includeCSS('_bhcMap.css')
  ),
  
  # inside <body>
  tags$style(type='text/css', 'body { overflow-y: scroll; }'),
  
  titlePanel(
    tags$p(style='font-size:22px', 'Bank Holding Company Organization Hierarchies'),
    windowTitle = 'shinyApp'),
  
  sidebarLayout(
    
    sidebarPanel(
      selectInput(inputId='bhc', label='Select holding company:', choices=bhcList),
      
      selectInput(inputId='asOfDate', label='as of Date:', choices=''),
      
      radioButtons(inputId='dispType', label='Select display type:',
                   choices=c('Network','Map')),
      width = 3),
    
    mainPanel(
      tabsetPanel(
        tabPanel(
          title='Plot',
          conditionalPanel(
            "input.dispType == 'Network'",
            forceNetworkOutput('network', height='670px')),
          
          conditionalPanel(
            "input.dispType == 'Map'",
            includeScript('_bhcMap.js'),
            d3IO('d3io') )),
        
        tabPanel(
          title='Table',
          div(dataTableOutput(outputId='bhcTable'), style='font-size:85%')),
        
        tabPanel(
          title='About',
          includeHTML('About.html'))
      ),
      
      width = 9 )
    
  ))

server = function(input,output,session) {
  
  observeEvent(input$bhc, updateSelectInput(
    session, 'asOfDate', choices=as.character(as.Date(
      str_sub( dir('txt/', paste0(input$bhc,'-.*.txt')), -12, -5 ),
      format='%Y%m%d'))))
  
  data = reactive({
    if (input$bhc != '' && input$asOfDate != '') {
      
      load_data(input$bhc, input$asOfDate)

    } else NULL })
  
  json_data = reactive({
    if (!is.null(data())) {
      nodes = data()[[3]]
      nodes[, Tier:= min(Tier), by='label']
      nodes = unique(nodes[, .(Tier, lat, lng, label)])
      nodes = unname(split(nodes, 1:nrow(nodes)))

      links = data()[[1]]
      links = unique(links[, .(Tier, from.lat, from.lng, to.lat, to.lng)])
      links = unname(split(links, 1:nrow(links)))

      fromJSON(toJSON(list(nodes, links)))

    } else NULL })
  
  output$network = renderForceNetwork({
    if (!is.null(data())) {

      forceNetwork(
        as.data.frame(data()[[1]]), as.data.frame(data()[[2]]), 'from.id', 'to.id',
        NodeID='name', Group='Type', zoom=T, colourScale = JS(ColorScale),
        opacity=.8, opacityNoHover=.5, fontSize=10, fontFamily='sans-serif')

    } })
    

  output$bhcTable = renderDataTable({
    if (!is.null(data())) {

      data()[[1]][, .(i=.I, from, to, to.Rssd=Id_Rssd, to.Type=Type)]

    }} )

  observe({session$sendCustomMessage(type='jsondata', json_data())})
  
}

#runApp( shinyApp(ui=ui, server=server), port=8080, host='192.168.1.124')
shinyApp(ui=ui, server=server)
