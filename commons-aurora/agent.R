# Builds the Aurora Lending commons agent. Sourced by app.R and deploy.R.

source("athena.R", local = TRUE)
source("connect_aws.R", local = TRUE)

options(commons.context_cache = "commons-cache")

# Claude on Amazon Bedrock through a US inference profile. Avoid Claude
# Haiku 4.5 here: the demo account enforces a guardrail on that model.
AURORA_MODEL <- Sys.getenv("AURORA_MODEL", "us.anthropic.claude-sonnet-5-5")

# "normal" lets the agent write its own SQL and R when no trusted calculation
# answers. Its R session needs an OS sandbox (Landlock or unprivileged user
# namespaces). "trusted only" answers only from the trusted calculations and
# needs no sandbox.
AURORA_MODE <- Sys.getenv("AURORA_MODE", "normal")

# Load the four tables from Athena once per R process. Every Shiny session
# shares these data frames; commons copies them into an in-process DuckDB
# for each agent, so agent-written SQL never runs against Athena directly.
aurora_tables <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) {
      aws_credentials_refresh()
      as_bool <- function(x) tolower(as.character(x)) %in% c("true", "1")
      loans <- athena_read("SELECT * FROM fct_loan_performance")
      loans$charged_off <- as_bool(loans$charged_off)
      loans$origination_date <- as.Date(loans$origination_date)
      cache <<- list(
        fct_loan_performance = loans,
        dim_borrower = athena_read("SELECT * FROM dim_borrower"),
        dim_loan_product = athena_read("SELECT * FROM dim_loan_product"),
        dim_date = athena_read("SELECT * FROM dim_date")
      )
    }
    cache
  }
})

# FICO bands exactly as the Portfolio Risk Review report defines them:
# cut(fico, breaks = c(579, 620, 660, 700, 740, 780, 850)), which is
# right-closed, so a score of 620 falls in "580-619".
FICO_BAND_SQL <- "
  CASE
    WHEN fico_at_origination <= 620 THEN '580-619'
    WHEN fico_at_origination <= 660 THEN '620-659'
    WHEN fico_at_origination <= 700 THEN '660-699'
    WHEN fico_at_origination <= 740 THEN '700-739'
    WHEN fico_at_origination <= 780 THEN '740-779'
    ELSE '780+'
  END"

aurora_measures <- function() {
  commons::semantic_layer(
    commons::measure(
      "portfolio_summary",
      paste(
        "Size and performance of the whole loan book: number of loans,",
        "first and last vintage, total originated, total outstanding, and",
        "the realized charge-off rate. Source: Portfolio Risk Review,",
        "'Portfolio at a glance'."
      ),
      function(aurora_lending) {
        DBI::dbGetQuery(aurora_lending, "
          SELECT COUNT(*) AS loans,
                 MIN(YEAR(origination_date)) AS first_vintage,
                 MAX(YEAR(origination_date)) AS last_vintage,
                 SUM(principal_amount) AS originated_usd,
                 SUM(outstanding_balance) AS outstanding_usd,
                 AVG(CASE WHEN charged_off THEN 1.0 ELSE 0.0 END) AS charge_off_rate
          FROM fct_loan_performance")
      },
      title = "Portfolio summary"
    ),
    commons::measure(
      "performance_by_purpose",
      paste(
        "Loans, amount originated, average APR, average FICO at origination,",
        "and realized charge-off rate for each loan purpose, highest",
        "charge-off rate first. Source: Portfolio Risk Review,",
        "'Performance by loan purpose'."
      ),
      function(aurora_lending) {
        DBI::dbGetQuery(aurora_lending, "
          SELECT purpose,
                 COUNT(*) AS loans,
                 SUM(principal_amount) AS originated_usd,
                 AVG(apr) AS avg_apr,
                 AVG(fico_at_origination) AS avg_fico,
                 AVG(CASE WHEN charged_off THEN 1.0 ELSE 0.0 END) AS charge_off_rate
          FROM fct_loan_performance
          GROUP BY purpose
          ORDER BY charge_off_rate DESC")
      },
      title = "Performance by loan purpose"
    ),
    commons::measure(
      "charge_off_by_fico_band",
      paste(
        "Number of loans and realized charge-off rate for each FICO band at",
        "origination (580-619, 620-659, 660-699, 700-739, 740-779, 780+).",
        "Source: Portfolio Risk Review, 'By FICO band at origination'."
      ),
      function(aurora_lending) {
        DBI::dbGetQuery(aurora_lending, paste0("
          SELECT ", FICO_BAND_SQL, " AS fico_band,
                 COUNT(*) AS loans,
                 AVG(CASE WHEN charged_off THEN 1.0 ELSE 0.0 END) AS charge_off_rate
          FROM fct_loan_performance
          GROUP BY fico_band
          ORDER BY fico_band"))
      },
      title = "Charge-off rate by FICO band"
    ),
    commons::measure(
      "charge_off_by_vintage_and_fico_band",
      paste(
        "Realized charge-off rate for each origination year (vintage) and",
        "FICO band. Recent vintages have had less time to charge off.",
        "Source: Portfolio Risk Review, 'By vintage and FICO band'."
      ),
      function(aurora_lending) {
        DBI::dbGetQuery(aurora_lending, paste0("
          SELECT YEAR(origination_date) AS vintage,
                 ", FICO_BAND_SQL, " AS fico_band,
                 COUNT(*) AS loans,
                 AVG(CASE WHEN charged_off THEN 1.0 ELSE 0.0 END) AS charge_off_rate
          FROM fct_loan_performance
          GROUP BY vintage, fico_band
          ORDER BY vintage, fico_band"))
      },
      title = "Charge-off rate by vintage and FICO band"
    )
  )
}

build_agent <- function(log = TRUE) {
  aws_credentials_refresh()
  tables <- aurora_tables()
  aurora <- commons::commons(
    data_sources = list(
      aurora_lending = do.call(
        commons::data_source,
        c(tables, list(dictionary = "dictionaries/aurora_lending.yaml"))
      )
    ),
    semantic_layer = aurora_measures(),
    context_layer = commons::context_layer("context/portfolio-risk-review.md")
  )
  commons::agent(
    ellmer::chat_aws_bedrock(model = AURORA_MODEL),
    commons = aurora,
    mode = AURORA_MODE,
    log = log
  )
}
