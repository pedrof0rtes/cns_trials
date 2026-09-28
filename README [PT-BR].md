# Pipeline de Término Precoce em Ensaios Clínicos de SNC (MVP)

Pipeline de dados (Databricks / Spark SQL) analisando término precoce em ensaios clínicos do sistema nervoso central (SNC), a partir do registro AACT/ClinicalTrials.gov.

<br>

---

<br>

## Contexto e Perguntas

### Problema

Quero entender quais características de desenho e execução de ensaios
clínicos de sistema nervoso central (SNC), incluindo quadros
neurológicos e psiquiátricos, estão associadas a término precoce (parada
antes do planejado) ou falha do estudo.

### Perguntas

**Pergunta principal:** Quais características de desenho e de execução estão
associadas a término precoce ou falha em ensaios clínicos de SNC?

<br>

**Perguntas originais (definidas antes da coleta de dados):**

1. Quais os motivos de falha em ensaios clínicos de SNC?
2. Qual é a taxa de término precoce por quadro clínico?
3. Número de sites influencia o término precoce?
4. Desenho com placebo, número de braços, ou duração longa influenciam o
   término precoce?
5. Número de instrumentos de desfecho influencia o término precoce?


**Perguntas transversais adicionadas ao longo do trabalho:**

* Placebo e número de braços interagem entre si na associação com término
  precoce? (cruzamento das duas variáveis da pergunta 4)
* O tipo de intervenção (droga, dispositivo, comportamental, biológica...)
  influencia o término precoce?

**Perguntas longitudinais adicionadas ao longo do trabalho (dimensão temporal não estava no escopo original):**

* Como o volume de estudos evoluiu ao longo do tempo, por transtorno?
* A taxa de término precoce por transtorno varia ao longo do tempo?
* Os motivos de término precoce mudam de composição ao longo do tempo (ex.:
  o impacto da pandemia de COVID-19 é visível e concentrado no período
  correto)?

<br>


### Fonte dos dados

O **AACT** (Aggregate Analysis of ClinicalTrials.gov), mantida pelo CTTI
(Clinical Trials Transformation Initiative, Duke University) é um espelho
relacional do registro **ClinicalTrials.gov**, mantido pela National Library
of Medicine (NLM) dos EUA. Snapshot mensal, baixado em 2026-09.


* Site: https://aact.ctti-clinicaltrials.org
* Licença: dados de **uso público e gratuito**. Os dados do
  ClinicalTrials.gov são produzidos por uma agência do governo dos EUA e,
  de forma geral, de domínio público; o AACT disponibiliza o espelho
  gratuitamente para download, sob os termos de uso publicados no próprio
  site. Nenhuma restrição de uso acadêmico foi identificada na
  documentação pública do AACT no momento da coleta. Recomenda-se conferir
  os termos vigentes no site antes de qualquer uso fora do escopo deste
  MVP.
  
* Citação:
_Aggregate Analysis of ClinicalTrials.gov (AACT) Database. Clinical Trials Transformation Initiative (CTTI). Available at: https://aact.ctti-clinicaltrials.org/ (Accessed: 2026-09)._

<br>

### Estrutura bruta dos dados

11 tabelas relacionais extraídas do snapshot AACT (arquivos `.txt`
delimitados por `|`): 

`studies`, `conditions`, `browse_conditions`,
`sponsors`, `facilities`, `countries`, `designs`, `design_groups`,
`interventions`, `design_outcomes`, `calculated_values`. 

Todas as colunas
chegam como texto (`string`), sem tipagem. 

**Detalhe completo de colunas em
[`data_catalog.md`](./data_catalog.md).**

<br>

---

<br>

## Carga dos Dados

Download manual do snapshot mensal do AACT (arquivo `.zip`
com os `.txt` pipe-delimited), upload para um Volume do Unity Catalog no Databricks (`/Volumes/cns_trials/1_bronze/raw_data`), descompactação e leitura via PySpark, com metadados de controle (`_source_file`, `_ingested_at`, `_aact_snapshot`) adicionados na ingestão.

**Script: [`notebooks/1_bronze.py`](./notebooks/1_bronze.py).**

<br>

---

<br>

## Modelagem e Catálogo de Dados

### Arquitetura

Arquitetura medalhão em três camadas, mapeadas para três schemas no mesmo catálogo Unity Catalog (`cns_trials`):

* `1_bronze` - dados crus, como vieram do AACT.
* `2_silver` - dados limpos, tipados, padronizados e restritos ao escopo do
  projeto (78.272 estudos intervencionais em 31 quadros diagnósticos de
  SNC).
* `3_gold` - modelo dimensional (esquema estrela) pronto para análise.

<br>

### Esquema estrela (Gold)

