source("config.R")

# Utilidades internas --------------------------------------------------------

numero_ptbr <- htmlwidgets::JS(
  "function(v){return Number(v).toLocaleString('pt-BR');}"
)

rotulo_ano <- htmlwidgets::JS(
  "function(v){return String(new Date(Array.isArray(v) ? v[0] : v).getFullYear());}"
)

# Widget a partir de uma lista de opções (altura relativa ao contêiner).
widget_echarts <- function(opcoes, altura = "100%") {
  echarts4r::e_charts(data.frame(x = 0, y = 0), x, height = altura) |>
    echarts4r::e_list(opcoes)
}

# Normaliza o eixo x: "YYYYMM" vira Date; demais tipos seguem como estão.
prepara_eixo_x <- function(x) {
  if (inherits(x, "POSIXt")) {
    return(as.Date(x))
  }
  if (inherits(x, "Date")) {
    return(x)
  }
  if (is.character(x) && all(grepl("^[0-9]{6}$", x))) {
    return(lubridate::ym(x))
  }
  x
}

# Pontos [x, y] de uma série, com timestamps em ms quando o eixo é temporal.
pontos_serie <- function(x, y, temporal) {
  ord <- order(x)
  x <- x[ord]
  y <- y[ord]
  Map(
    function(xi, yi) {
      list(
        if (temporal) as.numeric(as.POSIXct(xi, tz = "UTC")) * 1000 else xi,
        if (is.na(yi)) NULL else yi
      )
    },
    x,
    y
  )
}

# Gráficos --------------------------------------------------------------------

grafico_barras_horizontal <- function(
    dados,
    categorias,
    valores,
    titulo,
    subtitulo = NULL,
    cor = 3,
    nome_valores = NULL,
    nome_categorias = NULL
) {
  dados |>
    transmute(
      categoria = as.character({{ categorias }}),
      valor = as.numeric({{ valores }})
    ) |>
    filter(!is.na(categoria), !is.na(valor)) |>
    summarise(
      valor = sum(valor, na.rm = TRUE),
      .by = categoria
    ) |>
    arrange(desc(valor)) |>
    e_charts(categoria, reorder = FALSE) |>
    e_color(background = cor_fundo) |>
    e_text_style(fontFamily = fonte_senado, color = "#333333") |>
    e_bar(
      valor,
      itemStyle = list(color = unname(paleta[cor]))
    ) |>
    e_flip_coords() |>
    e_y_axis(
      name = nome_categorias,
      inverse = TRUE,
      axisLabel = list(
        width = 250,
        overflow = "break",
        lineHeight = 18
      )
    ) |>
    e_x_axis(name = nome_valores) |>
    e_tooltip(trigger = "item") |>
    e_title(
      text = titulo,
      subtext = subtitulo,
      left = "center"
    ) |>
    e_legend(show = FALSE)
}

grafico_linhas <- function(
    dados,
    eixo_x,
    eixo_y,
    categorias,
    titulo,
    subtitulo = "mensal",
    razao = NULL,
    nome_razao = NULL
) {
  dados <- dados |>
    transmute(
      x = {{ eixo_x }},
      y = as.numeric({{ eixo_y }}),
      categoria = {{ categorias }}
    ) |>
    filter(!is.na(x), !is.na(y), !is.na(categoria))

  if (is.character(dados$x) &&
      all(grepl("^[0-9]{6}$", dados$x))) {
    dados$x <- ym(dados$x)
  }

  dados <- dados |>
    summarise(
      y = sum(y, na.rm = TRUE),
      .by = c(x, categoria)
    ) |>
    arrange(x, categoria)

  if (is.null(razao)) {
    grafico <- dados |>
      group_by(categoria) |>
      e_charts(x) |>
      e_line(y, symbol = "none")
  } else {
    dados <- dados |>
      pivot_wider(names_from = categoria, values_from = y) |>
      mutate(.razao = .data[[razao[1]]] / .data[[razao[2]]])

    grafico <- e_charts(dados, x)

    for (categoria in setdiff(names(dados), c("x", ".razao"))) {
      grafico <- e_line_(
        grafico,
        categoria,
        name = categoria,
        symbol = "none"
      )
    }

    if (is.null(nome_razao)) {
      nome_razao <- paste("Razão", paste(razao, collapse = "/"))
    }

    grafico <- grafico |>
      e_line_(
        ".razao",
        name = nome_razao,
        symbol = "none",
        y_index = 1,
        lineStyle = list(type = "dashed")
      ) |>
      e_y_axis(
        index = 1,
        name = nome_razao,
        position = "right",
        scale = TRUE,
        splitLine = list(show = FALSE)
      )
  }

  grafico |>
    e_color(unname(paleta), background = cor_fundo) |>
    e_text_style(fontFamily = fonte_senado, color = "#333333") |>
    e_tooltip(trigger = "axis") |>
    e_title(
      text = titulo,
      subtext = subtitulo,
      left = "center"
    ) |>
    e_legend(type = "scroll", bottom = 0) |>
    e_x_axis(
      axisLine = list(show = FALSE),
      axisTick = list(show = FALSE),
      splitLine = list(show = FALSE)
    ) |>
    e_y_axis(
      index = 0,
      scale = TRUE,
      axisLine = list(show = TRUE),
      axisTick = list(show = FALSE),
      splitLine = list(show = TRUE)
    ) |>
    e_grid(
      left = "5%",
      right = if (is.null(razao)) "3%" else "7%",
      top = "15%",
      bottom = "15%",
      containLabel = TRUE
    )
}

