-- ============================================
-- PROJETO: Análise Financeira Banco do Brasil (2016-2025)
-- ARQUIVO: 02_roe_banco_brasil.sql
-- OBJETIVO: Calcular o ROE (Return on Equity) anual do BB
--           usando dados públicos da CVM
-- ============================================


-- ============================================
-- EXPLORAÇÃO: nomes de conta para Lucro Líquido na DRE
-- ============================================
-- A CVM mudou o nome dessa conta ao longo dos anos.
-- Usamos LIKE para encontrar todas as variações antes
-- de filtrar com o nome exato.
SELECT DISTINCT ds_conta
FROM dre
WHERE ds_conta LIKE '%Lucro%';


-- ============================================
-- LUCRO LÍQUIDO CONSOLIDADO POR ANO (2016-2025)
-- ============================================
-- Duas variações do nome da conta encontradas:
--   2016-2019: 'Lucro/Prejuízo Consolidado do Período'
--   2020-2025: 'Lucro ou Prejuízo Líquido Consolidado do Período'
-- Filtramos ordem_exerc = 'ÚLTIMO' para evitar duplicação:
-- a CVM traz o ano atual E o anterior no mesmo arquivo.
SELECT
    dt_refer,
    ds_conta,
    vl_conta
FROM
    dre
WHERE
    (ds_conta = 'Lucro/Prejuízo Consolidado do Período'
    OR ds_conta = 'Lucro ou Prejuízo Líquido Consolidado do Período')
    AND ordem_exerc = 'ÚLTIMO'
ORDER BY
    dt_refer;


-- ============================================
-- EXPLORAÇÃO: nomes de conta para Patrimônio Líquido no BPP
-- ============================================
-- 3 variações encontradas:
--   - 'Patrimônio Líquido Consolidado' (TOTAL - é esse que usamos)
--   - 'Patrimônio Líquido Atribuído ao Controlador'
--   - 'Patrimônio Líquido Atribuído aos Não Controladores'
-- Usamos o TOTAL para consistência com o lucro consolidado da DRE.
SELECT DISTINCT ds_conta
FROM bpp
WHERE ds_conta LIKE '%Patrimônio Líquido%';


-- ============================================
-- PATRIMÔNIO LÍQUIDO CONSOLIDADO POR ANO (2016-2025)
-- ============================================
-- Atenção: o valor é case-sensitive — 'ÚLTIMO' em maiúsculas.
SELECT
    dt_refer,
    ds_conta,
    vl_conta
FROM
    bpp
WHERE
    ds_conta = 'Patrimônio Líquido Consolidado'
    AND ordem_exerc = 'ÚLTIMO'
ORDER BY
    dt_refer;


-- ============================================
-- ROE DO BANCO DO BRASIL (2016-2025)
-- ROE = (Lucro Líquido / Patrimônio Líquido) * 100
-- ============================================
-- JOIN entre DRE e BPP usando dt_refer como chave de ligação.
-- Cada tabela tem sua própria condição de filtro (prefixo dre./bpp.)
-- para evitar ambiguidade entre colunas de mesmo nome.
-- ROUND(..., 2) arredonda o resultado para 2 casas decimais.
--
-- Resultado observado:
--   2016-2019: ROE crescendo (9,6% → 17,2%) — recuperação pós-crise
--   2020: queda para 10,4% — impacto da pandemia
--   2021-2023: recuperação, pico de 19,1% em 2023
--   2024-2025: queda (15,8% → 8,6%) — crise da carteira agro/inadimplência
SELECT
    dre.dt_refer AS ano,
    dre.vl_conta AS lucro_liquido,
    bpp.vl_conta AS patrimonio_liquido,
    ROUND((dre.vl_conta / bpp.vl_conta) * 100, 2) AS roe_percentual
FROM
    dre
    JOIN bpp ON dre.dt_refer = bpp.dt_refer
WHERE
    (dre.ds_conta = 'Lucro/Prejuízo Consolidado do Período'
    OR dre.ds_conta = 'Lucro ou Prejuízo Líquido Consolidado do Período')
    AND dre.ordem_exerc = 'ÚLTIMO'
    AND bpp.ds_conta = 'Patrimônio Líquido Consolidado'
    AND bpp.ordem_exerc = 'ÚLTIMO'
ORDER BY
    dre.dt_refer;

-- ANÁLISE PRÉVIA
-- 2016-2019: ROE crescendo de 9,6% para 17,2% — recuperação pós-crise Dilma/Temer
-- 2020: queda para 10,4% — pandemia, inadimplência, Selic na mínima histórica (2%)
-- 2021-2023: recuperação forte, pico de 19,1% em 2023
-- 2024-2025: queda brusca para 15,8% e 8,6% — crise do agro e inadimplência recorde. Na verdade, 2026 está pior e a ação está 19,53 (19/06/26) sendo que atingiu o pico de 27,48 em 25/02/26
