# Exploring Aurora Lending with Posit Assistant

A Quarto document for stepping through exploratory analysis with Posit Assistant in Positron on Amazon SageMaker. It is the Posit Assistant demo from the Posit and AWS webinar "From 'No' to 'Go'" (November 2026).

The data is synthetic, and Aurora Lending Group is fictional.

## Files

- **`aurora-eda.qmd`:** the starting point. It has a setup cell and one prompt for each step: orient, load, check, analyze, follow up, and write a brief. Give each prompt to Posit Assistant and review the code it writes.
- **`aurora-eda-reference.qmd`:** worked code for each step, so you can compare results.
- **`athena.R`:** a small helper that queries Amazon Athena with paws. It needs no ODBC driver and no keys.

## Run it in Positron on Amazon SageMaker

1. Clone the repository in your Space's terminal:

   ```bash
   git clone https://github.com/blairj09/aws-webinar-november-2026.git
   ```

2. Open the `aws-webinar-november-2026` folder in Positron. Install any missing packages in the R console:

   ```r
   pak::pak(c("dplyr", "ggplot2", "readr", "scales",
              "paws.analytics", "paws.security.identity", "paws.storage"))
   ```

3. Open `posit-assistant-eda/aurora-eda.qmd`, run the setup cell, and start with step 1.

The Space's execution role needs to query the `aurora_lending` database in Athena and to write query results to the `athena-query-results/` prefix of the demo bucket. Posit Assistant calls Claude on Amazon Bedrock with the same role.
