# Prewarm the context index, then deploy to Posit Connect.
#
#   Rscript deploy.R                 # deploys to the "pub.current" server
#   CONNECT_SERVER_NAME=other Rscript deploy.R
#
# Needs AWS credentials locally (for the prewarm, which loads the tables)
# and on Connect. On Connect, prefer a Connect AWS integration or a
# dedicated, scoped IAM identity for this app. See AGENTS.md for the
# permissions it needs.

Sys.setenv(OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT = "true")

source("agent.R", local = TRUE)
agent <- build_agent(log = FALSE)
agent$prewarm()

app_files <- c(
  "app.R",
  "agent.R",
  "athena.R",
  "connect_aws.R",
  "DESCRIPTION",
  "dictionaries/aurora_lending.yaml",
  "context/portfolio-risk-review.md",
  list.files("commons-cache", recursive = TRUE, full.names = TRUE)
)

# The prewarm can load reticulate, which sets RETICULATE_PYTHON = "managed";
# rsconnect then tries to bundle a Python environment. The app is R only.
Sys.unsetenv(c("RETICULATE_PYTHON", "RETICULATE_PYTHON_FALLBACK"))

rsconnect::deployApp(
  appDir = ".",
  appFiles = app_files,
  appPrimaryDoc = "app.R",
  appTitle = "Aurora Lending credit risk agent (Commons demo)",
  server = Sys.getenv("CONNECT_SERVER_NAME", "pub.current"),
  # On pub.current the "R4.6-python3.14-ubuntu-22.04-pro" image is registered
  # with R 4.6.0 but has no /opt/R/4.6.0, so pin a working image.
  image = Sys.getenv("CONNECT_IMAGE", "posit/connect-content:R4.6.0-python3.14.5-ubuntu-24.04"),
  envVars = c("OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT", "AURORA_MODEL")
)
