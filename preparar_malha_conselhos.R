# Executar na raiz do projeto: Rscript preparar_malha_conselhos.R
# Preparo independente dos gráficos; mantém os limites municipais de 2022.
arquivo_origem <- "conselhos_tutelares/mun_geo_2022.rds"
if (!file.exists(arquivo_origem)) {
  malha_baixada <- geobr::read_municipality(
    code_muni = "all", year = 2022, simplified = TRUE
  )
  if (is.null(malha_baixada)) {
    stop("Não foi possível baixar a malha municipal de 2022.", call. = FALSE)
  }
  dir.create(dirname(arquivo_origem), recursive = TRUE, showWarnings = FALSE)
  saveRDS(malha_baixada, arquivo_origem)
}
malha_original <- readRDS(arquivo_origem)
codigos_originais <- as.character(malha_original$code_muni)
stopifnot(nrow(malha_original) == 5570L, !anyDuplicated(codigos_originais))

malha_exibicao <- malha_original |>
  sf::st_transform(3857) |>
  sf::st_simplify(dTolerance = 500, preserveTopology = TRUE) |>
  sf::st_transform(4326) |>
  # Corrige também anéis que colapsam com a precisão usada no GeoJSON.
  sf::st_set_precision(1e4) |>
  sf::st_make_valid() |>
  sf::st_collection_extract("POLYGON") |>
  sf::st_cast("MULTIPOLYGON") |>
  dplyr::transmute(name = as.character(code_muni))
stopifnot(nrow(malha_exibicao) == 5570L,
          identical(malha_exibicao$name, codigos_originais),
          !any(sf::st_is_empty(malha_exibicao)))

dir.create("assets", showWarnings = FALSE)
sf::st_write(malha_exibicao, "assets/municipios_2022.geojson",
             driver = "GeoJSON", layer_options = "COORDINATE_PRECISION=4",
             delete_dsn = TRUE, quiet = TRUE)
malha_gravada <- sf::st_read("assets/municipios_2022.geojson", quiet = TRUE)
stopifnot(identical(malha_gravada$name, codigos_originais),
          all(sf::st_is_valid(malha_gravada)),
          !any(sf::st_is_empty(malha_gravada)))
# Metadados sem geometria para juntar indicadores sem carregar a malha pesada.
saveRDS(sf::st_drop_geometry(malha_original), "assets/municipios_2022_dados.rds")
message("Malha de exibição preparada: 5.570 municípios de 2022.")
