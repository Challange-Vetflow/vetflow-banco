-- ============================================================================
-- VetFlow - Challenge FIAP 2026 (Clyvo Vet)
-- Mastering Relational and Non-Relational Database - Sprint 4
-- 03_pkg_util.sql - PKG_VETFLOW_UTIL
-- ============================================================================
-- Funcoes utilitarias da Sprint 3 (agora empacotadas) + exportacao do
-- dataset completo em JSON para importacao no MongoDB.
--
--   FN_PET_TO_JSON ............ JSON manual de um pet (igual Sprint 3)
--   FN_CALCULAR_IDADE_MESES ... idade do pet em meses (igual Sprint 3)
--   SP_LISTAR_PETS_JSON ....... lista pets em JSON via DBMS_OUTPUT (Sprint 3)
--   SP_LISTAR_PETS_JSON(OUT) .. overload para a aplicacao: array JSON em CLOB
--   FN_EXPORTAR_DATASET_JSON .. dataset completo (tutores > pets > vacinas /
--                               medicamentos / consultas + clinicas) em CLOB
--
-- O JSON e montado MANUALMENTE (sem JSON_OBJECT/JSON_ARRAYAGG): strings
-- escapadas, numeros com ponto decimal independente de NLS, datas ISO-8601,
-- enums como texto e booleanos true/false.
--
-- As funcoes podem ser chamadas dentro de SELECT (ex.: o Java usa
-- FN_CALCULAR_IDADE_MESES num SELECT ... FROM DUAL), por isso o log de erro
-- usa PRAGMA AUTONOMOUS_TRANSACTION (DML normal dentro de SELECT daria
-- ORA-14551).
-- ============================================================================

SET DEFINE OFF
SET SERVEROUTPUT ON

CREATE OR REPLACE PACKAGE PKG_VETFLOW_UTIL AS

    FUNCTION FN_PET_TO_JSON(p_pet_name IN VARCHAR2, p_species IN NUMBER, p_breed IN VARCHAR2, p_weight IN NUMBER, p_tutor_name IN VARCHAR2) RETURN VARCHAR2;

    FUNCTION FN_CALCULAR_IDADE_MESES(p_birth_date IN TIMESTAMP) RETURN NUMBER;

    FUNCTION FN_EXPORTAR_DATASET_JSON RETURN CLOB;

    PROCEDURE SP_LISTAR_PETS_JSON;

    PROCEDURE SP_LISTAR_PETS_JSON(p_resultado OUT CLOB);

END PKG_VETFLOW_UTIL;
/

