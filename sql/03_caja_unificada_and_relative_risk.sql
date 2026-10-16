-- =============================================================================
-- PROJETO: Análise de Risco de Crédito e Score de Inadimplência (Banco Super Caja)
-- ETAPA 03: Construção da Tabela Chave (caja_unificada), Quartis e Segmentação
-- AUTORA: Maria Eduarda Carvalho de Castro
-- =============================================================================

-- 1. Construção da Camada Analítica Unificada (caja_unificada)
CREATE OR REPLACE TABLE `projetolab3.bancocaja.caja_unificada` AS
WITH user_info_tratada AS (
    SELECT
        user_id,
        age AS idade,
        CASE
            WHEN age < 18 THEN 'menor de idade'
            WHEN age BETWEEN 18 AND 25 THEN '18-25'
            WHEN age BETWEEN 26 AND 40 THEN '31-40'
            WHEN age BETWEEN 41 AND 50 THEN '41-50'
            WHEN age BETWEEN 51 AND 65 THEN '51-65'
            ELSE '+65'
        END AS faixa_etaria,
        CASE
            WHEN dependentes > 0 THEN 'sim'
            ELSE 'não'
        END AS tem_dependentes,
        IFNULL(dependentes, -1) AS n_dependentes,
        IFNULL(salario, 0) AS salario,
        salario / (dependentes + 1) AS renda_per_capita
    FROM `projetolab3.bancocaja.view_user_info_limpo`
),
qtd_emprestimos AS (
    SELECT
        user_id,
        COUNT(*) AS qtd_emprestimos
    FROM `projetolab3.bancocaja.view_emprestimos_limpos`
    GROUP BY user_id
),
tipo_emprestimo_frequente AS (
    SELECT
        user_id,
        tipo_padronizado,
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY COUNT(*) DESC) AS ordem
    FROM `projetolab3.bancocaja.view_emprestimos_limpos`
    GROUP BY user_id, tipo_padronizado
),
mais_frequente AS (
    SELECT
        user_id,
        tipo_padronizado AS tipo_frequente
    FROM tipo_emprestimo_frequente
    WHERE ordem = 1
),
info_pagamento AS (
    SELECT
        user_id,
        using_lines_not_secured_personal_assets,
        number_times_delayed_payment_loan_30_59_days,
        debt_ratio,
        CASE
            WHEN debt_ratio <= 1 THEN 'saudável'
            WHEN debt_ratio BETWEEN 1.01 AND 2.0 THEN 'atenção'
            WHEN debt_ratio BETWEEN 2.01 AND 5.0 THEN 'risco relevante'
            WHEN debt_ratio BETWEEN 5.01 AND 10 THEN 'altíssimo risco'
            WHEN debt_ratio > 10 THEN 'caso extremo'
        END AS debt_categoria
    FROM `projetolab3.bancocaja.view_infopagamento_limpo`
)
SELECT
    u.*,
    CASE
        WHEN salario = 0 THEN 'sem salário'
        WHEN salario BETWEEN 0 AND 482.05 THEN 'valor infimo'
        ELSE 'possui salário'
    END AS salario_status,
    IFNULL(e.qtd_emprestimos, 0) AS qtd_emprestimos,
    IFNULL(f.tipo_frequente, 'sem emprestimo') AS tipo_frequente,
    g.default_flag,
    p.using_lines_not_secured_personal_assets,
    CASE
        WHEN p.using_lines_not_secured_personal_assets BETWEEN 1.33 AND 10 THEN 'atenção'
        WHEN p.using_lines_not_secured_personal_assets BETWEEN 10 AND 100 THEN 'risco médio'
        WHEN p.using_lines_not_secured_personal_assets BETWEEN 100 AND 1000 THEN 'risco alto'
        WHEN p.using_lines_not_secured_personal_assets BETWEEN 1000 AND 10000 THEN 'discrepantes'
        WHEN p.using_lines_not_secured_personal_assets > 10000 THEN 'extremos'
        ELSE 'saudável'
    END AS lines_categoria,
    p.number_times_delayed_payment_loan_30_59_days,
    p.debt_ratio,
    p.debt_categoria,
    CASE
        WHEN salario <= 482.05 AND p.debt_ratio > 1.92 THEN 'salário inconsistente'
        WHEN salario >= 482.05 AND p.debt_ratio > 1.92 THEN 'debt ratio inconsistente'
        ELSE 'valores consistentes'
    END AS debt_status
