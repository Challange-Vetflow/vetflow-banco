-- ============================================================================
-- VetFlow - Challenge FIAP 2026 (Clyvo Vet)
-- Mastering Relational and Non-Relational Database - Sprint 4
-- 04_pkg_relatorios.sql - PKG_VETFLOW_RELATORIOS
-- ============================================================================
--   SP_RELATORIO_PESO_POR_TUTOR ............. relatorio da Sprint 3 em
--       DBMS_OUTPUT (soma manual por Tutor+Especie, subtotal e total geral,
--       sem ROLLUP/CUBE/GROUPING SETS)
--   SP_RELATORIO_PESO_POR_TUTOR(p_cursor) ... overload para a aplicacao
--       (pagina "Relatorios" do Java). Colunas:
--       TUTOR_NAME, SPECIES, TOTAL_WEIGHT, TOTAL_PETS
--       (uma linha por tutor+especie, ordenado; a app soma os subtotais)
--   SP_RESUMO_CLINICO(p_cursor) ............. dashboard do Java. Uma linha
--       por pet ativo. Colunas: PET_ID, PET_NAME, SPECIES, TUTOR_NAME,
--       IDADE_MESES, TOTAL_VACINAS, VACINAS_VENCIDAS, MEDICAMENTOS_ATIVOS,
--       PROXIMA_CONSULTA
--
-- Pre-requisito: 03_pkg_util.sql (usa PKG_VETFLOW_UTIL.FN_CALCULAR_IDADE_MESES)
-- ============================================================================

SET DEFINE OFF
SET SERVEROUTPUT ON

CREATE OR REPLACE PACKAGE PKG_VETFLOW_RELATORIOS AS

    PROCEDURE SP_RELATORIO_PESO_POR_TUTOR;

    PROCEDURE SP_RELATORIO_PESO_POR_TUTOR(p_cursor OUT SYS_REFCURSOR);

    PROCEDURE SP_RESUMO_CLINICO(p_cursor OUT SYS_REFCURSOR);

END PKG_VETFLOW_RELATORIOS;
/