# Linha(s) temporais ou numéricas em um único painel que ocupa o contêiner.
grafico_linha <- function(
    dados,
    eixo_x,
    eixo_y,
    grupo = NULL,
    titulo = NULL,
    subtitulo = NULL,
    nome_x = NULL,
    nome_y = NULL,
    cores = NULL,
    ponto_destaque = NULL,
    legenda = c("top", "bottom", "none"),
    largura_linha = 2,
    altura = "100%"
) {
  legenda <- match.arg(legenda)

  eixo_x <- rlang::enquo(eixo_x)
  eixo_y <- rlang::enquo(eixo_y)
  grupo <- rlang::enquo(grupo)

  dados <- dados |>
    dplyr::transmute(
      .x = prepara_eixo_x(!!eixo_x),
      .y = as.numeric(!!eixo_y),
      .grupo = if (rlang::quo_is_null(grupo)) {
        nome_y %||% "Série"
      } else {
        as.character(!!grupo)
      }
    ) |>
    dplyr::filter(!is.na(.x), !is.na(.grupo)) |>
    dplyr::summarise(
      .y = if (all(is.na(.y))) NA_real_ else sum(.y, na.rm = TRUE),
      .by = c(.x, .grupo)
    )

  temporal <- inherits(dados$.x, "Date")
  grupos <- sort(unique(dados$.grupo))
  if (!is.null(cores)) {
    grupos <- c(intersect(names(cores), grupos), setdiff(grupos, names(cores)))
  }

  series <- lapply(grupos, function(g) {
    d <- dados[dados$.grupo == g, , drop = FALSE]
    serie <- list(
      name = g,
      type = "line",
      data = pontos_serie(d$.x, d$.y, temporal),
      showSymbol = FALSE,
      connectNulls = FALSE,
      lineStyle = list(width = largura_linha)
    )
    if (!is.null(cores) && g %in% names(cores)) {
      serie$itemStyle <- list(color = unname(cores[g]))
      serie$lineStyle$color <- unname(cores[g])
    }
    if (!is.null(ponto_destaque) && nrow(ponto_destaque) > 0 && g == grupos[1]) {
      px <- prepara_eixo_x(ponto_destaque[[1]][1])
      py <- as.numeric(ponto_destaque[[2]][1])
      serie$markPoint <- list(
        symbol = "circle",
        symbolSize = 8,
        label = list(
          show = TRUE,
          position = "top",
          color = "#333333",
          backgroundColor = "#FFFFFF",
          borderColor = "#DDDDDD",
          borderWidth = 1,
          padding = 4,
          fontSize = 11,
          formatter = as.character(ponto_destaque[[3]][1])
        ),
        data = list(list(coord = list(
          if (temporal) as.numeric(as.POSIXct(px, tz = "UTC")) * 1000 else px,
          py
        )))
      )
    }
    serie
  })

  widget_echarts(list(
    color = as.list(unname(paleta)),
    textStyle = list(fontFamily = fonte_senado, fontSize = 12),
    title = list(
      text = titulo,
      subtext = subtitulo,
      left = "center",
      top = 4,
      textStyle = list(fontSize = 14),
      subtextStyle = list(fontSize = 12)
    ),
    grid = list(
      top = if (legenda == "top") {
        70
      } else if (!is.null(titulo) || !is.null(subtitulo)) {
        52
      } else if (!is.null(nome_y)) {
        34
      } else {
        20
      },
      bottom = if (legenda == "bottom") 48 else 30,
      left = 14,
      right = 18,
      containLabel = TRUE
    ),
    legend = c(
      list(
        show = legenda != "none" && length(grupos) > 1,
        type = "scroll"
      ),
      if (legenda == "top") list(top = 36) else list(),
      if (legenda == "bottom") list(bottom = 0) else list()
    ),
    tooltip = list(
      trigger = "axis",
      valueFormatter = numero_ptbr
    ),
    xAxis = list(
      type = if (temporal) "time" else "value",
      scale = TRUE,
      name = nome_x,
      nameLocation = "middle",
      nameGap = 28,
      axisLabel = if (temporal) {
        list(formatter = rotulo_ano)
      } else {
        list(formatter = numero_ptbr)
      },
      axisLine = list(show = TRUE),
      axisTick = list(show = FALSE),
      splitLine = list(show = FALSE)
    ),
    yAxis = list(
      type = "value",
      min = 0,
      name = nome_y,
      axisLabel = list(formatter = numero_ptbr),
      axisTick = list(show = FALSE),
      splitLine = list(show = TRUE)
    ),
    series = series
  ), altura)
}

