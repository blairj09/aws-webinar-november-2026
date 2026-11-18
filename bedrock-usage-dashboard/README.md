# Amazon Bedrock usage dashboard

A Quarto dashboard of Amazon Bedrock model calls: calls per hour by caller, tokens by model, prompt cache use, and the latest calls. It reads Bedrock model invocation logs from CloudWatch Logs with [paws](https://www.paws-r-sdk.com/).

Each chart runs a CloudWatch Logs Insights query, so the aggregation happens in AWS and only the summary comes back to R. Callers are labeled by IAM role, not session name, because an SSO session name is the person's email address. By default the dashboard doesn't show prompts or responses.

## Before you start

- Turn on Bedrock model invocation logging to CloudWatch Logs. The dashboard reads the log group `/aws/bedrock/model-invocations`. To use a different log group, set `BEDROCK_LOG_GROUP`.
- The identity that renders the dashboard needs `logs:StartQuery` and `logs:GetQueryResults` on that log group.

## Render it

Install the packages in the R console:

```r
pak::pak(c("dplyr", "plotly", "reactable", "readr", "scales", "paws.management"))
```

Then render it. The `hours` parameter sets the window, and the default is 24 hours:

```bash
quarto render dashboard.qmd -P hours:168
```

In Positron on Amazon SageMaker, the Space's execution role provides the credentials. On a laptop, set `AWS_PROFILE` and `AWS_REGION` first.

## Show prompts and responses

For a demo, the Conversations page can show the newest calls from one caller: the newest turn sent to the model and the model's answer, with thinking left out. Turn it on when you render:

```bash
quarto render dashboard.qmd -P show_content:true -P content_caller:persona-james-blair
```

`content_caller` matches part of the caller's IAM ARN, and `content_n` sets how many calls to show (30 by default). The identity that renders the dashboard also needs `logs:FilterLogEvents`. The rendered file then holds prompt and response text, so don't share it.

