-- ============================================================================
-- VetFlow - Challenge FIAP 2026 (Clyvo Vet)
-- Mastering Relational and Non-Relational Database - Sprint 4
-- 02_pkg_cadastro.sql - PKG_VETFLOW_CADASTRO
-- ============================================================================
-- Empacota as procedures de insercao da Sprint 3 (antes avulsas), agora com:
--   * id gerado por SYS_GUID() e devolvido em p_id OUT RAW;
--   * validacoes de negocio com RAISE_APPLICATION_ERROR padronizado;
--   * log de TODOS os erros em CV_ERROR_LOG por uma procedure privada com
--     PRAGMA AUTONOMOUS_TRANSACTION (o log fica gravado mesmo se a aplicacao
--     fizer ROLLBACK);
--   * SEM COMMIT: quem controla a transacao e a aplicacao (Java/.NET) ou o
--     bloco que chamou (seed/testes).
--
-- Codigos de erro (contrato com as aplicacoes):
--   -20001 e-mail duplicado (tutor/usuario) ............... HTTP 409
--   -20002 campo obrigatorio nulo/vazio ..................... HTTP 400
--   -20003 registro referenciado nao existe ................. HTTP 404
--   -20004 regra de negocio violada ......................... HTTP 400
--   -20099 erro inesperado (OTHERS, depois de logar) ........ HTTP 500
--
-- Pre-requisito: tabelas CV_* (01_ddl.sql ou EF Core) e CV_ERROR_LOG
-- (01b_tabelas_apoio.sql).
-- ============================================================================

SET DEFINE OFF
SET SERVEROUTPUT ON

CREATE OR REPLACE PACKAGE PKG_VETFLOW_CADASTRO AS

    -- Codigos de erro publicos (as aplicacoes traduzem para HTTP)
    c_err_email_duplicado CONSTANT PLS_INTEGER := -20001;
    c_err_obrigatorio     CONSTANT PLS_INTEGER := -20002;
    c_err_nao_encontrado  CONSTANT PLS_INTEGER := -20003;
    c_err_regra_negocio   CONSTANT PLS_INTEGER := -20004;
    c_err_inesperado      CONSTANT PLS_INTEGER := -20099;

    PROCEDURE SP_INSERT_TUTOR(p_name IN NVARCHAR2, p_email IN NVARCHAR2, p_phone IN NVARCHAR2, p_id OUT RAW);

    PROCEDURE SP_INSERT_CLINIC(p_name IN NVARCHAR2, p_address IN NVARCHAR2, p_phone IN NVARCHAR2, p_email IN NVARCHAR2, p_id OUT RAW);

    PROCEDURE SP_INSERT_PET(p_name IN NVARCHAR2, p_species IN NUMBER, p_breed IN NVARCHAR2, p_birth_date IN TIMESTAMP, p_weight_kg IN BINARY_DOUBLE, p_tutor_id IN RAW, p_id OUT RAW);

    PROCEDURE SP_INSERT_APPOINTMENT(p_pet_id IN RAW, p_clinic_id IN RAW, p_scheduled_at IN TIMESTAMP, p_type IN NUMBER, p_notes IN NVARCHAR2, p_id OUT RAW);

    PROCEDURE SP_INSERT_VACCINE(p_pet_id IN RAW, p_vaccine_name IN NVARCHAR2, p_applied_at IN TIMESTAMP, p_next_dose_at IN TIMESTAMP, p_batch IN NVARCHAR2, p_id OUT RAW);

    PROCEDURE SP_INSERT_MEDICATION(p_pet_id IN RAW, p_name IN NVARCHAR2, p_dosage IN NVARCHAR2, p_frequency IN NVARCHAR2, p_start_date IN TIMESTAMP, p_end_date IN TIMESTAMP, p_id OUT RAW);

    PROCEDURE SP_INSERT_USER(p_name IN NVARCHAR2, p_email IN NVARCHAR2, p_password_hash IN NVARCHAR2, p_role IN NVARCHAR2, p_tutor_id IN RAW, p_id OUT RAW);

END PKG_VETFLOW_CADASTRO;
/

