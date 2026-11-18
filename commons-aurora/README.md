# Aurora Lending credit risk agent

A [commons](https://posit-dev.github.io/commons/) data agent in R, from the Posit and AWS webinar "From 'No' to 'Go': governed AI for data science with Posit and Amazon Bedrock" (November 2026).

Ask questions about the Aurora Lending Group consumer loan book in plain language. The agent answers from the data team's vetted calculations when it can. For a new question it writes its own SQL and tags the answer with how it was produced.

The data is synthetic, and Aurora Lending Group is fictional.

## How it works

- **Data:** four tables in the Amazon Athena database `aurora_lending`. The app reads them once with paws, and then queries an in-process copy in DuckDB.
- **Model:** Claude Sonnet 5.5 on Amazon Bedrock, through `ellmer::chat_aws_bedrock()`. Set `AURORA_MODEL` to use a different model.
- **Credentials:** the standard AWS credential chain. In Positron on Amazon SageMaker, that is the Space's execution role, so there are no keys to manage. On Posit Connect, `connect_aws.R` gets short-lived credentials from a Connect AWS integration.

## Run it in Positron on Amazon SageMaker

1. Open a terminal in your Positron Space and clone the repository:

   ```bash
   git clone -b main https://github.com/blairj09/aws-webinar-november-2026.git
   ```

2. Open the `aws-webinar-november-2026` folder in Positron, the repository root, so that renv starts. Then install the pinned packages in the R console:

   ```r
   renv::restore()
   ```

3. A SageMaker Space can't sandbox the agent's R session, because it offers neither Landlock nor unprivileged user namespaces. For this demo on synthetic data, opt in to commons' best-effort R guardrails in the R console:

   ```r
   Sys.setenv(AURORA_ALLOW_UNSAFE_R = "true")
   ```

   These guardrails are not a security boundary. On a host that supports sandboxing, such as Posit Connect on a current Linux kernel, leave this unset. Alternatively, set `AURORA_MODE = "trusted only"`: the agent then answers only from trusted calculations and needs no sandbox.

4. Open `commons-aurora/app.R` and select **Run App**. The first start reads the tables from Athena and builds the context index, which takes a minute or two.

The execution role needs:

- `athena:StartQueryExecution` and `athena:GetQueryExecution` on the workgroup
- Glue read access to `aurora_lending`
- S3 read access to the data, and write access to the `athena-query-results/` prefix
- `bedrock:InvokeModel` and `bedrock:InvokeModelWithResponseStream` on the model

## Share it on Posit Connect

`deploy.R` deploys the app to Posit Connect. On Connect, give the app AWS access with a Connect AWS integration (auth type Service Account). The integration assumes a narrowly scoped IAM role, so the app never holds long-lived keys.
