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
theme_set(theme_bw() + theme(panel.border=element_rect(color=NA)))

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

ui = fluidPage(
  shinyjs::useShinyjs(),
  
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
  tags$style(type='text/css', 'body {overflow-y: scroll;}'),
  tags$style(id='legend.style', type='text/css',
             'g.legend {opacity: 1; pointer-events: none;}'),
  # subtract off size of header + tabs (~102px)
  tags$style(type='text/css', '#network {height: calc(100vh - 102px) !important;}'),
  
  titlePanel(
    tags$p(style='font-size:22px', 'Visualizing the Structure of U.S. Bank 
           Holding Companies'),
    windowTitle = 'shinyApp'),
  
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
      checkboxInput(inputId='bundle', label='Bundle nodes (speeds up rendering 
                    for some large networks)', value=FALSE),
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
            #includeScript('_bhcMap.js'),
            div(id='d3io', class='d3io') )),
        
        tabPanel(
          title='Table',
          div(dataTableOutput(outputId='bhcTable'), style='font-size:85%')),
        
        tabPanel(
          title='Plots',
          tags$h2('Some Plots'),
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
          title='About',
          #withMathJax(includeMarkdown('About.md')))
          includeMarkdown('About.md'))
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
    rssd = input$bhc
    if (entity.region[Id_Rssd==rssd, uniqueN(asOfDate) > 2]) {
      dat = entity.region[Id_Rssd==rssd]
      dat.ofc = entity.ofc[Id_Rssd==rssd]
      lev = dat[, N[.N], by='Region'][order(V1), Region]
      dat[, Region:= factor(Region, lev)]
      dat = zero_pad_plot1(dat)
      
      # Define "groups" to plot discontinuous geom_areas separately
      # (i.e., breaks when a firm was not an HC)
      dat[, group:= cumsum(c(TRUE, diff(asOfDate) > 92))]
      dat.ofc[, group:= cumsum(c(TRUE, diff(asOfDate) > 92))]

      p = ggplot(dat, aes(x=asOfDate, y=N))
      
      for (g in dat[, unique(group)]) {
        p = p + geom_area(data=dat[group==g], aes(fill=Region),
                          col='lightgray', pos='stack', size=.2, alpha=.9) +
          geom_line(data=dat.ofc[group==g],
                    aes(x=asOfDate, y=N, color=factor('OFC', labels= str_wrap(
                      'Offshore Financial Centers (IMF Classification)', 30))),
                    lwd=1.3, lty=2)
      }
      
      p + scale_color_manual(values='black') +
        scale_x_date(date_breaks='2 years', labels=function(x) year(x)) +
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
  
  output$plot4 = renderPlot({
    # Simple time series: link-node ratio
    rssd = input$bhc
    if (link.node.ratio[Id_Rssd==rssd, .N > 2]) {
      dat = link.node.ratio[Id_Rssd==rssd]
      dat[, discontinuity:= c(FALSE, diff(asOfDate) > 92)]
      dat[, group:= cumsum(discontinuity)]
      
      p = ggplot(dat, aes(x=asOfDate, y=link.node.ratio)) +
        geom_line(aes(group=group)) +
        scale_x_date(date_breaks='2 years', labels=function(x) year(x)) +
        scale_y_continuous(limits=c(1,NA)) +
        labs(x='', y='#Connections / #Subsidiaries')
      
      # dotted lines for discontinuities
      for (d in dat[, which(discontinuity)]) {
        p = p + geom_path(data=dat[c(d-1,d)], lty=3) }
      
      p
    }
  })
  
  output$plot5 = renderPlot({
    # Connected scatterplot: (n_entities, assets)
    rssd = input$bhc
    if (assets[Id_Rssd==rssd, .N > 2]) {
      dat = entity.region[Id_Rssd==rssd, .(N=sum(N)), by='asOfDate']
      dat.asset = assets[Id_Rssd==rssd]
      
      dat = dat[dat.asset, on=.(asOfDate==yearqtr), nomatch=0]
      dat[, discontinuity:= c(FALSE, diff(asOfDate) > 92)]
      dat[, group:= cumsum(discontinuity)]
      
      p = ggplot(dat, aes(x=BHCK2170, y=N)) +
        geom_point() + geom_point(data=dat[month(asOfDate)==12], col='red') +
        geom_path(aes(group=group)) +
        scale_x_continuous(limits=c(0,NA)) +
        scale_y_continuous(limits=c(0,NA)) +
        labs(x='Assets (billions)', y='Number of entities')
      
      # dotted lines for discontinuities
      for (d in dat[, which(discontinuity)]) {
        p = p + geom_path(data=dat[c(d-1,d)], lty=3) }
      
      p + geom_text(data=dat[month(asOfDate)==12],
                    aes(label=year(asOfDate) + 1), size=3, col='red',
                    nudge_x = -.02*dat[, max(BHCK2170)])
    }
    
  })
  
  output$plot6 = renderPlot({
    # Connected scatterplot: (n_entitites, link-node ratio)
    rssd = input$bhc
    if (link.node.ratio[Id_Rssd==rssd, .N] > 2) {
      dat = entity.region[Id_Rssd==rssd, .(N=sum(N)), by='asOfDate']
      dat.ratio = link.node.ratio[Id_Rssd==rssd]
      
      dat = dat[dat.ratio, on='asOfDate']
      dat[, discontinuity:= c(FALSE, diff(asOfDate) > 92)]
      dat[, group:= cumsum(discontinuity)]
      
      p = ggplot(dat, aes(x=link.node.ratio, y=N)) +
        geom_point() + geom_point(data=dat[month(asOfDate)==12], col='red') +
        geom_path(aes(group=group)) +
        scale_x_continuous(limits=c(1,NA)) +
        scale_y_continuous(limits=c(0,NA)) +
        labs(x='#Connections / #Subsidiaries', y='Number of entities')
      
      # dotted lines for discontinuities
      for (d in dat[, which(discontinuity)]) {
        p = p + geom_path(data=dat[c(d-1,d)], lty=3) }
      
      p + geom_text(data=dat[month(asOfDate)==12],
                    aes(label=year(asOfDate) + 1), size=3, col='red',
                    nudge_x = -.02*dat[, max(link.node.ratio) - 1])
      
    }
  })
  
  output$bhcTable = renderDataTable({
    if (!is.null(data())) {

      data()[[1]][, .(i=.I, from, to, to.Rssd=Id_Rssd, to.Type=Type)]

    }} )
  
  
  ### Observers send messages to _bhcMap.js
  observe({session$sendCustomMessage('toggleLegend', list(input$legend))})
  
  observe({session$sendCustomMessage('jsondata', json_data())})

  observe({session$sendCustomMessage('windowResize', list(input$dimension))})

  observe({session$sendCustomMessage('maxDist', if (input$maxDist != '') {
    list(input$maxDist) } else NULL )})
  
}

shinyApp(ui=ui, server=server)


