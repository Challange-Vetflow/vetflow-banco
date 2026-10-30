-- ============================================================================
-- VetFlow - Challenge FIAP 2026 (Clyvo Vet)
-- Mastering Relational and Non-Relational Database - Sprint 4
-- 01_ddl.sql - MODELO FISICO (tabelas de negocio CV_*)
-- ============================================================================
-- Estas tabelas sao IDENTICAS (mesmos nomes entre aspas, mesmos tipos) as
-- geradas pelas migrations do EF Core da API .NET (`dotnet ef database update`).
-- O EF Core e o "dono" oficial do DDL das tabelas CV_*; este script e o modelo
-- fisico equivalente entregue para a disciplina de banco e serve de alternativa
-- para quem nao rodou o EF.
--
--   * Se voce JA rodou `dotnet ef database update`: NAO rode este arquivo
--     (ele apagaria e recriaria as tabelas). Rode apenas 01b_tabelas_apoio.sql
--     e siga para o 02.
--   * Se NAO usou o EF: rode este arquivo e depois o 01b_tabelas_apoio.sql.
--
-- Este script pode ser reexecutado: o bloco de limpeza abaixo remove os
-- objetos do VetFlow que existirem (pacotes, trigger, procedures/funcoes
-- avulsas da Sprint 3 e tabelas CV_*), ignorando apenas os erros de
-- "objeto nao existe" (ORA-00942, ORA-04043, ORA-04080).
-- ATENCAO: a limpeza apaga os DADOS das tabelas CV_*.
--
-- Enums gravados como NUMBER (ordinal - a ordem e contrato com Java/.NET):
--   Species ........... 0=DOG, 1=CAT, 2=BIRD, 3=RABBIT, 4=OTHER
--   AppointmentType ... 0=VACCINATION, 1=CHECKUP, 2=SURGERY, 3=RETURN,
--                       4=EMERGENCY, 5=OTHER
--   MedicationStatus .. 0=ACTIVE, 1=COMPLETED, 2=SUSPENDED
--   Booleanos ......... "Active"/"Completed": 0=falso, 1=verdadeiro
--   Role (CV_Users) ... 'TUTOR' ou 'VET'
-- ============================================================================

SET DEFINE OFF
SET SERVEROUTPUT ON

-- ----------------------------------------------------------------------------
-- 0. LIMPEZA SEGURA (permite reexecutar o script)
-- ----------------------------------------------------------------------------
DECLARE
    TYPE t_comandos IS TABLE OF VARCHAR2(200);
    v_comandos t_comandos := t_comandos(
        'DROP TRIGGER TRG_AUDITORIA_CV_PETS',
        'DROP PACKAGE PKG_VETFLOW_AUDITORIA',
        'DROP PACKAGE PKG_VETFLOW_RELATORIOS',
        'DROP PACKAGE PKG_VETFLOW_UTIL',
        'DROP PACKAGE PKG_VETFLOW_CADASTRO',
        -- objetos avulsos da Sprint 3 (agora vivem dentro dos pacotes)
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
        -- tabelas (filhas antes das maes)
        'DROP TABLE "CV_Users" CASCADE CONSTRAINTS PURGE',
        'DROP TABLE "CV_Medications" CASCADE CONSTRAINTS PURGE',
        'DROP TABLE "CV_Vaccines" CASCADE CONSTRAINTS PURGE',
        'DROP TABLE "CV_Appointments" CASCADE CONSTRAINTS PURGE',
        'DROP TABLE "CV_Pets" CASCADE CONSTRAINTS PURGE',
        'DROP TABLE "CV_Clinics" CASCADE CONSTRAINTS PURGE',
        'DROP TABLE "CV_Tutors" CASCADE CONSTRAINTS PURGE'
    );
BEGIN
    FOR i IN 1 .. v_comandos.COUNT LOOP
        BEGIN
            EXECUTE IMMEDIATE v_comandos(i);
            DBMS_OUTPUT.PUT_LINE('OK ....... ' || v_comandos(i));
        EXCEPTION
            WHEN OTHERS THEN
                -- -942: tabela nao existe | -4043: objeto nao existe | -4080: trigger nao existe
                IF SQLCODE NOT IN (-942, -4043, -4080) THEN
                    RAISE;
                END IF;
                DBMS_OUTPUT.PUT_LINE('ignorado . ' || v_comandos(i) || ' (nao existia)');
        END;
    END LOOP;
END;
/

