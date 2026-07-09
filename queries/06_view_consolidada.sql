-- ============================================
-- PROJETO: Análise Financeira Banco do Brasil (2016-2025)
-- ARQUIVO: 06_view_consolidada.sql
-- OBJETIVO: VIEW consolidada com todos os indicadores anuais
-- ============================================
--
-- CONCEITO:
-- Uma VIEW não armazena dados — armazena a query.
-- Toda vez que consultada, o banco executa a lógica
-- por baixo e retorna o resultado atualizado.
-- Permite consultar todos os indicadores com:
--   SELECT * FROM indicadores_bb;
--
-- INDICADORES INCLUÍDOS:
--   - ROE (%): Lucro Líquido / Patrimônio Líquido
--   - Margem Financeira (%): Resultado Bruto / Receita de Intermediação
--   - Índice de Eficiência (%): Despesas / Receitas Operacionais
--   - YoY Lucro (%): variação anual do Lucro Líquido
--   - YoY Receita (%): variação anual da Receita de Intermediação
--
-- TÉCNICAS SQL UTILIZADAS:
--   - JOIN entre tabelas (dre e bpp)
--   - SUM(CASE WHEN) para pivotar contas em colunas
--   - CTEs encadeadas (10 CTEs no mesmo WITH)
--   - Window function LAG() para cálculo YoY
--   - ABS() para tratar despesas com sinal negativo
--
-- NOTA: CAGR não está incluído na VIEW porque retorna
-- uma única linha (não uma por ano). Ver 05_cagr.sql.
-- ============================================


-- ============================================
-- CONSULTA FINAL (após criar a VIEW)
-- ============================================
-- SELECT * FROM indicadores_bb;