# Mapa de calor com escala de cores em log1p(n).
grafico_heatmap <- function(
    dados,
    eixo_x,
    eixo_y,
    valores,
    titulo = NULL,
    nome_x = NULL,
    nome_y = NULL,
    altura = "100%",
    tamanho_fonte = 12
) {
  dados <- dados |>
    dplyr::transmute(
      .x = as.character({{ eixo_x }}),
      .y = as.character({{ eixo_y }}),
      .n = as.numeric({{ valores }})
    ) |>
    dplyr::filter(!is.na(.x), !is.na(.y), !is.na(.n))

  xs <- sort(unique(dados$.x))
  ys <- sort(unique(dados$.y))

  pontos <- lapply(seq_len(nrow(dados)), function(i) {
    list(
      match(dados$.x[i], xs) - 1,
      match(dados$.y[i], ys) - 1,
      dados$.n[i],
      log1p(dados$.n[i])
    )
  })

  fmt_tooltip <- sprintf(
    paste0(
      "function(p){var x=%s[p.value[0]],y=%s[p.value[1]];",
      "return x+' × '+y+'<br>Frequência: '+Number(p.value[2]).toLocaleString('pt-BR');}"
    ),
    jsonlite::toJSON(xs),
    jsonlite::toJSON(ys)
  )

  widget_echarts(list(
    textStyle = list(fontFamily = fonte_senado, fontSize = tamanho_fonte),
    title = list(
      text = titulo,
      left = "center",
      top = 4,
      textStyle = list(fontSize = tamanho_fonte + 2)
    ),
    grid = list(
      left = 14,
      right = 26,
      top = 34,
      bottom = 92,
      containLabel = TRUE
    ),
    xAxis = list(
      type = "category",
      data = as.list(xs),
      name = nome_x,
      nameTextStyle = list(fontSize = tamanho_fonte),
      nameLocation = "middle",
      nameGap = 66,
      axisLabel = list(rotate = 40, interval = 0, fontSize = tamanho_fonte),
      axisTick = list(show = FALSE)
    ),
    yAxis = list(
      type = "category",
      data = as.list(ys),
      name = nome_y,
      nameTextStyle = list(fontSize = tamanho_fonte),
      axisLabel = list(fontSize = tamanho_fonte),
      axisTick = list(show = FALSE)
    ),
    tooltip = list(formatter = htmlwidgets::JS(fmt_tooltip)),
    visualMap = list(
      textStyle = list(fontSize = tamanho_fonte),
      min = 0,
      max = max(log1p(dados$.n)),
      dimension = 3,
      calculable = FALSE,
      orient = "horizontal",
      left = "center",
      bottom = 6,
      text = list("Frequência", ""),
      formatter = htmlwidgets::JS(
        "function(v){return Math.round(Math.expm1(v)).toLocaleString('pt-BR');}"
      ),
      inRange = list(color = as.list(viridisLite::viridis(256)))
    ),
    series = list(list(
      type = "heatmap",
      name = "Frequência",
      data = pontos,
      itemStyle = list(borderColor = "white", borderWidth = 1.5),
      label = list(
        show = TRUE,
        fontSize = tamanho_fonte - 1,
        color = "#333333",
        formatter = htmlwidgets::JS(
          "function(p){return Number(p.value[2]).toLocaleString('pt-BR');}"
        )
      )
    ))
  ), altura)
}