Uma tabela fato e quatro dimensões, ligadas por quatro tabelas-ponte (as relações são N:N, ou seja, um estudo pode pertencer a mais de um transtorno, ter mais de um tipo de intervenção, etc.):

* `fact_study` — grão de um estudo (78.272 linhas): desfecho, término
  precoce, motivo de parada, sites, países, braços, placebo, desfechos
  monitorados, duração planejada, patrocinador líder.
* `dim_disorder` + `bridge_study_disorder` — 31 quadros diagnósticos.
* `dim_intervention_type` + `bridge_study_intervention_type` — 11 tipos de
  intervenção.
* `dim_group_type` + `bridge_study_group_type` — 6 tipos de braço de
  estudo.
* `dim_country` + `bridge_study_country` — 167 países.

<br>

### Catálogo de dados

**Catálogo completo (tabela por tabela, coluna por coluna: tipo, domínio de
valores, linhagem) em [`data_catalog.md`](./data_catalog.md).**

Screenshots do Catalog Explorer evidenciando a estrutura e os tipos de
coluna, na pasta `screenshots/`:

* `data_collection_aact_flat` — origem dos dados (site do AACT)
* `databricks_repository` — repositório conectado ao Databricks
* `bronze_catalog_structure_step_1`, `bronze_catalog_structure_step_2` —
  estrutura da camada Bronze
* `bronze_studies_table_types` — tipos de coluna, Bronze (tudo string)
* `silver_catalog_structure_step_3`, `silver_catalog_structure_step_4`
  — estrutura da camada Silver
* `silver_studies_table_types` — tipos de coluna, `studies` (Silver)
* `silver_mesh_table_types` — tipos de coluna, `ref_mesh_disorder`
* `silver_study_disorder_table_types` — tipos de coluna, `study_disorder`
* `gold_catalog_structure_step_5`, `gold_catalog_structure_step_6`,
  `gold_catalog_structure_step_7` — estrutura da camada Gold
* `gold_fact_study_table_types` — tipos de coluna, `fact_study`

<br>

---

<br>

## Pipeline de Dados

Um notebook por etapa de refinamento do pipeline, na ordem em que devem ser executados:

1. [`1_bronze.py`](./notebooks/1_bronze.py) — unzip e carga das 11
   tabelas cruas.
2. [`2_post_bronze_checks.py`](./notebooks/2_post_bronze_checks.py) —
   checks estruturais (existência de colunas, contagem de linhas).
3. [`3_silver.sql`](./notebooks/3_silver.sql) — mapeamento MeSH →
   31 quadros diagnósticos, tabela-ponte de escopo, tabela `studies`
   refinada (tipagem, classificação do motivo de parada, duração), 7
   tabelas filhas limpas.
4. [`4_post_silver_checks.sql`](./notebooks/4_post_silver_checks.sql) —
   checks estruturais (unicidade de chaves, integridade referencial).
5. [`5_gold.sql`](./notebooks/5_gold.sql) — 4 dimensões, 4 pontes, 1
   tabela fato (esquema estrela).
6. [`6_post_gold_checks.sql`](./notebooks/6_post_gold_checks.sql) - checks estruturais da camada gold.
6. [`7_quality.sql`](./notebooks/6_quality.sql) — investigação de
   qualidade nas três camadas (ver seção seguinte).
7. [`8_analysis.py`](./notebooks/7_analysis.py) — resposta às
   perguntas do projeto, com testes estatísticos e visualizações.

Cada transformação relevante tem seu propósito documentado em comentário
SQL na própria célula do notebook.


<br>

---

<br>

## Qualidade de Dados

Investigação de qualidade completa no notebook
[`7_quality.sql`](./notebooks/7_quality.sql), cobrindo completude,
consistência, unicidade, acurácia e outliers nas três camadas. Principais
problemas encontrados e como foram tratados:

**Bronze**

* Termos MeSH sinônimos/subtipos no mesmo nível (ex.: "Depression",
  "Depressive Disorder, Major" e mais 3 variantes para o mesmo transtorno): agrupados manualmente em 31 quadros diagnósticos (`ref_mesh_disorder`).
