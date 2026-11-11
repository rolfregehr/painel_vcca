# Configuração ----
rm(list = ls())
pacman::p_load(arrow, tidyverse)


# PA ----

ds_sia_pa <- list.files("/srv/dados_nvme/dados/pqt/siasus/",
           full.names = TRUE,
           pattern = '^pa[a-z]{2}[0-9]{4}')

## viol_sexual_ca_sia_pa ----

viol_sexual_ca_sia_pa <- open_dataset(ds_sia_pa) |> 
  filter(str_detect(PA_CIDPRI, "T742|Y05")) |> # filtro de estupro e violência sexual
  transmute(competencia = ym(PA_CMP),
            genero = PA_SEXO,
            idade = as.numeric(PA_IDADE),
            raca_cor = case_when(
              PA_RACACOR == "01" ~ "Branca",
              PA_RACACOR == "02" ~ "Preta",
              PA_RACACOR == "03" ~ "Parda",
              PA_RACACOR == "04" ~ "Amarela",
              PA_RACACOR == "05" ~ "Indígena",
              PA_RACACOR == "99" ~ "Sem informação",
              TRUE ~ NA_character_
              )
            ) |> 
  filter(idade >= 0, idade <= 17) |> 
  group_by(competencia,
           genero,
           idade,
           raca_cor
           ) |> 
  summarise(n=n(), .groups = 'drop')  |> 
  collect() 


save(viol_sexual_ca_sia_pa, file = 'tabelas/viol_sexual_ca_sia_pa.rda')


# RD ----

ds_sih_rd <- list.files("/srv/dados_nvme/dados/pqt/sihsus/",
                     full.names = TRUE,
                     pattern = '^rd[a-z]{2}[0-9]{4}')



## sih_viol_sexual ----


sih_viol_sexual <- open_dataset(ds_sih_rd) |> 
  filter(str_detect(DIAG_PRINC, "T742|Y05")) |> # filtro de estupro e violência sexual
  select(NASC, DT_INTER, SEXO, RACA_COR) |>
  collect() |>
  transmute(competencia = lubridate::floor_date(lubridate::ymd(DT_INTER), "month"),
            genero = SEXO,
            idade = floor(lubridate::time_length(
              lubridate::interval(lubridate::ymd(NASC), lubridate::ymd(DT_INTER)),
              "years"
            )),
            raca_cor = case_when(
              RACA_COR == "01" ~ "Branca",
              RACA_COR == "02" ~ "Preta",
              RACA_COR == "03" ~ "Parda",
              RACA_COR == "04" ~ "Amarela",
              RACA_COR == "05" ~ "Indígena",
              RACA_COR == "99" ~ "Sem informação",
              TRUE ~ NA_character_
            )
  ) |> 
  filter(idade >= 0, idade <= 17) |> 
  group_by(competencia,
           genero,
           idade,
           raca_cor
  ) |> 
  summarise(n=n(), .groups = 'drop') |> 
  collect()
  


save(sih_viol_sexual, file = 'tabelas/sih_viol_sexual')



# SINAN ----
ds_sinan_viol <- list.files("/srv/dados_nvme/dados/pqt/sinan/",
                        full.names = TRUE,
                        pattern = '^violbr')

## VIOL ----