# Vários gráficos htmlwidgets em uma grade que ocupa todo o contêiner.
grade_paineis <- function(paineis, colunas = 2, gap = 12) {
  colunas <- max(1L, as.integer(colunas))
  linhas <- ceiling(length(paineis) / colunas)
  celulas <- lapply(paineis, function(p) {
    htmltools::div(class = "grade-paineis__celula", p)
  })
  htmltools::browsable(
    do.call(
      htmltools::div,
      c(
        list(
          class = "grade-paineis",
          style = paste0(
            "width:100%;height:100%;max-width:100%;min-width:0;min-height:0;",
            "overflow:hidden;box-sizing:border-box;display:grid;",
            "grid-template-columns:repeat(", colunas, ",minmax(0,1fr));",
            "grid-template-rows:repeat(", linhas, ",minmax(0,1fr));",
            "gap:", gap, "px;"
          )
        ),
        list(htmltools::tags$style(htmltools::HTML(
          paste0(
            ".grade-paineis__celula{position:relative;min-width:0;min-height:0;",
            "width:100%;height:100%;max-width:100%;max-height:100%;",
            "overflow:hidden;box-sizing:border-box;}",
            ".grade-paineis__celula>.html-widget{position:absolute!important;inset:0;",
            "width:100%!important;height:100%!important;}",
            "@media(max-width:768px){",
            ".grade-paineis{grid-template-columns:minmax(0,1fr)!important;}}"
          )
        ))),
        celulas
      )
    )
  )
}

