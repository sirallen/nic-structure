library(shiny)
library(shinyjs)
library(knitr)
library(data.table)
library(networkD3)
library(stringr)
library(rjson)
library(gplots)
library(ggplot2)
library(gridExtra)
source('_functions.R') # also loads some data

load('bhcList.RData')
# updated in observeEvent()
bhcMaxTier = NULL

suppressWarnings(knit('About.Rmd', quiet=TRUE))

legend.key = list(
  'Holding Company'       = 'red',
  'Domestic Bank'         = 'darkorange3',
  'Domestic Nonbank'      = '#3182bd',
  'International Bank'    = 'black',
  'International Nonbank' = 'darkmagenta',
  'Finance Company'       = 'limegreen',
  'Data Processing Servicer' = '#116043',
  'Securities Broker/Dealer' = '#ff7373'
)

legend.key = lapply(legend.key, col2hex)

ColorScale = paste0(
  'd3.scaleOrdinal().domain([',quoteStr(names(legend.key)),'])',
  '.range([',quoteStr(legend.key),'])')

ui = fluidPage(
  shinyjs::useShinyjs(),
  
  tags$head(
    tags$link(rel='shortcut icon', href=''),
    # var countries
    includeScript('ne_50m_admin.json'),

    includeCSS('_bhcMap.css')
  ),
  
  # inside <body>
  tags$style(type='text/css', 'body { overflow-y: scroll; }'),
  tags$head(tags$script(paste0(
    '$(document).on("shiny:connected", function(e) {',
    'Shiny.onInputChange("innerWidth", window.innerWidth);});
    $(window).resize(function(e) {
    Shiny.onInputChange("innerWidth", window.innerWidth);});'))),
  
  titlePanel(
    tags$p(style='font-size:22px', 'Visualizing the Structure of U.S. Bank 
           Holding Companies'),
    windowTitle = 'shinyApp'),
  
  sidebarLayout(
    
    sidebarPanel(
      style = 'position:fixed;width:23%;',
      selectInput(inputId='bhc', label='Select holding company:',
                  choices=bhcList),
      
      selectInput(inputId='asOfDate', label='Date:', choices=''),
      
      radioButtons(inputId='dispType', label='Select display type:',
                   choices=c('Network','Map')),
      
      selectInput(inputId='maxDist', label='Max node distance (map only)',
                  choices=''),
      
      checkboxInput(inputId='legend', label='Show legend', value=TRUE),
      width = 3),
    
    mainPanel(
      tabsetPanel(
        tabPanel(
          title='Display',
          conditionalPanel(
            "input.dispType == 'Network'",
            forceNetworkOutput('network', height='670px')),

          conditionalPanel(
            "input.dispType == 'Map'",
            includeScript('_bhcMap.js'),
            div(id='d3io', class='d3io') )),
        
        tabPanel(
          title='Table',
          div(dataTableOutput(outputId='bhcTable'), style='font-size:85%')),
        
        tabPanel(
          title='Plots',
          tags$h2('Some Plots'),
          paste0('The following plots are updated in response to changes in ',
                 'user-selected input. Not all holding companies have enough ',
                 'data with which to generate plots, so for some selections ',
                 'the plot areas may appear blank.'),
          plotOutput('plot1', width='80%', height='600px'),
          plotOutput('plot2', width='80%', height='600px'),
          plotOutput('plot3', width='80%', height='600px')),
        
        tabPanel(
          title='About',
          withMathJax(includeMarkdown('About.md')))
      ),
      
      width = 9 )
    
  ))

server = function(input,output,session) {
  
  observeEvent(input$bhc, {
    new_choices = rev(gsub(
      '.*-(\\d{4})(\\d{2})(\\d{2}).RData', '\\1-\\2-\\3',
      dir('rdata/', paste0(isolate(input$bhc),'-.*.RData'))))
    
    x = intersect(isolate(input$asOfDate), new_choices)
    
    updateSelectInput(
      session, 'asOfDate', choices = new_choices,
      selected = if (length(x) > 0) x else new_choices[1] )
  })
  
  data = reactive({
    if (input$bhc != '' && input$asOfDate != '') {
      
      load_data(input$bhc, input$asOfDate)
      
    } else NULL })
  
  observeEvent(data(), {
    bhcMaxTier <<- data()[[1]][, max(Tier)]
  }, priority=1)

  observeEvent(data(), {
    bhcMaxDist = bhcMaxTier - 1

    updateSelectInput(
      session, 'maxDist', choices = 1:bhcMaxDist,
      selected = min(4, bhcMaxDist))
  })

  json_data = reactive({
    if (!is.null(data())) {
      # Important!! Need to use copy(); otherwise will also modify
      # Tier in data()[[3]] -- see http://stackoverflow.com/questions/10225098
      nodes = copy(data()[[3]])
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
        Links=data()[[1]], Nodes=data()[[2]], Source='from.id', Target='to.id',
        NodeID='name', Group='Group', Value='value', zoom=T, opacity=.8,
        opacityNoHover=.5, fontSize=10, fontFamily='sans-serif', arrows = T,
        linkDistance = JS('function(d){return 50}'), legend=input$legend,
        colourScale = JS(ColorScale))

    } })
  
  output$plot1 = renderPlot({
    rssd = input$bhc
    if (entity.region[Id_Rssd==rssd, uniqueN(asOfDate) > 2]) {
      dat = entity.region[Id_Rssd==rssd]
      lev = dat[, N[.N], by='Region'][order(V1), Region]
      dat[, Region:= factor(Region, lev)]

      ggplot(dat, aes(x=asOfDate, y=N)) +
        geom_area(aes(fill=Region), color='lightgray', position='stack',
                  size=.2, alpha=.9) +
        geom_line(data=entity.ofc[Id_Rssd==rssd],
                  aes(x=asOfDate, y=N, color=factor('OFC', labels= str_wrap(
                    'Offshore Financial Centers (IMF Classification)', 30))),
                  lwd=1.3, lty=2) +
        scale_color_manual(values='black') +
        labs(x='', y='Number of entities', color='') +
        guides(fill = guide_legend(order=1),
               color = guide_legend(order=2))

    } })
  
  output$plot2 = renderPlot({
    if (!is.null(data())) {
      dat = data()[[3]][-1, .(Id_Rssd, Tier)]
      
      dat[, linkDist:= min(Tier) - 1, by='Id_Rssd']
      dat = dat[!duplicated(Id_Rssd)][order(linkDist)][, .N, by='linkDist']
      dat[, cumShare:= cumsum(N)/sum(N)]
      
      p = ggplot(dat, aes(x = as.factor(linkDist), y = N)) +
        geom_bar(stat='identity', fill='royalblue') +
        labs(x='Distance from center', y='Number of entities')
      
      p + geom_line(aes(x = linkDist, y = cumShare*get_ymax(p)),
                    lty=2, lwd=1.3, col='red') +
        scale_y_continuous(sec.axis = sec_axis(
          ~./get_ymax(p), 'Cum. fraction of entities',
          breaks = seq(0,1,.25)))
      
    } })
  
  output$plot3 = renderPlot({
    # Most common states / countries
    if (!is.null(data())) {
      dat = data()[[3]][, .(Id_Rssd, label)]
      dat = dat[!duplicated(Id_Rssd)]
      dat[, label:= gsub('.*, *(.*)', '\\1', label)]
      
      dat = dat[, .N, by='label']
      dat[, unit:= ifelse(label %in% c(state.abb,'DC'), 'States', 'Countries')]
      # full names for states
      dat[unit=='States', label:= c(state.name, 'District of Columbia')[
        match(label, c(state.abb,'DC'))]]
      # pad with 'NULL' labels (N=0) if number of states or countries < 10
      dat = null_pad_plot3(dat)
      
      dat = dat[order(unit, N)]
      dat = dat[dat[, tail(.I, 10), by='unit']$V1]
      
      p1 = ggplot(dat[unit=='States'], aes(x=factor(label, label), y=N)) +
        geom_bar(stat='identity', fill='coral') +
        coord_flip() +
        labs(x='', y='Number of entities') +
        ggtitle('Top 10 States')
      
      p2 = ggplot(dat[unit=='Countries'], aes(x=factor(label, label), y=N)) +
        geom_bar(stat='identity', fill='coral') +
        coord_flip() +
        labs(x='', y='Number of entities') +
        ggtitle('Top 10 Countries/Territories (outside U.S.)')
      
      grid.arrange(p1, p2, ncol=2)
    }
  })
  
  output$bhcTable = renderDataTable({
    if (!is.null(data())) {

      data()[[1]][, .(i=.I, from, to, to.Rssd=Id_Rssd, to.Type=Type)]

    }} )

  ### Observers send messages to _bhcMap.js

  observe({session$sendCustomMessage(type='jsondata', json_data())})

  observe({session$sendCustomMessage(type='windowResize', list(input$innerWidth))})

  observe({session$sendCustomMessage(type='maxDist', if (input$maxDist != '') {
    list(input$maxDist) } else NULL )})
  
}

shinyApp(ui=ui, server=server)


