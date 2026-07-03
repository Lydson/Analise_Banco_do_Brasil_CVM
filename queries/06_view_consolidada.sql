-- ============================================
-- PROJETO: Análise Financeira Banco do Brasil (2016-2025)
-- ARQUIVO: 06_view_consolidada.sql
-- OBJETIVO: VIEW consolidada com todos os indicadores anuais
-- ============================================
--
-- Após criar a VIEW, consulte com:
--   SELECT * FROM indicadores_bb;
--
-- Indicadores incluídos:
--   - ROE (%)
--   - Margem Financeira (%)
--   - Índice de Eficiência (%)
--   - YoY Lucro (%)
--   - YoY Receita (%)
-- ============================================

CREATE VIEW indicadores_bb AS
WITH
roe_dre AS (
  SELECT dt_refer, vl_conta AS lucro_liquido
  FROM dre
  WHERE (ds_conta = 'Lucro/Prejuízo Consolidado do Período'
    OR ds_conta = 'Lucro ou Prejuízo Líquido Consolidado do Período')
    AND ordem_exerc = 'ÚLTIMO'
),
roe_bpp AS (
  SELECT dt_refer, vl_conta AS patrimonio_liquido
  FROM bpp
  WHERE ds_conta = 'Patrimônio Líquido Consolidado'
    AND ordem_exerc = 'ÚLTIMO'
),
roe AS (
  SELECT
    roe_dre.dt_refer,
    ROUND((roe_dre.lucro_liquido / roe_bpp.patrimonio_liquido) * 100, 2) AS roe_percentual
  FROM roe_dre
  JOIN roe_bpp ON roe_dre.dt_refer = roe_bpp.dt_refer
),
margem_base AS (
  SELECT
    dt_refer,
    SUM(CASE WHEN ds_conta IN ('Receitas de Intermediação Financeira','Receitas da Intermediação Financeira') THEN vl_conta ELSE 0 END) AS receita_financeira,
    SUM(CASE WHEN ds_conta IN ('Resultado Bruto Intermediação Financeira','Resultado Bruto de Intermediação Financeira') THEN vl_conta ELSE 0 END) AS resultado_bruto
  FROM dre
  WHERE ordem_exerc = 'ÚLTIMO'
  GROUP BY dt_refer
),
margem AS (
  SELECT
    dt_refer,
    ROUND((resultado_bruto / receita_financeira) * 100, 2) AS margem_financeira
  FROM margem_base
),
eficiencia_base AS (
  SELECT
    dt_refer,
    SUM(CASE WHEN ds_conta IN ('Despesas de Pessoal','Despesas com Pessoal') THEN vl_conta ELSE 0 END) AS despesa_pessoal,
    SUM(CASE WHEN ds_conta IN ('Outras Despesas Administrativas','Outras Despesas de Administrativas') THEN vl_conta ELSE 0 END) AS despesa_adm,
    SUM(CASE WHEN ds_conta IN ('Resultado Bruto Intermediação Financeira','Resultado Bruto de Intermediação Financeira') THEN vl_conta ELSE 0 END) AS resultado_bruto,
    SUM(CASE WHEN ds_conta IN ('Receitas de Prestação de Serviços') THEN vl_conta ELSE 0 END) AS receita_servicos,
    SUM(CASE WHEN ds_conta IN ('Outras Receitas Operacionais') THEN vl_conta ELSE 0 END) AS outras_receitas
  FROM dre
  WHERE ordem_exerc = 'ÚLTIMO'
  GROUP BY dt_refer
),
eficiencia AS (
  SELECT
    dt_refer,
    ROUND(ABS(despesa_pessoal + despesa_adm) / (resultado_bruto + receita_servicos + outras_receitas) * 100, 2) AS indice_eficiencia
  FROM eficiencia_base
),
lucro_yoy AS (
  SELECT dt_refer, vl_conta AS lucro_liquido
  FROM dre
  WHERE (ds_conta = 'Lucro/Prejuízo Consolidado do Período'
    OR ds_conta = 'Lucro ou Prejuízo Líquido Consolidado do Período')
    AND ordem_exerc = 'ÚLTIMO'
),
receita_yoy AS (
  SELECT dt_refer, vl_conta AS receita
  FROM dre
  WHERE (ds_conta = 'Receitas de Intermediação Financeira'
    OR ds_conta = 'Receitas da Intermediação Financeira')
    AND ordem_exerc = 'ÚLTIMO'
),
yoy AS (
  SELECT
    lucro_yoy.dt_refer,
    ROUND((lucro_yoy.lucro_liquido - LAG(lucro_yoy.lucro_liquido, 1) OVER (ORDER BY lucro_yoy.dt_refer)) / LAG(lucro_yoy.lucro_liquido, 1) OVER (ORDER BY lucro_yoy.dt_refer) * 100, 2) AS yoy_lucro,
    ROUND((receita_yoy.receita - LAG(receita_yoy.receita, 1) OVER (ORDER BY receita_yoy.dt_refer)) / LAG(receita_yoy.receita, 1) OVER (ORDER BY receita_yoy.dt_refer) * 100, 2) AS yoy_receita
  FROM lucro_yoy
  JOIN receita_yoy ON lucro_yoy.dt_refer = receita_yoy.dt_refer
)
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

SELECT * FROM indicadores_bb;