# Facetas de linhas (um painel por categoria) ocupando todo o contêiner,
# com legenda única compartilhada entre os painéis.
grafico_linhas_facetas <- function(
    dados,
    eixo_x,
    eixo_y,
    grupo,
    facet,
    colunas = 2,
    titulo = NULL,
    nome_eixo_x = NULL,
    nome_eixo_y = NULL,
    escala_y_livre = FALSE,
    facetas_y_sem_zero = NULL
) {
  if (length(colunas) != 1 || !is.numeric(colunas) ||
      is.na(colunas) || colunas < 1) {
    stop("`colunas` deve ser um número inteiro maior ou igual a 1.")
  }
  colunas <- as.integer(colunas)

  dados <- dados |>
    transmute(
      .eixo_x = {{ eixo_x }},
      .eixo_y = as.numeric({{ eixo_y }}),
      .grupo = as.character({{ grupo }}),
      .facet = as.character({{ facet }})
    ) |>
    filter(
      !is.na(.eixo_x),
      !is.na(.eixo_y),
      !is.na(.grupo),
      !is.na(.facet)
    ) |>
    summarise(
      .eixo_y = sum(.eixo_y, na.rm = TRUE),
      .by = c(.eixo_x, .grupo, .facet)
    )

  if (nrow(dados) == 0) {
    stop("Não há dados válidos para gerar os gráficos.")
  }

  grupos <- sort(unique(dados$.grupo))
  facetas <- dados |>
    summarise(
      .total_facet = sum(.eixo_y, na.rm = TRUE),
      .by = .facet
    ) |>
    arrange(desc(.total_facet), .facet) |>
    pull(.facet)

  if (!is.null(facetas_y_sem_zero) && !is.character(facetas_y_sem_zero)) {
    stop("`facetas_y_sem_zero` deve ser um vetor de nomes de facetas.")
  }

  dados <- dados |>
    mutate(.grupo = factor(.grupo, levels = grupos)) |>
    arrange(.facet, .grupo, .eixo_x)

  limite_y <- if (escala_y_livre) NULL else max(dados$.eixo_y, na.rm = TRUE)

  graficos <- lapply(facetas, function(valor_facet) {
    dados_facet <- dados |>
      filter(.facet == valor_facet)

    remover_zero_eixo_y <- valor_facet %in% facetas_y_sem_zero

    grafico <- dados_facet |>
      group_by(.grupo) |>
      e_charts(.eixo_x) |>
      e_line(.eixo_y, symbol = "none") |>
      e_color(unname(paleta), background = cor_fundo) |>
      e_text_style(fontFamily = fonte_senado, color = "#333333") |>
      e_tooltip(trigger = "axis") |>
      e_legend(show = FALSE) |>
      e_title(
        text = stringr::str_wrap(valor_facet, width = 42),
        left = "center",
        textStyle = list(fontSize = 13, lineHeight = 16)
      ) |>
      e_x_axis(
        name = nome_eixo_x,
        nameLocation = "middle",
        nameGap = 22,
        axisTick = list(show = FALSE),
        splitLine = list(show = FALSE)
      ) |>
      e_grid(
        left = "8%",
        right = "4%",
        top = 40,
        bottom = 20,
        containLabel = TRUE
      )

    if (is.null(limite_y)) {
      grafico |>
        e_y_axis(
          name = nome_eixo_y,
          scale = remover_zero_eixo_y,
          min = if (remover_zero_eixo_y) NULL else 0,
          axisTick = list(show = FALSE),
          splitLine = list(show = TRUE)
        )
    } else {
      grafico |>
        e_y_axis(
          name = nome_eixo_y,
          min = 0,
          max = limite_y,
          axisTick = list(show = FALSE),
          splitLine = list(show = TRUE)
        )
    }
  })

  paineis <- lapply(graficos, function(grafico) {
    htmltools::div(
      class = "grafico-linhas-facetas__painel",
      grafico
    )
  })

  legenda <- htmltools::div(
    class = "grafico-linhas-facetas__legenda",
    lapply(seq_along(grupos), function(i) {
      htmltools::tags$span(
        class = "grafico-linhas-facetas__legenda-item",
        htmltools::tags$span(
          class = "grafico-linhas-facetas__legenda-cor",
          style = paste0(
            "background:",
            unname(paleta[(i - 1) %% length(paleta) + 1])
          )
        ),
        grupos[i]
      )
    })
  )

  htmltools::browsable(
    htmltools::div(
      class = "grafico-linhas-facetas",
      style = paste0(
        "width:100%;height:100%;max-width:100%;min-width:0;min-height:0;",
        "overflow:hidden;box-sizing:border-box;",
        "display:grid;grid-template-rows:auto minmax(0,1fr) auto;"
      ),
      htmltools::tags$style(htmltools::HTML(
        paste0(
          ".grafico-linhas-facetas__painel{",
          "position:relative;min-width:0;min-height:0;",
          "width:100%;height:100%;max-width:100%;max-height:100%;",
          "overflow:hidden;box-sizing:border-box;}",
          ".grafico-linhas-facetas__painel>.html-widget{",
          "position:absolute!important;inset:0;",
          "width:100%!important;height:100%!important;",
          "max-width:100%!important;max-height:100%!important;}",
          ".grafico-linhas-facetas__legenda{",
          "text-align:center;font-size:12px;color:#333333;",
          "font-family:", fonte_senado, ";padding-top:2px;}",
          ".grafico-linhas-facetas__legenda-item{display:inline-flex;align-items:center;margin:0 10px;}",
          ".grafico-linhas-facetas__legenda-cor{",
          "display:inline-block;width:10px;height:10px;border-radius:50%;",
          "margin-right:6px;}",
          "@media(max-width:768px){",
          ".grafico-linhas-facetas__grade{",
          "grid-template-columns:minmax(0,1fr)!important;}}"
        )
      )),
      if (!is.null(titulo)) htmltools::tags$h3(titulo),
      do.call(
        htmltools::div,
        c(
          list(
            class = "grafico-linhas-facetas__grade",
            style = paste0(
              "width:100%;height:100%;max-width:100%;min-width:0;min-height:0;",
              "display:grid;box-sizing:border-box;overflow:hidden;",
              "grid-template-columns:repeat(", colunas, ",minmax(0,1fr));",
              "grid-auto-rows:minmax(0,1fr);gap:12px;"
            )
          ),
          paineis
        )
      ),
      legenda
    )
  )
}


