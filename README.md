# 🏦 Análise de Risco de Crédito & Modelagem de Score (Banco Super Caja)

![SQL BigQuery](https://img.shields.io/badge/SQL-Google_BigQuery-4285F4?logo=googlebigquery&logoColor=white)
![Python](https://img.shields.io/badge/Python-Pandas_%7C_Scikit--Learn-3776AB?logo=python&logoColor=white)
![Looker Studio](https://img.shields.io/badge/BI-Looker_Studio-4285F4?logo=looker&logoColor=white)
![Status](https://img.shields.io/badge/Recall_Inadimplência-84%25-success)

> **Resumo Executivo:** Com o aumento da demanda por crédito e sobrecarga na avaliação manual, o banco **Super Caja** precisava automatizar a análise de solicitações para reduzir a inadimplência. Este projeto processou **36.000 clientes** e **305.335 registros de empréstimos** no Google BigQuery e Python, tratando inconsistências severas de renda/endividamento com flags analíticas e desenvolvendo um **Score de Risco Relativo** capaz de capturar **84% dos clientes inadimplentes reais (Recall)** em uma base fortemente desbalanceada (1,9% de default).

🔗 **Links Rápidos:**
- 📓 [Notebook Completo no Google Colab (Python, Correlações e Matrizes de Confusão)](https://colab.research.google.com/drive/1Yx-ip8KkN9QLWg-nfWph80RyN7PJzWO3?usp=sharing)
- 📄 [Relatório Técnico Completo com Prints e Gráficos (PDF)](./reports/PROJETO_3_RISCO_RELATIVO.pdf)

---

## 1. Contexto e Problema de Negócio

O processo manual de concessão de crédito do **Banco Super Caja** gerava gargalos operacionais e exposição a risco de inadimplência (*default*). O desafio técnico central consistia em:
1. Unificar bases granulares (`user_info` com 36.000 clientes, `loans_outstanding` com 305.335 empréstimos, `loans_detail` e `default_flag`).
2. Lidar com **forte assimetria e inconsistências cadastrais** (ex: 7.199 salários nulos e 7.262 clientes com `debt_ratio` extremo devido a salário declarado $\le 1$).
3. Construir e validar uma regra de pontuação (*Score de Risco*) em um cenário de **forte desbalanceamento de classe**: apenas **683 dos 36.000 clientes (1,9%)** possuíam flag de inadimplência ativa.

---

## 2. Arquitetura de Dados e Decisões de Engenharia (SQL / BigQuery)

Em vez de excluir registros discrepantes e perder quase 21% da base de clientes, o pipeline no BigQuery foi desenhado com **views limpas e flags de diagnóstico**:

| Etapa | Tabela / View | Tratamento Aplicado |
| :--- | :--- | :--- |
| **1. Limpeza e Padronização** | `view_user_info_limpo` / `view_emprestimos_limpos` | Tratamento de nulos (`COALESCE` em salário e dependentes) e padronização de `loan_type` (`real estate` vs `other`) com `CASE WHEN LOWER(...)`. |
| **2. Detecção de Outliers (IQR + Z-Score)** | `view_infopagamento_limpo` | Identificação do limite superior de `debt_ratio` via IQR ($1.92$) e de uso de limite rotativo (`using_lines_not_secured` $> 1.33$). |
| **3. Engenharia de Variáveis (Feature Engineering)** | `caja_unificada` | Criação de `renda_per_capita`, `qtd_emprestimos`, `tipo_frequente` (via `ROW_NUMBER() OVER (PARTITION BY user_id)`), `debt_categoria`, `debt_status` e `lines_categoria`. |

---

## 3. Principais Descobertas Analíticas

1. **Histórico de atrasos é o maior preditor individual:** A variável `number_times_delayed_payment_loan_30_59_days` apresentou a maior correlação positiva com `default_flag` ($r = 0.30$) e o maior desvio padrão entre as faixas de atraso ($4.14$). No Quartil 4 de atrasos, a taxa de inadimplência salta para **7,11%** (quase 4x a média da base).
2. **Alavancagem rotativa e Risco Relativo extremo:** Clientes no Quartil 4 de utilização de linhas de crédito não garantidas (`using_lines_not_secured_personal_assets`) apresentaram **Risco Relativo de 44,65**, seguido pelo Quartil 4 de atrasos (**Risco Relativo de 31,15**).
3. **Isolamento do grupo extremo de `debt_ratio` (Caso 01 vs. Caso 02):**
   - **Caso 01 (Quartis tradicionais via `NTILE(4)`):** Misturava clientes com salário zerado/inconsistente no último quartil.
   - **Caso 02 (Segmentação híbrida com corte IQR $\ge 1.92$):** Isolou os 7.579 registros extremos em um 5º grupo dedicado e dividiu os 28.420 registros consistentes em 4 quartis regulares, elevando a capacidade discriminatória do `debt_ratio` (Risco Relativo de $1.26 \rightarrow 1.61$).

---

## 4. Validação do Score de Risco (Matriz de Confusão)

Como apenas **1,9%** da base era inadimplente, avaliar o modelo por *Acurácia* seria enganoso. A validação priorizou o **Recall da classe inadimplente** (minimizar falsos negativos, cujo custo financeiro de calote supera o custo de revisão manual):

| Configuração Testada | Inadimplentes Capturados (VP) | Falsos Negativos (FN) | Falsos Positivos (FP) | Recall (Sensibilidade) | Recomendação |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **Caso 01 — Score $\ge 3$** | 570 | 113 | 9.007 | 83% | Boa captura, mas mais falsos positivos |
| **Caso 01 — Score $\ge 4$** | 384 | 299 | 3.357 | 56% | Alto risco de inadimplência não prevista |
| **🏆 Caso 02 — Score $\ge 3$** | **573** | **110** | **8.642** | **84%** | **Melhor equilíbrio (Mais seguro contra default)** |
| **Caso 02 — Score $\ge 4$** | 377 | 306 | 3.294 | 55% | Privilegia aprovação rápida, mas deixa passar 45% dos defaults |

> **Recomendação Executiva:** Adotar o **Score $\ge 3$ do Caso 02**, que captura **84% dos inadimplentes reais (573 de 683)** e reduz em **365 clientes** o volume de falsos positivos em relação ao Caso 01.

---

## 5. Estrutura do Repositório

```text
credit-risk-super-caja/
├── README.md                                       # Documentação executiva e resultados
├── sql/
│   ├── 01_data_cleaning_and_views.sql              # Auditoria de nulos/duplicados e views limpas
│   ├── 02_outliers_iqr_and_flags.sql               # Tratamento de outliers (IQR/Z-Score) e flags de risco
│   └── 03_caja_unificada_and_relative_risk.sql     # Feature engineering, quartis e cálculo de Score
└── reports/
    └── PROJETO_3_RISCO_RELATIVO.pdf                # Ficha técnica completa com gráficos e matrizes
```
