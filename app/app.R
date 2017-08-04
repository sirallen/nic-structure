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
source('_loadData.R')
source('_functions.R')

theme_set(
  theme_bw() +
    theme(panel.border=element_rect(color=NA))
)

load('bhcList.RData')
# updated in observeEvent()
bhcMaxTier = NULL

# knit manually to decrease application load time
#suppressWarnings(knit('About.Rmd', quiet=TRUE))

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

ui = navbarPage(
  title = 'Visualizing the Structure of U.S. Bank 
           Holding Companies',
  
  tabPanel(
    shinyjs::useShinyjs(),
    
    title = 'Main',
    
    tags$head(
      tags$link(rel='shortcut icon', href=''),
      # var countries
      includeScript('ne_50m_admin.json'),
      includeCSS('_bhcMap.css'),
      includeScript('_bhcMap.js'),
      includeScript('_toggleLegend.js'),
      
      # size of <svg> canvas controlled inside _bhcMap.js
      tags$script(
        'var dimension = [0, 0];
        $(document).on("shiny:connected", function(e) {
        dimension[0] = window.innerWidth;
        dimension[1] = window.innerHeight;
        Shiny.onInputChange("dimension", dimension)});
        $(window).resize(function(e) {
        dimension[0] = window.innerWidth;
        dimension[1] = window.innerHeight;
        Shiny.onInputChange("dimension", dimension)});')
      ),
    
    # inside <body>
    # Added 'padding-top' since I set navbar position to 'fixed-top'
    tags$style(type='text/css', 'body {overflow-y: scroll; padding-top: 60px}'),
    tags$style(id='legend.style', type='text/css',
               'g.legend {opacity: 1; pointer-events: none;}'),
    # subtract off size of header + tabs (~102px)
    tags$style(type='text/css',
               '#network {height: calc(100vh - 107px) !important;}'),
    
    sidebarLayout(
      
      sidebarPanel(
        # "sticky" sidebar
        style = 'position:fixed;width:23%;',
        selectInput(inputId='bhc', label='Select holding company:',
                    choices=bhcList),
        
        selectInput(inputId='asOfDate', label='Date:', choices='2017-03-31'),
        
        radioButtons(inputId='dispType', label='Select display type:',
                     choices=c('Network','Map')),
        
        selectInput(inputId='maxDist', label='Max node distance (map only)',
                    choices='4'),
        
        checkboxInput(inputId='legend', label='Show legend', value=TRUE),
        checkboxInput(inputId='domOnly', label='Hide international entities',
                      value=FALSE),
        checkboxInput(inputId='bundle', label='Bundle nodes (speeds up rendering 
                      for some large structures)', value=FALSE),
        # checkboxInput(inputID='highlight', label='Highlight nodes added since
        #               previous time period', value=FALSE),
        width = 3),
      
      mainPanel(
        tabsetPanel(
          tabPanel(
            title='Display',
            conditionalPanel(
              "input.dispType == 'Network'",
              forceNetworkOutput('network')),
            
            conditionalPanel(
              "input.dispType == 'Map'",
              div(id='d3io', class='d3io') )),
          
          tabPanel(
            title='Table',
            HTML('<br>'),
            DT::dataTableOutput(outputId='bhcTable'),
            style='font-size:85%'),
          
          tabPanel(
            title='Plots',
            HTML('<br>'),
            
            'The following plots are updated in response to changes in 
            user-selected input. (May take several seconds to render.) 
            Not all holding companies have enough data with which to 
            generate plots, so for some selections the plot areas may 
            appear blank.',
            
            plotOutput('plot1', width='80%', height='600px'),
            
            'Connected scatterplot to track growth along two dimensions:',
            
            plotOutput('plot5', width='80%', height='600px'),
            plotOutput('plot2', width='80%', height='600px'),
            plotOutput('plot3', width='80%', height='600px'),
            
            'Plots below use the ratio of links (connections) to nodes minus one
            (subsidiaries) as a measure of complexity. If each subsidiary has
            exactly one direct parent, the structure is minimally complex with a
            link-node ratio equal to one:',
            
            plotOutput('plot4', width='80%', height='600px'),
            plotOutput('plot6', width='80%', height='600px')),
          
          tabPanel(
            title='History',
            HTML('<br>'),
            
            DT::dataTableOutput(outputId='historyTable'),
            style='font-size:85%'
          )
          
        ),
        
        width = 9 )
      
    )),
  
  tabPanel(
    title='HCs > $10B',
    fluidRow(
      column(3, 'Holding Companies with Assets Greater than $10 Billion'),
      
      column(9, DT::dataTableOutput(outputId='HC10bnTable'),
             style='font-size:85%')
    )),
  
  tabPanel(
    title='Coverage',
    fluidRow(
     column(3, 'This chart shows the time period(s) for which structure
            data is available for each holding company. Discontinuous
            segments indicate that an institution may have changed its status
            to something other than a holding company.',
            
            HTML('<br><br>'),

            'Note that each row really traces a particular RSSD; the name
            displayed is the one most recently associated with the RSSD, which
            is not shown.'),
     
     column(9, plotOutput(outputId='coveragePlot', height='1200px'))
    )),
  
  tabPanel(
    title='About',
    fluidRow(
      column(2),
      column(8, includeMarkdown('About.md')),
      column(2)
    )),
  
  # Additional navbarPage() options
  fluid = TRUE, inverse = TRUE, position = 'fixed-top',
  windowTitle = 'shinyApp'
)


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
      selected = bhcMaxDist)
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
      links = copy(data()[[1]])
      nodes = copy(data()[[2]])
      nodes[, Nodesize:= .1]
      
      if (input$domOnly) {
        # Remove foreign nodes and any descendants which become disconnected
        # from the main graph (may include nodes which are not foreign)
        links[nodes, on=.(from.id==id), from.Group:= i.Group]
        links = links[!(grepl('International', Group) |
                          grepl('International', from.Group))]
        
        # Prune the disconnected pieces
        while (links[, any(!from.id %in% c(0, links$to.id))]) {
          links = links[from.id %in% c(0, to.id)]
        }
        
        nodes = nodes[c(TRUE, id[-1] %in% links$to.id)]
        # update ids
        nodes[, i:= .I - 1L]
        links[nodes, on=.(to.id==id), to.id:= i]
        links[nodes, on=.(from.id==id), from.id:= i]
        nodes[, `:=`(id = i, i = NULL)]
      }
      
      if (input$bundle) {
        # set of links to "terminal" nodes (no children)
        links.toTerminal = links[!links[, .(from.id)], on=.(to.id==from.id)]
        # counts of total children (N) and terminal children (M)
        numChildren = links[, .N, by='from.id'][
          links.toTerminal[, .(M=.N), by='from.id'], on='from.id']
        bundleNodes = numChildren[N > 3, .(from.id, M)]
        
        # Remove links to terminal children of parents in bundleNodes
        links = links[!links.toTerminal[bundleNodes[, .(from.id)], on='from.id'],
                      on=.(from.id, to.id)]
        # Remove those terminal children from nodes
        nodes = nodes[id %in% c(0, unique(links$to.id))]
        nodes[bundleNodes, on=.(id==from.id), Nodesize:= as.double(M+4)]
        # update ids
        nodes[, i:= .I - 1L]
        links[nodes, on=.(to.id==id), to.id:= i]
        links[nodes, on=.(from.id==id), from.id:= i]
        nodes[, `:=`(id = i, i = NULL)]
      }

      forceNetwork(
        Links=links, Nodes=nodes, Source='from.id', Target='to.id',
        NodeID='name', Group='Group', Value='value', Nodesize='Nodesize',
        zoom=T, opacity=.8,
        opacityNoHover=.5, fontSize=10, fontFamily='sans-serif', arrows = T,
        linkDistance = JS('function(d){return 50}'),
        legend=TRUE, colourScale = JS(ColorScale))

    } })
  
  output$plot1 = renderPlot({
    # Area plot -- number of entities by region
    rssd = input$bhc
    source('plot_code/plot1.R', local=TRUE)$value
  })
  
  output$plot2 = renderPlot({
    # Distribution of entities by distance from HC
    if (!is.null(data())) {
      source('plot_code/plot2.R', local=TRUE)$value
    }
  })
  
  output$plot3 = renderPlot({
    # Most common states / countries
    if (!is.null(data())) {
      source('plot_code/plot3.R', local=TRUE)$value
    }
  })
  
  output$plot4 = renderPlot({
    # Simple time series: link-node ratio
    rssd = input$bhc
    source('plot_code/plot4.R', local=TRUE)$value
  })
  
  output$plot5 = renderPlot({
    # Connected scatterplot: (n_entities, assets)
    rssd = input$bhc
    source('plot_code/plot5.R', local=TRUE)$value
    
  })
  
  output$plot6 = renderPlot({
    # Connected scatterplot: (n_entitites, link-node ratio)
    rssd = input$bhc
    source('plot_code/plot6.R', local=TRUE)$value
  })
  
  # Make sure to use renderDataTable() from /DT/, not /shiny/
  output$bhcTable = DT::renderDataTable({
    if (!is.null(data())) {
      DT::datatable(
        data()[[1]][, .(Entity=to, Parent=from, RSSD=Id_Rssd, Type)]
      )
    }
  })
  
  output$historyTable = DT::renderDataTable({
    NULL
  })
  
  output$HC10bnTable = DT::renderDataTable({
    DT::datatable(HC10bn, options=list(dom='t', paging=FALSE, ordering=FALSE))
  })
  
  output$coveragePlot = renderPlot({
    source('plot_code/coveragePlot.R', local=TRUE)$value
  })
  
  
  ### Observers send messages to _bhcMap.js
  observe({session$sendCustomMessage('toggleLegend', list(input$legend))})
  
  observe({session$sendCustomMessage('jsondata', json_data())})

  observe({session$sendCustomMessage('windowResize', list(input$dimension))})

  observe({session$sendCustomMessage('maxDist', if (input$maxDist != '') {
    list(input$maxDist) } else NULL )})
  
  #observe({session$sendCustomMessage('toggleHighlight', list(input$highlight))})
  
}

shinyApp(ui=ui, server=server)


