-- ============================================================================
-- VetFlow - Challenge FIAP 2026 (Clyvo Vet)
-- Mastering Relational and Non-Relational Database - Sprint 4
-- 01b_tabelas_apoio.sql - tabelas de apoio dos pacotes PL/SQL
-- ============================================================================
-- CV_ERROR_LOG ....... log de erros gravado pelos pacotes (transacao autonoma)
-- CV_PETS_AUDITORIA .. auditoria de INSERT/UPDATE/DELETE em "CV_Pets"
--
-- O EF Core NAO mapeia estas duas tabelas, por isso elas ficam neste script.
-- Rode SEMPRE este arquivo, tanto depois do `dotnet ef database update`
-- quanto depois do 01_ddl.sql.
--
-- Reexecutavel: remove antes as duas tabelas (e os objetos avulsos da
-- Sprint 3, que agora vivem dentro dos pacotes), ignorando "nao existe".
-- ATENCAO: reexecutar apaga o historico de log e de auditoria.
-- ============================================================================

SET DEFINE OFF
SET SERVEROUTPUT ON

DECLARE
    TYPE t_comandos IS TABLE OF VARCHAR2(200);
    v_comandos t_comandos := t_comandos(
        -- objetos avulsos da Sprint 3 (substituidos pelos pacotes PKG_VETFLOW_*)
        'DROP PROCEDURE SP_INSERT_TUTOR',
        'DROP PROCEDURE SP_INSERT_CLINIC',
        'DROP PROCEDURE SP_INSERT_PET',
        'DROP PROCEDURE SP_INSERT_APPOINTMENT',
        'DROP PROCEDURE SP_INSERT_VACCINE',
        'DROP PROCEDURE SP_INSERT_MEDICATION',
        'DROP PROCEDURE SP_LISTAR_PETS_JSON',
        'DROP PROCEDURE SP_RELATORIO_PESO_POR_TUTOR',
        'DROP FUNCTION FN_PET_TO_JSON',
        'DROP FUNCTION FN_CALCULAR_IDADE_MESES',
        -- tabelas de apoio
        'DROP TABLE CV_PETS_AUDITORIA CASCADE CONSTRAINTS PURGE',
        'DROP TABLE CV_ERROR_LOG CASCADE CONSTRAINTS PURGE'
    );
BEGIN
    FOR i IN 1 .. v_comandos.COUNT LOOP
        BEGIN
            EXECUTE IMMEDIATE v_comandos(i);
            DBMS_OUTPUT.PUT_LINE('OK ....... ' || v_comandos(i));
        EXCEPTION
            WHEN OTHERS THEN
                -- -942: tabela nao existe | -4043: objeto nao existe
                IF SQLCODE NOT IN (-942, -4043) THEN
                    RAISE;
                END IF;
                DBMS_OUTPUT.PUT_LINE('ignorado . ' || v_comandos(i) || ' (nao existia)');
        END;
    END LOOP;
END;
/

-- ----------------------------------------------------------------------------
-- CV_ERROR_LOG - log de erros (mesma estrutura da Sprint 3)
-- ----------------------------------------------------------------------------
CREATE TABLE CV_ERROR_LOG (
    id           NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL,
    procedure_nm VARCHAR2(100),
    user_nm      VARCHAR2(100),
    error_date   TIMESTAMP DEFAULT SYSTIMESTAMP,
    error_code   NUMBER,
    error_msg    VARCHAR2(4000),
    CONSTRAINT PK_ERROR_LOG PRIMARY KEY (id)
);

COMMENT ON TABLE CV_ERROR_LOG IS 'Log de erros gravado pelos pacotes PKG_VETFLOW_* (PRAGMA AUTONOMOUS_TRANSACTION)';

-- ----------------------------------------------------------------------------
-- CV_PETS_AUDITORIA - auditoria de "CV_Pets" (mesma estrutura da Sprint 3)
-- ----------------------------------------------------------------------------
CREATE TABLE CV_PETS_AUDITORIA (
    id_auditoria NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL,
    nm_usuario   VARCHAR2(100)  NOT NULL,
    tp_operacao  VARCHAR2(10)   NOT NULL,
    dt_operacao  TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    valor_antigo VARCHAR2(4000),
    valor_novo   VARCHAR2(4000),
    CONSTRAINT PK_CV_PETS_AUDITORIA PRIMARY KEY (id_auditoria),
    CONSTRAINT CK_AUDITORIA_TIPO CHECK (tp_operacao IN ('INSERT', 'UPDATE', 'DELETE'))
);

COMMENT ON TABLE CV_PETS_AUDITORIA IS 'Auditoria de CV_Pets preenchida por TRG_AUDITORIA_CV_PETS via PKG_VETFLOW_AUDITORIA';

PROMPT 01b_tabelas_apoio.sql concluido: CV_ERROR_LOG e CV_PETS_AUDITORIA criadas.
