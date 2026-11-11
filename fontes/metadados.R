# Calculado a cada renderização, em ambiente próprio; não altera bases.
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(lubridate))
arquivos <- c(
  SIA = "tabelas/viol_sexual_ca_sia_pa.rda",
  SIH = "tabelas/sih_viol_sexual", SINAN = "tabelas/sinan.rda",
  CNJ = "justica/processos_df.rda", MUNIC = "conselhos_tutelares/cons_tut.rda",
  Taxa_SIA = "tabelas/taxa_ambulatorial_municipio.rda",
  Taxa_SIH = "tabelas/taxa_hospitalar_municipio.rda")
bases <- lapply(arquivos, function(p) {
  e <- new.env(parent = emptyenv())
  nomes <- load(file.path("..", p), envir = e)
  stopifnot(length(nomes) == 1L)
  e[[nomes]]
})
datas <- list(SIA = bases$SIA$competencia, SIH = bases$SIH$competencia,
              SINAN = bases$SINAN$data_notific,
              CNJ = as.Date(substr(bases$CNJ$data_ajuizamento, 1, 8), "%Y%m%d"))
fmt <- function(x) format(x, big.mark = ".", decimal.mark = ",", trim = TRUE, scientific = FALSE)
periodo <- function(nome) paste(format(range(datas[[nome]], na.rm = TRUE), "%m/%Y"), collapse = " a ")
tabela <- function(d) {
  cat('<div class="tabela-rolagem" tabindex="0">\n')
  print(knitr::kable(d, format = "html", escape = TRUE, row.names = FALSE))
  cat('</div>\n')
}
unidades <- c(SIA = "Registros de produção ambulatorial", SIH = "Registros hospitalares",
              SINAN = "Notificações de violência sexual", CNJ = "Processos distintos",
              MUNIC = "Municípios", Taxa_SIA = "Municípios", Taxa_SIH = "Municípios")
resumo <- bind_rows(lapply(names(bases), function(nome) {
  d <- bases[[nome]]
  data <- datas[[nome]]
  tibble(fonte = nome, linhas = nrow(d), variaveis = ncol(d),
         volume = if (nome == "CNJ") n_distinct(d$numero_processo, na.rm = TRUE)
           else if (nome %in% c("SIA", "SIH", "SINAN")) sum(d$n) else nrow(d),
         unidade = unidades[[nome]],
         data_minima = if (!is.null(data)) as.character(min(data, na.rm = TRUE))
           else if (nome == "MUNIC") "2023 (ano de referência)" else as.character(min(d$inicio)),
         data_maxima = if (!is.null(data)) as.character(max(data, na.rm = TRUE))
           else if (nome == "MUNIC") "2023 (ano de referência)" else as.character(max(d$fim)))
}))
mensal <- bind_rows(lapply(names(datas), function(nome) {
  d <- bases[[nome]]
  mes <- floor_date(datas[[nome]], "month")
  x <- if (nome == "CNJ") tibble(mes, processo = d$numero_processo) |>
    filter(!is.na(mes)) |> distinct(mes, processo) |> count(mes, name = "volume")
    else tibble(mes, n = d$n) |> filter(!is.na(mes)) |>
      summarise(volume = sum(n), .by = mes)
  calendario <- tibble(mes = seq(min(mes, na.rm = TRUE), max(mes, na.rm = TRUE), by = "month"))
  calendario |> left_join(x, by = "mes") |>
    mutate(fonte = nome, com_registros = !is.na(volume), .before = 1)
}))
anual <- mensal |> mutate(ano = year(mes)) |>
  summarise(volume = sum(volume, na.rm = TRUE),
            meses_com_registros = sum(com_registros), .by = c(fonte, ano))
