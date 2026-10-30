-- ============================================================================
-- VetFlow - Challenge FIAP 2026 (Clyvo Vet)
-- Mastering Relational and Non-Relational Database - Sprint 4
-- 05_pkg_auditoria_trigger.sql - PKG_VETFLOW_AUDITORIA + TRG_AUDITORIA_CV_PETS
-- ============================================================================
-- Triggers nao podem ficar dentro de um pacote. Para "empacotar" o gatilho,
-- toda a regra de auditoria mora em PKG_VETFLOW_AUDITORIA e o trigger
-- TRG_AUDITORIA_CV_PETS fica fino: so monta os valores antigo/novo e chama
-- o pacote.
--
-- A gravacao da auditoria acontece na MESMA transacao do DML em "CV_Pets"
-- (se a aplicacao fizer ROLLBACK, a auditoria tambem e desfeita - coerente).
-- Nenhum COMMIT dentro do trigger nem da procedure.
-- Uma falha de auditoria NAO derruba o DML do usuario: o erro e gravado em
-- CV_ERROR_LOG (transacao autonoma) e o processamento segue.
-- ============================================================================

SET DEFINE OFF
SET SERVEROUTPUT ON

CREATE OR REPLACE PACKAGE PKG_VETFLOW_AUDITORIA AS

    PROCEDURE SP_REGISTRAR_AUDITORIA_PET(p_operacao IN VARCHAR2, p_valor_antigo IN VARCHAR2, p_valor_novo IN VARCHAR2);

END PKG_VETFLOW_AUDITORIA;
/

CREATE OR REPLACE PACKAGE BODY PKG_VETFLOW_AUDITORIA AS

    -- PRIVADO: log de erro em transacao autonoma
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
    -- SP_REGISTRAR_AUDITORIA_PET
    -- p_operacao: 'INSERT', 'UPDATE' ou 'DELETE'
    -- ========================================================================
    PROCEDURE SP_REGISTRAR_AUDITORIA_PET(p_operacao IN VARCHAR2, p_valor_antigo IN VARCHAR2, p_valor_novo IN VARCHAR2) IS
        v_operacao VARCHAR2(10);
        v_err_code NUMBER;
        v_err_msg  VARCHAR2(4000);
    BEGIN
        v_operacao := UPPER(TRIM(p_operacao));

        IF v_operacao IS NULL OR v_operacao NOT IN ('INSERT', 'UPDATE', 'DELETE') THEN
            RAISE_APPLICATION_ERROR(-20004, 'Operação de auditoria inválida: ' || NVL(p_operacao, '(nula)'));
        END IF;

        INSERT INTO CV_PETS_AUDITORIA (nm_usuario, tp_operacao, dt_operacao, valor_antigo, valor_novo)
        VALUES (SUBSTR(USER, 1, 100), v_operacao, SYSTIMESTAMP,
                SUBSTR(p_valor_antigo, 1, 4000), SUBSTR(p_valor_novo, 1, 4000));
    EXCEPTION
        WHEN OTHERS THEN
            -- Nao propaga: auditoria nunca pode impedir o cadastro do pet.
            v_err_code := SQLCODE;
            v_err_msg  := SQLERRM;
            prc_log_erro('PKG_VETFLOW_AUDITORIA.SP_REGISTRAR_AUDITORIA_PET', v_err_code, v_err_msg);
    END SP_REGISTRAR_AUDITORIA_PET;

END PKG_VETFLOW_AUDITORIA;
/

SHOW ERRORS PACKAGE BODY PKG_VETFLOW_AUDITORIA

-- ----------------------------------------------------------------------------
-- Trigger fino: so monta os valores e delega ao pacote
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_AUDITORIA_CV_PETS
AFTER INSERT OR UPDATE OR DELETE ON "CV_Pets"
FOR EACH ROW
DECLARE
    v_valor_antigo VARCHAR2(4000);
    v_valor_novo   VARCHAR2(4000);
    v_tp_operacao  VARCHAR2(10);
BEGIN
    IF UPDATING OR DELETING THEN
        v_valor_antigo := SUBSTR('Name=' || TO_CHAR(:OLD."Name")
                        || ';Species=' || TO_CHAR(:OLD."Species")
                        || ';Breed=' || TO_CHAR(:OLD."Breed")
                        || ';WeightKg=' || TO_CHAR(:OLD."WeightKg")
                        || ';Active=' || TO_CHAR(:OLD."Active"), 1, 4000);
    END IF;

    IF INSERTING OR UPDATING THEN
        v_valor_novo := SUBSTR('Name=' || TO_CHAR(:NEW."Name")
                      || ';Species=' || TO_CHAR(:NEW."Species")
                      || ';Breed=' || TO_CHAR(:NEW."Breed")
                      || ';WeightKg=' || TO_CHAR(:NEW."WeightKg")
                      || ';Active=' || TO_CHAR(:NEW."Active"), 1, 4000);
    END IF;

    IF INSERTING THEN
        v_tp_operacao := 'INSERT';
    ELSIF UPDATING THEN
        v_tp_operacao := 'UPDATE';
    ELSE
        v_tp_operacao := 'DELETE';
    END IF;

    PKG_VETFLOW_AUDITORIA.SP_REGISTRAR_AUDITORIA_PET(v_tp_operacao, v_valor_antigo, v_valor_novo);
END TRG_AUDITORIA_CV_PETS;
/

SHOW ERRORS TRIGGER TRG_AUDITORIA_CV_PETS

PROMPT 05_pkg_auditoria_trigger.sql concluido: PKG_VETFLOW_AUDITORIA e TRG_AUDITORIA_CV_PETS criados.
