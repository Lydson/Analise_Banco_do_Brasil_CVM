-- ============================================
-- PROJETO: Análise Financeira Banco do Brasil (2016-2025)
-- ARQUIVO: 03_indice_eficiencia.sql
-- OBJETIVO: Calcular o Índice de Eficiência anual do BB
-- ============================================
--
-- CONCEITO:
-- O Índice de Eficiência (IE) mede quanto o banco gasta em estrutura
-- operacional (pessoal + administrativo) para cada R$100 de receita gerada.
-- Quanto MENOR, mais eficiente. Um IE de 30% significa que o banco
-- gasta R$30 de estrutura para gerar R$100 de receita operacional.
--
-- FÓRMULA USADA:
-- IE = (Despesas com Pessoal + Despesas Administrativas)
--    / (Resultado Bruto de Intermediação Financeira
--       + Receitas de Prestação de Serviços
--       + Outras Receitas Operacionais) × 100
--
-- ============================================
-- NOTA METODOLÓGICA — POR QUE NOSSOS VALORES DIFEREM DO OFICIAL
-- ============================================
-- O BB divulga o IE com base em "Despesas Administrativas / Receitas
-- Operacionais Ajustadas" (metodologia gerencial com reclassificações
-- internas de DRE — conceito chamado internamente de "DRE realocado").
--
-- A Tabela 33 do Relatório de Análise de Desempenho 1T26 do BB detalha
-- o denominador oficial, que inclui:
--   - Margem Financeira Bruta (conceito gerencial)
--   - Recuperação de Crédito
--   - Descontos Concedidos
--   - Receitas de Prestação de Serviços
--   - Part. em Controladas, Coligadas e JV
--   - Outras Receitas/Despesas Operacionais
--
-- "Recuperação de Crédito" e "Descontos Concedidos" são conceitos
-- gerenciais internos que NÃO existem como contas separadas no DFP
-- público da CVM. Tentativa de localização confirmou isso:
--
--   SELECT DISTINCT ds_conta FROM dre
--   WHERE ds_conta LIKE '%Recupera%' OR ds_conta LIKE '%Desconto%';
--   → Success. No rows returned.
--
-- CONCLUSÃO: não é possível replicar exatamente o IE oficial do BB
-- usando apenas o DFP público da CVM.
--
-- Valores oficiais obtidos via DeepSearch (OpenAI) consultando os
-- Relatórios de Desempenho do BB (4T17, 4T18, 4T22, 4T24) e
-- Análise de Desempenho 1T26:
--
--   Ano  | Nossa query | Oficial BB
--   2016 |   50,69%   |   39,7%    ← divergência por reclassificações
--   2017 |   48,46%   |   38,1%
--   2018 |   42,28%   |   38,5%
--   2019 |   41,68%   |   36,1%
--   2020 |   36,63%   |   36,6%    ← convergência < 1 p.p.
--   2021 |   34,32%   |   35,6%
--   2022 |   29,84%   |   29,4%
--   2023 |   28,11%   |   27,1%
--   2024 |   26,28%   |   25,6%
--   2025 |   26,29%   |  ~27-28%   ← estimado via 1T26
--
-- A convergência a partir de 2020 (< 2 p.p.) valida a tendência:
-- o BB melhorou seu IE de ~40% em 2016 para ~26% em 2024-2025,
-- reflexo de digitalização, redução de agências e crescimento de
-- receitas acima do crescimento de custos.
-- ============================================


-- ============================================
-- DESAFIO TÉCNICO: mudança de nomenclatura na CVM
-- ============================================
-- A CVM reestruturou a DRE a partir de 2020 — nomes E códigos das
-- contas mudaram simultaneamente. Filtrar por cd_conta não é seguro:
--
--   Conta                          | Código 2016 | Código 2020
--   Receitas de Prestação Serviços |   3.04.01   |   3.04.02
--   Despesas com Pessoal           |   3.04.02   |   3.04.03
--   Outras Despesas Administrativas|   3.04.03   |   3.04.04
--
-- Solução: usar ds_conta com OR cobrindo as variações de nome.
-- ============================================


-- ============================================
-- EXPLORAÇÃO: nomes de conta para Pessoal e Administrativas
-- ============================================
-- Resultado: 4 variações encontradas (mudança de nomenclatura em 2020):
--   'Despesas de Pessoal'                (2016-2019)
--   'Despesas com Pessoal'               (2020-2025)
--   'Outras Despesas Administrativas'    (2016-2019)
--   'Outras Despesas de Administrativas' (2020-2025)
SELECT DISTINCT ds_conta
FROM dre
WHERE ds_conta LIKE '%Pessoal%'
  OR ds_conta LIKE '%Administrativ%';


-- ============================================
-- EXPLORAÇÃO: estrutura completa da DRE por ano
-- ============================================
-- Confirma a reestruturação de códigos entre 2016 e 2020.
SELECT DISTINCT ds_conta, cd_conta
FROM dre
WHERE ordem_exerc = 'ÚLTIMO'
  AND dt_refer = '2016-12-31'
ORDER BY cd_conta;


-- ============================================
-- ÍNDICE DE EFICIÊNCIA POR ANO (2016-2025)
-- ============================================
-- CTE calcula as cinco somas necessárias usando SUM(CASE WHEN),
-- pivotando contas diferentes em colunas sem precisar de JOIN
-- (todas as contas estão na tabela dre).
-- O SELECT final divide numerador pelo denominador de forma limpa,
-- sem repetir os CASE WHEN (vantagem da CTE sobre query direta).
-- ABS() necessário porque despesas vêm com sinal negativo no DFP.
WITH despesas_resultado AS (
  SELECT
    dt_refer,
    SUM(CASE WHEN ds_conta IN (
      'Despesas de Pessoal',
      'Despesas com Pessoal'
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
)
SELECT
  dt_refer,
  ROUND(
    ABS(despesa_pessoal + despesa_adm) /
    (resultado_bruto + receita_servicos + outras_receitas) * 100
  , 2) AS indice_eficiencia
FROM despesas_resultado
ORDER BY dt_refer;
