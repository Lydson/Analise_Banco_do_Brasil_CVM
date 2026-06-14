"""
Baixa os arquivos DFP da CVM (2016-2025), extrai as demonstrações
financeiras (BPA, BPP, DRE consolidados) e filtra apenas os dados
do Banco do Brasil S.A.

Gera 3 arquivos CSV consolidados em dados/processados/:
- bpa_bb.csv  (Balanço Patrimonial Ativo)
- bpp_bb.csv  (Balanço Patrimonial Passivo)
- dre_bb.csv  (Demonstração de Resultado)
"""

import requests
import zipfile
import io
import pandas as pd
import os

# --- Configurações ---
ANOS = range(2016, 2026)  # 2016 até 2025
URL_BASE = "https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC/DFP/DADOS/dfp_cia_aberta_{ano}.zip"
PASTA_RAW = "dados/raw"
PASTA_PROCESSADOS = "dados/processados"

# Termo de busca para filtrar o Banco do Brasil
FILTRO_EMPRESA = "BCO BRASIL S.A."

# Os 3 demonstrativos que vamos extrair (versão consolidada)
DEMONSTRATIVOS = {
    "BPA": "bpa_bb.csv",
    "BPP": "bpp_bb.csv",
    "DRE": "dre_bb.csv",
}


def criar_pastas():
    """Garante que as pastas de saída existem."""
    os.makedirs(PASTA_RAW, exist_ok=True)
    os.makedirs(PASTA_PROCESSADOS, exist_ok=True)


def baixar_zip_ano(ano):
    """
    Baixa o ZIP da CVM para o ano informado e retorna o objeto ZipFile.
    Usa stream para não carregar tudo na memória de uma vez.
    """
    url = URL_BASE.format(ano=ano)
    print(f"Baixando {url} ...")

    resposta = requests.get(url, timeout=60)
    resposta.raise_for_status()  # gera erro se o download falhar

    # Salva uma cópia local (opcional, útil para debug)
    caminho_local = os.path.join(PASTA_RAW, f"dfp_cia_aberta_{ano}.zip")
    with open(caminho_local, "wb") as f:
        f.write(resposta.content)

    return zipfile.ZipFile(io.BytesIO(resposta.content))


def extrair_dados_bb(zip_arquivo, ano):
    """
    Para cada demonstrativo (BPA, BPP, DRE), encontra o CSV consolidado
    correspondente dentro do ZIP, lê e filtra pelas linhas do BB.

    Retorna um dicionário {tipo: DataFrame filtrado}.
    """
    resultados = {}

    for tipo in DEMONSTRATIVOS:
        # Nome esperado do arquivo dentro do ZIP, ex: dfp_cia_aberta_BPA_con_2016.csv
        nome_arquivo = f"dfp_cia_aberta_{tipo}_con_{ano}.csv"

        if nome_arquivo not in zip_arquivo.namelist():
            print(f"  [AVISO] {nome_arquivo} não encontrado no ZIP de {ano}")
            continue

        # CSVs da CVM usam encoding latin-1 e separador ';'
        with zip_arquivo.open(nome_arquivo) as f:
            df = pd.read_csv(f, sep=";", encoding="latin-1")

        # Filtra pelo nome da empresa (case-insensitive)
        df_bb = df[df["DENOM_CIA"].str.contains(FILTRO_EMPRESA, case=False, na=False)]

        print(f"  [{tipo}] {ano}: {len(df_bb)} linhas do BB encontradas")
        resultados[tipo] = df_bb

    return resultados


def main():
    criar_pastas()

    # Acumuladores: vamos juntar os dados de todos os anos aqui
    consolidado = {tipo: [] for tipo in DEMONSTRATIVOS}

    for ano in ANOS:
        try:
            zip_arquivo = baixar_zip_ano(ano)
            dados_ano = extrair_dados_bb(zip_arquivo, ano)

            for tipo, df in dados_ano.items():
                consolidado[tipo].append(df)

        except requests.exceptions.RequestException as e:
            print(f"  [ERRO] Falha ao baixar {ano}: {e}")

    # Junta todos os anos em um único DataFrame por tipo e salva em CSV
    for tipo, lista_dfs in consolidado.items():
        if not lista_dfs:
            print(f"Nenhum dado encontrado para {tipo}, pulando.")
            continue

        df_final = pd.concat(lista_dfs, ignore_index=True)
        caminho_saida = os.path.join(PASTA_PROCESSADOS, DEMONSTRATIVOS[tipo])
        df_final.to_csv(caminho_saida, index=False, encoding="utf-8")

        print(f"\n✅ {tipo}: {len(df_final)} linhas totais salvas em {caminho_saida}")


if __name__ == "__main__":
    main()