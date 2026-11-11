# Levantamento de dados do painel de violência

Análise de `index.qmd`, realizada em 10/11/2026.

O painel exige **cinco tabelas de dados e uma base geográfica**. Este documento descreve as colunas necessárias para atender ao código atual, os dados públicos que podem ser obtidos e as regras de preparação que ainda precisam ser definidas.

As bases e os scripts auxiliares referenciados não estavam presentes no projeto no momento da análise. Assim, as estruturas mínimas abaixo foram deduzidas dos acessos às colunas no `index.qmd`; elas não constituem uma inspeção dos arquivos originais. Nenhuma base foi baixada nesta etapa.

## 1. Tabelas que precisam ser criadas

### 1.1. Atendimentos ambulatoriais — SIA/SUS

- **Arquivo:** `tabelas/viol_sexual_ca_sia_pa.rda`.
- **Objeto dentro do arquivo:** `viol_sexual_ca_sia_pa`.
- **Uso:** indicadores iniciais e gráficos por idade, sexo, raça/cor e competência.
- **Unidade da linha:** combinação de competência, sexo, idade e raça/cor, após selecionar os registros pertinentes ao recorte do painel.

| Coluna obrigatória | Tipo recomendado no R | Conteúdo esperado |
| --- | --- | --- |
| `competencia` | `Date` | Primeiro dia do mês da produção ambulatorial |
| `genero` | `character` | O código espera `F` e `M` |
| `idade` | `integer` | Idade em anos completos |
| `raca_cor` | `character` | Código com dois caracteres, antes da conversão para rótulos |
| `n` | Numérico inteiro | Quantidade correspondente à combinação das demais colunas |

Não é necessário armazenar totais, percentuais, categoria mais frequente ou idade mais frequente: esses resultados são calculados pelo painel.

#### Campos de origem e preparação

Os campos de interesse no SIA/PA incluem:

| Campo de origem | Uso na preparação |
| --- | --- |
| `PA_CMP` | Competência da produção |
| `PA_PROC_ID` | Seleção dos procedimentos |
| `PA_IDADE` | Idade |
| `PA_SEXO` | Sexo |
| `PA_RACACOR` | Raça/cor |
| `PA_QTDAPR` | Quantidade aprovada, caso essa seja a medida adotada |

Recomenda-se preservar também os diagnósticos e códigos territoriais disponíveis na extração para permitir auditoria do recorte. A presença e o significado dos campos devem ser conferidos no leiaute de cada período.

#### Regras identificadas e pendências

1. O painel filtra `competencia >= 2015-01-01`.
2. O nome do arquivo sugere crianças e adolescentes, mas o código não aplica filtro etário nessa tabela. Esse recorte precisa ser definido e aplicado na preparação.
3. O documento não informa quais procedimentos ou diagnósticos caracterizam violência sexual.
4. O documento não informa se `n` corresponde à contagem de linhas ou à soma de `PA_QTDAPR`. Essas medidas podem produzir resultados diferentes.
5. A categoria ignorada de sexo precisa de tratamento explícito: o cálculo percentual atual pressupõe as colunas `F` e `M` e usa apenas essas duas no denominador.
6. O rótulo do cartão de raça/cor está fixado em “pessoas pardas”, embora o código selecione a categoria de maior frequência. O rótulo deve acompanhar a categoria efetivamente selecionada.
7. A correspondência entre códigos e rótulos de raça/cor usada no documento deve ser validada com o dicionário do SIA antes da geração da tabela.

