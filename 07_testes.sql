-- ============================================================================
-- VetFlow - Challenge FIAP 2026 (Clyvo Vet)
-- Mastering Relational and Non-Relational Database - Sprint 4
-- 07_testes.sql - testes de sucesso e de excecao de todos os objetos
-- ============================================================================
-- Rodar DEPOIS do 06_seed.sql (usa os dados do seed).
-- Cada teste de excecao e um bloco com EXCEPTION WHEN OTHERS que so imprime
-- o erro (o script segue sem parar). Os testes de sucesso que inserem dados
-- terminam com ROLLBACK TO SAVEPOINT: o seed NAO e alterado. O log de erros
-- (CV_ERROR_LOG) continua gravado porque usa transacao autonoma.
--
-- SQL Developer: executar como script (F5). SQL*Plus: @07_testes.sql
-- ============================================================================

SET DEFINE OFF
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100
COLUMN TUTOR_NAME FORMAT A20
COLUMN PET_NAME   FORMAT A12
COLUMN procedure_nm FORMAT A55
COLUMN error_msg    FORMAT A80
COLUMN valor_antigo FORMAT A60
COLUMN valor_novo   FORMAT A60

PROMPT ===================================================================
PROMPT 1. PKG_VETFLOW_CADASTRO - sucesso (todos os SP_INSERT_* + ROLLBACK)
PROMPT ===================================================================
DECLARE
    v_tutor  RAW(16);
    v_clinic RAW(16);
    v_pet    RAW(16);
    v_id     RAW(16);