-- ----------------------------------------------------------------------------
-- 1. CV_Tutors - responsaveis pelos pets
-- ----------------------------------------------------------------------------
CREATE TABLE "CV_Tutors" (
    "Id"        RAW(16)         NOT NULL,
    "Name"      NVARCHAR2(100)  NOT NULL,
    "Email"     NVARCHAR2(255)  NOT NULL,
    "Phone"     NVARCHAR2(20)   NOT NULL,
    "Active"    NUMBER(1,0)     NOT NULL,
    "CreatedAt" TIMESTAMP(6)    NOT NULL,
    CONSTRAINT "PK_CV_Tutors" PRIMARY KEY ("Id"),
    CONSTRAINT "CK_CV_Tutors_Active" CHECK ("Active" IN (0, 1))
);

-- E-mail do tutor e unico (a procedure SP_INSERT_TUTOR trata DUP_VAL_ON_INDEX)
CREATE UNIQUE INDEX "UQ_CV_Tutors_Email" ON "CV_Tutors" ("Email");

-- ----------------------------------------------------------------------------
-- 2. CV_Clinics - clinicas e hospitais veterinarios parceiros
-- ----------------------------------------------------------------------------
CREATE TABLE "CV_Clinics" (
    "Id"        RAW(16)         NOT NULL,
    "Name"      NVARCHAR2(200)  NOT NULL,
    "Address"   NVARCHAR2(500)  NOT NULL,
    "Phone"     NVARCHAR2(20)   NOT NULL,
    "Email"     NVARCHAR2(255)  NOT NULL,
    "Active"    NUMBER(1,0)     NOT NULL,
    "CreatedAt" TIMESTAMP(6)    NOT NULL,
    CONSTRAINT "PK_CV_Clinics" PRIMARY KEY ("Id"),
    CONSTRAINT "CK_CV_Clinics_Active" CHECK ("Active" IN (0, 1))
);

-- ----------------------------------------------------------------------------
-- 3. CV_Pets - animais, vinculados ao tutor (N:1)
-- ----------------------------------------------------------------------------
CREATE TABLE "CV_Pets" (
    "Id"        RAW(16)         NOT NULL,
    "Name"      NVARCHAR2(100)  NOT NULL,
    "Species"   NUMBER(10,0)    NOT NULL,
    "Breed"     NVARCHAR2(100)  NOT NULL,
    "BirthDate" TIMESTAMP(6)    NOT NULL,
    "WeightKg"  BINARY_DOUBLE   NOT NULL,
    "TutorId"   RAW(16)         NOT NULL,
    "Active"    NUMBER(1,0)     NOT NULL,
    "CreatedAt" TIMESTAMP(6)    NOT NULL,
    CONSTRAINT "PK_CV_Pets" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_CV_Pets_CV_Tutors_TutorId"
        FOREIGN KEY ("TutorId") REFERENCES "CV_Tutors" ("Id") ON DELETE CASCADE,
    CONSTRAINT "CK_CV_Pets_Species" CHECK ("Species" BETWEEN 0 AND 4),
    CONSTRAINT "CK_CV_Pets_Active"  CHECK ("Active" IN (0, 1))
);

CREATE INDEX "IX_CV_Pets_TutorId" ON "CV_Pets" ("TutorId");

-- ----------------------------------------------------------------------------
-- 4. CV_Appointments - agendamentos/consultas (pet N:1, clinica N:1)
-- ----------------------------------------------------------------------------
CREATE TABLE "CV_Appointments" (
    "Id"          RAW(16)         NOT NULL,
    "PetId"       RAW(16)         NOT NULL,
    "ClinicId"    RAW(16)         NOT NULL,
    "ScheduledAt" TIMESTAMP(6)    NOT NULL,
    "Type"        NUMBER(10,0)    NOT NULL,
    "Notes"       NVARCHAR2(1000) NOT NULL,
    "Completed"   NUMBER(1,0)     DEFAULT (0) NOT NULL,
    "Active"      NUMBER(1,0)     NOT NULL,
    "CreatedAt"   TIMESTAMP(6)    NOT NULL,
    CONSTRAINT "PK_CV_Appointments" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_CV_Appointments_CV_Pets_PetId"
        FOREIGN KEY ("PetId") REFERENCES "CV_Pets" ("Id") ON DELETE CASCADE,
    CONSTRAINT "FK_CV_Appointments_CV_Clinics_ClinicId"
        FOREIGN KEY ("ClinicId") REFERENCES "CV_Clinics" ("Id") ON DELETE CASCADE,
    CONSTRAINT "CK_CV_Appointments_Type"      CHECK ("Type" BETWEEN 0 AND 5),
    CONSTRAINT "CK_CV_Appointments_Completed" CHECK ("Completed" IN (0, 1)),
    CONSTRAINT "CK_CV_Appointments_Active"    CHECK ("Active" IN (0, 1))
);