CREATE OR REPLACE PACKAGE BODY PKG_VETFLOW_RELATORIOS AS

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

    -- ========================================================================
    -- SP_RELATORIO_PESO_POR_TUTOR (Sprint 3) - DBMS_OUTPUT
    -- Passo 1: agrupa manualmente por (Tutor, Especie) numa tabela
    -- associativa INDEX BY. Passo 2: imprime em ordem com subtotal por tutor
    -- e total geral.
    -- Excecoes: NO_DATA_FOUND (aviso), VALUE_ERROR (-20402), OTHERS (log).
    -- ========================================================================
    PROCEDURE SP_RELATORIO_PESO_POR_TUTOR IS
        CURSOR c_pets IS
            SELECT TO_CHAR(t."Name") AS tutor_name,
                   p."Species"       AS species,
                   p."WeightKg"      AS weight
              FROM "CV_Pets" p
              JOIN "CV_Tutors" t ON t."Id" = p."TutorId"
             ORDER BY t."Name", p."Species";

        -- Chave de agrupamento manual: "NomeTutor|Especie" -> soma de peso
        TYPE t_grupo_peso IS TABLE OF NUMBER INDEX BY VARCHAR2(250);
        v_grupos t_grupo_peso;

        v_chave         VARCHAR2(250);
        v_chave_idx     VARCHAR2(250);
        v_tutor_atual   VARCHAR2(200);
        v_especie_atual NUMBER;

        v_prev_tutor    VARCHAR2(200) := NULL;
        v_subtotal_peso NUMBER := 0;
        v_total_geral   NUMBER := 0;
        v_linhas        NUMBER := 0;
        v_err_code      NUMBER;
        v_err_msg       VARCHAR2(4000);
    BEGIN
        DBMS_OUTPUT.PUT_LINE('=== PKG_VETFLOW_RELATORIOS.SP_RELATORIO_PESO_POR_TUTOR ===');
        DBMS_OUTPUT.PUT_LINE(RPAD('TUTOR', 20) || RPAD('ESPECIE', 10) || 'PESO_TOTAL');
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 45, '-'));

        FOR r IN c_pets LOOP
            v_linhas := v_linhas + 1;
            v_chave  := r.tutor_name || '|' || TO_CHAR(r.species);

            IF v_grupos.EXISTS(v_chave) THEN
                v_grupos(v_chave) := v_grupos(v_chave) + r.weight;
            ELSE
                v_grupos(v_chave) := r.weight;
            END IF;
        END LOOP;

        IF v_linhas = 0 THEN
            RAISE NO_DATA_FOUND;
        END IF;

        v_chave_idx := v_grupos.FIRST;
        WHILE v_chave_idx IS NOT NULL LOOP
            v_tutor_atual   := SUBSTR(v_chave_idx, 1, INSTR(v_chave_idx, '|') - 1);
            v_especie_atual := TO_NUMBER(SUBSTR(v_chave_idx, INSTR(v_chave_idx, '|') + 1));

            IF v_prev_tutor IS NOT NULL AND v_prev_tutor != v_tutor_atual THEN
                DBMS_OUTPUT.PUT_LINE(RPAD(' ', 30) || 'Sub Total: ' || TO_CHAR(v_subtotal_peso, 'FM999990.00'));
                v_total_geral   := v_total_geral + v_subtotal_peso;
                v_subtotal_peso := 0;
            END IF;

            DBMS_OUTPUT.PUT_LINE(
                RPAD(v_tutor_atual, 20) ||
                RPAD(TO_CHAR(v_especie_atual), 10) ||
                TO_CHAR(v_grupos(v_chave_idx), 'FM999990.00')
            );

            v_subtotal_peso := v_subtotal_peso + v_grupos(v_chave_idx);
            v_prev_tutor    := v_tutor_atual;
            v_chave_idx     := v_grupos.NEXT(v_chave_idx);
        END LOOP;

        IF v_prev_tutor IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE(RPAD(' ', 30) || 'Sub Total: ' || TO_CHAR(v_subtotal_peso, 'FM999990.00'));
            v_total_geral := v_total_geral + v_subtotal_peso;
        END IF;

        DBMS_OUTPUT.PUT_LINE(RPAD(' ', 30) || 'Total Geral: ' || TO_CHAR(v_total_geral, 'FM999990.00'));
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            prc_log_erro('PKG_VETFLOW_RELATORIOS.SP_RELATORIO_PESO_POR_TUTOR', 100, 'Nenhum pet encontrado para o relatório.');
            DBMS_OUTPUT.PUT_LINE('Aviso: nenhum registro encontrado.');
        WHEN VALUE_ERROR THEN
            v_err_code := SQLCODE;
            v_err_msg  := SQLERRM;
            prc_log_erro('PKG_VETFLOW_RELATORIOS.SP_RELATORIO_PESO_POR_TUTOR', v_err_code, v_err_msg);
            RAISE_APPLICATION_ERROR(-20402, 'Erro de conversão numérica ao montar a chave de agrupamento.');
        WHEN OTHERS THEN
            v_err_code := SQLCODE;
            v_err_msg  := SQLERRM;
            prc_log_erro('PKG_VETFLOW_RELATORIOS.SP_RELATORIO_PESO_POR_TUTOR', v_err_code, v_err_msg);
            RAISE;
    END SP_RELATORIO_PESO_POR_TUTOR;

    -- ========================================================================
    -- SP_RELATORIO_PESO_POR_TUTOR(p_cursor) - overload para a aplicacao
    -- ========================================================================
    PROCEDURE SP_RELATORIO_PESO_POR_TUTOR(p_cursor OUT SYS_REFCURSOR) IS
        v_err_code NUMBER;
        v_err_msg  VARCHAR2(4000);
    BEGIN
        OPEN p_cursor FOR
            SELECT TO_CHAR(t."Name")                  AS TUTOR_NAME,
                   p."Species"                        AS SPECIES,
                   CAST(SUM(p."WeightKg") AS NUMBER)  AS TOTAL_WEIGHT,
                   COUNT(*)                           AS TOTAL_PETS
              FROM "CV_Pets" p
              JOIN "CV_Tutors" t ON t."Id" = p."TutorId"
             GROUP BY t."Name", p."Species"
             ORDER BY t."Name", p."Species";
    EXCEPTION
        WHEN OTHERS THEN
            v_err_code := SQLCODE;
            v_err_msg  := SQLERRM;
            prc_log_erro('PKG_VETFLOW_RELATORIOS.SP_RELATORIO_PESO_POR_TUTOR(CURSOR)', v_err_code, v_err_msg);
            RAISE_APPLICATION_ERROR(-20099, 'Erro inesperado no relatório de peso por tutor: ' || SUBSTR(v_err_msg, 1, 1500));
    END SP_RELATORIO_PESO_POR_TUTOR;

    -- ========================================================================
    -- SP_RESUMO_CLINICO(p_cursor) - dashboard (uma linha por pet ativo)
    -- ========================================================================
    PROCEDURE SP_RESUMO_CLINICO(p_cursor OUT SYS_REFCURSOR) IS
        v_err_code NUMBER;
        v_err_msg  VARCHAR2(4000);
    BEGIN
        OPEN p_cursor FOR
            SELECT p."Id"                                                  AS PET_ID,
                   TO_CHAR(p."Name")                                       AS PET_NAME,
                   p."Species"                                             AS SPECIES,
                   TO_CHAR(t."Name")                                       AS TUTOR_NAME,
                   PKG_VETFLOW_UTIL.FN_CALCULAR_IDADE_MESES(p."BirthDate") AS IDADE_MESES,
                   (SELECT COUNT(*)
                      FROM "CV_Vaccines" v
                     WHERE v."PetId" = p."Id"
                       AND v."Active" = 1)                                 AS TOTAL_VACINAS,
                   (SELECT COUNT(*)
                      FROM "CV_Vaccines" v
                     WHERE v."PetId" = p."Id"
                       AND v."Active" = 1
                       AND v."NextDoseAt" < SYSTIMESTAMP)                  AS VACINAS_VENCIDAS,
                   (SELECT COUNT(*)
                      FROM "CV_Medications" m
                     WHERE m."PetId" = p."Id"
                       AND m."Active" = 1
                       AND m."Status" = 0)                                 AS MEDICAMENTOS_ATIVOS,
                   (SELECT MIN(a."ScheduledAt")
                      FROM "CV_Appointments" a
                     WHERE a."PetId" = p."Id"
                       AND a."Active" = 1
                       AND a."Completed" = 0
                       AND a."ScheduledAt" > SYSTIMESTAMP)                 AS PROXIMA_CONSULTA
              FROM "CV_Pets" p
              JOIN "CV_Tutors" t ON t."Id" = p."TutorId"
             WHERE p."Active" = 1
             ORDER BY t."Name", p."Name";
    EXCEPTION
        WHEN OTHERS THEN
            v_err_code := SQLCODE;
            v_err_msg  := SQLERRM;
            prc_log_erro('PKG_VETFLOW_RELATORIOS.SP_RESUMO_CLINICO', v_err_code, v_err_msg);
            RAISE_APPLICATION_ERROR(-20099, 'Erro inesperado no resumo clínico: ' || SUBSTR(v_err_msg, 1, 1500));
    END SP_RESUMO_CLINICO;

END PKG_VETFLOW_RELATORIOS;
/

SHOW ERRORS PACKAGE BODY PKG_VETFLOW_RELATORIOS

PROMPT 04_pkg_relatorios.sql concluido: PKG_VETFLOW_RELATORIOS criado.