CREATE OR REPLACE PACKAGE BODY PKG_VETFLOW_CADASTRO AS

    -- ------------------------------------------------------------------------
    -- PRIVADO: grava o erro em CV_ERROR_LOG numa transacao autonoma.
    -- O COMMIT aqui afeta SO esta transacao autonoma, nunca a da aplicacao.
    -- ------------------------------------------------------------------------
    PROCEDURE prc_log_erro(p_procedure IN VARCHAR2, p_code IN NUMBER, p_msg IN VARCHAR2) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO CV_ERROR_LOG (procedure_nm, user_nm, error_code, error_msg)
        VALUES (SUBSTR(p_procedure, 1, 100), SUBSTR(USER, 1, 100), p_code, SUBSTR(p_msg, 1, 4000));
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            -- falha ao logar nunca pode esconder o erro original
            ROLLBACK;
    END prc_log_erro;

    -- ------------------------------------------------------------------------
    -- PRIVADO: loga e lanca um erro de negocio (-20001..-20004).
    -- ------------------------------------------------------------------------
    PROCEDURE prc_falhar(p_procedure IN VARCHAR2, p_code IN PLS_INTEGER, p_msg IN VARCHAR2) IS
    BEGIN
        prc_log_erro(p_procedure, p_code, p_msg);
        RAISE_APPLICATION_ERROR(p_code, p_msg);
    END prc_falhar;

    -- ------------------------------------------------------------------------
    -- PRIVADO: tratamento comum do WHEN OTHERS.
    -- Erros de negocio ja logados (-20001..-20004) sao repassados como estao;
    -- qualquer outro erro e logado e convertido em -20099.
    -- ------------------------------------------------------------------------
    PROCEDURE prc_tratar_outros(p_procedure IN VARCHAR2, p_code IN NUMBER, p_msg IN VARCHAR2) IS
    BEGIN
        IF p_code IN (c_err_email_duplicado, c_err_obrigatorio, c_err_nao_encontrado, c_err_regra_negocio) THEN
            RAISE_APPLICATION_ERROR(p_code, REGEXP_REPLACE(p_msg, '^ORA-[0-9]+: ', ''));
        END IF;
        prc_log_erro(p_procedure, p_code, p_msg);
        RAISE_APPLICATION_ERROR(c_err_inesperado, 'Erro inesperado em ' || p_procedure || ': ' || SUBSTR(p_msg, 1, 1500));
    END prc_tratar_outros;

    -- ------------------------------------------------------------------------
    -- PRIVADO: texto nulo ou so com espacos
    -- ------------------------------------------------------------------------
    FUNCTION fn_vazio(p_valor IN NVARCHAR2) RETURN BOOLEAN IS
    BEGIN
        RETURN p_valor IS NULL OR TRIM(p_valor) IS NULL;
    END fn_vazio;

    -- ------------------------------------------------------------------------
    -- PRIVADO: verificacoes de existencia (FK) - evitam ORA-02291 generico
    -- ------------------------------------------------------------------------
    FUNCTION fn_tutor_existe(p_id IN RAW) RETURN BOOLEAN IS
        v_qtd NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_qtd FROM "CV_Tutors" WHERE "Id" = p_id;
        RETURN v_qtd > 0;
    END fn_tutor_existe;

    FUNCTION fn_pet_existe(p_id IN RAW) RETURN BOOLEAN IS
        v_qtd NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_qtd FROM "CV_Pets" WHERE "Id" = p_id;
        RETURN v_qtd > 0;
    END fn_pet_existe;

    FUNCTION fn_clinica_existe(p_id IN RAW) RETURN BOOLEAN IS
        v_qtd NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_qtd FROM "CV_Clinics" WHERE "Id" = p_id;
        RETURN v_qtd > 0;
    END fn_clinica_existe;

    -- ========================================================================
    -- SP_INSERT_TUTOR
    -- ========================================================================
    PROCEDURE SP_INSERT_TUTOR(p_name IN NVARCHAR2, p_email IN NVARCHAR2, p_phone IN NVARCHAR2, p_id OUT RAW) IS
        c_proc CONSTANT VARCHAR2(60) := 'PKG_VETFLOW_CADASTRO.SP_INSERT_TUTOR';
        v_id   RAW(16);
        v_qtd  NUMBER;
        v_code NUMBER;
        v_msg  VARCHAR2(4000);
    BEGIN
        IF fn_vazio(p_name) THEN
            prc_falhar(c_proc, c_err_obrigatorio, 'Nome do tutor é obrigatório.');
        END IF;
        IF fn_vazio(p_email) THEN
            prc_falhar(c_proc, c_err_obrigatorio, 'E-mail do tutor é obrigatório.');
        END IF;
        IF fn_vazio(p_phone) THEN
            prc_falhar(c_proc, c_err_obrigatorio, 'Telefone do tutor é obrigatório.');
        END IF;

        SELECT COUNT(*) INTO v_qtd FROM "CV_Tutors" WHERE LOWER("Email") = LOWER(TRIM(p_email));
        IF v_qtd > 0 THEN
            prc_falhar(c_proc, c_err_email_duplicado, 'E-mail já cadastrado: ' || p_email);
        END IF;

        v_id := SYS_GUID();
        INSERT INTO "CV_Tutors" ("Id", "Name", "Email", "Phone", "Active", "CreatedAt")
        VALUES (v_id, TRIM(p_name), TRIM(p_email), TRIM(p_phone), 1, SYSTIMESTAMP);

        p_id := v_id;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            prc_falhar(c_proc, c_err_email_duplicado, 'E-mail já cadastrado: ' || p_email);
        WHEN OTHERS THEN
            v_code := SQLCODE;
            v_msg  := SQLERRM;
            prc_tratar_outros(c_proc, v_code, v_msg);
    END SP_INSERT_TUTOR;

    -- ========================================================================
    -- SP_INSERT_CLINIC
    -- ========================================================================
    PROCEDURE SP_INSERT_CLINIC(p_name IN NVARCHAR2, p_address IN NVARCHAR2, p_phone IN NVARCHAR2, p_email IN NVARCHAR2, p_id OUT RAW) IS
        c_proc CONSTANT VARCHAR2(60) := 'PKG_VETFLOW_CADASTRO.SP_INSERT_CLINIC';
        v_id   RAW(16);
        v_code NUMBER;
        v_msg  VARCHAR2(4000);
    BEGIN
        IF fn_vazio(p_name) THEN
            prc_falhar(c_proc, c_err_obrigatorio, 'Nome da clínica é obrigatório.');
        END IF;
        IF fn_vazio(p_address) THEN
            prc_falhar(c_proc, c_err_obrigatorio, 'Endereço da clínica é obrigatório.');
        END IF;
        IF fn_vazio(p_phone) THEN
            prc_falhar(c_proc, c_err_obrigatorio, 'Telefone da clínica é obrigatório.');
        END IF;
        IF fn_vazio(p_email) THEN
            prc_falhar(c_proc, c_err_obrigatorio, 'E-mail da clínica é obrigatório.');
        END IF;

        v_id := SYS_GUID();
        INSERT INTO "CV_Clinics" ("Id", "Name", "Address", "Phone", "Email", "Active", "CreatedAt")
        VALUES (v_id, TRIM(p_name), TRIM(p_address), TRIM(p_phone), TRIM(p_email), 1, SYSTIMESTAMP);

        p_id := v_id;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            prc_falhar(c_proc, c_err_email_duplicado, 'Clínica já cadastrada: ' || p_email);
        WHEN OTHERS THEN
            v_code := SQLCODE;
            v_msg  := SQLERRM;
            prc_tratar_outros(c_proc, v_code, v_msg);
    END SP_INSERT_CLINIC;

    -- ========================================================================
    -- SP_INSERT_PET
    -- ========================================================================
    PROCEDURE SP_INSERT_PET(p_name IN NVARCHAR2, p_species IN NUMBER, p_breed IN NVARCHAR2, p_birth_date IN TIMESTAMP, p_weight_kg IN BINARY_DOUBLE, p_tutor_id IN RAW, p_id OUT RAW) IS
        c_proc CONSTANT VARCHAR2(60) := 'PKG_VETFLOW_CADASTRO.SP_INSERT_PET';
        v_id   RAW(16);
        v_code NUMBER;
        v_msg  VARCHAR2(4000);
    BEGIN
        IF fn_vazio(p_name) THEN
            prc_falhar(c_proc, c_err_obrigatorio, 'Nome do pet é obrigatório.');
        END IF;
        IF p_species IS NULL THEN
            prc_falhar(c_proc, c_err_obrigatorio, 'Espécie do pet é obrigatória.');
        END IF;
        IF p_birth_date IS NULL THEN
            prc_falhar(c_proc, c_err_obrigatorio, 'Data de nascimento do pet é obrigatória.');
        END IF;
        IF p_weight_kg IS NULL THEN
            prc_falhar(c_proc, c_err_obrigatorio, 'Peso do pet é obrigatório.');
        END IF;
        IF p_tutor_id IS NULL THEN
            prc_falhar(c_proc, c_err_obrigatorio, 'Tutor do pet é obrigatório.');
        END IF;

        IF p_species NOT IN (0, 1, 2, 3, 4) THEN
            prc_falhar(c_proc, c_err_regra_negocio, 'Espécie inválida (use 0=DOG, 1=CAT, 2=BIRD, 3=RABBIT, 4=OTHER): ' || p_species);
        END IF;
        IF p_weight_kg <= 0 THEN
            prc_falhar(c_proc, c_err_regra_negocio, 'Peso do pet deve ser maior que zero.');
        END IF;
        IF TRUNC(CAST(p_birth_date AS DATE)) > TRUNC(SYSDATE) THEN
            prc_falhar(c_proc, c_err_regra_negocio, 'Data de nascimento não pode ser no futuro.');
        END IF;

        IF NOT fn_tutor_existe(p_tutor_id) THEN
            prc_falhar(c_proc, c_err_nao_encontrado, 'Tutor não encontrado: ' || RAWTOHEX(p_tutor_id));
        END IF;

        v_id := SYS_GUID();
        INSERT INTO "CV_Pets" ("Id", "Name", "Species", "Breed", "BirthDate", "WeightKg", "TutorId", "Active", "CreatedAt")
        VALUES (v_id, TRIM(p_name), p_species, NVL(TRIM(p_breed), 'SRD'), p_birth_date, p_weight_kg, p_tutor_id, 1, SYSTIMESTAMP);

        p_id := v_id;
    EXCEPTION
        WHEN OTHERS THEN
            v_code := SQLCODE;
            v_msg  := SQLERRM;
            prc_tratar_outros(c_proc, v_code, v_msg);
    END SP_INSERT_PET;

    -- ========================================================================
    -- SP_INSERT_APPOINTMENT
    -- "Agendamento no passado" = data anterior a HOJE (comparacao por dia,
    -- para nao depender do fuso da sessao da aplicacao).
    -- ========================================================================
    PROCEDURE SP_INSERT_APPOINTMENT(p_pet_id IN RAW, p_clinic_id IN RAW, p_scheduled_at IN TIMESTAMP, p_type IN NUMBER, p_notes IN NVARCHAR2, p_id OUT RAW) IS
        c_proc CONSTANT VARCHAR2(60) := 'PKG_VETFLOW_CADASTRO.SP_INSERT_APPOINTMENT';
        v_id   RAW(16);
        v_code NUMBER;
        v_msg  VARCHAR2(4000);
    BEGIN
        IF p_pet_id IS NULL THEN
            prc_falhar(c_proc, c_err_obrigatorio, 'Pet da consulta é obrigatório.');
        END IF;
        IF p_clinic_id IS NULL THEN
            prc_falhar(c_proc, c_err_obrigatorio, 'Clínica da consulta é obrigatória.');
        END IF;
        IF p_scheduled_at IS NULL THEN
            prc_falhar(c_proc, c_err_obrigatorio, 'Data/hora da consulta é obrigatória.');
        END IF;
        IF p_type IS NULL THEN
            prc_falhar(c_proc, c_err_obrigatorio, 'Tipo da consulta é obrigatório.');
        END IF;

        IF p_type NOT IN (0, 1, 2, 3, 4, 5) THEN
            prc_falhar(c_proc, c_err_regra_negocio, 'Tipo de consulta inválido (0=VACCINATION, 1=CHECKUP, 2=SURGERY, 3=RETURN, 4=EMERGENCY, 5=OTHER): ' || p_type);
        END IF;
        IF TRUNC(CAST(p_scheduled_at AS DATE)) < TRUNC(SYSDATE) THEN
            prc_falhar(c_proc, c_err_regra_negocio, 'Não é possível agendar consulta no passado.');
        END IF;

        IF NOT fn_pet_existe(p_pet_id) THEN
            prc_falhar(c_proc, c_err_nao_encontrado, 'Pet não encontrado: ' || RAWTOHEX(p_pet_id));
        END IF;
        IF NOT fn_clinica_existe(p_clinic_id) THEN
            prc_falhar(c_proc, c_err_nao_encontrado, 'Clínica não encontrada: ' || RAWTOHEX(p_clinic_id));
        END IF;

        v_id := SYS_GUID();
        INSERT INTO "CV_Appointments" ("Id", "PetId", "ClinicId", "ScheduledAt", "Type", "Notes", "Completed", "Active", "CreatedAt")
        VALUES (v_id, p_pet_id, p_clinic_id, p_scheduled_at, p_type, NVL(TRIM(p_notes), 'Sem observações'), 0, 1, SYSTIMESTAMP);

        p_id := v_id;
    EXCEPTION
        WHEN OTHERS THEN
            v_code := SQLCODE;
            v_msg  := SQLERRM;
            prc_tratar_outros(c_proc, v_code, v_msg);
    END SP_INSERT_APPOINTMENT;

    -- ========================================================================
    -- SP_INSERT_VACCINE
    -- ========================================================================
    PROCEDURE SP_INSERT_VACCINE(p_pet_id IN RAW, p_vaccine_name IN NVARCHAR2, p_applied_at IN TIMESTAMP, p_next_dose_at IN TIMESTAMP, p_batch IN NVARCHAR2, p_id OUT RAW) IS
        c_proc CONSTANT VARCHAR2(60) := 'PKG_VETFLOW_CADASTRO.SP_INSERT_VACCINE';
        v_id   RAW(16);
        v_code NUMBER;
        v_msg  VARCHAR2(4000);
    BEGIN
        IF p_pet_id IS NULL THEN
            prc_falhar(c_proc, c_err_obrigatorio, 'Pet da vacina é obrigatório.');
        END IF;
        IF fn_vazio(p_vaccine_name) THEN
            prc_falhar(c_proc, c_err_obrigatorio, 'Nome da vacina é obrigatório.');
        END IF;
        IF p_applied_at IS NULL THEN
            prc_falhar(c_proc, c_err_obrigatorio, 'Data de aplicação é obrigatória.');
        END IF;
        IF p_next_dose_at IS NULL THEN
            prc_falhar(c_proc, c_err_obrigatorio, 'Data da próxima dose é obrigatória.');
        END IF;

        IF p_next_dose_at < p_applied_at THEN
            prc_falhar(c_proc, c_err_regra_negocio, 'Próxima dose não pode ser anterior à data de aplicação.');
        END IF;

        IF NOT fn_pet_existe(p_pet_id) THEN
            prc_falhar(c_proc, c_err_nao_encontrado, 'Pet não encontrado: ' || RAWTOHEX(p_pet_id));
        END IF;

        v_id := SYS_GUID();
        INSERT INTO "CV_Vaccines" ("Id", "PetId", "VaccineName", "AppliedAt", "NextDoseAt", "Batch", "Active", "CreatedAt")
        VALUES (v_id, p_pet_id, TRIM(p_vaccine_name), p_applied_at, p_next_dose_at, NVL(TRIM(p_batch), 'NÃO INFORMADO'), 1, SYSTIMESTAMP);

        p_id := v_id;
    EXCEPTION
        WHEN OTHERS THEN
            v_code := SQLCODE;
            v_msg  := SQLERRM;
            prc_tratar_outros(c_proc, v_code, v_msg);
    END SP_INSERT_VACCINE;

    -- ========================================================================
    -- SP_INSERT_MEDICATION (Status inicial 0 = ACTIVE)
    -- ========================================================================
    PROCEDURE SP_INSERT_MEDICATION(p_pet_id IN RAW, p_name IN NVARCHAR2, p_dosage IN NVARCHAR2, p_frequency IN NVARCHAR2, p_start_date IN TIMESTAMP, p_end_date IN TIMESTAMP, p_id OUT RAW) IS
        c_proc CONSTANT VARCHAR2(60) := 'PKG_VETFLOW_CADASTRO.SP_INSERT_MEDICATION';
        v_id   RAW(16);
        v_code NUMBER;
        v_msg  VARCHAR2(4000);
    BEGIN
        IF p_pet_id IS NULL THEN
            prc_falhar(c_proc, c_err_obrigatorio, 'Pet do medicamento é obrigatório.');
        END IF;
        IF fn_vazio(p_name) THEN
            prc_falhar(c_proc, c_err_obrigatorio, 'Nome do medicamento é obrigatório.');
        END IF;
        IF fn_vazio(p_dosage) THEN
            prc_falhar(c_proc, c_err_obrigatorio, 'Dosagem é obrigatória.');
        END IF;
        IF fn_vazio(p_frequency) THEN
            prc_falhar(c_proc, c_err_obrigatorio, 'Frequência é obrigatória.');
        END IF;
        IF p_start_date IS NULL THEN
            prc_falhar(c_proc, c_err_obrigatorio, 'Data de início é obrigatória.');
        END IF;
        IF p_end_date IS NULL THEN
            prc_falhar(c_proc, c_err_obrigatorio, 'Data de fim é obrigatória.');
        END IF;

        IF p_end_date < p_start_date THEN
            prc_falhar(c_proc, c_err_regra_negocio, 'Data de fim não pode ser anterior à data de início.');
        END IF;

        IF NOT fn_pet_existe(p_pet_id) THEN
            prc_falhar(c_proc, c_err_nao_encontrado, 'Pet não encontrado: ' || RAWTOHEX(p_pet_id));
        END IF;

        v_id := SYS_GUID();
        INSERT INTO "CV_Medications" ("Id", "PetId", "Name", "Dosage", "Frequency", "StartDate", "EndDate", "Status", "Active", "CreatedAt")
        VALUES (v_id, p_pet_id, TRIM(p_name), TRIM(p_dosage), TRIM(p_frequency), p_start_date, p_end_date, 0, 1, SYSTIMESTAMP);

        p_id := v_id;
    EXCEPTION
        WHEN OTHERS THEN
            v_code := SQLCODE;
            v_msg  := SQLERRM;
            prc_tratar_outros(c_proc, v_code, v_msg);
    END SP_INSERT_MEDICATION;

    -- ========================================================================
    -- SP_INSERT_USER (login compartilhado Java/.NET - senha ja vem em BCrypt)
    -- ========================================================================
    PROCEDURE SP_INSERT_USER(p_name IN NVARCHAR2, p_email IN NVARCHAR2, p_password_hash IN NVARCHAR2, p_role IN NVARCHAR2, p_tutor_id IN RAW, p_id OUT RAW) IS
        c_proc CONSTANT VARCHAR2(60) := 'PKG_VETFLOW_CADASTRO.SP_INSERT_USER';
        v_id   RAW(16);
        v_role NVARCHAR2(10);
        v_qtd  NUMBER;
        v_code NUMBER;
        v_msg  VARCHAR2(4000);
    BEGIN
        IF fn_vazio(p_name) THEN
            prc_falhar(c_proc, c_err_obrigatorio, 'Nome do usuário é obrigatório.');
        END IF;
        IF fn_vazio(p_email) THEN
            prc_falhar(c_proc, c_err_obrigatorio, 'E-mail do usuário é obrigatório.');
        END IF;
        IF fn_vazio(p_password_hash) THEN
            prc_falhar(c_proc, c_err_obrigatorio, 'Hash da senha é obrigatório.');
        END IF;
        IF fn_vazio(p_role) THEN
            prc_falhar(c_proc, c_err_obrigatorio, 'Perfil (role) do usuário é obrigatório.');
        END IF;

        IF UPPER(TRIM(p_role)) NOT IN ('TUTOR', 'VET') THEN
            prc_falhar(c_proc, c_err_regra_negocio, 'Role inválida (use TUTOR ou VET): ' || p_role);
        END IF;
        v_role := UPPER(TRIM(p_role));

        IF p_tutor_id IS NOT NULL AND NOT fn_tutor_existe(p_tutor_id) THEN
            prc_falhar(c_proc, c_err_nao_encontrado, 'Tutor não encontrado: ' || RAWTOHEX(p_tutor_id));
        END IF;

        SELECT COUNT(*) INTO v_qtd FROM "CV_Users" WHERE LOWER("Email") = LOWER(TRIM(p_email));
        IF v_qtd > 0 THEN
            prc_falhar(c_proc, c_err_email_duplicado, 'E-mail já cadastrado: ' || p_email);
        END IF;

        v_id := SYS_GUID();
        INSERT INTO "CV_Users" ("Id", "Name", "Email", "PasswordHash", "Role", "TutorId", "Active", "CreatedAt")
        VALUES (v_id, TRIM(p_name), TRIM(p_email), p_password_hash, v_role, p_tutor_id, 1, SYSTIMESTAMP);

        p_id := v_id;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            prc_falhar(c_proc, c_err_email_duplicado, 'E-mail já cadastrado: ' || p_email);
        WHEN OTHERS THEN
            v_code := SQLCODE;
            v_msg  := SQLERRM;
            prc_tratar_outros(c_proc, v_code, v_msg);
    END SP_INSERT_USER;

END PKG_VETFLOW_CADASTRO;
/

SHOW ERRORS PACKAGE BODY PKG_VETFLOW_CADASTRO

PROMPT 02_pkg_cadastro.sql concluido: PKG_VETFLOW_CADASTRO criado.
