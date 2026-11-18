---
provenance: https://github.com/posit-dev/positron-sagemaker-demo/blob/98c96e9/data/data-dict.yaml (aurora_lending notes); https://github.com/posit-dev/positron-sagemaker-demo/blob/98c96e9/reports/aurora_lending/portfolio_risk_review_r.qmd#L104-L200
---

# Interpreting Aurora Lending charge-off figures

## The 580 FICO floor

Aurora's credit policy refuses applicants below a 580 FICO score, so no loan in the book has a score below 580. The lowest FICO band therefore starts at 580. Results for low scores describe approved borrowers only. They are not evidence about applicants Aurora declined.

## Vintage seasoning

The charge-off rate is realized: it counts loans that have already charged off as of 2025-12-31. Recent vintages have had less time on book to charge off, so their rates are lower partly because they are younger, not only because they are better loans. Compare vintages with care, and mention months on book when it matters.

## Charge-off definition

A loan is charged off when it is 120 or more days past due (`delinquency_days`). The `charged_off` flag on `fct_loan_performance` is the authoritative indicator and the target of Aurora's risk model.
