# VetFlow — Banco de Dados Oracle | Challenge FIAP 2026

Projeto de banco de dados relacional desenvolvido para o **Challenge FIAP 2026** em parceria com a **CLYVO VET**.

## Integrantes do Grupo

| Nome | RM | Turma |
|------|----|-------|
| Andrei de Paiva Gibbini | 563061 | 2TDSPF |
| Pedro Sakai Silva Zambaca | 565956 | 2TDSPF |
| Pedro Santos Pequini | 561842 | 2TDSPF |
| Arthur Câmara | 562310 | 2TDSPG |
| Diogo Cunha | 563654 | 2TDSPF |

## Problema de Negócio

A jornada de saúde do pet é fragmentada — tutores só interagem com clínicas em urgências, vacinas e retornos pontuais. Isso gera histórico clínico disperso, abandono de tratamentos e baixa recorrência para as clínicas.

## Solução

Modelagem relacional centralizada que serve de base para a plataforma VetFlow, armazenando tutores, pets, clínicas, agendamentos, vacinas e medicamentos de forma integrada e rastreável.

## Tecnologia

Oracle Database XE — acessado via `oracle.fiap.com.br:1521/orcl`

## Como Executar

1. Acesse o Oracle via SQL Developer ou SQL*Plus com suas credenciais FIAP (RM/senha)
2. Execute o script `vetflow_oracle.sql` na ordem em que está organizado

```sql
-- Exemplo via SQL*Plus
@vetflow_oracle.sql
```

## Estrutura do Banco

### Tabelas

| Tabela | Descrição |
|--------|-----------|
| `CV_TUTORS` | Responsáveis pelos pets |
| `CV_PETS` | Animais cadastrados, vinculados ao tutor |
| `CV_CLINICS` | Clínicas e hospitais veterinários parceiros |
| `CV_APPOINTMENTS` | Agendamentos e consultas dos pets nas clínicas |
| `CV_VACCINES` | Histórico de vacinas aplicadas e próximas doses |
| `CV_MEDICATIONS` | Medicamentos prescritos com controle de adesão |
| `CV_ERROR_LOG` | Registro de erros das procedures (auditoria) |

### Relacionamentos principais

```
CV_TUTORS (1) ──< (N) CV_PETS
CV_PETS   (1) ──< (N) CV_APPOINTMENTS ──> (N) CV_CLINICS
CV_PETS   (1) ──< (N) CV_VACCINES
CV_PETS   (1) ──< (N) CV_MEDICATIONS
```

Todas as tabelas usam `RAW(16)` com `SYS_GUID()` como chave primária, garantindo unicidade global sem dependência de sequences.

## Conteúdo do Script SQL

O arquivo `vetflow_oracle.sql` está organizado nas seguintes seções:

**1. DDL — Criação das tabelas**
Todas as tabelas com constraints (PK, FK, CHECK, UNIQUE) e 3ª Forma Normal (3FN).

**2. Procedures de carga**
Uma procedure por tabela para inserção de dados via parâmetro (sem hard-code). Todas incluem:
- `EXCEPTION WHEN OTHERS`
- `DUP_VAL_ON_INDEX` — trata duplicidade de chave única
- `VALUE_ERROR` — trata erro de tipo/tamanho de dado
- Registro automático na tabela `CV_ERROR_LOG`

**3. Carga de dados**
Inserção de dados significativos via chamada das procedures:
- 2 tutores, 2 clínicas, 3 pets
- Vacinas, medicamentos e agendamentos para cada pet

**4. Consultas com JOIN, GROUP BY e ORDER BY**
3 blocos anônimos com junções entre tabelas, agrupamento e ordenação.

**5. Relatório LAG/LEAD**
Bloco que exibe valor atual, anterior e próximo de uma coluna usando funções de janela, com "Vazio" quando não há linha adjacente.

**6. Relatórios com cursor explícito**
4 blocos anônimos com cursor explícito e tomada de decisão:
- Listagem completa com sub-totais por tutor
- Alerta de vacinas vencidas por pet
- Agendamentos pendentes por clínica
- Alerta de medicamentos com término próximo

## Benefícios para o Negócio

- Histórico clínico longitudinal estruturado por pet
- Rastreabilidade completa de vacinas e medicamentos
- Base de dados para alertas preventivos e score de risco
- Suporte a analytics para clínicas (recorrência, LTV, adesão)