uf_cod <- c(11,12,13,14,15,16,17,21,22,23,24,25,26,27,28,29,31,32,33,35,41,42,43,50,51,52,53)
uf_sig <- c("RO","AC","AM","RR","PA","AP","TO","MA","PI","CE","RN","PB","PE","AL","SE","BA","MG","ES","RJ","SP","PR","SC","RS","MS","MT","GO","DF")
territorio <- bind_rows(lapply(c("SINAN", "CNJ"), function(nome) {
  d <- bases[[nome]]
  uf <- if (nome == "CNJ") d$uf else uf_sig[match(d$SG_UF_OCOR, uf_cod)]
  data <- datas[[nome]]
  x <- tibble(uf, data, peso = if (nome == "CNJ") 1 else d$n,
              id = if (nome == "CNJ") d$numero_processo else as.character(seq_len(nrow(d))))
  x |> summarise(data_minima = min(data, na.rm = TRUE),
                 data_maxima = max(data, na.rm = TRUE),
                 volume = if (nome == "CNJ") n_distinct(id) else sum(peso), .by = uf) |>
    mutate(fonte = nome, .before = 1)
})) |> arrange(fonte, uf)
descricoes <- c(
  competencia = "Mês da produção (SIA) ou da internação (SIH); dia 01 é convenção de agregação.",
  genero = "Sexo registrado na fonte: SIA F/M; SIH 1 masculino, 3 feminino. Não mede identidade de gênero.",
  idade = "Idade em anos: PA_IDADE no SIA; diferença entre NASC e DT_INTER no SIH.",
  raca_cor = "Raça/cor registrada; códigos 01 a 05 recodificados e 99 como Sem informação.",
  n = "Frequência dos registros de origem; somar n para obter o total de saúde.",
  data_notific = "DT_NOTIFIC reduzida ao primeiro dia do mês; não representa a data da violência.",
  SG_UF_OCOR = "Código IBGE da UF de ocorrência da violência (não a UF da notificação).",
  ciclo_vida = "Vítima: Criança, menos de 12 anos; Adolescente, de 12 a 17 anos.",
  motivo_violencia = "VIOL_MOTIV recodificado; motivação registrada, diferente do tipo de violência.",
  autor = "Vínculo com provável autor a partir de REL_*; mais de um vínculo vira Múltiplas relações.",
  ciclo_vida_autor = "CICL_VID do provável autor; preservadas todas as faixas etárias.",
  genero_autor = "AUTOR_SEXO: masculino, feminino, ambos ou ignorado.",
  genero_vitima = "CS_SEXO: F/M; outros códigos convertidos para ausente.",
  ano = "Ano de ajuizamento usado na consulta do DataJud.", uf = "UF do tribunal no CNJ; UF municipal nas demais bases.",
  index = "Índice/alias do tribunal na API pública do DataJud.",
  id_elasticsearch = "Identificador do documento retornado pela API; deduplicação com index.",
  score = "Pontuação da busca da API; pode estar ausente ao ordenar por timestamp.",
  id = "Chave do DataJud; pode distinguir classe, grau e órgão de um mesmo processo.",
  tribunal = "Sigla do tribunal de origem.", grau = "Grau/instância: G1, G2, JE ou TR, conforme os registros.",
  numero_processo = "Número único do processo preservado como texto; base da contagem de processos.",
  data_ajuizamento = "Data de ajuizamento na capa; painel interpreta os oito primeiros caracteres AAAAMMDD.",
  nivel_sigilo = "Nível de sigilo retornado nos metadados públicos; o acervo não inclui todos os processos sigilosos.",
  assunto_codigo = "Códigos de assuntos separados por ponto e vírgula.",
  assunto_nome = "Nomes dos assuntos separados por ponto e vírgula; contagens por assunto não são aditivas.",
  orgao_codigo = "Código do órgão julgador.", orgao_nome = "Nome do órgão julgador.",
  municipio_ibge = "Município do órgão julgador; não identifica a residência da vítima.",
  classe_codigo = "Código da classe processual.", classe_nome = "Nome da classe processual.",
  sistema_codigo = "Código do sistema processual.", sistema_nome = "Nome do sistema processual.",
  formato_codigo = "Código do formato do processo.", formato_nome = "Nome do formato, como eletrônico ou físico.",
  ultima_atualizacao = "Data/hora de atualização informada pelo DataJud; não é a data de download local.",
  timestamp = "Timestamp do registro na API, usado na paginação da coleta.",
  mun = "Código IBGE municipal de sete dígitos.", nome_municipio = "Nome do município.", nome_uf = "Nome da UF.",
  num_crianca = "População de 0 a 11 anos, Censo 2022, SIDRA 9606.",
  num_adolescente = "População de 12 a 17 anos, Censo 2022, SIDRA 9606.",
  num_crianca_adolescente = "Soma da população de 0 a 17 anos do Censo 2022.",
  num_ct = "MDHU612, número de conselhos tutelares em 2023; '-' e Não informou convertidos para zero.",
  ct_por_pop_crianca = "Conselhos por mil crianças (0–11 anos).",
  ct_por_pop_adolescente = "Conselhos por mil adolescentes (12–17 anos).",
  ct_por_pop_crianca_adolescente = "Conselhos por mil habitantes de 0–17 anos; a história multiplica por 100.",
  inicio = "Primeiro dia da janela comum de 12 meses para as taxas.", fim = "Último dia da janela das taxas.",
  ano_populacao = "Ano de referência do denominador populacional (2025).",
  pop_total = "População de todas as idades, ambos os sexos; corte dos rankings >= 20 mil.",
  pop_crianca_adolescente = "População de 0 a 17 anos, ambos os sexos, arquivo POP25.dbf.",
  taxa_100mil = "100.000 vezes n dividido pela população de 0–17 anos; frequência de registros, não risco individual.")
