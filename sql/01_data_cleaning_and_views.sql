-- =============================================================================
-- PROJETO: Análise de Risco de Crédito e Score de Inadimplência (Banco Super Caja)
-- ETAPA 01: Auditoria de Nulos, Duplicados e Criação de Views Limpas (BigQuery)
-- AUTORA: Maria Eduarda Carvalho de Castro
-- =============================================================================

-- 1. Conferência de valores nulos na tabela user_info (36.000 linhas)
SELECT
    COUNTIF(user_id IS NULL) AS id_nulo,
    COUNTIF(age IS NULL) AS idade_nula,
    COUNTIF(sex IS NULL) AS sexo_nulo,
    COUNTIF(last_month_salary IS NULL) AS salario_nulo,
    COUNTIF(number_dependents IS NULL) AS dependentes_nulos
FROM `projetolab3.bancocaja.user_info`;

-- 2. Conferência de duplicidade em user_info
SELECT
    user_id,
    COUNT(*) AS qtd_repeticoes
FROM `projetolab3.bancocaja.user_info`
GROUP BY user_id
HAVING COUNT(*) > 1
ORDER BY qtd_repeticoes DESC;

-- 3. View limpa de clientes (tratando nulos de salário e dependentes com COALESCE)
CREATE OR REPLACE VIEW `projetolab3.bancocaja.view_user_info_limpo` AS
SELECT
    user_id,
    age,
    sex,
    COALESCE(last_month_salary, 0.0) AS salario,
    COALESCE(number_dependents, 0) AS dependentes
FROM `projetolab3.bancocaja.user_info`;

-- 4. Conferência de nulos e duplicados em emprestimos (305.335 linhas)
SELECT
    COUNTIF(user_id IS NULL) AS id_nulo,
    COUNTIF(loan_id IS NULL) AS loan_nulo,
    COUNTIF(loan_type IS NULL) AS type_nulo
FROM `projetolab3.bancocaja.emprestimos`;

SELECT
    loan_id,
    COUNT(*) AS qtd_repeticoes
FROM `projetolab3.bancocaja.emprestimos`
GROUP BY loan_id
HAVING COUNT(*) > 1;

-- 5. Padronização de inconsistências categóricas em loan_type
CREATE OR REPLACE VIEW `projetolab3.bancocaja.view_emprestimos_limpos` AS
SELECT
    loan_id,
    user_id,
    CASE
        WHEN LOWER(loan_type) IN ('other', 'others') THEN 'other'
        WHEN LOWER(loan_type) IN ('real estate') THEN 'real estate'
    END AS tipo_padronizado
FROM `projetolab3.bancocaja.emprestimos`;

-- 6. Conferência de nulos em infopagamento e flag de default
SELECT
    COUNTIF(user_id IS NULL) AS id_nulo,
    COUNTIF(more_90_days_overdue IS NULL) AS more_nulo,
    COUNTIF(using_lines_not_secured_personal_assets IS NULL) AS lines_nulo,
    COUNTIF(number_times_delayed_payment_loan_30_59_days IS NULL) AS delayed_nulo,
    COUNTIF(debt_ratio IS NULL) AS ratio_nulo,
    COUNTIF(number_times_delayed_payment_loan_60_89_days IS NULL) AS delayed_2_nulo
FROM `projetolab3.bancocaja.infopagamento`;
