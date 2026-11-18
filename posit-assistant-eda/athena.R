# Read Amazon Athena with paws.
#
# Credentials come from the standard AWS chain. In Positron on Amazon
# SageMaker that is the Space's execution role, so there are no keys to set.
# On a laptop, set AWS_PROFILE to a profile that can query the database.

athena_region <- function() Sys.getenv("POSIT_DEMO_REGION", "us-east-2")
athena_database <- function() Sys.getenv("POSIT_DEMO_DATABASE", "aurora_lending")
athena_workgroup <- function() Sys.getenv("POSIT_DEMO_WORKGROUP", "primary")

# The workgroup has no default output location, so every query names one.
athena_staging <- function() {
  bucket <- Sys.getenv("POSIT_DEMO_BUCKET")
  if (!nzchar(bucket)) {
    account <- whoami()$account
    bucket <- sprintf("sagemaker-posit-conf-2026-demo-%s-%s", account, athena_region())
  }
  sprintf("s3://%s/athena-query-results/posit-assistant-eda/", bucket)
}

#' The AWS identity this session runs as.
whoami <- function() {
  id <- paws.security.identity::sts(config = list(region = athena_region()))$get_caller_identity()
  list(
    account = id$Account,
    role = sub("^arn:aws:sts::[0-9]+:assumed-role/([^/]+)/.*$", "\\1", id$Arn),
    region = athena_region()
  )
}

#' Run one SQL query in Athena and return a tibble.
athena_query <- function(sql, database = athena_database()) {
  config <- list(region = athena_region())
  athena <- paws.analytics::athena(config = config)
  id <- athena$start_query_execution(
    QueryString = sql,
    QueryExecutionContext = list(Database = database),
    WorkGroup = athena_workgroup(),
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

  # Read the CSV result from S3 in one request, which is much faster than
  # paging through GetQueryResults.
  location <- sub("^s3://", "", execution$ResultConfiguration$OutputLocation)
  bucket <- sub("/.*$", "", location)
  key <- sub("^[^/]+/", "", location)
  body <- paws.storage::s3(config = config)$get_object(Bucket = bucket, Key = key)$Body
  readr::read_csv(body, show_col_types = FALSE)
}
