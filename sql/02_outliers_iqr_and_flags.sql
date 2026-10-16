-- =============================================================================
-- PROJETO: Análise de Risco de Crédito e Score de Inadimplência (Banco Super Caja)
-- ETAPA 02: Tratamento de Outliers (IQR / Z-Score) e Flags de Consistência
-- AUTORA: Maria Eduarda Carvalho de Castro
-- =============================================================================

-- Durante a auditoria de outliers pelo método IQR:
-- 1. debt_ratio apresentou limite superior IQR = 1.92 (7.579 outliers, dos quais 7.262 tinham salário <= 1).
-- 2. using_lines_not_secured_personal_assets apresentou limite superior IQR = 1.33.
-- Decisão de Engenharia: Isolar comportamentos extremos com flags analíticas sem descartar registros reais.

SELECT
    user_id,
    salario,
    debt_ratio,
    using_lines_not_secured_personal_assets,

    -- Flag 1: Nível de saúde do endividamento (debt_ratio)
    CASE
        WHEN debt_ratio <= 1 THEN 'saudável'
        WHEN debt_ratio BETWEEN 1.01 AND 2.0 THEN 'atenção'
        WHEN debt_ratio BETWEEN 2.01 AND 5.0 THEN 'risco relevante'
        WHEN debt_ratio BETWEEN 5.01 AND 10 THEN 'altíssimo risco'
        WHEN debt_ratio > 10 THEN 'caso extremo'
    END AS debt_categoria,

    -- Flag 2: Diagnóstico de consistência entre salário declarado e debt_ratio (Referência: R$ 482,05)
    CASE
        WHEN salario <= 482.05 AND debt_ratio > 1.92 THEN 'salário inconsistente'
        WHEN salario >= 482.05 AND debt_ratio > 1.92 THEN 'debt ratio inconsistente'
        ELSE 'valores consistentes'
    END AS debt_status,

    -- Flag 3: Faixas de utilização de crédito rotativo não garantido
    CASE
        WHEN using_lines_not_secured_personal_assets BETWEEN 1.33 AND 10 THEN 'atenção'
        WHEN using_lines_not_secured_personal_assets BETWEEN 10 AND 100 THEN 'risco médio'
        WHEN using_lines_not_secured_personal_assets BETWEEN 100 AND 1000 THEN 'risco alto'
        WHEN using_lines_not_secured_personal_assets BETWEEN 1000 AND 10000 THEN 'discrepantes'
        WHEN using_lines_not_secured_personal_assets > 10000 THEN 'extremos'
        ELSE 'saudável'
    END AS lines_categoria
FROM `projetolab3.bancocaja.caja_unificada`;
