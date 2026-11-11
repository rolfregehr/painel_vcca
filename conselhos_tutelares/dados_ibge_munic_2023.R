library(tidyverse)
library(readxl)

url <- paste0(
  "https://ftp.ibge.gov.br/Perfil_Municipios/2023/",
  "Base_de_Dados/Base_MUNIC_2023.xlsx"
)

arquivo <- "conselhos_tutelares/Base_MUNIC_2023.xlsx"

download.file(
  url,
  destfile = arquivo,
  mode = "wb"
)

excel_sheets(arquivo)


library(tidyverse)
library(readxl)

dic <- read_excel(
  arquivo,
  sheet = "Dicionário"
)

glimpse(dic)
names(dic)


library(tidyverse)
library(readxl)

dh_raw <- read_excel(
  arquivo,
  sheet = "Direitos Humanos",
  col_names = TRUE
)

achou <- dh_raw |>
  mutate(linha = row_number()) |>
  pivot_longer(
    -linha,
    names_to = "coluna",
    values_to = "valor"
  ) |>
  mutate(
    coluna_num = parse_number(coluna)
  ) |>
  filter(
    str_detect(
      str_to_lower(as.character(valor)),
      "tutelar"
    )
  )

achou


dh_raw$MDHU61
unique(dh_raw$MDHU61)


conselhos_tut <- dic[1256:1259,]


dic$variável[which(str_detect(dic$variável, 'MDHU61'))]



table(dh_raw$MDHU604)
table(dh_raw$MDHU61)

dh_raw$MDHU611a
dh_raw$MDHU611b
dh_raw$MDHU612[which(dh_raw$MDHU612>'1')]


table(dh_raw$MDHU612)