CREATE INDEX "IX_CV_Appointments_PetId"    ON "CV_Appointments" ("PetId");
CREATE INDEX "IX_CV_Appointments_ClinicId" ON "CV_Appointments" ("ClinicId");

-- ----------------------------------------------------------------------------
-- 5. CV_Vaccines - historico de vacinas e proxima dose (pet N:1)
-- ----------------------------------------------------------------------------
CREATE TABLE "CV_Vaccines" (
    "Id"          RAW(16)         NOT NULL,
    "PetId"       RAW(16)         NOT NULL,
    "VaccineName" NVARCHAR2(100)  NOT NULL,
    "AppliedAt"   TIMESTAMP(6)    NOT NULL,
    "NextDoseAt"  TIMESTAMP(6)    NOT NULL,
    "Batch"       NVARCHAR2(50)   NOT NULL,
    "Active"      NUMBER(1,0)     NOT NULL,
    "CreatedAt"   TIMESTAMP(6)    NOT NULL,
    CONSTRAINT "PK_CV_Vaccines" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_CV_Vaccines_CV_Pets_PetId"
        FOREIGN KEY ("PetId") REFERENCES "CV_Pets" ("Id") ON DELETE CASCADE,
    CONSTRAINT "CK_CV_Vaccines_Active" CHECK ("Active" IN (0, 1))
);

CREATE INDEX "IX_CV_Vaccines_PetId" ON "CV_Vaccines" ("PetId");

-- ----------------------------------------------------------------------------
-- 6. CV_Medications - medicamentos prescritos (pet N:1)
-- ----------------------------------------------------------------------------
CREATE TABLE "CV_Medications" (
    "Id"        RAW(16)         NOT NULL,
    "PetId"     RAW(16)         NOT NULL,
    "Name"      NVARCHAR2(100)  NOT NULL,
    "Dosage"    NVARCHAR2(100)  NOT NULL,
    "Frequency" NVARCHAR2(100)  NOT NULL,
    "StartDate" TIMESTAMP(6)    NOT NULL,
    "EndDate"   TIMESTAMP(6)    NOT NULL,
    "Status"    NUMBER(10,0)    NOT NULL,
    "Active"    NUMBER(1,0)     NOT NULL,
    "CreatedAt" TIMESTAMP(6)    NOT NULL,
    CONSTRAINT "PK_CV_Medications" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_CV_Medications_CV_Pets_PetId"
        FOREIGN KEY ("PetId") REFERENCES "CV_Pets" ("Id") ON DELETE CASCADE,
    CONSTRAINT "CK_CV_Medications_Status" CHECK ("Status" BETWEEN 0 AND 2),
    CONSTRAINT "CK_CV_Medications_Active" CHECK ("Active" IN (0, 1))
);

CREATE INDEX "IX_CV_Medications_PetId" ON "CV_Medications" ("PetId");

-- ----------------------------------------------------------------------------
-- 7. CV_Users - NOVA na Sprint 4: login compartilhado entre Java e .NET
-- ----------------------------------------------------------------------------
CREATE TABLE "CV_Users" (
    "Id"           RAW(16)         NOT NULL,
    "Name"         NVARCHAR2(100)  NOT NULL,
    "Email"        NVARCHAR2(255)  NOT NULL,
    "PasswordHash" NVARCHAR2(255)  NOT NULL,
    "Role"         NVARCHAR2(10)   NOT NULL,
    "TutorId"      RAW(16)         NULL,
    "Active"       NUMBER(1,0)     NOT NULL,
    "CreatedAt"    TIMESTAMP(6)    NOT NULL,
    CONSTRAINT "PK_CV_Users" PRIMARY KEY ("Id"),
    CONSTRAINT "UQ_CV_Users_Email" UNIQUE ("Email"),
    CONSTRAINT "FK_CV_Users_CV_Tutors_TutorId"
        FOREIGN KEY ("TutorId") REFERENCES "CV_Tutors" ("Id") ON DELETE SET NULL,
    CONSTRAINT "CK_CV_Users_Role"   CHECK ("Role" IN ('TUTOR', 'VET')),
    CONSTRAINT "CK_CV_Users_Active" CHECK ("Active" IN (0, 1))
);

CREATE INDEX "IX_CV_Users_TutorId" ON "CV_Users" ("TutorId");

