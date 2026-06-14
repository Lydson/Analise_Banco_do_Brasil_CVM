# Análise Financeira: Banco do Brasil (2016-2025)

Projeto de análise de dados aplicado a finanças, usando dados públicos
da CVM (Comissão de Valores Mobiliários) para estudar a evolução
financeira do Banco do Brasil S.A. na última década.

## Objetivo

Aplicar SQL, modelagem de dados e visualização para responder:
- Como evoluiu o ROE, margem financeira e eficiência do BB entre 2016-2025?
- Qual foi o CAGR de receita e lucro no período?
- Como a transição para IFRS 9 (2018) afetou a comparabilidade dos dados?

## Fonte de dados

[Portal de Dados Abertos da CVM](https://dados.cvm.gov.br/) -
Demonstrações Financeiras Padronizadas (DFP), 2016-2025.

## Stack

- **Python**: extração e preparação dos dados (`scripts/baixar_dados_cvm.py`)
- **PostgreSQL (Supabase)**: armazenamento e queries analíticas
- **Looker Studio**: visualização e dashboard

## Status

🚧 Em desenvolvimento

## Estrutura

```
dados/processados/   → CSVs filtrados (BPA, BPP, DRE) do BB, 2016-2025
scripts/              → scripts de extração de dados
```