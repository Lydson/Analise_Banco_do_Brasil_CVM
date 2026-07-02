-- ============================================
-- PROJETO: Análise Financeira Banco do Brasil (2016-2025)
-- ARQUIVO: 05_cagr.sql
-- OBJETIVO: Calcular o CAGR (Compound Annual Growth Rate) do
--           Lucro Líquido e da Receita de Intermediação (2016-2025)
-- ============================================
--
-- CONCEITO:
-- CAGR responde: "se o crescimento tivesse sido constante ao longo
-- de todos os anos, qual seria a taxa anual?"
-- Suaviza as oscilações do YoY e revela a tendência real de longo prazo.
--
-- Fórmula: (valor_final / valor_inicial) ^ (1 / n_anos) - 1
-- No nosso caso: n = 9 anos (de 2016 até 2025)
--
-- CONCEITO SQL NOVO: POWER() e MAX() FILTER (WHERE ...)
-- POWER(base, expoente): calcula potência. Equivalente a base^expoente.
-- FILTER (WHERE condição): sintaxe moderna do PostgreSQL para filtrar
-- linhas dentro de uma agregação. Alternativa mais legível ao
-- MAX(CASE WHEN dt_refer = '...' THEN vl_conta END).
--
-- NOTA SOBRE CROSS JOIN:
-- Usado aqui porque ambas as CTEs são agregadas para uma linha só
-- via MAX() FILTER. Em qualquer outro contexto, CROSS JOIN geraria
-- produto cartesiano e resultado incorreto. Para maior segurança,
-- uma alternativa seria JOIN ON lucro_anual.dt_refer = receita_anual.dt_refer.
-- ============================================


-- ============================================
-- PASSO 1: confirmar os valores de 2016 e 2025 (validação)
-- ============================================
-- Antes de calcular CAGR, confirmamos os dois valores
-- que serão usados como inicial e final da série.
SELECT
  dt_refer,
  vl_conta
FROM dre
WHERE
  (ds_conta = 'Lucro/Prejuízo Consolidado do Período'
  OR ds_conta = 'Lucro ou Prejuízo Líquido Consolidado do Período')
  AND ordem_exerc = 'ÚLTIMO'
  AND dt_refer IN ('2016-12-31', '2025-12-31')
ORDER BY dt_refer;


-- ============================================
-- PASSO 2: CAGR do Lucro (versão simples, valores fixos)
-- ============================================
-- Primeira versão com valores numéricos diretos —
-- útil para validar a fórmula antes de dinamizar com CTE.
-- Resultado esperado: 7,63%
SELECT
  ROUND(
    (POWER(16781938.0 / 8659577.0, 1.0 / 9) - 1) * 100
  , 2) AS cagr_lucro_percentual;


-- ============================================
-- PASSO 3: CAGR consolidado (Lucro + Receita) — versão dinâmica
-- ============================================
-- Versão final: valores buscados dinamicamente do banco via CTEs.
-- Duas CTEs encadeadas (lucro_anual e receita_anual), combinadas
-- via CROSS JOIN porque ambas são agregadas para uma única linha.
--
-- Resultados:
--   CAGR Lucro  (2016-2025): 7,63% ao ano
--   CAGR Receita(2016-2025): 7,40% ao ano
--
-- Lucro e receita cresceram em ritmo muito próximo ao longo de 9 anos,
-- indicando que o BB expandiu receita mantendo margens.
-- Porém, o CAGR suaviza oscilações — o YoY mostrou que 2024-2025
-- foi uma exceção: receita cresceu (+16,80%) mas lucro despencou
-- (-42,47%) por causa das provisões da carteira agro.
-- O CAGR captura a tendência de longo prazo; o YoY revela os choques.
WITH lucro_anual AS (
  SELECT
    dt_refer,
    vl_conta
  FROM dre
  WHERE
    (ds_conta = 'Lucro/Prejuízo Consolidado do Período'
    OR ds_conta = 'Lucro ou Prejuízo Líquido Consolidado do Período')
    AND ordem_exerc = 'ÚLTIMO'
),
receita_anual AS (
  SELECT
    dt_refer,
    vl_conta
  FROM dre
  WHERE
    (ds_conta = 'Receitas de Intermediação Financeira'
    OR ds_conta = 'Receitas da Intermediação Financeira')
    AND ordem_exerc = 'ÚLTIMO'
)
SELECT
  MAX(l.vl_conta) FILTER (WHERE l.dt_refer = '2016-12-31') AS lucro_inicial_2016,
  MAX(l.vl_conta) FILTER (WHERE l.dt_refer = '2025-12-31') AS lucro_final_2025,
  ROUND(
    (POWER(
      MAX(l.vl_conta) FILTER (WHERE l.dt_refer = '2025-12-31') /
      MAX(l.vl_conta) FILTER (WHERE l.dt_refer = '2016-12-31'),
      1.0 / 9
    ) - 1) * 100,
    2
  ) AS cagr_lucro_percentual,
  MAX(r.vl_conta) FILTER (WHERE r.dt_refer = '2016-12-31') AS receita_inicial_2016,
  MAX(r.vl_conta) FILTER (WHERE r.dt_refer = '2025-12-31') AS receita_final_2025,
  ROUND(
    (POWER(
      MAX(r.vl_conta) FILTER (WHERE r.dt_refer = '2025-12-31') /
      MAX(r.vl_conta) FILTER (WHERE r.dt_refer = '2016-12-31'),
      1.0 / 9
    ) - 1) * 100,
    2
  ) AS cagr_receita_percentual
FROM
  lucro_anual l
  CROSS JOIN receita_anual r;