FROM user_info_tratada u
LEFT JOIN qtd_emprestimos e ON u.user_id = e.user_id
LEFT JOIN mais_frequente f ON u.user_id = f.user_id
LEFT JOIN info_pagamento p ON u.user_id = p.user_id
LEFT JOIN `projetolab3.bancocaja.flag` g ON u.user_id = g.user_id;

-- 2. Cálculo de Quartis e Percentual de Inadimplência por Variável
WITH base AS (
    SELECT
        user_id,
        default_flag,
        debt_ratio,
        idade,
        n_dependentes,
        number_times_delayed_payment_loan_30_59_days,
        qtd_emprestimos,
        renda_per_capita,
        salario,
        using_lines_not_secured_personal_assets,
        NTILE(4) OVER (ORDER BY debt_ratio) AS quartil_debt_ratio,
        NTILE(4) OVER (ORDER BY idade) AS quartil_idade,
        NTILE(4) OVER (ORDER BY n_dependentes) AS quartil_dependentes,
        NTILE(4) OVER (ORDER BY number_times_delayed_payment_loan_30_59_days) AS quartil_atrasos,
        NTILE(4) OVER (ORDER BY qtd_emprestimos) AS quartil_emprestimos,
        NTILE(4) OVER (ORDER BY renda_per_capita) AS quartil_renda,
        NTILE(4) OVER (ORDER BY salario) AS quartil_salario,
        NTILE(4) OVER (ORDER BY using_lines_not_secured_personal_assets) AS quartil_using_lines
    FROM `projetolab3.bancocaja.caja_unificada`
)
SELECT 'salario' AS variavel, quartil_salario AS grupo, COUNT(*) AS qtd_clientes, SUM(default_flag) AS inadimplentes, ROUND(SUM(default_flag) / COUNT(*) * 100, 2) AS pct_inadimplentes FROM base GROUP BY quartil_salario
UNION ALL
SELECT 'renda_per_capita', quartil_renda, COUNT(*), SUM(default_flag), ROUND(SUM(default_flag) / COUNT(*) * 100, 2) FROM base GROUP BY quartil_renda
UNION ALL
SELECT 'debt_ratio', quartil_debt_ratio, COUNT(*), SUM(default_flag), ROUND(SUM(default_flag) / COUNT(*) * 100, 2) FROM base GROUP BY quartil_debt_ratio
UNION ALL
SELECT 'using_lines', quartil_using_lines, COUNT(*), SUM(default_flag), ROUND(SUM(default_flag) / COUNT(*) * 100, 2) FROM base GROUP BY quartil_using_lines
UNION ALL
SELECT 'atrasos_30_59_dias', quartil_atrasos, COUNT(*), SUM(default_flag), ROUND(SUM(default_flag) / COUNT(*) * 100, 2) FROM base GROUP BY quartil_atrasos
UNION ALL
SELECT 'idade', quartil_idade, COUNT(*), SUM(default_flag), ROUND(SUM(default_flag) / COUNT(*) * 100, 2) FROM base GROUP BY quartil_idade
UNION ALL
SELECT 'n_dependentes', quartil_dependentes, COUNT(*), SUM(default_flag), ROUND(SUM(default_flag) / COUNT(*) * 100, 2) FROM base GROUP BY quartil_dependentes
UNION ALL
SELECT 'qtd_emprestimos', quartil_emprestimos, COUNT(*), SUM(default_flag), ROUND(SUM(default_flag) / COUNT(*) * 100, 2) FROM base GROUP BY quartil_emprestimos;