**Referência:** [Guia do Ministério da Saúde — atributos selecionados do SIA/PA](https://bvsms.saude.gov.br/bvs/publicacoes/avaliacao_impacto_politicas_saude_guia_sus.pdf).

### 1.2. Atendimentos hospitalares — SIH/SUS

- **Arquivo esperado pelo código:** `sih/sih_viol_sexual`, sem extensão.
- **Objeto dentro do arquivo:** `sih_viol_sexual`.
- **Formato de gravação:** compatível com `load()`, por exemplo, um arquivo criado por `save()`.
- **Uso:** séries trimestrais e distribuições por idade e sexo.
- **Unidade da linha:** registro hospitalar selecionado na preparação.

| Coluna obrigatória | Tipo recomendado | Conteúdo esperado |
| --- | --- | --- |
| `MUNIC_RES` | `character` | Código do município de residência |
| `DT_INTER` | `character`, no formato `AAAAMMDD` | Data da internação |
| `SEXO` | `character` | O código converte `1` para masculino e `3` para feminino |
| `NASC` | `character`, no formato `AAAAMMDD` | Data de nascimento |

O painel deriva as seguintes colunas, que não precisam ser previamente gravadas:

| Coluna derivada | Transformação |
| --- | --- |
| `cod_mun` | Cópia de `MUNIC_RES` |
| `data` | Data da internação, convertida para o início do trimestre |
| `genero` | `Masc`, `Fem` ou `NI` |
| `idade` | Anos completos entre nascimento e internação |
| `ciclo_vida` | Classificação da vítima por idade |

#### Regras identificadas e pendências

1. O filtro que identifica violência sexual não está no documento.
2. Os gráficos usam `count()`: cada linha da tabela conta como uma unidade. É necessário definir o tratamento de repetições e registros de continuidade antes de chamar o resultado de número de internações.
3. Recomenda-se preservar número da AIH, diagnósticos e campos de identificação do tipo de registro disponíveis na origem.
4. A classificação atual coloca pessoas de 12 anos em `Criança`, pois usa `idade <= 12`. Para uma classificação de criança até 11 anos e adolescente de 12 a 17, o código precisa ser alterado.
5. Idades ausentes e inválidas precisam de tratamento explícito antes da classificação.
6. O trimestre mais recente é sempre excluído pelo código, independentemente de estar completo. A regra deveria se basear na disponibilidade efetiva dos dados.
7. As datas de disponibilização/competência do SIH e a data de internação não devem ser tratadas como conceitos equivalentes na coleta da série.

### 1.3. Notificações de violência — Sinan

- **Arquivo:** `tabelas/dados_001.rda`.
- **Objeto dentro do arquivo:** `dados_001`.
- **Uso:** Motivos, Agressores, Agressores × Vítimas, cruzamentos e comparação com processos judiciais.
- **Unidade da linha para a tabela agregada:** combinação das dimensões abaixo, acompanhada da frequência `n`.

| Coluna obrigatória | Tipo recomendado | Conteúdo |
| --- | --- | --- |
| `data_notific` | `Date` | Data da notificação; preservar precisão diária para permitir agregação mensal |
| `SG_UF_OCOR` | Inteiro ou texto padronizado | Código IBGE da UF de ocorrência, compatível com o cadastro de UFs do painel |
| `ciclo_vida` | `character` | Ciclo de vida da vítima; o código usa os rótulos `Criança` e `Adolescente` |
| `motivo_violencia` | `character` | Categoria da motivação ou classificação escolhida |
| `autor` | `character` | Categoria do provável autor ou vínculo com a vítima |
| `ciclo_vida_autor` | `character` | Ciclo de vida do provável autor |
| `genero_autor` | `character` | Categoria do sexo/gênero do provável autor |
| `genero_vitima` | `character` | Categoria do sexo/gênero da vítima |
| `n` | Numérico inteiro | Frequência da combinação |

Para manter disponíveis todos os cruzamentos atuais, a agregação deve considerar todas essas dimensões, exceto `n`.

#### Correspondências e conceitos a confirmar

O Sinan possui campos para data de notificação, idade e sexo da vítima, UF de ocorrência, motivação, tipos de violência, vínculos com o provável autor e características do autor. A correspondência exata deve ser validada no dicionário da versão efetivamente baixada.

- `motivo_violencia` é ambíguo: o código não mostra se representa **motivação**, como racismo e conflito geracional, ou **tipo de violência**, como física, sexual e negligência. São conceitos distintos na ficha.
- `autor` parece representar vínculo com a vítima, mas a transformação não está disponível no projeto.
- Os limites dos ciclos de vida da vítima e do autor precisam ser documentados separadamente.
- Os nomes `genero_autor` e `genero_vitima` devem refletir corretamente o campo de origem; sexo registrado e identidade de gênero não devem ser confundidos.
- A idade codificada do Sinan precisa ser decodificada conforme sua unidade: não basta interpretar todos os valores como anos.

#### Prevenção de contagem duplicada

Uma notificação pode registrar múltiplos vínculos ou tipos de violência. Ao desdobrar esses campos em várias linhas, a soma de `n` pode passar a contar a mesma notificação mais de uma vez.

Estrutura recomendada para a preparação:

1. **Base principal:** uma linha por notificação, com chave técnica e os atributos únicos do registro.
2. **Tabela auxiliar de vínculos:** uma linha por notificação e vínculo selecionado.
3. **Tabela auxiliar de tipos de violência:** uma linha por notificação e tipo selecionado, se necessária.
4. **Agregações de apresentação:** geradas dessas bases com unidade de contagem explícita.

As tabelas auxiliares são uma recomendação de modelagem; não são arquivos exigidos diretamente pelo `index.qmd` atual. O número da notificação isolado não deve ser presumido como chave nacional única sem verificar as regras de identificação da fonte e a disponibilidade dos campos na versão pública.

#### Recorte na comparação com a Justiça

O código compara processos com toda a `dados_001`, sem filtro etário nessa etapa. Se o objetivo for comparar apenas notificações de crianças e adolescentes, esse filtro precisa ser incorporado. As outras abas filtram esses grupos em vários gráficos, mas isso não restringe automaticamente a tabela inteira.

**Referência:** [Dicionário oficial de violência do Sinan](https://portalsinan.saude.gov.br/images/documentos/Agravos/via/DIC_DADOS_NET_Violencias_v5.pdf). O dicionário descreve o sistema de origem; a versão pública pode disponibilizar apenas um subconjunto dos campos.

### 1.4. Processos judiciais — CNJ/DataJud

- **Arquivo:** `justica/processos_df.rda`.
- **Objeto dentro do arquivo:** `processos_df`.
- **Uso:** séries mensais de processos para Brasil e UFs e ranking de assuntos.
- **Unidade da linha recomendada:** processo consolidado, após tratar repetições entre registros e instâncias.

| Coluna obrigatória | Tipo recomendado | Conteúdo esperado |
| --- | --- | --- |
| `numero_processo` | `character` | Número do processo, preservando zeros à esquerda |
| `data_ajuizamento` | `character` | O código atual espera os primeiros oito caracteres em `AAAAMMDD` |
| `uf` | `character` | Sigla da UF |
| `assunto_nome` | `character` | Nomes dos assuntos separados por ponto e vírgula (`;`) |

O painel conta processos distintos por mês e repete o cálculo por UF. Para o ranking, separa os assuntos e conta processos distintos por assunto.

#### Campos adicionais recomendados na preparação

| Campo | Finalidade |
| --- | --- |
| Identificador do registro no DataJud | Rastreabilidade e tratamento de duplicações |
| Tribunal | Identificar a origem e apoiar a classificação territorial |
| Grau | Tratar múltiplos registros do mesmo processo |
| Classe e código da classe | Definir e auditar o recorte temático |
| Códigos dos assuntos | Filtrar por identificadores estáveis e guardar os rótulos |
| Município do órgão julgador | Apoiar a atribuição territorial |
| Data de atualização | Controlar a atualização da coleta |

#### Regras identificadas e pendências

1. O título “Assuntos mais frequentes — ECA” não aplica filtro temático. O recorte precisa ocorrer na coleta ou preparação.
2. A API não apresenta no glossário uma coluna simples `uf` equivalente à usada pelo painel. É necessário definir se ela representa UF do tribunal, do órgão julgador ou outra referência.
3. A data da API pode vir em formato ISO, como `2024-03-15T...`. O código atual extrai oito caracteres e não interpreta corretamente esse formato. É necessário padronizar a saída ou alterar a leitura.
4. A chave do registro do DataJud pode incluir tribunal, classe, grau e órgão julgador. Não se deve pressupor que cada resultado da API corresponde a um processo novo.
5. A contagem por assunto não é aditiva: um processo pode aparecer em vários assuntos.
6. Processos e notificações têm unidades e datas diferentes. O gráfico compara séries agregadas, sem demonstrar correspondência individual entre elas.

**Referências:** [Glossário de dados do DataJud](https://datajud-wiki.cnj.jus.br/api-publica/glossario/) e [Acesso à API pública](https://datajud-wiki.cnj.jus.br/api-publica/acesso/).

### 1.5. Conselhos tutelares — MUNIC/IBGE

- **Arquivo:** `conselhos_tutelares/cons_tut.rda`.
- **Objeto dentro do arquivo:** `cons_tut`.
- **Uso:** mapa municipal e lista de municípios sem conselho tutelar.
- **Unidade da linha:** município, para a edição de referência 2023.

| Coluna obrigatória | Tipo recomendado | Conteúdo |
| --- | --- | --- |
| `mun` | `character` | Código municipal IBGE de sete dígitos, compatível com a malha |
| `uf` | `character` | Sigla da UF |
| `nome_municipio` | `character` | Nome do município |
| `num_ct` | Inteiro | Número de conselhos tutelares |
| `ct_por_pop_crianca_adolescente` | Numérico | Número de conselhos por 100 mil crianças e adolescentes |

Colunas adicionais recomendadas para tornar o indicador reproduzível:

| Coluna | Finalidade |
| --- | --- |
| `ano_munic` | Ano do numerador: 2023 |
| `ano_populacao` | Ano do denominador: 2022 |
| `pop_crianca_adolescente` | População usada no cálculo |
| `situacao_informacao_ct` | Distinguir quantidade conhecida, ausência de conselho e falta de informação |

Fórmula indicada no mapa:

```text
ct_por_pop_crianca_adolescente =
    100000 × num_ct / pop_crianca_adolescente
```

#### Regras identificadas e pendências

1. O mapa informa MUNIC 2023 e Censo 2022. O indicador combina numerador e denominador de anos diferentes; isso deve ser registrado nos metadados.
2. O denominador deve ter um recorte etário explícito. Para a população de 0 a 17 anos, somar apenas categorias sem sobreposição.
3. Valores ausentes de `num_ct` não devem ser convertidos automaticamente em zero.
4. A lista lateral filtra somente `num_ct == 0`. Apesar de seu título mencionar “não informado”, registros com `NA` não entram na lista.
5. Selecionar a variável de **conselho tutelar**, distinguindo-a de conselho municipal dos direitos da criança e do adolescente.
6. Municípios e territórios especiais devem ser compatibilizados entre MUNIC, população e malha, com conferência de registros sem correspondência.

**Referência:** [MUNIC 2023 — IBGE](https://www.ibge.gov.br/estatisticas/sociais/protecao-social/2110-np-pesquisa-de-informacoes-basicas-municipais/10586-pesquisa-de-informacoes-basicas-municipais.html?edicao=41644).

### 1.6. Base geográfica municipal

- **Arquivo:** `conselhos_tutelares/mun_geo_2022.rds`.
- **Objeto:** base municipal `sf`, lida por `readRDS()`.
- **Uso:** geometria e identificação dos municípios no mapa.
- **Unidade da linha:** município ou unidade territorial representada na malha.

| Coluna necessária | Conteúdo |
| --- | --- |
| `code_muni` | Código municipal IBGE |
| `name_muni` | Nome do município |
| `geometry` | Geometria municipal, preservada no objeto `sf` |

O próprio documento já baixa essa base se o arquivo não existir:

```r
geobr::read_municipality(
  code_muni = "all",
  year = 2022,
  simplified = TRUE
)
```

**Referência:** [Documentação do geobr/Ipea](https://github.com/ipea/geobr/blob/master/README.md).

## 2. O que pode ser baixado

| Fonte | Dados a obter | Organização da coleta | Preparação posterior |
| --- | --- | --- | --- |
| SIA/SUS — PA | Produção ambulatorial e documentação | UF e competência mensal | Seleção de procedimentos/diagnósticos, recorte etário e agregação |
| SIH/SUS — RD | Registros hospitalares e documentação | UF e competência de disponibilização | Seleção de violência sexual, tratamento dos registros e datas |
| Sinan — violência | Microdados públicos anonimizados e dicionários | Ano e abrangência disponível | Recodificações, ciclos de vida, múltiplas respostas e contagens |
| CNJ/DataJud | Metadados de processos públicos | API por tribunal, com paginação | Filtro temático, consolidação, definição de UF e assuntos |
| IBGE/MUNIC 2023 | Base municipal e documentação da edição | Arquivos da edição 2023 | Seleção da variável de quantidade de conselhos tutelares |
| IBGE/Censo 2022 | População municipal por idade | Municípios e idades selecionadas | Soma da população de crianças e adolescentes |
| Malha municipal 2022 | Geometrias e identificação municipal | Brasil, via `geobr` | Gravação do `.rds` e compatibilização dos códigos |

### 2.1. DATASUS: SIA e SIH

**Ponto de entrada:** [Transferência de Arquivos do DATASUS](https://datasus.saude.gov.br/transferencia-de-arquivos/).

Os arquivos de disseminação são usualmente trabalhados a partir de DBC/DBF. É necessário conferir a família de arquivo, os períodos disponíveis e o leiaute aplicável antes da extração.

Para o SIA, o documento exige dados a partir de janeiro de 2015. Para o SIH, não existe início explícito de série no código. O período de coleta hospitalar precisa ser escolhido e documentado.

O arquivo original baixado não corresponde à tabela final do painel: os filtros e agregações devem ser executados antes da gravação dos objetos esperados.

### 2.2. Sinan: violência interpessoal e autoprovocada

**Orientações oficiais:** [Dados sobre agravos de notificações — Ministério da Saúde](https://www.gov.br/saude/pt-br/acesso-a-informacao/sic/dados-em-transparencia-ativa/svsa/agravos-de-notificacoes/agravos-de-notificacoes).

O Ministério informa a disponibilização de dados abertos anonimizados e orienta selecionar fonte, agravo, ano e documentação. A presença de uma variável na ficha de notificação ou no dicionário completo do sistema não garante sua disponibilização na extração pública.

Não há período inicial explícito para essa base no `index.qmd`. A cobertura deve ser definida antes da preparação. Também é necessário conferir se os anos mais recentes são preliminares e registrar a data de extração.

### 2.3. CNJ: processos judiciais

**Ponto de entrada:** [API pública do DataJud — acesso](https://datajud-wiki.cnj.jus.br/api-publica/acesso/).

A coleta utiliza a chave pública disponibilizada pelo CNJ. Os resultados são metadados de processos públicos e precisam ser consultados e paginados por tribunal.

Não se deve pressupor cobertura integral dos processos relacionados à violência contra crianças e adolescentes, em razão das restrições de publicidade. A ausência de um processo na resposta da API, isoladamente, não demonstra a razão de sua ausência.

O documento não informa quais tribunais, classes ou assuntos devem ser consultados. Esses critérios fazem parte da especificação da coleta.

### 2.4. IBGE: MUNIC 2023

**Ponto de entrada:** [MUNIC 2023 — edição e resultados](https://www.ibge.gov.br/estatisticas/sociais/protecao-social/2110-np-pesquisa-de-informacoes-basicas-municipais/10586-pesquisa-de-informacoes-basicas-municipais.html?edicao=41644).

O IBGE informa a disponibilização da base completa da edição e das tabelas de resultados. A coluna original correspondente à quantidade de conselhos tutelares deve ser identificada no dicionário da edição; seu código não consta no `index.qmd` e não foi confirmado nesta análise.

### 2.5. IBGE: população de crianças e adolescentes

**Referências:** [SIDRA, tabela 9514](https://sidra.ibge.gov.br/tabela/9514) e [Censo 2022 — população por idade e sexo](https://www.ibge.gov.br/estatisticas/sociais/populacao/22827-censo-demografico-2022.html?edicao=38166&t=resultados).

A tabela 9514 é uma opção para obter a população municipal por idade. Para o denominador de 0 a 17 anos, selecionar:

- Ano: 2022.
- Nível territorial: município.
- Variável: população residente.
- Sexo: total.
- Forma de declaração da idade: total.
- Idades: categorias que cubram 0 a 17 anos sem sobreposição.

Não somar o total de uma faixa etária com as idades que já a compõem. Preservar o código municipal para a junção com MUNIC e malha.

### 2.6. Malha municipal

O download já está implementado no `index.qmd`, por `geobr::read_municipality()`. O código salva a primeira obtenção em `conselhos_tutelares/mun_geo_2022.rds` e reutiliza esse arquivo nas próximas renderizações.

## 3. Estruturas de apoio recomendadas

Além das tabelas mínimas, as estruturas abaixo ajudam a manter as coletas reproduzíveis. São recomendações; não são dependências diretas do código atual.

| Estrutura | Colunas sugeridas | Finalidade |
| --- | --- | --- |
| Correspondência municipal | `cod_mun_6`, `cod_mun_7`, `nome_municipio`, `cod_uf`, `uf`, `ano_referencia` | Integrar códigos territoriais de diferentes fontes |
| Regras do recorte temático | `fonte`, `tipo_codigo`, `codigo`, `descricao`, `inicio_vigencia`, `fim_vigencia`, `justificativa` | Registrar procedimentos, diagnósticos, classes e assuntos selecionados |
| Controle de extrações | `fonte`, `recurso`, `periodo`, `uf_ou_tribunal`, `data_extracao`, `arquivo_origem`, `status` | Acompanhar cobertura e atualização |
| Dicionário de recodificações | `fonte`, `variavel`, `codigo_original`, `rotulo`, `regra`, `versao` | Documentar categorias e transformações |

O cadastro das 27 UFs já é construído no documento. Rankings, séries agregadas, quintis do mapa e tabelas intermediárias também são calculados em execução e não precisam ser persistidos separadamente para atender ao painel atual.

## 4. Definições necessárias antes de produzir as bases

1. **Violência sexual no SIA:** procedimentos/diagnósticos incluídos, vigência dos códigos e definição de `n`.
2. **Violência sexual no SIH:** diagnósticos/campos usados e tratamento de registros de continuidade ou repetição.
3. **Sinan:** significado de `motivo_violencia`, classificação de `autor` e tratamento de respostas múltiplas.
4. **Idade:** limites dos ciclos de vida, população de interesse e tratamento de idades ausentes ou inválidas.
5. **Justiça:** classes/assuntos, tribunais, cobertura temporal, consolidação e atribuição de UF.
6. **Comparação entre fontes:** períodos comparáveis e unidades de contagem claramente identificadas. Produção ambulatorial, registros hospitalares, notificações e processos não representam automaticamente pessoas distintas.
7. **Conselhos tutelares:** variável original da MUNIC, denominador populacional e distinção entre zero e falta de informação.
8. **Atualização:** data de corte por fonte e política para períodos preliminares ou incompletos.

## 5. Dependências do projeto que precisam ser recuperadas ou recriadas

| Caminho | Função |
| --- | --- |
| `funcoes_graf.r` | Funções de gráficos e montagem dos painéis |
| `config.R` | Configuração, incluindo os objetos visuais usados pelo documento |
| `senado.scss` | Tema visual |
| `assets/logo-datasenado.jpg` | Logotipo |
| `historia/historia.html` | Página independente incorporada na aba de história |

O início do documento usa funções e objetos antes de carregar explicitamente suas dependências. Recomenda-se um bloco inicial de preparação que carregue pacotes, funções e configurações antes da primeira aba.

Os arquivos `.rda` exigem também o **nome correto do objeto interno**. Gravar o arquivo com o nome certo, mas com outro nome de objeto, não atende aos `load()` atuais.

## 6. Downloads disponíveis para quem consulta o painel

O `index.qmd` atual **não implementa botões de exportação de dados**. O único download programado nele é a obtenção da malha municipal durante a renderização, quando o arquivo local ainda não existe.

Caso se deseje permitir downloads aos usuários, será necessário gerar arquivos de exportação e inserir links ou controles apropriados, com identificação da fonte, período, unidade de contagem e data de atualização.
