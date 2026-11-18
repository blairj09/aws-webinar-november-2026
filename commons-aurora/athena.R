# Read Amazon Athena with paws (no ODBC driver needed, so this runs on any
# Posit Connect server). Credentials come from the standard AWS chain: an
# instance or task role, AWS_PROFILE locally, or environment variables.

AURORA_REGION <- Sys.getenv("POSIT_DEMO_REGION", "us-east-2")
AURORA_DATABASE <- Sys.getenv("POSIT_DEMO_DATABASE", "aurora_lending")
AURORA_WORKGROUP <- Sys.getenv("POSIT_DEMO_WORKGROUP", "primary")

athena_staging <- function() {
  bucket <- Sys.getenv("POSIT_DEMO_BUCKET")
  if (!nzchar(bucket)) {
    account <- paws.security.identity::sts(
      config = list(region = AURORA_REGION)
    )$get_caller_identity()$Account
    bucket <- sprintf("sagemaker-posit-conf-2026-demo-%s-%s", account, AURORA_REGION)
  }
  sprintf("s3://%s/athena-query-results/commons-aurora/", bucket)
}

#' Run one Athena query and return a data frame.
#'
#' Waits for the query, then reads the CSV result from S3 in one request,
#' which is much faster than paging through GetQueryResults.
athena_read <- function(sql, database = AURORA_DATABASE) {
  config <- list(region = AURORA_REGION)
  athena <- paws.analytics::athena(config = config)
  id <- athena$start_query_execution(
    QueryString = sql,
    QueryExecutionContext = list(Database = database),
    WorkGroup = AURORA_WORKGROUP,
    ResultConfiguration = list(OutputLocation = athena_staging())
  )$QueryExecutionId

  repeat {
    execution <- athena$get_query_execution(QueryExecutionId = id)$QueryExecution
    state <- execution$Status$State
    if (state %in% c("SUCCEEDED", "FAILED", "CANCELLED")) break
    Sys.sleep(0.5)
  }
  if (state != "SUCCEEDED") {
    stop("Athena query ", state, ": ", execution$Status$StateChangeReason, call. = FALSE)
  }

  location <- sub("^s3://", "", execution$ResultConfiguration$OutputLocation)
  bucket <- sub("/.*$", "", location)
  key <- sub("^[^/]+/", "", location)
  body <- paws.storage::s3(config = config)$get_object(Bucket = bucket, Key = key)$Body
  utils::read.csv(text = rawToChar(body), stringsAsFactors = FALSE)
}