CREATE OR REPLACE PACKAGE BODY PKG_VETFLOW_UTIL AS

    c_nls_num CONSTANT VARCHAR2(40) := 'NLS_NUMERIC_CHARACTERS=''.,''';

    -- ------------------------------------------------------------------------
    -- PRIVADO: log de erro em transacao autonoma
    -- ------------------------------------------------------------------------
    PROCEDURE prc_log_erro(p_procedure IN VARCHAR2, p_code IN NUMBER, p_msg IN VARCHAR2) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO CV_ERROR_LOG (procedure_nm, user_nm, error_code, error_msg)
        VALUES (SUBSTR(p_procedure, 1, 100), SUBSTR(USER, 1, 100), p_code, SUBSTR(p_msg, 1, 4000));
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
    END prc_log_erro;

    -- ------------------------------------------------------------------------
    -- PRIVADO: escapa texto para dentro de uma string JSON
    -- (barra invertida primeiro, depois aspas e caracteres de controle)
    -- ------------------------------------------------------------------------
    FUNCTION fn_esc(p_texto IN VARCHAR2) RETURN VARCHAR2 IS
        v_txt VARCHAR2(32767);
    BEGIN
        IF p_texto IS NULL THEN
            RETURN NULL;
        END IF;
        v_txt := REPLACE(p_texto, '\', '\\');
        v_txt := REPLACE(v_txt, '"', '\"');
        v_txt := REPLACE(v_txt, CHR(13), '\r');
        v_txt := REPLACE(v_txt, CHR(10), '\n');
        v_txt := REPLACE(v_txt, CHR(9), '\t');
        RETURN v_txt;
    END fn_esc;

    -- PRIVADO: valor string JSON ("texto" ou null)
    FUNCTION fn_str(p_texto IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        IF p_texto IS NULL THEN
            RETURN 'null';
        END IF;
        RETURN '"' || fn_esc(p_texto) || '"';
    END fn_str;

    -- PRIVADO: numero JSON com ponto decimal (independente de NLS).
    -- Inteiros saem sem casas ("79"); decimais com ate 3 casas ("28.5").
    -- O RTRIM do ponto evita "4." (invalido em JSON) quando o arredondamento
    -- gera um inteiro.
    FUNCTION fn_num(p_valor IN NUMBER) RETURN VARCHAR2 IS
        v_arred NUMBER;
    BEGIN
        IF p_valor IS NULL THEN
            RETURN 'null';
        END IF;
        v_arred := ROUND(p_valor, 3);
        IF v_arred = TRUNC(v_arred) THEN
            RETURN TO_CHAR(v_arred, 'FM99999999999990', c_nls_num);
        END IF;
        RETURN RTRIM(TO_CHAR(v_arred, 'FM999999990.999', c_nls_num), '.');
    END fn_num;

    -- PRIVADO: data ISO (YYYY-MM-DD) entre aspas
    FUNCTION fn_data(p_valor IN TIMESTAMP) RETURN VARCHAR2 IS
    BEGIN
        IF p_valor IS NULL THEN
            RETURN 'null';
        END IF;
        RETURN '"' || TO_CHAR(p_valor, 'YYYY-MM-DD') || '"';
    END fn_data;

    -- PRIVADO: timestamp ISO (YYYY-MM-DDTHH24:MI:SS) entre aspas
    FUNCTION fn_data_hora(p_valor IN TIMESTAMP) RETURN VARCHAR2 IS
    BEGIN
        IF p_valor IS NULL THEN
            RETURN 'null';
        END IF;
        RETURN '"' || TO_CHAR(p_valor, 'YYYY-MM-DD"T"HH24:MI:SS') || '"';
    END fn_data_hora;

    -- PRIVADO: booleano NUMBER(1) -> true/false
    FUNCTION fn_bool(p_valor IN NUMBER) RETURN VARCHAR2 IS
    BEGIN
        IF p_valor = 1 THEN
            RETURN 'true';
        END IF;
        RETURN 'false';
    END fn_bool;

    -- PRIVADO: enums (ordinal -> texto). A ordem e contrato com Java/.NET.
    FUNCTION fn_especie(p_valor IN NUMBER) RETURN VARCHAR2 IS
    BEGIN
        RETURN CASE p_valor
                   WHEN 0 THEN 'DOG'
                   WHEN 1 THEN 'CAT'
                   WHEN 2 THEN 'BIRD'
                   WHEN 3 THEN 'RABBIT'
                   ELSE 'OTHER'
               END;
    END fn_especie;

    FUNCTION fn_tipo_consulta(p_valor IN NUMBER) RETURN VARCHAR2 IS
    BEGIN
        RETURN CASE p_valor
                   WHEN 0 THEN 'VACCINATION'
                   WHEN 1 THEN 'CHECKUP'
                   WHEN 2 THEN 'SURGERY'
                   WHEN 3 THEN 'RETURN'
                   WHEN 4 THEN 'EMERGENCY'
                   ELSE 'OTHER'
               END;
    END fn_tipo_consulta;

    FUNCTION fn_status_medicamento(p_valor IN NUMBER) RETURN VARCHAR2 IS
    BEGIN
        RETURN CASE p_valor
                   WHEN 0 THEN 'ACTIVE'
                   WHEN 1 THEN 'COMPLETED'
                   ELSE 'SUSPENDED'
               END;
    END fn_status_medicamento;

    -- PRIVADO: acrescenta texto ao CLOB (ignora texto vazio)
    PROCEDURE prc_append(p_clob IN OUT NOCOPY CLOB, p_texto IN VARCHAR2) IS
    BEGIN
        IF p_texto IS NOT NULL THEN
            DBMS_LOB.WRITEAPPEND(p_clob, LENGTH(p_texto), p_texto);
        END IF;
    END prc_append;

    -- ========================================================================
    -- FN_PET_TO_JSON (Sprint 3) - JSON manual de um pet.
    -- Ajuste Sprint 4: peso com ponto decimal independente de NLS e escape
    -- tambem da barra invertida.
    -- Excecoes: NO_DATA_FOUND (-20101), VALUE_ERROR (-20102), OTHERS (log).
    -- ========================================================================
    FUNCTION FN_PET_TO_JSON(p_pet_name IN VARCHAR2, p_species IN NUMBER, p_breed IN VARCHAR2, p_weight IN NUMBER, p_tutor_name IN VARCHAR2) RETURN VARCHAR2 IS
        v_json     VARCHAR2(4000);
        v_err_code NUMBER;
        v_err_msg  VARCHAR2(4000);
    BEGIN
        -- Campos obrigatorios nao podem ser nulos
        IF p_pet_name IS NULL OR p_tutor_name IS NULL THEN
            RAISE NO_DATA_FOUND;
        END IF;

        v_json := '{'
            || '"nome":'    || fn_str(p_pet_name)                   || ','
            || '"especie":' || NVL(TO_CHAR(p_species), 'null')      || ','
            || '"raca":"'   || fn_esc(p_breed)                      || '",'
            || '"pesoKg":'  || fn_num(p_weight)                     || ','
            || '"tutor":'   || fn_str(p_tutor_name)
            || '}';

        RETURN v_json;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            prc_log_erro('PKG_VETFLOW_UTIL.FN_PET_TO_JSON', -20101, 'Nome do pet e do tutor são obrigatórios.');
            RAISE_APPLICATION_ERROR(-20101, 'Nome do pet e do tutor são obrigatórios para gerar o JSON.');
        WHEN VALUE_ERROR THEN
            v_err_code := SQLCODE;
            v_err_msg  := SQLERRM;
            prc_log_erro('PKG_VETFLOW_UTIL.FN_PET_TO_JSON', v_err_code, v_err_msg);
            RAISE_APPLICATION_ERROR(-20102, 'Erro de conversão de tipo ao montar o JSON do pet.');
        WHEN OTHERS THEN
            v_err_code := SQLCODE;
            v_err_msg  := SQLERRM;
            prc_log_erro('PKG_VETFLOW_UTIL.FN_PET_TO_JSON', v_err_code, v_err_msg);
            RAISE;
    END FN_PET_TO_JSON;

    -- ========================================================================
    -- FN_CALCULAR_IDADE_MESES (Sprint 3) - idade do pet em meses.
    -- Excecoes: data nula/futura (-20205 -> -20204), VALUE_ERROR (-20206),
    -- OTHERS (log + RAISE).
    -- ========================================================================
    FUNCTION FN_CALCULAR_IDADE_MESES(p_birth_date IN TIMESTAMP) RETURN NUMBER IS
        v_meses NUMBER;

        e_data_invalida EXCEPTION;
        PRAGMA EXCEPTION_INIT(e_data_invalida, -20205);

        v_err_code NUMBER;
        v_err_msg  VARCHAR2(4000);
    BEGIN
        IF p_birth_date IS NULL THEN
            RAISE_APPLICATION_ERROR(-20205, 'Data de nascimento não informada.');
        END IF;

        IF p_birth_date > SYSTIMESTAMP THEN
            RAISE_APPLICATION_ERROR(-20205, 'Data de nascimento não pode ser no futuro.');
        END IF;

        v_meses := MONTHS_BETWEEN(SYSDATE, CAST(p_birth_date AS DATE));

        IF v_meses < 0 THEN
            RAISE VALUE_ERROR;
        END IF;

        RETURN TRUNC(v_meses);
    EXCEPTION
        WHEN e_data_invalida THEN
            v_err_msg := SQLERRM;
            prc_log_erro('PKG_VETFLOW_UTIL.FN_CALCULAR_IDADE_MESES', -20204, v_err_msg);
            RAISE_APPLICATION_ERROR(-20204, 'Data de nascimento inválida: ' || v_err_msg);
        WHEN VALUE_ERROR THEN
            v_err_code := SQLCODE;
            v_err_msg  := SQLERRM;
            prc_log_erro('PKG_VETFLOW_UTIL.FN_CALCULAR_IDADE_MESES', v_err_code, v_err_msg);
            RAISE_APPLICATION_ERROR(-20206, 'Cálculo de idade resultou em valor inválido.');
        WHEN OTHERS THEN
            v_err_code := SQLCODE;
            v_err_msg  := SQLERRM;
            prc_log_erro('PKG_VETFLOW_UTIL.FN_CALCULAR_IDADE_MESES', v_err_code, v_err_msg);
            RAISE;
    END FN_CALCULAR_IDADE_MESES;

    -- ========================================================================
    -- FN_EXPORTAR_DATASET_JSON - dataset completo (formato da secao 5 do
    -- CONTRACT.md). Um objeto { "tutores": [...], "clinicas": [...] }.
    -- Cada elemento e escrito numa linha propria (CHR(10)) para o SPOOL do
    -- SQL*Plus/SQL Developer nunca precisar quebrar uma linha no meio.
    -- ========================================================================
    FUNCTION FN_EXPORTAR_DATASET_JSON RETURN CLOB IS
        c_nl CONSTANT VARCHAR2(1) := CHR(10);

        v_json     CLOB;
        v_prim_tut BOOLEAN := TRUE;
        v_prim_pet BOOLEAN;
        v_prim_sub BOOLEAN;
        v_prim_cli BOOLEAN := TRUE;
        v_err_code NUMBER;
        v_err_msg  VARCHAR2(4000);
    BEGIN
        DBMS_LOB.CREATETEMPORARY(v_json, TRUE);

        prc_append(v_json, '{' || c_nl || '"tutores": [');

        FOR t IN (SELECT "Id", TO_CHAR("Name") AS nome, TO_CHAR("Email") AS email,
                         TO_CHAR("Phone") AS telefone, "Active", "CreatedAt"
                    FROM "CV_Tutors"
                   ORDER BY "Name", "Id") LOOP

            IF NOT v_prim_tut THEN
                prc_append(v_json, ',');
            END IF;
            v_prim_tut := FALSE;

            prc_append(v_json, c_nl || '{"_id":' || fn_str(RAWTOHEX(t."Id"))
                || ',"nome":'     || fn_str(t.nome)
                || ',"email":'    || fn_str(t.email)
                || ',"telefone":' || fn_str(t.telefone)
                || ',"ativo":'    || fn_bool(t."Active")
                || ',"criadoEm":' || fn_data_hora(t."CreatedAt")
                || ',"pets":[');

            v_prim_pet := TRUE;
            FOR p IN (SELECT "Id", TO_CHAR("Name") AS nome, "Species", TO_CHAR("Breed") AS raca,
                             "BirthDate", "WeightKg", "Active"
                        FROM "CV_Pets"
                       WHERE "TutorId" = t."Id"
                       ORDER BY "Name", "Id") LOOP

                IF NOT v_prim_pet THEN
                    prc_append(v_json, ',');
                END IF;
                v_prim_pet := FALSE;

                prc_append(v_json, c_nl || ' {"petId":' || fn_str(RAWTOHEX(p."Id"))
                    || ',"nome":'           || fn_str(p.nome)
                    || ',"especie":'        || fn_str(fn_especie(p."Species"))
                    || ',"raca":'           || fn_str(p.raca)
                    || ',"dataNascimento":' || fn_data(p."BirthDate")
                    || ',"pesoKg":'         || fn_num(p."WeightKg")
                    || ',"idadeMeses":'     || fn_num(FN_CALCULAR_IDADE_MESES(p."BirthDate"))
                    || ',"ativo":'          || fn_bool(p."Active"));

                -- vacinas
                prc_append(v_json, ',' || c_nl || '  "vacinas":[');
                v_prim_sub := TRUE;
                FOR v IN (SELECT "Id", TO_CHAR("VaccineName") AS nome, "AppliedAt", "NextDoseAt",
                                 TO_CHAR("Batch") AS lote
                            FROM "CV_Vaccines"
                           WHERE "PetId" = p."Id"
                           ORDER BY "AppliedAt", "Id") LOOP
                    IF NOT v_prim_sub THEN
                        prc_append(v_json, ',');
                    END IF;
                    v_prim_sub := FALSE;
                    prc_append(v_json, c_nl || '   {"vacinaId":' || fn_str(RAWTOHEX(v."Id"))
                        || ',"nome":'        || fn_str(v.nome)
                        || ',"aplicadaEm":'  || fn_data(v."AppliedAt")
                        || ',"proximaDose":' || fn_data(v."NextDoseAt")
                        || ',"lote":'        || fn_str(v.lote)
                        || '}');
                END LOOP;
                prc_append(v_json, ']');

                -- medicamentos
                prc_append(v_json, ',' || c_nl || '  "medicamentos":[');
                v_prim_sub := TRUE;
                FOR m IN (SELECT "Id", TO_CHAR("Name") AS nome, TO_CHAR("Dosage") AS dosagem,
                                 TO_CHAR("Frequency") AS frequencia, "StartDate", "EndDate", "Status"
                            FROM "CV_Medications"
                           WHERE "PetId" = p."Id"
                           ORDER BY "StartDate", "Id") LOOP
                    IF NOT v_prim_sub THEN
                        prc_append(v_json, ',');
                    END IF;
                    v_prim_sub := FALSE;
                    prc_append(v_json, c_nl || '   {"medicamentoId":' || fn_str(RAWTOHEX(m."Id"))
                        || ',"nome":'       || fn_str(m.nome)
                        || ',"dosagem":'    || fn_str(m.dosagem)
                        || ',"frequencia":' || fn_str(m.frequencia)
                        || ',"inicio":'     || fn_data(m."StartDate")
                        || ',"fim":'        || fn_data(m."EndDate")
                        || ',"status":'     || fn_str(fn_status_medicamento(m."Status"))
                        || '}');
                END LOOP;
                prc_append(v_json, ']');

                -- consultas (com nome da clinica desnormalizado)
                prc_append(v_json, ',' || c_nl || '  "consultas":[');
                v_prim_sub := TRUE;
                FOR ap IN (SELECT a."Id", a."ClinicId", TO_CHAR(c."Name") AS clinica_nome,
                                 a."ScheduledAt", a."Type", TO_CHAR(a."Notes") AS observacoes, a."Completed"
                            FROM "CV_Appointments" a
                            JOIN "CV_Clinics" c ON c."Id" = a."ClinicId"
                           WHERE a."PetId" = p."Id"
                           ORDER BY a."ScheduledAt", a."Id") LOOP
                    IF NOT v_prim_sub THEN
                        prc_append(v_json, ',');
                    END IF;
                    v_prim_sub := FALSE;
                    prc_append(v_json, c_nl || '   {"consultaId":' || fn_str(RAWTOHEX(ap."Id"))
                        || ',"clinicaId":'    || fn_str(RAWTOHEX(ap."ClinicId"))
                        || ',"clinicaNome":'  || fn_str(ap.clinica_nome)
                        || ',"agendadaPara":' || fn_data_hora(ap."ScheduledAt")
                        || ',"tipo":'         || fn_str(fn_tipo_consulta(ap."Type"))
                        || ',"observacoes":'  || fn_str(ap.observacoes)
                        || ',"concluida":'    || fn_bool(ap."Completed")
                        || '}');
                END LOOP;
                prc_append(v_json, ']}');

            END LOOP;  -- pets

            prc_append(v_json, ']}');
        END LOOP;  -- tutores

        prc_append(v_json, c_nl || '],' || c_nl || '"clinicas": [');

        FOR c IN (SELECT "Id", TO_CHAR("Name") AS nome, TO_CHAR("Address") AS endereco,
                         TO_CHAR("Phone") AS telefone, TO_CHAR("Email") AS email, "Active"
                    FROM "CV_Clinics"
                   ORDER BY "Name", "Id") LOOP
            IF NOT v_prim_cli THEN
                prc_append(v_json, ',');
            END IF;
            v_prim_cli := FALSE;
            prc_append(v_json, c_nl || '{"_id":' || fn_str(RAWTOHEX(c."Id"))
                || ',"nome":'     || fn_str(c.nome)
                || ',"endereco":' || fn_str(c.endereco)
                || ',"telefone":' || fn_str(c.telefone)
                || ',"email":'    || fn_str(c.email)
                || ',"ativo":'    || fn_bool(c."Active")
                || '}');
        END LOOP;

        prc_append(v_json, c_nl || ']' || c_nl || '}' || c_nl);

        RETURN v_json;
    EXCEPTION
        WHEN OTHERS THEN
            v_err_code := SQLCODE;
            v_err_msg  := SQLERRM;
            prc_log_erro('PKG_VETFLOW_UTIL.FN_EXPORTAR_DATASET_JSON', v_err_code, v_err_msg);
            RAISE_APPLICATION_ERROR(-20099, 'Erro inesperado ao exportar o dataset JSON: ' || SUBSTR(v_err_msg, 1, 1500));
    END FN_EXPORTAR_DATASET_JSON;

    -- ========================================================================
    -- SP_LISTAR_PETS_JSON (Sprint 3) - JOIN pets x tutores, um JSON por linha
    -- no DBMS_OUTPUT (usa FN_PET_TO_JSON).
    -- Excecoes: NO_DATA_FOUND (aviso), VALUE_ERROR (-20301), OTHERS (log).
    -- ========================================================================
    PROCEDURE SP_LISTAR_PETS_JSON IS
        CURSOR c_pets IS
            SELECT TO_CHAR(p."Name") AS pet_name,
                   p."Species"       AS species,
                   TO_CHAR(p."Breed") AS breed,
                   p."WeightKg"      AS weight,
                   TO_CHAR(t."Name") AS tutor_name
              FROM "CV_Pets" p
              JOIN "CV_Tutors" t ON t."Id" = p."TutorId"
             ORDER BY t."Name", p."Name";

        v_json       VARCHAR2(4000);
        v_total_rows NUMBER := 0;
        v_err_code   NUMBER;
        v_err_msg    VARCHAR2(4000);
    BEGIN
        DBMS_OUTPUT.PUT_LINE('=== PKG_VETFLOW_UTIL.SP_LISTAR_PETS_JSON ===');

        FOR r IN c_pets LOOP
            v_json := FN_PET_TO_JSON(r.pet_name, r.species, r.breed, r.weight, r.tutor_name);
            DBMS_OUTPUT.PUT_LINE(v_json);
            v_total_rows := v_total_rows + 1;
        END LOOP;

        IF v_total_rows = 0 THEN
            RAISE NO_DATA_FOUND;
        END IF;

        DBMS_OUTPUT.PUT_LINE('Total de registros: ' || v_total_rows);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            prc_log_erro('PKG_VETFLOW_UTIL.SP_LISTAR_PETS_JSON', 100, 'Nenhum pet encontrado para gerar JSON.');
            DBMS_OUTPUT.PUT_LINE('Aviso: nenhum registro encontrado.');
        WHEN VALUE_ERROR THEN
            v_err_code := SQLCODE;
            v_err_msg  := SQLERRM;
            prc_log_erro('PKG_VETFLOW_UTIL.SP_LISTAR_PETS_JSON', v_err_code, v_err_msg);
            RAISE_APPLICATION_ERROR(-20301, 'Erro de conversão de tipo ao listar pets.');
        WHEN OTHERS THEN
            v_err_code := SQLCODE;
            v_err_msg  := SQLERRM;
            prc_log_erro('PKG_VETFLOW_UTIL.SP_LISTAR_PETS_JSON', v_err_code, v_err_msg);
            RAISE;
    END SP_LISTAR_PETS_JSON;

    -- ========================================================================
    -- SP_LISTAR_PETS_JSON(p_resultado OUT CLOB) - overload para a aplicacao.
    -- Mesmo JOIN, devolvido como array JSON "[{...},{...}]" (ou "[]").
    -- ========================================================================
    PROCEDURE SP_LISTAR_PETS_JSON(p_resultado OUT CLOB) IS
        v_clob     CLOB;
        v_primeiro BOOLEAN := TRUE;
        v_err_code NUMBER;
        v_err_msg  VARCHAR2(4000);
    BEGIN
        DBMS_LOB.CREATETEMPORARY(v_clob, TRUE);
        prc_append(v_clob, '[');

        FOR r IN (SELECT TO_CHAR(p."Name") AS pet_name,
                         p."Species"       AS species,
                         TO_CHAR(p."Breed") AS breed,
                         p."WeightKg"      AS weight,
                         TO_CHAR(t."Name") AS tutor_name
                    FROM "CV_Pets" p
                    JOIN "CV_Tutors" t ON t."Id" = p."TutorId"
                   ORDER BY t."Name", p."Name") LOOP
            IF NOT v_primeiro THEN
                prc_append(v_clob, ',');
            END IF;
            v_primeiro := FALSE;
            prc_append(v_clob, FN_PET_TO_JSON(r.pet_name, r.species, r.breed, r.weight, r.tutor_name));
        END LOOP;

        prc_append(v_clob, ']');
        p_resultado := v_clob;
    EXCEPTION
        WHEN OTHERS THEN
            v_err_code := SQLCODE;
            v_err_msg  := SQLERRM;
            prc_log_erro('PKG_VETFLOW_UTIL.SP_LISTAR_PETS_JSON(CLOB)', v_err_code, v_err_msg);
            RAISE_APPLICATION_ERROR(-20099, 'Erro inesperado ao listar pets em JSON: ' || SUBSTR(v_err_msg, 1, 1500));
    END SP_LISTAR_PETS_JSON;

END PKG_VETFLOW_UTIL;
/

SHOW ERRORS PACKAGE BODY PKG_VETFLOW_UTIL

PROMPT 03_pkg_util.sql concluido: PKG_VETFLOW_UTIL criado.
