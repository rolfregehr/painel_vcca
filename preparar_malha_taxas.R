# Malha IBGE 2025 distribuída pelo geobr/Ipea, somente para apresentação.
# Preserva os 5.571 municípios, incluindo Boa Esperança do Norte.
mun_geo_taxas <- geobr::read_municipality(
  code_muni = "all", year = 2025, simplified = TRUE, cache = FALSE,
  showProgress = FALSE
)
stopifnot(!is.null(mun_geo_taxas), nrow(mun_geo_taxas) == 5571L)
mun_geo_taxas <- mun_geo_taxas |>
  sf::st_transform(3857) |>
  sf::st_simplify(dTolerance = 500, preserveTopology = TRUE) |>
  sf::st_transform(4326) |>
  # ECharts não aceita GeometryCollection: mantém apenas os polígonos.
  sf::st_collection_extract("POLYGON") |>
  sf::st_cast("MULTIPOLYGON") |>
  dplyr::transmute(name = as.character(code_muni))
stopifnot(nrow(mun_geo_taxas) == 5571L,
          !any(sf::st_is_empty(mun_geo_taxas)))
dir.create("assets", showWarnings = FALSE)
sf::st_write(
  mun_geo_taxas, "assets/municipios_2025.geojson", driver = "GeoJSON",
  layer_options = "COORDINATE_PRECISION=4", delete_dsn = TRUE, quiet = TRUE
)