# Taxas municipais: mapa e rankings -----------------------------------------
carregar_malha_conselhos <- function(raiz = ".") {
  arquivos <- file.path(raiz, c("assets/municipios_2022.geojson",
                               "assets/municipios_2022_dados.rds"))
  fontes <- file.path(raiz, c("preparar_malha_conselhos.R",
                             "conselhos_tutelares/mun_geo_2022.rds"))
  # Mudanças de cores, legendas ou JavaScript não invalidam a geometria.
  if (any(!file.exists(arquivos)) ||
      any(file.info(arquivos)$mtime < max(file.info(fontes)$mtime, na.rm = TRUE))) {
    source(fontes[1], local = new.env(), chdir = TRUE)
  }
  list(dados = readRDS(arquivos[2]),
       geojson = jsonlite::read_json(arquivos[1], simplifyVector = FALSE))
}

adicionar_elementos_cartograficos <- function(mapa, arquivo = "assets/elementos-cartograficos.js") {
  htmlwidgets::onRender(mapa, paste(
    readLines(arquivo, warn = FALSE),
    collapse = "\n"
  ))
}

grafico_taxa_municipal <- function(dados, geojson, titulo, populacao_minima = 0) {
  x <- dados$taxa_100mil
  incluidos <- !is.na(dados$pop_total) & dados$pop_total > populacao_minima
  corte <- format(populacao_minima, big.mark = ".", decimal.mark = ",",
                  scientific = FALSE, trim = TRUE)
  recorte <- paste0("Municípios com mais de ", corte, " habitantes (população total).")
  limites <- unique(quantile(x[incluidos & is.finite(x) & x > 0],
                             seq(0, 1, 0.2), names = FALSE))
  if (length(limites) >= 2) {
    faixa <- as.integer(cut(x, limites, include.lowest = TRUE))
    formato <- function(v) formatC(v, format = "f", digits = 1, decimal.mark = ",")
    rotulos <- vapply(seq_len(length(limites) - 1), function(i) {
      if (i == 1) paste0("Até ", formato(limites[i + 1])) else
        paste0("> ", formato(limites[i]), " a ", formato(limites[i + 1]))
    }, character(1))
  } else {
    faixa <- ifelse(x > 0, 1L, NA_integer_)
    rotulos <- if (any(x[incluidos] > 0, na.rm = TRUE)) "Taxa positiva" else character()
  }
  faixa[x == 0] <- 0L
  faixa[is.na(x)] <- -1L
  faixa[!incluidos] <- -2L
  cores <- grDevices::colorRampPalette(c("#d6e8f5", "#005b9e"))(max(1, length(rotulos)))
  pedacos <- c(
    list(list(value = -2, label = "Fora do recorte populacional", color = "#f7f8fa")),
    list(list(value = 0, label = "0 registros", color = "#e9edf0")),
    lapply(seq_along(rotulos), function(i) {
      list(value = i, label = rotulos[i], color = cores[i])
    }),
    list(list(value = -1, label = "Sem dados", color = "#8b949c"))
  )
  valores <- lapply(seq_len(nrow(dados)), function(i) list(
    name = dados$mun[i], value = faixa[i],
    municipio = paste0(dados$nome_municipio[i], " / ", dados$uf[i]),
    registros = dados$n[i], populacao = dados$pop_crianca_adolescente[i],
    populacao_total = dados$pop_total[i], fora_recorte = !incluidos[i],
    taxa = if (incluidos[i]) dados$taxa_100mil[i] else NULL
  ))
  periodo <- paste(format(min(dados$inicio), "%m/%Y"),
                   format(max(dados$fim), "%m/%Y"), sep = " a ")
  widget_echarts(list(
    textStyle = list(fontFamily = fonte_senado, fontSize = 12),
    title = list(text = titulo,
      subtext = paste0(periodo, " · por 100 mil residentes de 0 a 17 anos\n", recorte),
      left = 12, top = 8, textStyle = list(fontSize = 15),
      subtextStyle = list(fontSize = 11)),
    tooltip = list(trigger = "item", formatter = htmlwidgets::JS(
      "function(p){var d=p.data;if(!d)return 'Sem dados';var cab='<b>'+d.municipio+'</b><br>População total: '+Number(d.populacao_total).toLocaleString('pt-BR');if(d.fora_recorte)return cab+'<br>Fora do recorte populacional';if(d.taxa==null)return cab+'<br>Sem dados';return cab+'<br>Registros: '+Number(d.registros).toLocaleString('pt-BR')+'<br>População de 0 a 17 anos: '+Number(d.populacao).toLocaleString('pt-BR')+'<br>Taxa por 100 mil: '+Number(d.taxa).toLocaleString('pt-BR',{maximumFractionDigits:1});}"
    )),
    visualMap = list(type = "piecewise", pieces = pedacos, left = 12, bottom = 38,
      itemWidth = 14, itemHeight = 10, itemGap = 5, textStyle = list(fontSize = 10)),
    graphic = list(list(type = "text", left = 12, bottom = 8, style = list(
      text = paste0("SIA/SIH · População MS/Ripsa ", unique(dados$ano_populacao),
                    " · Malha IBGE 2025. Valores positivos em quintis."),
      fontSize = 9, fill = "#66727d"))),
    series = list(list(type = "map", map = "municipios_taxas", roam = TRUE,
      layoutCenter = list("58%", "53%"), layoutSize = "88%", aspectScale = 1,
      scaleLimit = list(min = 0.8, max = 12),
      itemStyle = list(borderWidth = 0.15, borderColor = "#ffffff"),
      label = list(show = FALSE),
      emphasis = list(label = list(show = FALSE),
                      itemStyle = list(borderColor = "#00305c", borderWidth = 1)),
      data = valores))
  )) |>
    echarts4r::e_map_register("municipios_taxas", geojson) |>
    adicionar_elementos_cartograficos()
}

