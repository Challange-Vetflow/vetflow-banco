# VetFlow — Banco de Dados (Oracle + MongoDB) | Sprint 4

Parte de banco de dados do **VetFlow** (Challenge FIAP 2026 com a **Clyvo Vet**) para a disciplina *Mastering Relational and Non-Relational Database*. O mesmo schema Oracle é usado pelas APIs **Java (Spring)** e **.NET (EF Core)**. O dataset exportado em JSON vai para o MongoDB (banco `vetflow`).

## Vídeo demonstrativo

https://youtu.be/qN8BhGBNxnM

## Integrantes

| Nome | RM | Turma |
|------|----|-------|
| Andrei de Paiva Gibbini | 563061 | 2TDSPF |
| Arthur Câmara | 562310 | 2TDSPG |
| Diogo Cunha | 563654 | 2TDSPF |
| Pedro Sakai Silva Zambaca | 565956 | 2TDSPF |
| Pedro Santos Pequini | 561842 | 2TDSPF |

## Entregáveis

| Entregável | Arquivo(s) |
|---|---|
| Modelos lógico e físico (PDF, 11 páginas: capa, modelo lógico com DER, modelo físico tabela por tabela, pacotes e trigger com exceções, estrutura MongoDB) | `docs/VetFlow_Sprint4_Modelos_Logico_Fisico.pdf` (gerado a partir de `docs/VetFlow_Sprint4_Modelos_Logico_Fisico.html`) |
| DER físico (imagem, com chaves e cardinalidades) | `docs/DER_VetFlow_Sprint4.png` |
| Codificação SQL (DDL) | `01_ddl.sql`, `01b_tabelas_apoio.sql` |
| Empacotamento (procedures, funções, gatilho) | `02_pkg_cadastro.sql` a `05_pkg_auditoria_trigger.sql` |
| Carga e testes | `06_seed.sql`, `07_testes.sql` |
| JSON gerado do banco relacional | `08_exportar_json.sql` → `dataset_vetflow.json` |
| Estrutura MongoDB (criação + importação + consultas) | `mongodb/01_criar_estrutura.js`, `mongodb/02_importar_dados.js`, `mongodb/03_consultas.js` |

> Para regerar o PDF depois de editar o HTML: `msedge --headless=new --no-pdf-header-footer --print-to-pdf=docs\VetFlow_Sprint4_Modelos_Logico_Fisico.pdf docs\VetFlow_Sprint4_Modelos_Logico_Fisico.html`.

## Ordem de execução (Oracle)

Conecte no SQL Developer (`oracle.fiap.com.br:1521/ORCL`, usuário RM/senha) e rode cada arquivo como **script (F5)**, nesta ordem, numa base limpa:

> **Codificação:** os scripts com mensagens e dados acentuados (`02` a `07`) estão em **UTF-8 com BOM**, e o banco da FIAP usa `AL32UTF8`, então os acentos entram corretos. Se aparecer `Ã§`/`Ã£` no resultado, o SQL Developer abriu o arquivo na codificação errada: ajuste **Ferramentas → Preferências → Ambiente → Codificação** para `UTF-8`, reabra o arquivo e rode de novo.

| # | Arquivo | O que faz |
|---|---|---|
| 1 | `01_ddl.sql` | Cria as 7 tabelas `CV_*` (inclui a nova `"CV_Users"` e o índice único `"UQ_CV_Tutors_Email"`). **Pule este arquivo se já rodou `dotnet ef database update`** (o EF cria as mesmas tabelas). Reexecutar apaga os dados. |
| 2 | `01b_tabelas_apoio.sql` | Cria `CV_ERROR_LOG` e `CV_PETS_AUDITORIA` (o EF não mapeia essas tabelas, então **rode sempre**). Remove também as procedures/funções avulsas da Sprint 3. |
| 3 | `02_pkg_cadastro.sql` | `PKG_VETFLOW_CADASTRO` |
| 4 | `03_pkg_util.sql` | `PKG_VETFLOW_UTIL` |
| 5 | `04_pkg_relatorios.sql` | `PKG_VETFLOW_RELATORIOS` (depende do UTIL) |
| 6 | `05_pkg_auditoria_trigger.sql` | `PKG_VETFLOW_AUDITORIA` + trigger `TRG_AUDITORIA_CV_PETS` |
| 7 | `06_seed.sql` | Carga inicial via pacote + 3 usuários de login. Faz `COMMIT`. |
| 8 | `07_testes.sql` | Testes de sucesso e de exceção de todos os objetos (não altera o seed) |
| 9 | `08_exportar_json.sql` | Gera `dataset_vetflow.json` |

