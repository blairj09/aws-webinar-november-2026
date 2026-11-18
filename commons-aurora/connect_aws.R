# AWS credentials on Posit Connect.
#
# On Connect, the app gets short-lived credentials from the content's AWS
# integration (a Service Account integration that assumes an IAM role in the
# demo account). They go into the standard AWS environment variables, so
# paws (Athena, S3, STS) and ellmer (Bedrock) pick them up with no other
# change. Off Connect this does nothing, and the usual chain (AWS_PROFILE,
# SSO) applies.

aws_credentials_refresh <- local({
  expires <- NULL
  function(min_remaining = 15 * 60) {
    if (!identical(Sys.getenv("RSTUDIO_PRODUCT"), "CONNECT")) {
      return(invisible(FALSE))
    }
    if (!is.null(expires) && difftime(expires, Sys.time(), units = "secs") > min_remaining) {
      return(invisible(FALSE))
    }
    creds <- connectapi::get_aws_content_credentials(connectapi::connect())
    Sys.setenv(
      AWS_ACCESS_KEY_ID = creds$access_key_id,
      AWS_SECRET_ACCESS_KEY = creds$secret_access_key,
      AWS_SESSION_TOKEN = creds$session_token,
      AWS_REGION = Sys.getenv("POSIT_DEMO_REGION", "us-east-2")
    )
    Sys.unsetenv("AWS_PROFILE")
    exp <- creds$expiration
    expires <<- if (is.numeric(exp)) {
      as.POSIXct(exp, origin = "1970-01-01", tz = "UTC")
    } else {
      as.POSIXct(sub("Z$", "", exp), format = "%Y-%m-%dT%H:%M:%OS", tz = "UTC")
    }
    if (is.na(expires)) expires <<- Sys.time() + 45 * 60
    invisible(TRUE)
  }
})