BEGIN
    SAVEPOINT sp_teste_cadastro;

    PKG_VETFLOW_CADASTRO.SP_INSERT_TUTOR('Tutor Teste', 'tutor.teste@email.com', '(11) 90000-0000', v_tutor);
    DBMS_OUTPUT.PUT_LINE('SP_INSERT_TUTOR ....... OK id=' || RAWTOHEX(v_tutor));

    PKG_VETFLOW_CADASTRO.SP_INSERT_CLINIC('Clinica Teste', 'Rua Teste, 1 - SP', '(11) 3000-0000', 'teste@clinica.com', v_clinic);
    DBMS_OUTPUT.PUT_LINE('SP_INSERT_CLINIC ...... OK id=' || RAWTOHEX(v_clinic));

    PKG_VETFLOW_CADASTRO.SP_INSERT_PET('Pet Teste', 2, 'Calopsita', TIMESTAMP '2024-01-10 00:00:00', 0.09, v_tutor, v_pet);
    DBMS_OUTPUT.PUT_LINE('SP_INSERT_PET ......... OK id=' || RAWTOHEX(v_pet));

    PKG_VETFLOW_CADASTRO.SP_INSERT_APPOINTMENT(v_pet, v_clinic, SYSTIMESTAMP + INTERVAL '3' DAY, 1, 'Consulta de teste', v_id);
    DBMS_OUTPUT.PUT_LINE('SP_INSERT_APPOINTMENT . OK id=' || RAWTOHEX(v_id));

    PKG_VETFLOW_CADASTRO.SP_INSERT_VACCINE(v_pet, 'Vacina Teste', SYSTIMESTAMP, SYSTIMESTAMP + INTERVAL '365' DAY, 'LOTE-T', v_id);
    DBMS_OUTPUT.PUT_LINE('SP_INSERT_VACCINE ..... OK id=' || RAWTOHEX(v_id));

    PKG_VETFLOW_CADASTRO.SP_INSERT_MEDICATION(v_pet, 'Remedio Teste', '1 gota', 'A cada 24h', SYSTIMESTAMP, SYSTIMESTAMP + INTERVAL '7' DAY, v_id);
    DBMS_OUTPUT.PUT_LINE('SP_INSERT_MEDICATION .. OK id=' || RAWTOHEX(v_id));

    PKG_VETFLOW_CADASTRO.SP_INSERT_USER('Tutor Teste', 'tutor.teste@email.com', '$2a$10$jq2BeYtOaA5O6ff.ct9/i.81Kmb5e4GM9OLRWUdDWQ.otPAtmFnAC', 'tutor', v_tutor, v_id);
    DBMS_OUTPUT.PUT_LINE('SP_INSERT_USER ........ OK id=' || RAWTOHEX(v_id));

    ROLLBACK TO SAVEPOINT sp_teste_cadastro;
    DBMS_OUTPUT.PUT_LINE('ROLLBACK TO SAVEPOINT: dados de teste descartados, seed intacto.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK TO SAVEPOINT sp_teste_cadastro;
        DBMS_OUTPUT.PUT_LINE('FALHA INESPERADA no teste de sucesso: ' || SQLERRM);
END;
/

PROMPT ===================================================================
PROMPT 2. PKG_VETFLOW_CADASTRO - excecoes tratadas (uma por procedure)
PROMPT ===================================================================

-- 2.1 SP_INSERT_TUTOR: e-mail duplicado -> -20001
DECLARE
    v_id RAW(16);
BEGIN
    PKG_VETFLOW_CADASTRO.SP_INSERT_TUTOR('Carlos Duplicado', 'carlos.mendes@email.com', '(11) 90000-0001', v_id);
    DBMS_OUTPUT.PUT_LINE('ERRO: deveria ter falhado');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('SP_INSERT_TUTOR (e-mail duplicado) -> ' || SQLCODE || ' | ' || SQLERRM);
END;
/

-- 2.2 SP_INSERT_CLINIC: nome vazio -> -20002
DECLARE
    v_id RAW(16);
BEGIN
    PKG_VETFLOW_CADASTRO.SP_INSERT_CLINIC('   ', 'Rua X, 1', '(11) 3000-0001', 'x@clinica.com', v_id);
    DBMS_OUTPUT.PUT_LINE('ERRO: deveria ter falhado');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('SP_INSERT_CLINIC (nome vazio) -> ' || SQLCODE || ' | ' || SQLERRM);
END;
/

-- 2.3 SP_INSERT_PET: peso <= 0 -> -20004
DECLARE
    v_tutor RAW(16);
    v_id    RAW(16);
BEGIN
    SELECT "Id" INTO v_tutor FROM "CV_Tutors" WHERE "Email" = 'ana.silva@email.com';
    PKG_VETFLOW_CADASTRO.SP_INSERT_PET('Peso Zero', 0, 'SRD', TIMESTAMP '2022-01-01 00:00:00', 0, v_tutor, v_id);
    DBMS_OUTPUT.PUT_LINE('ERRO: deveria ter falhado');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('SP_INSERT_PET (peso zero) -> ' || SQLCODE || ' | ' || SQLERRM);
END;
/

-- 2.4 SP_INSERT_PET: tutor inexistente -> -20003
DECLARE
    v_id RAW(16);
BEGIN
    PKG_VETFLOW_CADASTRO.SP_INSERT_PET('Sem Dono', 1, 'SRD', TIMESTAMP '2022-01-01 00:00:00', 3.5, SYS_GUID(), v_id);
    DBMS_OUTPUT.PUT_LINE('ERRO: deveria ter falhado');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('SP_INSERT_PET (tutor inexistente) -> ' || SQLCODE || ' | ' || SQLERRM);
END;
/

-- 2.5 SP_INSERT_APPOINTMENT: agendamento no passado -> -20004
DECLARE
    v_pet    RAW(16);
    v_clinic RAW(16);
    v_id     RAW(16);
BEGIN
    SELECT "Id" INTO v_pet    FROM "CV_Pets"    WHERE "Name" = 'Rex';
    SELECT "Id" INTO v_clinic FROM "CV_Clinics" WHERE "Name" = 'Clínica VetSaúde';
    PKG_VETFLOW_CADASTRO.SP_INSERT_APPOINTMENT(v_pet, v_clinic, SYSTIMESTAMP - INTERVAL '2' DAY, 1, 'No passado', v_id);
    DBMS_OUTPUT.PUT_LINE('ERRO: deveria ter falhado');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('SP_INSERT_APPOINTMENT (no passado) -> ' || SQLCODE || ' | ' || SQLERRM);
END;
/

-- 2.6 SP_INSERT_VACCINE: proxima dose antes da aplicacao -> -20004
DECLARE
    v_pet RAW(16);
    v_id  RAW(16);
BEGIN
    SELECT "Id" INTO v_pet FROM "CV_Pets" WHERE "Name" = 'Mia';
    PKG_VETFLOW_CADASTRO.SP_INSERT_VACCINE(v_pet, 'V4', TIMESTAMP '2026-10-01 00:00:00', TIMESTAMP '2026-01-01 00:00:00', 'LOTE-X', v_id);
    DBMS_OUTPUT.PUT_LINE('ERRO: deveria ter falhado');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('SP_INSERT_VACCINE (dose antes da aplicacao) -> ' || SQLCODE || ' | ' || SQLERRM);
END;
/

-- 2.7 SP_INSERT_MEDICATION: pet inexistente -> -20003
DECLARE
    v_id RAW(16);
BEGIN
    PKG_VETFLOW_CADASTRO.SP_INSERT_MEDICATION(SYS_GUID(), 'Dipirona', '1 gota/kg', 'A cada 8h', SYSTIMESTAMP, SYSTIMESTAMP + INTERVAL '3' DAY, v_id);
    DBMS_OUTPUT.PUT_LINE('ERRO: deveria ter falhado');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('SP_INSERT_MEDICATION (pet inexistente) -> ' || SQLCODE || ' | ' || SQLERRM);
END;
/

-- 2.8 SP_INSERT_MEDICATION: data fim antes do inicio -> -20004
DECLARE
    v_pet RAW(16);
    v_id  RAW(16);
BEGIN
    SELECT "Id" INTO v_pet FROM "CV_Pets" WHERE "Name" = 'Thor';
    PKG_VETFLOW_CADASTRO.SP_INSERT_MEDICATION(v_pet, 'Dipirona', '1 gota/kg', 'A cada 8h', SYSTIMESTAMP, SYSTIMESTAMP - INTERVAL '3' DAY, v_id);
    DBMS_OUTPUT.PUT_LINE('ERRO: deveria ter falhado');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('SP_INSERT_MEDICATION (fim antes do inicio) -> ' || SQLCODE || ' | ' || SQLERRM);
END;
/

-- 2.9 SP_INSERT_USER: role invalida -> -20004
DECLARE
    v_id RAW(16);
BEGIN
    PKG_VETFLOW_CADASTRO.SP_INSERT_USER('Hacker', 'admin@vetflow.com', '$2a$10$hash', 'ADMIN', NULL, v_id);
    DBMS_OUTPUT.PUT_LINE('ERRO: deveria ter falhado');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('SP_INSERT_USER (role invalida) -> ' || SQLCODE || ' | ' || SQLERRM);
END;
/

-- 2.10 SP_INSERT_USER: e-mail duplicado -> -20001
DECLARE
    v_id RAW(16);
BEGIN
    PKG_VETFLOW_CADASTRO.SP_INSERT_USER('Outro Vet', 'vet@vetflow.com', '$2a$10$hash', 'VET', NULL, v_id);
    DBMS_OUTPUT.PUT_LINE('ERRO: deveria ter falhado');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('SP_INSERT_USER (e-mail duplicado) -> ' || SQLCODE || ' | ' || SQLERRM);
END;
/

PROMPT ===================================================================
PROMPT 3. PKG_VETFLOW_UTIL
PROMPT ===================================================================

-- 3.1 FN_PET_TO_JSON - sucesso (com aspas no nome para provar o escape)
SELECT PKG_VETFLOW_UTIL.FN_PET_TO_JSON('Rex "Bravo"', 0, 'Labrador', 28.5, 'Carlos Mendes') AS json_pet FROM DUAL;

-- 3.2 FN_PET_TO_JSON - excecao (nome nulo -> -20101)
BEGIN
    DBMS_OUTPUT.PUT_LINE(PKG_VETFLOW_UTIL.FN_PET_TO_JSON(NULL, 0, 'SRD', 1, 'Ninguem'));
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('FN_PET_TO_JSON (nome nulo) -> ' || SQLCODE || ' | ' || SQLERRM);
END;
/

-- 3.3 FN_CALCULAR_IDADE_MESES - sucesso
SELECT TO_CHAR(p."Name") AS pet, PKG_VETFLOW_UTIL.FN_CALCULAR_IDADE_MESES(p."BirthDate") AS idade_meses
  FROM "CV_Pets" p
 ORDER BY p."Name";

-- 3.4 FN_CALCULAR_IDADE_MESES - excecao (data futura -> -20204)
BEGIN
    DBMS_OUTPUT.PUT_LINE(PKG_VETFLOW_UTIL.FN_CALCULAR_IDADE_MESES(SYSTIMESTAMP + INTERVAL '30' DAY));
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('FN_CALCULAR_IDADE_MESES (data futura) -> ' || SQLCODE || ' | ' || SQLERRM);
END;
/

-- 3.5 SP_LISTAR_PETS_JSON (DBMS_OUTPUT) - sucesso
EXEC PKG_VETFLOW_UTIL.SP_LISTAR_PETS_JSON;

-- 3.6 SP_LISTAR_PETS_JSON (OUT CLOB) - sucesso
DECLARE
    v_json CLOB;
BEGIN
    PKG_VETFLOW_UTIL.SP_LISTAR_PETS_JSON(v_json);
    DBMS_OUTPUT.PUT_LINE('Tamanho do array JSON: ' || DBMS_LOB.GETLENGTH(v_json) || ' caracteres');
    DBMS_OUTPUT.PUT_LINE(DBMS_LOB.SUBSTR(v_json, 3000, 1));
END;
/

-- 3.7 SP_LISTAR_PETS_JSON - caminho de excecao tratada (sem pets -> aviso
--     "nenhum registro" + log em CV_ERROR_LOG). Apaga os pets dentro de um
--     SAVEPOINT e desfaz em seguida.
BEGIN
    SAVEPOINT sp_sem_pets;
    DELETE FROM "CV_Pets";
    PKG_VETFLOW_UTIL.SP_LISTAR_PETS_JSON;
    ROLLBACK TO SAVEPOINT sp_sem_pets;
    DBMS_OUTPUT.PUT_LINE('ROLLBACK TO SAVEPOINT: pets restaurados.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK TO SAVEPOINT sp_sem_pets;
        DBMS_OUTPUT.PUT_LINE('SP_LISTAR_PETS_JSON (sem pets) -> ' || SQLCODE || ' | ' || SQLERRM);
END;
/

-- 3.8 FN_EXPORTAR_DATASET_JSON - sucesso (inicio do CLOB)
DECLARE
    v_json CLOB;
BEGIN
    v_json := PKG_VETFLOW_UTIL.FN_EXPORTAR_DATASET_JSON;
    DBMS_OUTPUT.PUT_LINE('Dataset JSON gerado: ' || DBMS_LOB.GETLENGTH(v_json) || ' caracteres');
    DBMS_OUTPUT.PUT_LINE(DBMS_LOB.SUBSTR(v_json, 1500, 1));
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('FN_EXPORTAR_DATASET_JSON -> ' || SQLCODE || ' | ' || SQLERRM);
END;
/

-- 3.9 FN_EXPORTAR_DATASET_JSON - base vazia gera arrays vazios ([]),
--     nao erro. Apaga tudo dentro de SAVEPOINT e desfaz.
DECLARE
    v_json CLOB;
BEGIN
    SAVEPOINT sp_base_vazia;
    DELETE FROM "CV_Users";
    DELETE FROM "CV_Tutors";
    DELETE FROM "CV_Clinics";
    v_json := PKG_VETFLOW_UTIL.FN_EXPORTAR_DATASET_JSON;
    DBMS_OUTPUT.PUT_LINE('Dataset com base vazia: ' || REPLACE(DBMS_LOB.SUBSTR(v_json, 200, 1), CHR(10), ' '));
    ROLLBACK TO SAVEPOINT sp_base_vazia;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK TO SAVEPOINT sp_base_vazia;
        DBMS_OUTPUT.PUT_LINE('FN_EXPORTAR_DATASET_JSON (base vazia) -> ' || SQLCODE || ' | ' || SQLERRM);
END;
/

PROMPT ===================================================================
PROMPT 4. PKG_VETFLOW_RELATORIOS
PROMPT ===================================================================

-- 4.1 SP_RELATORIO_PESO_POR_TUTOR (DBMS_OUTPUT) - sucesso
--     Carlos Mendes / especie 0 = Rex (28.5) + Thor (32.0) = 60.50
EXEC PKG_VETFLOW_RELATORIOS.SP_RELATORIO_PESO_POR_TUTOR;

-- 4.2 SP_RELATORIO_PESO_POR_TUTOR (DBMS_OUTPUT) - caminho de excecao
--     tratada (sem pets -> aviso + log)
BEGIN
    SAVEPOINT sp_sem_pets_rel;
    DELETE FROM "CV_Pets";
    PKG_VETFLOW_RELATORIOS.SP_RELATORIO_PESO_POR_TUTOR;
    ROLLBACK TO SAVEPOINT sp_sem_pets_rel;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK TO SAVEPOINT sp_sem_pets_rel;
        DBMS_OUTPUT.PUT_LINE('SP_RELATORIO_PESO_POR_TUTOR (sem pets) -> ' || SQLCODE || ' | ' || SQLERRM);
END;
/

-- 4.3 SP_RELATORIO_PESO_POR_TUTOR (OUT SYS_REFCURSOR) - sucesso
VARIABLE rc REFCURSOR
EXEC PKG_VETFLOW_RELATORIOS.SP_RELATORIO_PESO_POR_TUTOR(:rc);
PRINT rc

-- 4.4 SP_RESUMO_CLINICO (OUT SYS_REFCURSOR) - sucesso
VARIABLE rc2 REFCURSOR
EXEC PKG_VETFLOW_RELATORIOS.SP_RESUMO_CLINICO(:rc2);
PRINT rc2

-- 4.5 SP_RESUMO_CLINICO - consumindo o cursor em PL/SQL (sucesso, com
--     alerta de vacinas vencidas) e, no bloco seguinte, excecao tratada
--     (FETCH com numero de variaveis incompativel)
DECLARE
    v_cur  SYS_REFCURSOR;
    v_qtd  NUMBER := 0;
    v_pet_id RAW(16);
    v_pet_name VARCHAR2(100);
    v_species NUMBER;
    v_tutor VARCHAR2(100);
    v_idade NUMBER;
    v_tot_vac NUMBER;
    v_venc NUMBER;
    v_med NUMBER;
    v_prox TIMESTAMP;
BEGIN
    PKG_VETFLOW_RELATORIOS.SP_RESUMO_CLINICO(v_cur);
    LOOP
        FETCH v_cur INTO v_pet_id, v_pet_name, v_species, v_tutor, v_idade, v_tot_vac, v_venc, v_med, v_prox;
        EXIT WHEN v_cur%NOTFOUND;
        v_qtd := v_qtd + 1;
        IF v_venc > 0 THEN
            DBMS_OUTPUT.PUT_LINE('ALERTA: ' || v_pet_name || ' (' || v_tutor || ') tem ' || v_venc || ' vacina(s) vencida(s).');
        END IF;
    END LOOP;
    CLOSE v_cur;
    DBMS_OUTPUT.PUT_LINE('SP_RESUMO_CLINICO: ' || v_qtd || ' pets ativos lidos do cursor.');
EXCEPTION
    WHEN OTHERS THEN
        IF v_cur%ISOPEN THEN
            CLOSE v_cur;
        END IF;
        DBMS_OUTPUT.PUT_LINE('SP_RESUMO_CLINICO (leitura) -> ' || SQLCODE || ' | ' || SQLERRM);
END;
/

DECLARE
    v_cur   SYS_REFCURSOR;
    v_unico NUMBER;
BEGIN
    PKG_VETFLOW_RELATORIOS.SP_RESUMO_CLINICO(v_cur);
    -- 9 colunas no cursor, 1 variavel no FETCH -> ORA-06504/ORA-00932 tratado
    FETCH v_cur INTO v_unico;
    CLOSE v_cur;
    DBMS_OUTPUT.PUT_LINE('ERRO: deveria ter falhado');
EXCEPTION
    WHEN OTHERS THEN
        IF v_cur%ISOPEN THEN
            CLOSE v_cur;
        END IF;
        DBMS_OUTPUT.PUT_LINE('SP_RESUMO_CLINICO (FETCH incompativel) -> ' || SQLCODE || ' | ' || SQLERRM);
END;
/

PROMPT ===================================================================
PROMPT 5. PKG_VETFLOW_AUDITORIA + TRG_AUDITORIA_CV_PETS
PROMPT ===================================================================

-- 5.1 Sucesso: INSERT/UPDATE/DELETE de um pet geram 3 linhas de auditoria.
--     A auditoria roda na mesma transacao: para deixar evidencia, este
--     bloco faz COMMIT do ciclo completo (o pet de teste e removido no
--     proprio bloco, entao o seed continua com os mesmos 6 pets).
DECLARE
    v_tutor RAW(16);
    v_pet   RAW(16);
BEGIN
    SELECT "Id" INTO v_tutor FROM "CV_Tutors" WHERE "Email" = 'marcos.rocha@email.com';
    PKG_VETFLOW_CADASTRO.SP_INSERT_PET('Pet Auditoria', 3, 'Mini Lop', TIMESTAMP '2025-05-05 00:00:00', 1.8, v_tutor, v_pet);
    UPDATE "CV_Pets" SET "WeightKg" = 2.1 WHERE "Id" = v_pet;
    DELETE FROM "CV_Pets" WHERE "Id" = v_pet;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Trigger: INSERT, UPDATE e DELETE auditados para "Pet Auditoria".');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Trigger (ciclo completo) -> ' || SQLCODE || ' | ' || SQLERRM);
END;
/

-- 5.2 Excecao tratada: operacao invalida chamada direto no pacote. A
--     procedure NAO propaga (auditoria nunca derruba o DML); o erro -20004
--     fica registrado em CV_ERROR_LOG.
BEGIN
    PKG_VETFLOW_AUDITORIA.SP_REGISTRAR_AUDITORIA_PET('MERGE', 'x', 'y');
    DBMS_OUTPUT.PUT_LINE('SP_REGISTRAR_AUDITORIA_PET (operacao invalida) -> tratada sem propagar; ver CV_ERROR_LOG.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('SP_REGISTRAR_AUDITORIA_PET -> ' || SQLCODE || ' | ' || SQLERRM);
END;
/

PROMPT ===================================================================
PROMPT 6. Evidencias: CV_PETS_AUDITORIA e CV_ERROR_LOG
PROMPT ===================================================================

SELECT id_auditoria, nm_usuario, tp_operacao,
       TO_CHAR(dt_operacao, 'DD/MM/YYYY HH24:MI:SS') AS dt_operacao,
       valor_antigo, valor_novo
  FROM CV_PETS_AUDITORIA
 ORDER BY id_auditoria;

SELECT id, procedure_nm, error_code,
       TO_CHAR(error_date, 'DD/MM/YYYY HH24:MI:SS') AS error_date,
       error_msg
  FROM CV_ERROR_LOG
 ORDER BY id;

-- Garante que nenhum dado de teste ficou pendente
ROLLBACK;

PROMPT 07_testes.sql concluido.