Depois disso, suba as aplicações Java e .NET (elas não criam nem alteram tabelas além das migrations do EF).

Conferência rápida:

```sql
SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_name LIKE 'PKG_VETFLOW%' OR object_name = 'TRG_AUDITORIA_CV_PETS'
 ORDER BY 1, 2;   -- tudo deve estar VALID
```

## Pacotes e objetos

### `PKG_VETFLOW_CADASTRO` — inserções com validação

| Procedure | Parâmetros |
|---|---|
| `SP_INSERT_TUTOR` | `p_name, p_email, p_phone, p_id OUT RAW` |
| `SP_INSERT_CLINIC` | `p_name, p_address, p_phone, p_email, p_id OUT RAW` |
| `SP_INSERT_PET` | `p_name, p_species, p_breed, p_birth_date, p_weight_kg, p_tutor_id, p_id OUT RAW` |
| `SP_INSERT_APPOINTMENT` | `p_pet_id, p_clinic_id, p_scheduled_at, p_type, p_notes, p_id OUT RAW` |
| `SP_INSERT_VACCINE` | `p_pet_id, p_vaccine_name, p_applied_at, p_next_dose_at, p_batch, p_id OUT RAW` |
| `SP_INSERT_MEDICATION` | `p_pet_id, p_name, p_dosage, p_frequency, p_start_date, p_end_date, p_id OUT RAW` |
| `SP_INSERT_USER` | `p_name, p_email, p_password_hash, p_role, p_tutor_id, p_id OUT RAW` |

- O id vem de `SYS_GUID()` e é devolvido em `p_id`.
- **Sem COMMIT**: a transação é da aplicação (ou do bloco que chamou).
- Todo erro é gravado em `CV_ERROR_LOG` por uma procedure privada com `PRAGMA AUTONOMOUS_TRANSACTION`, então o log fica salvo mesmo se a aplicação fizer rollback.
- Referências (tutor/pet/clínica) são verificadas **antes** do INSERT, o que gera -20003 em vez do ORA-02291 genérico.

### `PKG_VETFLOW_UTIL` — JSON e cálculos

| Objeto | Descrição |
|---|---|
| `FN_PET_TO_JSON(...) RETURN VARCHAR2` | JSON manual de um pet (Sprint 3) |
| `FN_CALCULAR_IDADE_MESES(p_birth_date) RETURN NUMBER` | Idade em meses (Sprint 3) |
| `SP_LISTAR_PETS_JSON` | Pets + tutor em JSON no `DBMS_OUTPUT` (Sprint 3) |
| `SP_LISTAR_PETS_JSON(p_resultado OUT CLOB)` | Overload para a aplicação: array `[{...},{...}]` |
| `FN_EXPORTAR_DATASET_JSON RETURN CLOB` | Dataset completo para o MongoDB, com JSON montado manualmente (sem `JSON_OBJECT`): `DBMS_LOB.WRITEAPPEND`, escape de `\` `"` e quebras de linha, números com ponto (independente de NLS), datas ISO-8601, enums como texto, `true/false` e `[]` |

### `PKG_VETFLOW_RELATORIOS` — relatórios

| Procedure | Saída |
|---|---|
| `SP_RELATORIO_PESO_POR_TUTOR` | `DBMS_OUTPUT` (Sprint 3): soma manual por tutor + espécie, com subtotal e total geral |
| `SP_RELATORIO_PESO_POR_TUTOR(p_cursor OUT SYS_REFCURSOR)` | `TUTOR_NAME, SPECIES, TOTAL_WEIGHT, TOTAL_PETS` |
| `SP_RESUMO_CLINICO(p_cursor OUT SYS_REFCURSOR)` | Uma linha por pet ativo: `PET_ID, PET_NAME, SPECIES, TUTOR_NAME, IDADE_MESES, TOTAL_VACINAS, VACINAS_VENCIDAS, MEDICAMENTOS_ATIVOS, PROXIMA_CONSULTA` |

