library(sidrar)
library(dplyr)

dados <- get_sidra(
  api = paste0(
    "/t/9606",
    "/n6/all",                     # todos os municípios
    "/v/93",                       # população residente
    "/p/2022",
    "/c86/0",                      # cor/raça: total
    "/c2/0",                       # sexo: total
    "/c287/93070,93084,6567,6568,6569,6570,6571,107453"
  )
)

crianca_adolescente <- dados |>
  mutate(
    grupo = case_when(
      Idade %in% c(
        "0 a 4 anos",
        "5 a 9 anos",
        "10 anos",
        "11 anos"
      ) ~ "crianca",
      
      Idade %in% c(
        "12 anos",
        "13 anos",
        "14 anos",
        "15 a 17 anos"
      ) ~ "adolescente"
    )
  ) |>
  group_by(`Município (Código)`, grupo) |>
  summarise(
    n = sum(Valor),
    .groups = "drop"
  ) |>
  tidyr::pivot_wider(
    names_from = grupo,
    values_from = n,
    names_prefix = "num_"
  ) |>
  transmute(
    mun = `Município (Código)`,
    num_crianca,
    num_adolescente
  )

crianca_adolescente


crianca_adolescente <- crianca_adolescente |>
  mutate(
    num_crianca_adolescente =
      num_crianca + num_adolescente
  )

cons_tut <- left_join(crianca_adolescente,
                      dh_raw |> 
                        transmute(mun = as.character(`Cod Munic`),
                                  num_ct = MDHU612)) |> 
  mutate(num_ct = as.numeric(case_when(num_ct == "-" | num_ct == 'Não informou' ~ '0',
                            T ~ num_ct)),
         ct_por_pop_crianca = 1000*num_ct/num_crianca,
         ct_por_pop_adolescente = 1000*num_ct/num_adolescente,
         ct_por_pop_crianca_adolescente = 1000*num_ct/(num_crianca_adolescente )) |> 
  arrange(ct_por_pop_crianca_adolescente) |> 
  print(n=30)


# Nome e UF dos municípios (malha municipal do IBGE/geobr, ano 2022) ---------

arquivo_mun_geo <- "conselhos_tutelares/mun_geo_2022.rds"

mun_geo <- if (file.exists(arquivo_mun_geo)) {
  readRDS(arquivo_mun_geo)
} else {
  message("Baixando a malha municipal de 2022 pela primeira vez...")
  malha <- geobr::read_municipality(
    code_muni = "all",
    year = 2022,
    simplified = TRUE
  )
  dir.create(dirname(arquivo_mun_geo), recursive = TRUE, showWarnings = FALSE)
  saveRDS(malha, arquivo_mun_geo)
  malha
}

cons_tut <- cons_tut |>
  left_join(
    mun_geo |>
      sf::st_drop_geometry() |>
      transmute(
        mun = as.character(code_muni),
        nome_municipio = name_muni,
        uf = abbrev_state,
        nome_uf = name_state
      ),
    by = "mun"
  ) |>
  relocate(nome_municipio, uf, nome_uf, .after = mun)

save(cons_tut, file = 'conselhos_tutelares/cons_tut.rda')
