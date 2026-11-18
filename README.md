# From "No" to "Go": governed AI with Posit and Amazon Bedrock

Materials from the Posit and AWS workflow demo webinar, November 18, 2026.

The slides and the security guide are published at <https://blairj09.github.io/aws-webinar-november-2026/>.

## What's here

- **`commons-aurora/`:** the Aurora Lending credit risk agent from the demo. It is a commons data agent in R that answers questions about a synthetic loan book in Amazon Athena, using Claude on Amazon Bedrock. See its [README](commons-aurora/README.md) to run it in Positron on Amazon SageMaker.
- **`posit-assistant-eda/`:** a Quarto document for stepping through exploratory analysis of the same loan book with Posit Assistant in Positron on Amazon SageMaker, with a worked reference version. See its [README](posit-assistant-eda/README.md).
- **`bedrock-usage-dashboard/`:** a Quarto dashboard of Amazon Bedrock usage by caller and model, built from the model invocation logs with paws. See its [README](bedrock-usage-dashboard/README.md).
- **`security-guide/`:** the Quarto source for "Posit and Amazon Bedrock: a guide for security and platform teams". It renders to HTML and PDF.
- **`index.qmd`, `landing.css`, `assets/`:** the landing page for the published site.
- **`publish.sh`:** renders the site and pushes it to the `gh-pages` branch.

## Set up R

The examples share one renv lockfile at the repository root. Start R in the repository root, then install the pinned packages:

```r
renv::restore()
```

All data in the demo is synthetic, and Aurora Lending Group is fictional.
