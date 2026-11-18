# Prompts and responses from Bedrock model invocation logs.
#
# Invocation logs hold the full request and response for each call. This file
# reads the most recent calls for one caller and reduces each one to what a
# person would want to see: the newest turn that was sent, and what the model
# answered. It handles the Anthropic Messages format (InvokeModel and
# InvokeModelWithResponseStream, which Posit Assistant uses) and the Converse
# format.

#' The most recent invocation log records whose caller ARN contains `caller`.
recent_invocations <- function(caller, hours = 24, n = 30,
                               region = Sys.getenv("AWS_REGION", "us-east-2")) {
  logs <- paws.management::cloudwatchlogs(config = list(region = region))
  start <- (as.numeric(Sys.time()) - hours * 3600) * 1000
  pattern <- sprintf('{ $.identity.arn = "*%s*" }', caller)

  # filter_log_events can return empty pages with a token, so keep paging
  # until the window is exhausted. Then keep the newest n.
  events <- list()
  token <- NULL
  repeat {
    page <- logs$filter_log_events(
      logGroupName = bedrock_log_group(),
      startTime = start,
      filterPattern = pattern,
      nextToken = token
    )
    events <- c(events, page$events)
    token <- page$nextToken
    if (length(token) == 0 || !nzchar(token)) break
  }
  if (length(events) == 0) return(list())
  times <- vapply(events, `[[`, numeric(1), "timestamp")
  events <- events[order(times, decreasing = TRUE)][seq_len(min(n, length(events)))]
  lapply(events, function(e) jsonlite::fromJSON(e$message, simplifyVector = FALSE))
}

# Text from a list of content blocks, in either API format.
blocks_text <- function(blocks) {
  if (is.character(blocks)) return(paste(blocks, collapse = "\n"))
  parts <- vapply(blocks, function(b) {
    type <- b$type %||% names(b)[1]
    if (identical(type, "text")) return(b$text)
    if (identical(type, "tool_result") || identical(type, "toolResult")) {
      inner <- b$content %||% list()
      return(paste0("[Tool result] ", blocks_text(inner)))
    }
    if (identical(type, "tool_use") || identical(type, "toolUse")) {
      return(paste0("[Tool call: ", b$name %||% b$toolUse$name, "]"))
    }
    ""
  }, character(1))
  paste(parts[nzchar(parts)], collapse = "\n\n")
}

#' What was sent: the newest message in the request.
sent_text <- function(record) {
  body <- record$input$inputBodyJson
  if (is.null(body)) return("(The request body is stored in Amazon S3.)")
  messages <- body$messages %||% list()
  if (length(messages) == 0) return("")
  blocks_text(messages[[length(messages)]]$content)
}

#' What came back: the model's text and any tool calls, without thinking.
response_text <- function(record) {
  body <- record$output$outputBodyJson
  if (is.null(body)) return("(The response body is stored in Amazon S3.)")

  # Converse: a single message.
  if (!is.null(body$output$message)) return(blocks_text(body$output$message$content))
  # InvokeModel: a single Messages API response.
  if (!is.null(body$content)) return(blocks_text(body$content))

  # InvokeModelWithResponseStream: rebuild the blocks from the stream events.
  blocks <- list()
  for (event in body) {
    if (identical(event$type, "content_block_start")) {
      blocks[[event$index + 1]] <- list(
        type = event$content_block$type,
        name = event$content_block$name,
        text = ""
      )
    } else if (identical(event$type, "content_block_delta")) {
      i <- event$index + 1
      delta <- event$delta
      piece <- delta$text %||% delta$partial_json %||% ""
      blocks[[i]]$text <- paste0(blocks[[i]]$text, piece)
    }
  }
  parts <- vapply(blocks, function(b) {
    if (is.null(b)) return("")
    switch(b$type %||% "",
      text = b$text,
      tool_use = {
        input <- tryCatch(jsonlite::fromJSON(b$text), error = function(e) NULL)
        code <- input$code %||% input$query %||% NULL
        if (!is.null(code)) paste0("[Tool call: ", b$name, "]\n", code)
        else paste0("[Tool call: ", b$name, "] ", b$text)
      },
      ""
    )
  }, character(1))
  paste(parts[nzchar(parts)], collapse = "\n\n")
}

# Posit Assistant wraps the user's words in workspace context. Show the
# conversation part when there is one, and keep long text readable.
tidy_text <- function(text, max_chars = 1500) {
  text <- sub("(?s)^.*--- Conversation ---\\s*", "", text, perl = TRUE)
  text <- gsub("(?s)<workspace-context>.*?</workspace-context>\\s*", "[workspace context]\n", text, perl = TRUE)
  text <- gsub("(?s)<workspace>.*?</workspace>\\s*", "[workspace context]\n", text, perl = TRUE)
  text <- trimws(text)
  if (nchar(text) > max_chars) text <- paste0(substr(text, 1, max_chars), " …")
  text
}
