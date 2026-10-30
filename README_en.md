# Credit Risk Analysis & Default Scoring Model (Banco Super Caja)

>  **Language / Idioma:** **English** • [Português](README.md)

![SQL BigQuery](https://img.shields.io/badge/SQL-Google_BigQuery-4285F4?logo=googlebigquery&logoColor=white)
![Python](https://img.shields.io/badge/Python-Google_Colab_%7C_Pandas-3776AB?logo=python&logoColor=white)
![Looker Studio](https://img.shields.io/badge/BI-Looker_Studio-4285F4?logo=looker&logoColor=white)
![Laboratoria 2025](https://img.shields.io/badge/Data_Analytics-Laboratoria_2025-FF009E)
![Status](https://img.shields.io/badge/Default_Recall-84%25-success)

**Author:** Maria Eduarda Carvalho de Castro  
**Context:** Capstone Project developed during the **Laboratoria Data Analytics Program (J01 — 2025)**

> **Executive Summary:** Facing increased loan demand and operational bottlenecks from manual credit underwriting, **Banco Super Caja** needed an automated decision engine to mitigate default risk. This project processed **36,000 customers** and **305,335 loan transactions** utilizing **SQL on Google BigQuery** and **Python in Google Colab**. It handled severe income/leverage data discrepancies using analytical diagnosis flags and engineered a **Relative Risk Scoring Model** achieving an **84% Recall rate on actual defaulting customers** across a heavily imbalanced portfolio (1.9% default baseline).

---

## Project Deliverables & Links

-  [**Complete Technical Project Spec on Notion**](https://app.notion.com/p/PROJETO-3_-RISCO-RELATIVO-20db5d32202880f2b216c1479d4a976b?source=copy_link) *(Step-by-step documentation, business rationale, charts, and interactive dashboard)*
-  [**Interactive Google Colab Notebook (Python)**](https://colab.research.google.com/drive/1Yx-ip8KkN9QLWg-nfWph80RyN7PJzWO3?usp=sharing) *(Exploratory Data Analysis, correlation heatmaps, distribution diagnostics, and Confusion Matrix threshold validation)*

---

## Tech Stack & Methodologies

- **SQL + Google BigQuery:** Data preprocessing, outlier detection (IQR & Z-Score), analytical view layering, quartile segmentation (`NTILE(4)`), and Relative Risk computation.
- **Python + Google Colab:** Exploratory Data Analysis (EDA), dispersion and central tendency metrics, correlation matrix modeling, statistical testing, visual storytelling, and Confusion Matrix trade-off calibration.
- **Looker Studio:** Executive dashboard design and interactive portfolio monitoring.
- **Notion:** Comprehensive workflow management and executive documentation.

---

## 1. Business Problem & Analytical Context

The manual credit approval process at **Banco Super Caja** suffered from slow turnaround times and heightened portfolio default exposure. The core analytical challenges were:
1. **Relational Data Integration:** Merging disparate datasets (`user_info` with 36,000 customers, `loans_outstanding` with 305,335 credit lines, `loans_detail`, and `default_flag`).
2. **Asymmetric & Sparse Data:** 7,199 null income records and 7,262 customers with extreme `debt_ratio` metrics due to nominal zero-income entries.
3. **Severe Class Imbalance:** Only **683 out of 36,000 borrowers (1.9%)** carried an active default flag, demanding high-recall evaluation thresholds over simplistic accuracy metrics.

---

## 2. Data Engineering & Pipeline Design (SQL / BigQuery)

Rather than arbitrarily dropping non-standard records—which would discard over 20% of the customer base—the BigQuery analytical pipeline was built around **clean view abstractions and diagnostic flags**:

| Stage | Table / View | Transformation Applied |
| :--- | :--- | :--- |
| **1. Cleaning & Standardization** | `view_user_info_limpo` / `view_emprestimos_limpos` | Null handling (`COALESCE` on income and dependents) and standardization of `loan_type` (`real estate` vs `other`) via `CASE WHEN LOWER(...)`. |
| **2. Outlier Detection (IQR + Z-Score)** | `view_infopagamento_limpo` | Computed upper IQR threshold for `debt_ratio` ($1.92$) and flagged revolving credit utilization (`using_lines_not_secured` $> 1.33$). |
| **3. Feature Engineering** | `caja_unificada` | Synthesized `per_capita_income`, `loan_count`, `primary_loan_type` (via `ROW_NUMBER() OVER (PARTITION BY user_id)`), `debt_category`, and `lines_category`. |

---

## 3. Key Analytical Insights

1. **Delinquency History is the Strongest Predictor:** `number_times_delayed_payment_loan_30_59_days` exhibited the highest positive correlation with `default_flag` ($r = 0.30$) and the largest standard deviation across tiers ($4.14$). In Quartile 4 of past delays, the default rate surges to **7.11%** (nearly 4x the baseline).
2. **Revolving Credit & Extreme Relative Risk:** Borrowers in Quartile 4 of unsecured line utilization (`using_lines_not_secured_personal_assets`) registered a **Relative Risk of 44.65**, followed by Quartile 4 of past delays (**Relative Risk of 31.15**).
3. **Two-Tier Debt Ratio Segmentation (Case 01 vs. Case 02):**
   - **Case 01 (Standard `NTILE(4)`):** Confounded missing/zero income artifacts in the top quartile.
   - **Case 02 (Hybrid segmentation with IQR $\ge 1.92$ cutoff):** Isolated 7,579 anomalous records into a dedicated 5th segment and split the 28,420 clean borrowers into 4 regular quartiles, elevating the discriminatory power of the `debt_ratio` (Relative Risk increased from $1.26 \rightarrow 1.61$).

---

## 4. Model Evaluation & Confusion Matrix

To protect portfolio capital, the scoring engine was calibrated to maximize **Recall** in identifying default-prone accounts:
- **Recall on Default:** **84.33%** (576 of 683 actual defaulters correctly flagged and mitigated).
- **Precision:** 8.92% (expected trade-off given the 1.9% underlying class imbalance).
- **Specificity:** 82.68% (preserving credit access for low-risk applicants while filtering out high-risk segments).