-- ============================================
-- CRIAÇÃO DA VIEW
-- ============================================
CREATE VIEW indicadores_bb AS
WITH
-- CTE 1: Lucro Líquido da DRE (para ROE e YoY)
-- Dois nomes de conta: CVM mudou nomenclatura em 2020
roe_dre AS (
  SELECT dt_refer, vl_conta AS lucro_liquido
  FROM dre
  WHERE (ds_conta = 'Lucro/Prejuízo Consolidado do Período'
    OR ds_conta = 'Lucro ou Prejuízo Líquido Consolidado do Período')
    AND ordem_exerc = 'ÚLTIMO'
),
-- CTE 2: Patrimônio Líquido do BPP (para ROE)
-- Usamos PL Consolidado (total), não só da controladora
roe_bpp AS (
  SELECT dt_refer, vl_conta AS patrimonio_liquido
  FROM bpp
  WHERE ds_conta = 'Patrimônio Líquido Consolidado'
    AND ordem_exerc = 'ÚLTIMO'
),
-- CTE 3: ROE calculado
-- ROE = Lucro Líquido / Patrimônio Líquido * 100
roe AS (
  SELECT
    roe_dre.dt_refer,
    ROUND((roe_dre.lucro_liquido / roe_bpp.patrimonio_liquido) * 100, 2) AS roe_percentual
  FROM roe_dre
  JOIN roe_bpp ON roe_dre.dt_refer = roe_bpp.dt_refer
),
-- CTE 4: Base da Margem Financeira
-- SUM(CASE WHEN) pivota duas contas diferentes em colunas separadas
-- sem precisar de JOIN (ambas estão na tabela dre)
margem_base AS (
  SELECT
    dt_refer,
    SUM(CASE WHEN ds_conta IN (
      'Receitas de Intermediação Financeira',
      'Receitas da Intermediação Financeira'
    ) THEN vl_conta ELSE 0 END) AS receita_financeira,
    SUM(CASE WHEN ds_conta IN (
      'Resultado Bruto Intermediação Financeira',
      'Resultado Bruto de Intermediação Financeira'
    ) THEN vl_conta ELSE 0 END) AS resultado_bruto
  FROM dre
  WHERE ordem_exerc = 'ÚLTIMO'
  GROUP BY dt_refer
),
-- CTE 5: Margem Financeira calculada
-- Margem = Resultado Bruto / Receita de Intermediação * 100
-- Equivalente à "margem bruta" para bancos —
-- mede eficiência da atividade-fim antes de despesas operacionais
margem AS (
  SELECT
    dt_refer,
    ROUND((resultado_bruto / receita_financeira) * 100, 2) AS margem_financeira
  FROM margem_base
),
-- CTE 6: Base do Índice de Eficiência
-- Metodologia aproximada (dados públicos CVM):
-- converge com o IE oficial do BB a partir de 2022 (< 2 p.p.)
-- Ver 03_indice_eficiencia.sql para nota metodológica completa
eficiencia_base AS (
  SELECT
    dt_refer,
    SUM(CASE WHEN ds_conta IN (
      'Despesas de Pessoal', 'Despesas com Pessoal'
    ) THEN vl_conta ELSE 0 END) AS despesa_pessoal,
    SUM(CASE WHEN ds_conta IN (
      'Outras Despesas Administrativas',
      'Outras Despesas de Administrativas'
    ) THEN vl_conta ELSE 0 END) AS despesa_adm,
    SUM(CASE WHEN ds_conta IN (
      'Resultado Bruto Intermediação Financeira',
      'Resultado Bruto de Intermediação Financeira'
    ) THEN vl_conta ELSE 0 END) AS resultado_bruto,
    SUM(CASE WHEN ds_conta IN (
      'Receitas de Prestação de Serviços'
    ) THEN vl_conta ELSE 0 END) AS receita_servicos,
    SUM(CASE WHEN ds_conta IN (
      'Outras Receitas Operacionais'
    ) THEN vl_conta ELSE 0 END) AS outras_receitas
  FROM dre
  WHERE ordem_exerc = 'ÚLTIMO'
  GROUP BY dt_refer
),
-- CTE 7: Índice de Eficiência calculado
-- IE = Despesas / Receitas Operacionais * 100
-- Quanto MENOR, mais eficiente. ABS() porque despesas
-- vêm com sinal negativo no DFP da CVM
eficiencia AS (
  SELECT
    dt_refer,
    ROUND(
      ABS(despesa_pessoal + despesa_adm) /
      (resultado_bruto + receita_servicos + outras_receitas) * 100
    , 2) AS indice_eficiencia
  FROM eficiencia_base
),
-- CTE 8: Lucro Líquido para cálculo YoY
lucro_yoy AS (
  SELECT dt_refer, vl_conta AS lucro_liquido
  FROM dre
  WHERE (ds_conta = 'Lucro/Prejuízo Consolidado do Período'
    OR ds_conta = 'Lucro ou Prejuízo Líquido Consolidado do Período')
    AND ordem_exerc = 'ÚLTIMO'
),
-- CTE 9: Receita de Intermediação para cálculo YoY
receita_yoy AS (
  SELECT dt_refer, vl_conta AS receita
  FROM dre
  WHERE (ds_conta = 'Receitas de Intermediação Financeira'
    OR ds_conta = 'Receitas da Intermediação Financeira')
    AND ordem_exerc = 'ÚLTIMO'
),
-- CTE 10: YoY calculado com LAG()
-- LAG() é window function: mantém todas as linhas e
-- "olha para a linha anterior" sem precisar de GROUP BY
-- Prefixo nas colunas (lucro_yoy.dt_refer) necessário
-- para evitar ambiguidade no JOIN entre CTEs
yoy AS (
  SELECT
    lucro_yoy.dt_refer,
    ROUND(
      (lucro_yoy.lucro_liquido - LAG(lucro_yoy.lucro_liquido, 1)
        OVER (ORDER BY lucro_yoy.dt_refer)) /
      LAG(lucro_yoy.lucro_liquido, 1)
        OVER (ORDER BY lucro_yoy.dt_refer) * 100
    , 2) AS yoy_lucro,
    ROUND(
      (receita_yoy.receita - LAG(receita_yoy.receita, 1)
        OVER (ORDER BY receita_yoy.dt_refer)) /
      LAG(receita_yoy.receita, 1)
        OVER (ORDER BY receita_yoy.dt_refer) * 100
    , 2) AS yoy_receita
  FROM lucro_yoy
  JOIN receita_yoy ON lucro_yoy.dt_refer = receita_yoy.dt_refer
)
-- SELECT FINAL: consolida todos os indicadores por ano
-- JOIN em cascata usando dt_refer como chave comum
-- Resultado: 10 linhas (uma por ano), 6 colunas de indicadores
SELECT
  roe.dt_refer AS ano,
  roe.roe_percentual,
  margem.margem_financeira,
  eficiencia.indice_eficiencia,
  yoy.yoy_lucro,
  yoy.yoy_receita
FROM roe
JOIN margem ON roe.dt_refer = margem.dt_refer
JOIN eficiencia ON roe.dt_refer = eficiencia.dt_refer
JOIN yoy ON roe.dt_refer = yoy.dt_refer
ORDER BY roe.dt_refer;