dicionario <- bind_rows(lapply(names(bases), function(nome) {
  d <- bases[[nome]]
  peso <- if (nome %in% c("SIA", "SIH", "SINAN")) d$n else rep(1, nrow(d))
  bind_rows(lapply(names(d), function(campo) {
    x <- d[[campo]]
    ausente <- is.na(x) | if (is.character(x)) trimws(x) == "" else FALSE
    tibble(fonte = nome, campo, tipo = paste(class(x), collapse = "/"),
           descricao = unname(descricoes[campo]), distintos = n_distinct(x, na.rm = TRUE),
           linhas_ausentes = sum(ausente),
           percentual_volume_ausente = round(100 * sum(peso[ausente]) / sum(peso), 3))
  }))
}))
stopifnot(!anyNA(dicionario$descricao))
inventario <- tibble(fonte = names(arquivos), arquivo = unname(arquivos),
  bytes = file.info(file.path("..", arquivos))$size,
  modificacao_local = format(file.info(file.path("..", arquivos))$mtime, tz = "America/Sao_Paulo", usetz = TRUE),
  md5 = unname(tools::md5sum(file.path("..", arquivos))))
for (item in c("resumo", "mensal", "anual", "territorio", "dicionario", "inventario")) {
  write.csv(get(item), paste0(item, ".csv"), row.names = FALSE, na = "", fileEncoding = "UTF-8")
}
coleta <- jsonlite::fromJSON("coleta_airflow.json", simplifyVector = FALSE)
coleta_resumo <- bind_rows(lapply(names(coleta$fontes), function(nome) {
  x <- coleta$fontes[[nome]]
  tibble(Fonte = nome, `Arquivos inventariados` = x$arquivos,
         `Último inventário (UTC)` = x$ultimo_inventario,
         `Último download registrado (UTC)` = if (is.null(x$ultimo_download)) "Não registrado / acervo legado" else x$ultimo_download,
         `Estados` = paste(vapply(x$estados, function(e) paste(e$status, e$arquivos), ""), collapse = "; "))
}))
