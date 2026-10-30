-- ============================================================================
-- VetFlow - Challenge FIAP 2026 (Clyvo Vet)
-- Mastering Relational and Non-Relational Database - Sprint 4
-- 08_exportar_json.sql - exporta o dataset relacional para dataset_vetflow.json
-- ============================================================================
-- Gera o arquivo JSON usado na importacao do MongoDB a partir de
-- PKG_VETFLOW_UTIL.FN_EXPORTAR_DATASET_JSON (formato da secao 5 do contrato).
--
-- SQL Developer: abra este arquivo e rode como SCRIPT (F5, nao Ctrl+Enter).
--   O arquivo e criado na pasta de trabalho do SQL Developer; para escolher
--   o local, troque o nome no SPOOL por um caminho completo, ex.:
--   SPOOL C:\vetflow\banco\dataset_vetflow.json
-- SQL*Plus / SQLcl: @08_exportar_json.sql (gera na pasta atual).
--
-- Alternativa sem SPOOL: GET /api/v1/export/dataset da API .NET devolve o
-- mesmo JSON (chama a mesma funcao).
-- ============================================================================

SET ECHO OFF
SET VERIFY OFF
SET FEEDBACK OFF
SET HEADING OFF
SET PAGESIZE 0
SET LINESIZE 32767
SET LONG 100000000
SET LONGCHUNKSIZE 32767
SET TRIMSPOOL ON
SET TRIMOUT ON
SET TERMOUT OFF
SET SERVEROUTPUT OFF

SPOOL dataset_vetflow.json

SELECT PKG_VETFLOW_UTIL.FN_EXPORTAR_DATASET_JSON FROM DUAL;

SPOOL OFF

SET TERMOUT ON
SET FEEDBACK ON
SET HEADING ON
SET PAGESIZE 100
SET LINESIZE 200

PROMPT 08_exportar_json.sql concluido: dataset_vetflow.json gerado.