-- ----------------------------------------------------------------------------
-- 8. COMENTARIOS (dicionario de dados)
-- ----------------------------------------------------------------------------
COMMENT ON TABLE "CV_Tutors" IS 'Tutores (responsaveis) dos pets';
COMMENT ON COLUMN "CV_Tutors"."Id" IS 'PK - GUID RAW(16) gerado por SYS_GUID() ou pela aplicacao';
COMMENT ON COLUMN "CV_Tutors"."Email" IS 'E-mail do tutor - unico (UQ_CV_Tutors_Email)';
COMMENT ON COLUMN "CV_Tutors"."Active" IS 'Booleano: 1=ativo, 0=inativo (exclusao logica)';
COMMENT ON COLUMN "CV_Tutors"."CreatedAt" IS 'Data/hora de criacao do registro';

COMMENT ON TABLE "CV_Clinics" IS 'Clinicas e hospitais veterinarios parceiros';
COMMENT ON COLUMN "CV_Clinics"."Id" IS 'PK - GUID RAW(16)';
COMMENT ON COLUMN "CV_Clinics"."Active" IS 'Booleano: 1=ativo, 0=inativo (exclusao logica)';

COMMENT ON TABLE "CV_Pets" IS 'Pets cadastrados, cada um vinculado a um tutor';
COMMENT ON COLUMN "CV_Pets"."Id" IS 'PK - GUID RAW(16)';
COMMENT ON COLUMN "CV_Pets"."Species" IS 'Enum Species: 0=DOG, 1=CAT, 2=BIRD, 3=RABBIT, 4=OTHER';
COMMENT ON COLUMN "CV_Pets"."Breed" IS 'Raca (SRD = sem raca definida quando nao informada)';
COMMENT ON COLUMN "CV_Pets"."WeightKg" IS 'Peso em kg (BINARY_DOUBLE, sempre > 0)';
COMMENT ON COLUMN "CV_Pets"."TutorId" IS 'FK para CV_Tutors (ON DELETE CASCADE)';
COMMENT ON COLUMN "CV_Pets"."Active" IS 'Booleano: 1=ativo, 0=inativo (exclusao logica)';

COMMENT ON TABLE "CV_Appointments" IS 'Agendamentos/consultas dos pets nas clinicas';
COMMENT ON COLUMN "CV_Appointments"."Type" IS 'Enum AppointmentType: 0=VACCINATION, 1=CHECKUP, 2=SURGERY, 3=RETURN, 4=EMERGENCY, 5=OTHER';
COMMENT ON COLUMN "CV_Appointments"."Completed" IS 'Booleano: 1=consulta realizada, 0=pendente';
COMMENT ON COLUMN "CV_Appointments"."PetId" IS 'FK para CV_Pets (ON DELETE CASCADE)';
COMMENT ON COLUMN "CV_Appointments"."ClinicId" IS 'FK para CV_Clinics (ON DELETE CASCADE)';
COMMENT ON COLUMN "CV_Appointments"."Active" IS 'Booleano: 1=ativo, 0=inativo (exclusao logica)';

COMMENT ON TABLE "CV_Vaccines" IS 'Historico de vacinas aplicadas e data da proxima dose';
COMMENT ON COLUMN "CV_Vaccines"."NextDoseAt" IS 'Proxima dose - vacina vencida quando NextDoseAt < agora';
COMMENT ON COLUMN "CV_Vaccines"."Batch" IS 'Lote da vacina';
COMMENT ON COLUMN "CV_Vaccines"."Active" IS 'Booleano: 1=ativo, 0=inativo (exclusao logica)';

COMMENT ON TABLE "CV_Medications" IS 'Medicamentos prescritos com controle de status';
COMMENT ON COLUMN "CV_Medications"."Status" IS 'Enum MedicationStatus: 0=ACTIVE, 1=COMPLETED, 2=SUSPENDED';
COMMENT ON COLUMN "CV_Medications"."Active" IS 'Booleano: 1=ativo, 0=inativo (exclusao logica)';

COMMENT ON TABLE "CV_Users" IS 'Usuarios de login (compartilhado entre as aplicacoes Java e .NET)';
COMMENT ON COLUMN "CV_Users"."Email" IS 'Login - unico (UQ_CV_Users_Email)';
COMMENT ON COLUMN "CV_Users"."PasswordHash" IS 'Hash BCrypt ($2a$) da senha - nunca a senha em texto';
COMMENT ON COLUMN "CV_Users"."Role" IS 'Perfil: TUTOR ou VET';
COMMENT ON COLUMN "CV_Users"."TutorId" IS 'FK opcional para CV_Tutors (perfil TUTOR) - ON DELETE SET NULL';
COMMENT ON COLUMN "CV_Users"."Active" IS 'Booleano: 1=ativo, 0=inativo';

PROMPT 01_ddl.sql concluido: 7 tabelas CV_* criadas. Rode agora 01b_tabelas_apoio.sql.