### `PKG_VETFLOW_AUDITORIA` + `TRG_AUDITORIA_CV_PETS`

Trigger não pode ficar dentro de pacote. Por isso a regra mora em `PKG_VETFLOW_AUDITORIA.SP_REGISTRAR_AUDITORIA_PET(p_operacao, p_valor_antigo, p_valor_novo)`, e o trigger `AFTER INSERT OR UPDATE OR DELETE ON "CV_Pets" FOR EACH ROW` só monta os valores e chama o pacote. Não há COMMIT dentro do trigger. Se a auditoria falhar, o erro vai para o log e o DML do usuário não é derrubado.

### Códigos de erro

| Código | Significado | HTTP nas apps |
|---|---|---|
| -20001 | E-mail duplicado (tutor ou usuário) | 409 |
| -20002 | Campo obrigatório nulo/vazio | 400 |
| -20003 | Registro referenciado não existe (tutor/pet/clínica) | 404 |
| -20004 | Regra de negócio: peso <= 0, nascimento no futuro, próxima dose antes da aplicação, fim antes do início, agendamento no passado, role inválida, espécie/tipo inválido | 400 |
| -20099 | Erro inesperado (logado antes) | 500 |
| -20101/-20102, -20204/-20206, -20301, -20402 | Erros das rotinas herdadas da Sprint 3 (JSON, idade, listagem, relatório) | — |

Enums gravados como NUMBER: Species `0=DOG 1=CAT 2=BIRD 3=RABBIT 4=OTHER`; AppointmentType `0=VACCINATION 1=CHECKUP 2=SURGERY 3=RETURN 4=EMERGENCY 5=OTHER`; MedicationStatus `0=ACTIVE 1=COMPLETED 2=SUSPENDED`.

## Quem chama cada procedure (integração com as aplicações)

| Aplicação | Onde | Objeto do banco |
|---|---|---|
| Java | Cadastro de tutor | `PKG_VETFLOW_CADASTRO.SP_INSERT_TUTOR` |
| Java | Cadastro de clínica | `PKG_VETFLOW_CADASTRO.SP_INSERT_CLINIC` |
| Java | Cadastro de pet | `PKG_VETFLOW_CADASTRO.SP_INSERT_PET` |
| Java | Agendamento de consulta | `PKG_VETFLOW_CADASTRO.SP_INSERT_APPOINTMENT` |
| Java | Registro de vacina | `PKG_VETFLOW_CADASTRO.SP_INSERT_VACCINE` |
| Java | Prescrição de medicamento | `PKG_VETFLOW_CADASTRO.SP_INSERT_MEDICATION` |
| Java | Cadastro de usuário | `PKG_VETFLOW_CADASTRO.SP_INSERT_USER` |
| Java | Dashboard | `PKG_VETFLOW_RELATORIOS.SP_RESUMO_CLINICO` |
| Java | Página "Relatórios" | `PKG_VETFLOW_RELATORIOS.SP_RELATORIO_PESO_POR_TUTOR(cursor)` |
| Java | Idade do pet | `PKG_VETFLOW_UTIL.FN_CALCULAR_IDADE_MESES` |
| .NET | `POST` de tutor / clínica / medicamento | `SP_INSERT_TUTOR` / `SP_INSERT_CLINIC` / `SP_INSERT_MEDICATION` |
| .NET | Register (auth) | `SP_INSERT_USER` |
| .NET | `GET /api/v1/export/dataset` | `PKG_VETFLOW_UTIL.FN_EXPORTAR_DATASET_JSON` |
| .NET | `GET /api/v1/reports/pets-json` | `PKG_VETFLOW_UTIL.SP_LISTAR_PETS_JSON(OUT CLOB)` |