ranking_taxa_municipal <- function(dados, maiores = TRUE, populacao_minima = 0) {
  recorte <- paste0("Municípios com mais de ",
                     format(populacao_minima, big.mark = ".", decimal.mark = ",",
                            scientific = FALSE, trim = TRUE),
                     " habitantes (população total estimada de ",
                     unique(dados$ano_populacao), ").")
  dados <- dados |> dplyr::filter(pop_total > populacao_minima, is.finite(taxa_100mil))
  dados <- if (maiores) {
    dados |> dplyr::arrange(dplyr::desc(taxa_100mil), nome_municipio, uf)
  } else {
    dados |> dplyr::arrange(taxa_100mil, nome_municipio, uf)
  }
  dados |>
    dplyr::slice_head(n = 20) |>
    dplyr::transmute(cidade = paste0(nome_municipio, " / ", uf),
                     populacao_total = pop_total,
                     populacao = pop_crianca_adolescente, n, taxa_100mil) |>
    gt::gt() |>
    gt::cols_label(cidade = "Município / UF", populacao_total = "Pop. total",
                   populacao = "Pop. 0–17",
                   n = "Registros", taxa_100mil = "Taxa¹") |>
    gt::fmt_number(columns = c(populacao_total, populacao, n), decimals = 0,
                    sep_mark = ".", dec_mark = ",") |>
    gt::fmt_number(columns = taxa_100mil, decimals = 1, sep_mark = ".", dec_mark = ",") |>
    gt::cols_align(align = "left", columns = cidade) |>
    gt::cols_align(align = "right", columns = c(populacao_total, populacao, n, taxa_100mil)) |>
    gt::cols_width(cidade ~ gt::pct(36), populacao_total ~ gt::pct(19),
                   populacao ~ gt::pct(19), n ~ gt::pct(13), taxa_100mil ~ gt::pct(13)) |>
    gt::tab_source_note(recorte) |>
    gt::tab_source_note("¹ Por 100 mil residentes de 0 a 17 anos. Empates por nome.") |>
    gt::tab_style(style = gt::cell_text(color = "#00305c"),
                  locations = gt::cells_column_labels()) |>
    gt::tab_options(
      table.width = gt::pct(100), table.font.size = gt::px(12),
      table.font.names = c("Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif"),
      table.background.color = "#ffffff", table.font.color = "#333333",
      table.border.top.style = "none", table.border.bottom.style = "none",
      column_labels.background.color = "#eef3f7",
      column_labels.font.weight = "600",
      column_labels.border.top.style = "none",
      column_labels.border.bottom.color = "#d8e1e8",
      table_body.hlines.color = "#edf0f3",
      data_row.padding = gt::px(4), source_notes.font.size = gt::px(10),
      source_notes.padding = gt::px(4)
    )
}