sinan <- open_dataset(ds_sinan_viol) |>
  # Somente notificações com violência sexual assinalada (1 = Sim).
  filter(VIOL_SEXU == "1") |>
  select(DT_NOTIFIC, SG_UF_OCOR, NU_IDADE_N, CS_SEXO, VIOL_MOTIV,
         AUTOR_SEXO, CICL_VID,
         REL_PAI, REL_MAE, REL_PAD, REL_MAD, REL_CONJ, REL_EXCON,
         REL_NAMO, REL_EXNAM, REL_FILHO, REL_IRMAO, REL_CONHEC,
         REL_DESCO, REL_CUIDA, REL_PATRAO, REL_INST, REL_POL,
         REL_PROPRI, REL_OUTROS) |>
  collect() |>
  mutate(
    data_notific = floor_date(DT_NOTIFIC, unit = "month"),
    SG_UF_OCOR = as.integer(as.character(SG_UF_OCOR)),
    # NU_IDADE_N: primeiro dígito indica horas, dias, meses ou anos.
    idade_codigo = as.integer(as.character(NU_IDADE_N)),
    unidade_idade = idade_codigo %/% 1000,
    idade_valor = idade_codigo %% 1000,
    idade_anos = case_when(
      unidade_idade == 1 ~ idade_valor / (24 * 365.25),
      unidade_idade == 2 ~ idade_valor / 365.25,
      unidade_idade == 3 ~ idade_valor / 12,
      unidade_idade == 4 & idade_valor != 999 ~ as.numeric(idade_valor),
      TRUE ~ NA_real_
    ),
    ciclo_vida = case_when(
      is.na(idade_anos) ~ NA_character_,
      idade_anos < 12 ~ "Criança",
      idade_anos < 18 ~ "Adolescente",
      idade_anos < 30 ~ "Jovem",
      idade_anos < 60 ~ "Adulto",
      TRUE ~ "Pessoa idosa"
    ),
    genero_vitima = case_when(
      CS_SEXO == "F" ~ "Feminino",
      CS_SEXO == "M" ~ "Masculino",
      TRUE ~ NA_character_
    ),
    # Categorias mantidas da preparação anterior de dados_001.
    cod_motivo = as.integer(as.character(VIOL_MOTIV)),
    motivo_violencia = case_when(
      cod_motivo == 1 ~ "Sexismo",
      cod_motivo == 2 ~ "LGBT-Fobia",
      cod_motivo == 3 ~ "Racismo",
      cod_motivo == 4 ~ "Intolerância religiosa",
      cod_motivo == 5 ~ "Xenofobia",
      cod_motivo == 6 ~ "Conflito geracional",
      cod_motivo == 7 ~ "Situação de rua",
      cod_motivo == 8 ~ "Deficiência",
      cod_motivo %in% c(9, 88, 99) ~ "Não detalhado / sem informação",
      TRUE ~ NA_character_
    ),
    # Uma notificação com vários vínculos fica em uma única categoria.
    n_rel_autor = rowSums(pick(starts_with("REL_")) == "1", na.rm = TRUE),
    autor = case_when(
      n_rel_autor > 1 ~ "Múltiplas relações",
      REL_PAI == "1" ~ "Pai",
      REL_MAE == "1" ~ "Mãe",
      REL_PAD == "1" ~ "Padrasto",
      REL_MAD == "1" ~ "Madrasta",
      REL_CONJ == "1" ~ "Cônjuge",
      REL_EXCON == "1" ~ "Ex-cônjuge",
      REL_NAMO == "1" ~ "Namorado(a)",
      REL_EXNAM == "1" ~ "Ex-namorado(a)",
      REL_FILHO == "1" ~ "Filho(a)",
      REL_IRMAO == "1" ~ "Irmão(ã)",
      REL_CONHEC == "1" ~ "Amigos/conhecidos",
      REL_DESCO == "1" ~ "Desconhecido",
      REL_CUIDA == "1" ~ "Cuidador",
      REL_PATRAO == "1" ~ "Patrão/chefe",
      REL_INST == "1" ~ "Pessoa com relação institucional",
      REL_POL == "1" ~ "Policial/agente da lei",
      REL_PROPRI == "1" ~ "Própria pessoa",
      REL_OUTROS == "1" ~ "Outros",
      TRUE ~ "Não informado"
    ),
    genero_autor = case_when(
      AUTOR_SEXO == "1" ~ "Masculino",
      AUTOR_SEXO == "2" ~ "Feminino",
      AUTOR_SEXO == "3" ~ "Ambos os sexos",
      AUTOR_SEXO == "9" ~ "Ignorado",
      TRUE ~ NA_character_
    ),
    ciclo_vida_autor = case_when(
      CICL_VID == "1" ~ "Criança",
      CICL_VID == "2" ~ "Adolescente",
      CICL_VID == "3" ~ "Jovem",
      CICL_VID == "4" ~ "Pessoa adulta",
      CICL_VID == "5" ~ "Pessoa idosa",
      CICL_VID == "9" ~ "Ignorado",
      TRUE ~ NA_character_
    )
  ) |>
  filter(ciclo_vida %in% c("Criança", "Adolescente")) |>
  group_by(data_notific, SG_UF_OCOR, ciclo_vida, motivo_violencia,
           autor, ciclo_vida_autor, genero_autor, genero_vitima) |>
  summarise(n = n(), .groups = "drop")

save(sinan, file = "tabelas/sinan.rda")


# Taxas municipais de violência sexual — últimos 12 meses ----

