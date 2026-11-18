# Aurora Lending commons agent

A commons data agent (R) for the synthetic Aurora Lending Group loan book, for the Nov 18, 2026 Posit + AWS webinar.

- Data: Amazon Athena database `aurora_lending` (us-east-2), loaded once per R process in `agent.R` (`aurora_tables()`), then served from commons' in-process DuckDB.
- Model: Claude on Amazon Bedrock via `ellmer::chat_aws_bedrock()`. The model is set by `AURORA_MODEL`, default `us.anthropic.claude-sonnet-5-5`. Do not use Claude Haiku 4.5: the demo account enforces a guardrail on it.
- Trusted calculations: the measures in `agent.R` reproduce `reports/aurora_lending/portfolio_risk_review_r.qmd` in posit-dev/positron-sagemaker-demo@98c96e9. Keep them in agreement with that report, including its right-closed FICO bands.
- Dictionary: `dictionaries/aurora_lending.yaml` is in the data-dict.tidyverse.org format, converted from the demo repo's `data/data-dict.yaml`.
- Credentials: the standard AWS chain. The identity needs Athena, Glue read, S3 read and write on the demo bucket's `athena-query-results/` prefix, and Bedrock invoke (including Marketplace view and subscribe).
- All data is synthetic. Keep that statement visible in the app greeting.