Usuários de teste criados pelo seed (senha `senha123` para todos): `vet@vetflow.com` (VET), `carlos.mendes@email.com` (TUTOR) e `ana.silva@email.com` (TUTOR).

## Exportação JSON → MongoDB

### 1. Gerar o JSON no Oracle

Abra `08_exportar_json.sql` no SQL Developer e rode com **F5** (Run Script). O arquivo `dataset_vetflow.json` é criado na pasta de trabalho do SQL Developer. Para escolher o local, troque a linha do `SPOOL` por um caminho completo, por exemplo `SPOOL C:\vetflow\banco\dataset_vetflow.json`.

Também dá para baixar o mesmo conteúdo pela API .NET em `GET /api/v1/export/dataset`. O `dataset_vetflow.json` versionado aqui foi gerado pelo `08_exportar_json.sql` a partir do seed atual do Oracle (os ids mudam a cada carga, porque vêm do `SYS_GUID()`; ao recarregar o seed, gere o JSON de novo e limpe as coleções antes de importar, senão o índice único de e-mail rejeita os tutores duplicados).

A API .NET também grava o mesmo dataset no MongoDB: `POST /api/v1/export/mongo` (perfil VET) chama a mesma função e faz upsert por `_id` em `tutores` e `clinicas`, convertendo as datas ISO para `Date`.

Estrutura do arquivo: `{ "tutores": [ { ..., "pets": [ { ..., "vacinas": [], "medicamentos": [], "consultas": [] } ] } ], "clinicas": [ ... ] }`.

### 2a. Importar com mongosh (recomendado: converte as datas para `Date`)

Rode a partir da pasta `banco/`:

```bash
mongosh "mongodb://localhost:27017" --file mongodb/01_criar_estrutura.js
mongosh "mongodb://localhost:27017" --file mongodb/02_importar_dados.js
mongosh "mongodb://localhost:27017" --file mongodb/03_consultas.js
```

- `01_criar_estrutura.js` cria as coleções `tutores` e `clinicas` com validação `$jsonSchema` e os índices (`email` único, `pets.petId`, `pets.vacinas.proximaDose`, `pets.consultas.agendadaPara`...). Pode ser rodado de novo sem problema.
- `02_importar_dados.js` lê o JSON com `fs.readFileSync`, converte as datas ISO em `Date` e faz upsert por `_id`. Reimportar não duplica nada. Para usar outro arquivo: `DATASET=/caminho/dataset_vetflow.json` (no PowerShell: `$env:DATASET="C:\...\dataset_vetflow.json"`).
- `03_consultas.js` mostra o prontuário de um pet, as vacinas vencidas (`$unwind` + `$match`), as próximas consultas com `$lookup` em `clinicas`, a média de peso por espécie (`$group`) e um update em array aninhado com `arrayFilters`.

### 2b. MongoDB Compass

1. Conecte em `mongodb://localhost:27017`.
2. Abra o painel **>_ MONGOSH** (rodapé do Compass), digite `cd C:\caminho\para\banco` (ou use caminhos absolutos) e rode `load("mongodb/01_criar_estrutura.js")` e depois `load("mongodb/02_importar_dados.js")`.
3. Confira os dados em **vetflow → tutores / clinicas**. O documento de cada tutor traz os pets embutidos.
4. Rode `load("mongodb/03_consultas.js")` ou monte as agregações na aba **Aggregations**.

> Pelo Compass não use *Add Data → Import JSON* direto com este arquivo. Ele contém um objeto com duas listas (não um array de documentos) e as datas estão em texto. O script `02_importar_dados.js` faz a separação por coleção e a conversão das datas.

### Por que esse modelo de documentos

- **`tutores`**: os pets ficam embutidos e, dentro de cada pet, as vacinas, os medicamentos e as consultas. O acesso principal é o "prontuário completo do tutor/pet", que assim sai de uma única leitura, sem joins. Os arrays crescem pouco por tutor.
- **`clinicas`**: coleção separada, porque a clínica é compartilhada por muitos tutores. As consultas referenciam a clínica por `clinicaId` e guardam `clinicaNome` desnormalizado, para listar sem `$lookup`. O `$lookup` só entra quando se precisa de endereço ou telefone.