# População municipal por sexo e idade simples: MS/Ripsa, com dados do IBGE.
# População total para o recorte municipal; 0 a 17 anos para o denominador.
# Ambos os sexos, estimativa de 2025.
dir.create("tabelas/fontes", recursive = TRUE, showWarnings = FALSE)
if (!file.exists("tabelas/fontes/POPSBR25.zip")) {
  download.file(
    "ftp://ftp.datasus.gov.br/dissemin/publicos/IBGE/POPSVS/POPSBR25.zip",
    "tabelas/fontes/POPSBR25.zip", mode = "wb"
  )
}
if (!file.exists("tabelas/fontes/municipios_ibge.json")) {
  download.file(
    "https://servicodados.ibge.gov.br/api/v1/localidades/municipios",
    "tabelas/fontes/municipios_ibge.json", mode = "wb"
  )
}

pasta_pop <- tempfile()
dir.create(pasta_pop)
unzip("tabelas/fontes/POPSBR25.zip", exdir = pasta_pop)
pop_crianca_adolescente <- foreign::read.dbf(
  file.path(pasta_pop, "POP25.dbf"), as.is = TRUE
) |>
  filter(sexo %in% c("1", "2")) |>
  group_by(mun = cod_mun) |>
  summarise(pop_total = sum(pop),
            pop_crianca_adolescente = sum(pop[as.integer(idade) %in% 0:17]),
            .groups = "drop") |>
  mutate(mun_sus = str_sub(mun, 1, 6), ano_populacao = 2025L) |>
  left_join(
    jsonlite::fromJSON("tabelas/fontes/municipios_ibge.json") |>
      transmute(mun = as.character(id), nome_municipio = nome,
                uf = `regiao-imediata`$`regiao-intermediaria`$UF$sigla),
    by = "mun"
  )
unlink(pasta_pop, recursive = TRUE)

# Mesma janela nas duas fontes, encerrada na última competência comum.
fim_taxas <- min(max(viol_sexual_ca_sia_pa$competencia),
                 max(sih_viol_sexual$competencia))
inicio_taxas <- fim_taxas %m-% months(11)
limite_taxas <- fim_taxas %m+% months(1)

## Ambulatoriais por município de residência ----

n_sia_municipio <- open_dataset(ds_sia_pa) |>
  filter(str_detect(PA_CIDPRI, "T742|Y05"),
         as.numeric(PA_IDADE) >= 0, as.numeric(PA_IDADE) <= 17,
         PA_CMP >= format(inicio_taxas, "%Y%m"),
         PA_CMP < format(limite_taxas, "%Y%m")) |>
  group_by(mun_sus = PA_MUNPCN) |>
  summarise(n = n(), .groups = "drop") |>
  collect() |>
  # Regiões administrativas do DF pertencem ao código IBGE de Brasília.
  mutate(mun_sus = if_else(str_starts(mun_sus, "53"), "530010", mun_sus)) |>
  group_by(mun_sus) |>
  summarise(n = sum(n), .groups = "drop")

taxa_ambulatorial_municipio <- pop_crianca_adolescente |>
  left_join(n_sia_municipio, by = "mun_sus") |>
  mutate(n = replace_na(n, 0L),
         taxa_100mil = 100000 * n / pop_crianca_adolescente,
         inicio = inicio_taxas, fim = limite_taxas - days(1)) |>
  select(mun, nome_municipio, uf, inicio, fim, ano_populacao,
         pop_total, pop_crianca_adolescente, n, taxa_100mil)

save(taxa_ambulatorial_municipio,
     file = "tabelas/taxa_ambulatorial_municipio.rda")

## Hospitalares por município de residência ----

n_sih_municipio <- open_dataset(ds_sih_rd) |>
  filter(str_detect(DIAG_PRINC, "T742|Y05"),
         DT_INTER >= format(inicio_taxas, "%Y%m%d"),
         DT_INTER < format(limite_taxas, "%Y%m%d")) |>
  select(MUNIC_RES, NASC, DT_INTER) |>
  collect() |>
  mutate(idade = floor(time_length(interval(ymd(NASC), ymd(DT_INTER)), "years")),
         mun_sus = if_else(str_starts(MUNIC_RES, "53"), "530010", MUNIC_RES)) |>
  filter(idade >= 0, idade <= 17) |>
  group_by(mun_sus) |>
  summarise(n = n(), .groups = "drop")

taxa_hospitalar_municipio <- pop_crianca_adolescente |>
  left_join(n_sih_municipio, by = "mun_sus") |>
  mutate(n = replace_na(n, 0L),
         taxa_100mil = 100000 * n / pop_crianca_adolescente,
         inicio = inicio_taxas, fim = limite_taxas - days(1)) |>
  select(mun, nome_municipio, uf, inicio, fim, ano_populacao,
         pop_total, pop_crianca_adolescente, n, taxa_100mil)

save(taxa_hospitalar_municipio,
     file = "tabelas/taxa_hospitalar_municipio.rda")
