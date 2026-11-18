# Query Amazon Bedrock model invocation logs with CloudWatch Logs Insights.
#
# Credentials come from the standard AWS chain: the Space's execution role in
# Positron on Amazon SageMaker, or AWS_PROFILE on a laptop. The identity needs
# logs:StartQuery, logs:GetQueryResults, and logs:DescribeLogGroups on the log
# group.

bedrock_log_group <- function() {
  Sys.getenv("BEDROCK_LOG_GROUP", "/aws/bedrock/model-invocations")
}

#' Run one Logs Insights query and return a tibble.
#'
#' The aggregation runs in CloudWatch, so only the summary comes back to R.
logs_insights <- function(query, hours = 24, region = Sys.getenv("AWS_REGION", "us-east-2")) {
  logs <- paws.management::cloudwatchlogs(config = list(region = region))
  end <- as.integer(Sys.time())
  id <- logs$start_query(
    logGroupName = bedrock_log_group(),
    startTime = end - as.integer(hours * 3600),
    endTime = end,
    queryString = query,
    limit = 10000
  )$queryId

  repeat {
    result <- logs$get_query_results(queryId = id)
    if (result$status %in% c("Complete", "Failed", "Cancelled", "Timeout")) break
    Sys.sleep(0.5)
  }
  if (result$status != "Complete") {
    stop("Logs Insights query ", result$status, call. = FALSE)
  }

  rows <- lapply(result$results, function(row) {
    values <- vapply(row, function(cell) cell$value %||% NA_character_, character(1))
    names(values) <- vapply(row, function(cell) cell$field, character(1))
    as.list(values[!startsWith(names(values), "@ptr")])
  })
  if (length(rows) == 0) return(tibble::tibble())
  dplyr::bind_rows(rows) |>
    readr::type_convert(col_types = readr::cols())
}

# Who made the call, from the caller's IAM role. Session names are left out
# on purpose: for SSO users the session name is the person's email address.
#
#   assumed-role/posit-nov2026-persona-mei-chen/mei-chen  -> mei-chen
#   assumed-role/AWSReservedSSO_PowerUser_abc123/<email>  -> SSO: PowerUser
#   assumed-role/sagemaker-demo-execution-role/<session>  -> sagemaker-demo-execution-role
caller_label <- function(role) {
  dplyr::case_when(
    startsWith(role, "posit-nov2026-persona-") ~ sub("^posit-nov2026-persona-", "", role),
    startsWith(role, "AWSReservedSSO_") ~ paste0("SSO: ", sub("^AWSReservedSSO_([^_]+)_.*$", "\\1", role)),
    is.na(role) ~ "unknown",
    TRUE ~ role
  )
}

# The Logs Insights fields shared by every query: the caller's role and the
# model, with the inference profile prefix (us., eu., global.) removed.
LOG_FIELDS <- '
  filter schemaType = "ModelInvocationLog"
  | parse identity.arn "assumed-role/*/*" as role, session
  | parse modelId /^(?:(?:us|eu|apac|global)\\.)?(?<model>.+)$/
'
