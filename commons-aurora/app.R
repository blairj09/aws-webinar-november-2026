source("agent.R", local = TRUE)

greeting <- paste(
  "Ask about Aurora Lending Group's consumer loan book. The data is synthetic",
  "and Aurora Lending Group is fictional.",
  "\n\nTry one of these questions:\n\n",
  "- <span class='suggestion'>What is the overall charge-off rate, and how big is the book?</span>\n",
  "- <span class='suggestion'>Which loan purposes have the highest charge-off rates?</span>\n",
  "- <span class='suggestion'>How does the charge-off rate change across FICO bands?</span>\n",
  "- <span class='suggestion'>What is the charge-off rate for borrowers who rent their home?</span>"
)

ui <- shinychat::page_chat(
  "Aurora Lending credit risk agent",
  id = "chat",
  greeting = greeting,
  theme = commons::commons_theme()
)

server <- function(input, output, session) {
  agent <- build_agent() # a fresh agent for every session
  # Keep the Connect-issued AWS credentials fresh during long sessions
  shiny::observe({
    shiny::invalidateLater(5 * 60 * 1000)
    aws_credentials_refresh()
  })
  commons::commons_server("chat", agent)
}

shiny::shinyApp(ui, server)