* Termos MeSH genéricos ou de outras especialidades (ex.: "Mental
  Disorders", "Obesity"): excluídos do escopo por lista pré-definida.
* Valores nulos em `design_groups.group_type` (~16%): flag de placebo derivada a nível de estudo, com estado "desconhecido" separado de "sem placebo".

**Silver**

* Um estudo pode pertencer a mais de um quadro diagnóstico (granularidade
  N:N): tabela-ponte, contagens sempre por `DISTINCT nct_id`.
* Estudos de dor pós-operatória contaminando o quadro "Dor": excluídos a
  nível de estudo na própria tabela-ponte.
* `why_stopped` é texto livre, sem categorias: classificação manual apoiado por LLM em 7 categorias por correspondência de palavras-chave, refinado iterativamente contra centenas de falsos positivos reais.
* ~65% dos estudos têm `phase = Not applicable`, incluindo 3.360 com
  intervenção do tipo `DRUG`: não é um bug, mas sim estudos de medicamento conduzido fora do processo regulatório da FDA; documentado, não corrigido.
* Lacunas de cobertura nas tabelas filhas (desenho, braços, desfechos,
  sites, países): sem imputação; viram categoria "desconhecido" na Gold.
* Ausência de sites concentrada em estudos `Withdrawn` (30,8% vs. 3,4% em
  `Terminated`): viés documentado; a pergunta sobre sites é respondida em
  duas versões (com e sem estudos `Withdrawn`).
* Duração real (`duration_months`) é circular para estudos terminados
  (mede o tempo até parar, não a duração planejada): variável adicional
  `time_frame_months`, extraída do texto dos desfechos do estudo, usada
  como aproximação não contaminada.

**Gold**

* Validação cruzada: cobertura de `n_sites`/`n_countries`/`has_placebo`/
  `n_arms` bate exatamente com os gaps documentados na Silver, confirma que a agregação não perdeu nem inventou informação.
* `has_drug_intervention` bate exatamente com a investigação da fase "Not applicable" (25.065 = 3.360 + 21.705), confirma a agregação da ponte de intervenções.
* Outliers mantidos sem tratamento em toda a pipeline (ex.: `n_sites` até 1.745, `enrollment` até 12 milhões), podem ser dados reais de estudos grandes; nenhum corte foi aplicado sem investigação específica.

Convenção geral: **nulo nunca é tratado como zero ou falso** em nenhuma etapa. Sempre representa "sem informação", separado explicitamente do valor real quando existe ambiguidade.

<br>

---

<br>

## Análise de Dados

**Notebook [`8_analysis.py`](./notebooks/8_analysis.py).**

Escopo: os
78.272 estudos da `fact_study`; denominador de término precoce restrito a
`outcome_group IN ('Completed', 'Terminated', 'Withdrawn')` (estudos ainda
em andamento são excluídos).

**Testes estatísticos:** teste Z de duas proporções para comparações entre
exatamente 2 grupos; qui-quadrado de independência para comparações entre
mais de 2 categorias (com filtro de amostra mínima de 30 por categoria).
Nenhuma correção para múltiplas comparações foi aplicada, então os p-valores devem ser interpretados como exploratórios, não confirmatórios.

**Perguntas respondidas:**

* **Motivos de parada** - Recruitment é o motivo mais comum tanto em
  `Terminated` (34,9%) quanto em `Withdrawn` (24,7%), seguido por
  Funding/business. A composição muda ao longo do tempo: COVID-19 chega a
  responder por ~39% dos motivos em 2020-2021 e desaparece fora dessa
  janela.
* **Taxa por transtorno** - variação significativa (qui-quadrado,
  p < 0,0001); ALS/doença do neurônio motor, Epilepsia e Traumatismo
  cranioencefálico têm as maiores taxas de término precoce (~19-20%);
  Transtornos de personalidade e TOC, as menores.
* **Sites** - mais sites está associado a maior taxa de término precoce
  (20+ sites: 16,5% vs. 1 site: 11,0%).
* **Placebo, braços e duração** - estudos com placebo têm taxa maior que
  sem placebo (16,2% vs. 11,4%); estudos de 1 braço têm taxa maior que 2 ou
  3+; o cruzamento das duas variáveis mostra que os efeitos são
  independentes (placebo eleva o risco dentro de cada faixa de braços). Durações planejadas mais longas (12+
  meses) têm taxa maior (18,6%).
* **Número de desfechos monitorados** - associação significativa mas fraca; estudos com poucos desfechos (1-2) têm taxa levemente maior (14,0%) que os demais.
* **Tipo de intervenção** - variação forte (qui-quadrado, p < 0,0001):
  Radiation e Genetic têm as maiores taxas (23-26%); Behavioral e Other, as menores (7-9%).


<br>

### Discussão geral

**Todas as associações testadas são estatisticamente significativas**
(alfa = 0,01): transtorno, 
número de sites, placebo, número de braços, duração planejada, número de desfechos monitorados e tipo de intervenção. Nenhuma correção para múltiplas comparações foi aplicada, mas a magnitude dos p-valores torna improvável que os achados sejam ruído.

Em conjunto, os resultados sugerem que término precoce em ensaios de SNC é explicado tanto por fatores operacionais e de recrutamento quanto pelo transtorno estudado em si. É relevante notar que **"Recruitment" domina os motivos de parada em praticamente todos os recortes** (transtorno, sites,
braços, duração, desfechos).

**Placebo e número de braços não têm uma relação simples de "mais
complexidade, mais risco".** O cruzamento das duas variáveis mostra que a
combinação 2 braços + placebo tem a maior taxa de término precoce (17,5%),
mas logo em seguida vem **1 braço sem placebo** (15,7%), um desenho bem
mais simples. Só depois aparecem 3+ braços + placebo (13,4%), 2 braços sem
placebo (10,2%) e 3+ braços sem placebo (10,1%). Ou seja, tanto o desenho
mais simples (1 braço) quanto o desenho comparativo mais rigoroso (2
braços + placebo) concentram risco.

**A taxa de término precoce varia de forma marcante por quadro clínico.**
No topo do risco estão ELA e doença do neurônio motor (20,4%), Epilepsia
(19,3%), Traumatismo cranioencefálico (19,0%) e Esclerose múltipla e
doenças desmielinizantes (16,6%). No outro extremo, com as menores taxas,
estão Transtornos do neurodesenvolvimento e deficiência intelectual
(7,8%), Ansiedade (8,4%), Sono (excluindo apneia) (9,8%), Uso de outras
substâncias e dependência (9,8%) e Depressão (11,3%).

**O volume de estudos cresceu de forma muito desigual entre transtornos
nos últimos 20 anos** (comparando a média de 2005-2009 com a de
2021-2025). Cresceram proporcionalmente mais: Suicidalidade e autolesão
(quase 10x), Paralisia cerebral (quase 9x) e Transtornos do
neurodesenvolvimento e deficiência intelectual (8,5x). Praticamente
estagnados no mesmo período: Transtorno bipolar (sem crescimento, 1,0x),
Esquizofrenia e psicoses (1,0x) e TDAH (1,5x, bem abaixo da mediana dos
demais transtornos). 

Em volume absoluto, porém, o cenário atual (soma de
2021-2025) é dominado por outros três quadros: Dor (excluindo
pós-operatória) (6.061 estudos), Depressão (3.276) e Ansiedade (3.178), que já eram grandes desde o início da série e não aparecem entre os que mais cresceram proporcionalmente. Ou seja, o crescimento relativo mais acentuado acontece em quadros que partiram de uma base pequena, não nos que hoje concentram o maior volume de pesquisa.

**O problema de recrutamento não parece ter melhorado ao longo do
tempo.** Olhando a composição dos motivos de parada por ano (entre
estudos `Terminated`), Recruitment permanece a categoria dominante ou
quase dominante em quase todos os 21 anos analisados, oscilando entre
~28% e ~46% — sem tendência clara de queda. As únicas exceções visíveis
são justamente os anos de pico da COVID-19 (2020-2021), quando a pandemia
temporariamente desloca Recruitment como motivo mais citado.

Isso responde, ainda que parcialmente, à pergunta principal do MVP: o desenho do estudo e o transtorno estudado importam, mas o principal fator associado a falha continua sendo o desafio de recrutar e manter pacientes.

**Evidência visual dos resultados:** screenshots dos gráficos principais (barras com intervalo de confiança, linhas de tendência temporal) na pasta `screenshots/`, prefixo `analysis_`.

<br>

---

<br>

## Autoavaliação

Acredito que obtive sucesso em construir um pipeline de dados com bastante rigor e cuidado. Ao final da modelagem dos dados, etapa mais demorada e trabalhosa do projeto, ainda foi possível extrair significado real e de valor prático das análises efetuadas. Gostaria de ter tido mais tempo para a execução do projeto, o que não foi possível devido a outros compromissos de trabalho. Por isso, ainda pretendo refinar o pipeline de modelagem e as análises mais adiante.

As perguntas originais foram respondidas por completo com testes estatísticos e visualização. A pergunta principal (motivos de falha) recebeu tratamento mais rico que o planejado originalmente, virando análise própria além de aparecer como resposta complementar em quase todas as outras perguntas.

A maior parte do esforço do projeto foi centrada na qualidade de dados, em especial duas codificações manuais extensas. A primeira foi a classificação do campo `why_stopped` (texto livre, motivo de parada) em 7 categorias, que exigiu várias rodadas de refinamento via LLMs contra falsos positivos reais (ex.: "corona radiata", estrutura cerebral, sendo capturada por engano pela regra de COVID-19). A segunda foi o mapeamento de termos MeSH em 31 quadros diagnósticos, que exigiu investigação extensa por causa de erros de mapeamento automático e alta redundância na própria fonte.

<br>

**Trabalhos futuros:**

* Modelo estatístico multivariado (ex.: regressão logística) controlando
  simultaneamente por todas as covariáveis, em vez de testes bivariados
  isolados.
* Correção para múltiplas comparações (ex.: Bonferroni ou FDR) nos
  p-valores dos 7+ testes realizados.
* Expandir a classificação de `why_stopped` para outros idiomas além de
  inglês/francês esporádico já encontrado nos dados.