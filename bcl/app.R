#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)
library(ggplot2)
library(dplyr)
library(shinyjs)
library(shinydashboard)

# Define UI for application that draws a histogram
# ui <- fluidPage(
# 
#     # Application title
#     titlePanel("Old Faithful Geyser Data"),
# 
#     # Sidebar with a slider input for number of bins 
#     sidebarLayout(
#         sidebarPanel(
#             sliderInput("bins",
#                         "Number of bins:",
#                         min = 1,
#                         max = 50,
#                         value = 30)
#         ),
# 
#         # Show a plot of the generated distribution
#         mainPanel(
#            plotOutput("distPlot")
#         )
#     )
# )

filename <- file.path("data", "bcl-data.csv")

if (file.exists(filename)) {
  bcl <- read.csv(filename, stringsAsFactors = FALSE)
} else {
  bcl <- read.csv("http://pub.data.gov.bc.ca/datasets/176284/BC_Liquor_Store_Product_Price_List.csv",
                  stringsAsFactors = FALSE)
  products <- c("BEER", "REFRESHMENT BEVERAGE", "SPIRITS", "WINE")
  bcl <- dplyr::filter(bcl, PRODUCT_CLASS_NAME %in% products) %>%
    dplyr::select(-PRODUCT_TYPE_NAME, -PRODUCT_SKU_NO, -PRODUCT_BASE_UPC_NO,
                  -PRODUCT_LITRES_PER_CONTAINER, -PRD_CONTAINER_PER_SELL_UNIT,
                  -PRODUCT_SUB_CLASS_NAME) %>%
    rename(Type = PRODUCT_CLASS_NAME,
           Subtype = PRODUCT_MINOR_CLASS_NAME,
           Name = PRODUCT_LONG_NAME,
           Country = PRODUCT_COUNTRY_ORIGIN_NAME,
           Alcohol_Content = PRODUCT_ALCOHOL_PERCENT,
           Price = CURRENT_DISPLAY_PRICE,
           Sweetness = SWEETNESS_CODE)
  bcl$Type <- sub("^REFRESHMENT BEVERAGE$", "REFRESHMENT", bcl$Type)
  dir.create("data", showWarnings = FALSE)
  write.csv(bcl, filename, row.names = FALSE)
}




ui <- dashboardPage(
  dashboardHeader(title = "BC Liquor Store Prices",
                  tags$li(a(href='http://www.bcliquorstores.com',
                            tags$img(src='BCLPIC.jpg',
                                     height='40',width='90')),
                          class = "dropdown")
                  
  ),
  # skin = "purple",
  dashboardSidebar(
    ###-------------------------------
    ## add css
    shinyjs::useShinyjs(),
    shinyjs::inlineCSS(list(.big = "font-size: 2em")),
    div(id = "myapp",
        checkboxInput("big", "Too small?", FALSE),
        ## test for bold input
        strong("Use below filters to choose your Liquor"),
        br(),
        
        p("Time: ",
          span(id = "time", date()),
          a(id = "update", "Update", href = "#")
        ),
        br()
    ),
    
    tags$head(tags$style("body{ color: grey; }")),
    ## css done------------------------
    
    tabsetPanel( id = "optionTabs", type = "tabs",
                 
                 tabPanel("Price", icon = icon("search-dollar"),
                          
                          checkboxInput("sortByPrice", "Sort by price and alcohol", FALSE),
                          
                          conditionalPanel(
                            condition = "input.sortByPrice",
                            uiOutput("PriceSortOutput"),
                            sliderInput("priceInput", "Price", 0, 100, c(25, 40),pre = "$"),
                            sliderInput("alcoholInput", "Alcohol_Content", 2, 76, c(10, 15), post = "°"),
                            uiOutput("typeSelectOutput")
                          )
                 ),
                 tabPanel("Country", icon = icon("globe-americas"),
                          checkboxInput("filterCountry", "Filtered by country", FALSE),
                          conditionalPanel(
                            condition = "input.filterCountry",
                            uiOutput("countrySelectorOutput"))
                 )
    ),
    actionButton("go", "Plot"),
    hr(),
    span("Data source:", 
         tags$a("OpenDataBC",
                href = "https://www.opendatabc.ca/dataset/bc-liquor-store-product-price-list-current-prices")),
    br()
    
    
  ),
  skin = "purple",
  
  dashboardBody(
    
    
    h3(textOutput("summaryText")),
    
    br(),
    tabsetPanel( id = "tabset",
                 
                 tabPanel("Plot",
                          plotOutput("coolplot")
                 ),
                 tabPanel("Results", DT::dataTableOutput("results"))
                 
                 
                 
    ),
    #div(img(src = "logo.gif"),height = '20', width = '180', style="text-align: center;"),
    tags$img(src='logo.gif',
             height='300',width='680'),
    hr(),
    downloadButton("download", "Download data file")
    
  )
)




#===============================================================
# Define server logic

server <- function(input, output) {
  #---------------------css part
  
  shinyjs::onclick("update", shinyjs::html("time", date()))
  
  observe({
    shinyjs::toggleClass("myapp", "big", input$big)
  })
  
  observeEvent(input$reset, {
    shinyjs::reset("myapp")
  })
  
  
  ## action button
  v <- reactiveValues(doPlot = FALSE)
  
  observeEvent(input$go, {
    v$doPlot <- input$go
  })
  
  observeEvent(input$tabset, {
    v$doPlot <- FALSE
  })
  
  
  
  #create reactive variable to reduce duplication
  
  filtered <- reactive({
    
    if(is.null(input$countryInput)){return (NULL)}
    if(is.null(input$priceInput)){return (NULL)}
    if(is.null(input$alcoholInput)){return (NULL)}
    if(is.null(input$typeInput)){return (NULL)}
    bcl %>%
      filter(Price >= input$priceInput[1],
             Price <= input$priceInput[2],
             Alcohol_Content >= input$alcoholInput[1],
             Alcohol_Content <= input$alcoholInput[2],
             Type == input$typeInput,
             Country == input$countryInput
      )
  })
  
  output$typeSelectOutput <- renderUI({
    selectInput("typeInput", "Product type",
                sort(unique(bcl$Type)),
                multiple = TRUE,
                selected = c("WINE"))
  })
  
  output$countrySelectorOutput <- renderUI({
    selectInput("countryInput", "Country",
                sort(unique(bcl$Country)),
                selected = "CANADA")
  })
  
  
  output$coolplot <- renderPlot({
    if(v$doPlot == FALSE){
      return()
    }
    
    if(is.null(filtered())){
      return()
    }
    
    isolate({
      ggplot(filtered(), aes(Alcohol_Content))+
        geom_histogram(colour = "black")+
        theme_classic(20)
      
    })
    
  })
  
  
  output$results <- DT::renderDataTable({
    filtered()
  })
  
  output$summaryText <- renderText({
    numOptions <- nrow(filtered())
    paste0("There are ", numOptions, " options for you")
  })
  
  
  
  
  output$countryOutput <- renderUI({
    selectInput("countryInput", "Country",
                sort(unique(bcl$Country)),
                selected = "CANADA")
  })
  
  output$download <- downloadHandler(
    filename = function() {
      "bcl-results.csv"
    },
    content = function(con) {
      write.csv(prices(), con)
    }
  )
  
  
}

# Run the application 
shinyApp(ui = ui, server = server)
