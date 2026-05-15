-- ============================================================
-- VetFlow - Challenge FIAP 2026
-- Banco de Dados Oracle - Script Completo
-- ============================================================

-- ============================================================
-- 1. DDL - CRIAÇÃO DAS TABELAS
-- ============================================================

CREATE TABLE CV_TUTORS (
    id          RAW(16)       DEFAULT SYS_GUID() NOT NULL,
    name        VARCHAR2(100) NOT NULL,
    email       VARCHAR2(255) NOT NULL,
    phone       VARCHAR2(20)  NOT NULL,
    active      NUMBER(1)     DEFAULT 1 NOT NULL,
    created_at  TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT PK_TUTORS     PRIMARY KEY (id),
    CONSTRAINT UQ_TUTOR_EMAIL UNIQUE (email),
    CONSTRAINT CK_TUTOR_ACTIVE CHECK (active IN (0,1))
);

CREATE TABLE CV_CLINICS (
    id          RAW(16)       DEFAULT SYS_GUID() NOT NULL,
    name        VARCHAR2(200) NOT NULL,
    address     VARCHAR2(500),
    phone       VARCHAR2(20),
    email       VARCHAR2(255),
    active      NUMBER(1)     DEFAULT 1 NOT NULL,
    created_at  TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT PK_CLINICS    PRIMARY KEY (id),
    CONSTRAINT CK_CLINIC_ACTIVE CHECK (active IN (0,1))
);

CREATE TABLE CV_PETS (
    id          RAW(16)       DEFAULT SYS_GUID() NOT NULL,
    name        VARCHAR2(100) NOT NULL,
    species     VARCHAR2(20)  NOT NULL,
    breed       VARCHAR2(100),
    birth_date  DATE          NOT NULL,
    weight_kg   NUMBER(6,2)   NOT NULL,
    active      NUMBER(1)     DEFAULT 1 NOT NULL,
    created_at  TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    tutor_id    RAW(16)       NOT NULL,
    CONSTRAINT PK_PETS           PRIMARY KEY (id),
    CONSTRAINT FK_PET_TUTOR      FOREIGN KEY (tutor_id) REFERENCES CV_TUTORS(id) ON DELETE CASCADE,
    CONSTRAINT CK_PET_ACTIVE     CHECK (active IN (0,1)),
    CONSTRAINT CK_PET_WEIGHT     CHECK (weight_kg > 0),
    CONSTRAINT CK_PET_SPECIES    CHECK (species IN ('DOG','CAT','BIRD','RABBIT','OTHER'))
);

CREATE TABLE CV_APPOINTMENTS (
    id            RAW(16)        DEFAULT SYS_GUID() NOT NULL,
    pet_id        RAW(16)        NOT NULL,
    clinic_id     RAW(16)        NOT NULL,
    scheduled_at  TIMESTAMP      NOT NULL,
    type          VARCHAR2(20)   NOT NULL,
    notes         VARCHAR2(1000),
    completed     NUMBER(1)      DEFAULT 0 NOT NULL,
    created_at    TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT PK_APPOINTMENTS      PRIMARY KEY (id),
    CONSTRAINT FK_APPT_PET          FOREIGN KEY (pet_id)    REFERENCES CV_PETS(id)    ON DELETE CASCADE,
    CONSTRAINT FK_APPT_CLINIC       FOREIGN KEY (clinic_id) REFERENCES CV_CLINICS(id) ON DELETE CASCADE,
    CONSTRAINT CK_APPT_COMPLETED    CHECK (completed IN (0,1)),
    CONSTRAINT CK_APPT_TYPE         CHECK (type IN ('VACCINATION','CHECKUP','SURGERY','RETURN','EMERGENCY','OTHER'))
);

CREATE TABLE CV_VACCINES (
    id            RAW(16)       DEFAULT SYS_GUID() NOT NULL,
    pet_id        RAW(16)       NOT NULL,
    vaccine_name  VARCHAR2(100) NOT NULL,
    applied_at    DATE          NOT NULL,
    next_dose_at  DATE          NOT NULL,
    batch         VARCHAR2(50),
    created_at    TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT PK_VACCINES      PRIMARY KEY (id),
    CONSTRAINT FK_VAC_PET       FOREIGN KEY (pet_id) REFERENCES CV_PETS(id) ON DELETE CASCADE,
    CONSTRAINT CK_VAC_DATES     CHECK (next_dose_at > applied_at)
);

CREATE TABLE CV_MEDICATIONS (
    id          RAW(16)       DEFAULT SYS_GUID() NOT NULL,
    pet_id      RAW(16)       NOT NULL,
    name        VARCHAR2(100) NOT NULL,
    dosage      VARCHAR2(100) NOT NULL,
    frequency   VARCHAR2(100) NOT NULL,
    start_date  DATE          NOT NULL,
    end_date    DATE          NOT NULL,
    status      VARCHAR2(20)  DEFAULT 'ACTIVE' NOT NULL,
    created_at  TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT PK_MEDICATIONS      PRIMARY KEY (id),
    CONSTRAINT FK_MED_PET          FOREIGN KEY (pet_id) REFERENCES CV_PETS(id) ON DELETE CASCADE,
    CONSTRAINT CK_MED_DATES        CHECK (end_date > start_date),
    CONSTRAINT CK_MED_STATUS       CHECK (status IN ('ACTIVE','COMPLETED','SUSPENDED'))
);

CREATE TABLE CV_ERROR_LOG (
    id           NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL,
    procedure_nm VARCHAR2(100),
    user_nm      VARCHAR2(100),
    error_date   TIMESTAMP     DEFAULT SYSTIMESTAMP,
    error_code   NUMBER,
    error_msg    VARCHAR2(4000),
    CONSTRAINT PK_ERROR_LOG PRIMARY KEY (id)
);

-- ============================================================
-- 2. PROCEDURES DE CARGA DE DADOS
-- ============================================================

CREATE OR REPLACE PROCEDURE SP_INSERT_TUTOR (
    p_name  IN CV_TUTORS.name%TYPE,
    p_email IN CV_TUTORS.email%TYPE,
    p_phone IN CV_TUTORS.phone%TYPE
) AS
    v_id CV_TUTORS.id%TYPE := SYS_GUID();
BEGIN
    INSERT INTO CV_TUTORS (id, name, email, phone)
    VALUES (v_id, p_name, p_email, p_phone);
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        INSERT INTO CV_ERROR_LOG (procedure_nm, user_nm, error_code, error_msg)
        VALUES ('SP_INSERT_TUTOR', USER, SQLCODE, 'E-mail duplicado: ' || p_email);
        COMMIT;
        RAISE_APPLICATION_ERROR(-20001, 'E-mail já cadastrado: ' || p_email);
    WHEN VALUE_ERROR THEN
        INSERT INTO CV_ERROR_LOG (procedure_nm, user_nm, error_code, error_msg)
        VALUES ('SP_INSERT_TUTOR', USER, SQLCODE, SQLERRM);
        COMMIT;
        RAISE;
    WHEN OTHERS THEN
        INSERT INTO CV_ERROR_LOG (procedure_nm, user_nm, error_code, error_msg)
        VALUES ('SP_INSERT_TUTOR', USER, SQLCODE, SQLERRM);
        COMMIT;
        RAISE;
END SP_INSERT_TUTOR;
/

CREATE OR REPLACE PROCEDURE SP_INSERT_CLINIC (
    p_name    IN CV_CLINICS.name%TYPE,
    p_address IN CV_CLINICS.address%TYPE,
    p_phone   IN CV_CLINICS.phone%TYPE,
    p_email   IN CV_CLINICS.email%TYPE
) AS
BEGIN
    INSERT INTO CV_CLINICS (id, name, address, phone, email)
    VALUES (SYS_GUID(), p_name, p_address, p_phone, p_email);
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        INSERT INTO CV_ERROR_LOG (procedure_nm, user_nm, error_code, error_msg)
        VALUES ('SP_INSERT_CLINIC', USER, SQLCODE, 'Clínica duplicada: ' || p_name);
        COMMIT;
        RAISE;
    WHEN VALUE_ERROR THEN
        INSERT INTO CV_ERROR_LOG (procedure_nm, user_nm, error_code, error_msg)
        VALUES ('SP_INSERT_CLINIC', USER, SQLCODE, SQLERRM);
        COMMIT;
        RAISE;
    WHEN OTHERS THEN
        INSERT INTO CV_ERROR_LOG (procedure_nm, user_nm, error_code, error_msg)
        VALUES ('SP_INSERT_CLINIC', USER, SQLCODE, SQLERRM);
        COMMIT;
        RAISE;
END SP_INSERT_CLINIC;
/

CREATE OR REPLACE PROCEDURE SP_INSERT_PET (
    p_name       IN CV_PETS.name%TYPE,
    p_species    IN CV_PETS.species%TYPE,
    p_breed      IN CV_PETS.breed%TYPE,
    p_birth_date IN CV_PETS.birth_date%TYPE,
    p_weight_kg  IN CV_PETS.weight_kg%TYPE,
    p_tutor_id   IN CV_PETS.tutor_id%TYPE
) AS
BEGIN
    INSERT INTO CV_PETS (id, name, species, breed, birth_date, weight_kg, tutor_id)
    VALUES (SYS_GUID(), p_name, p_species, p_breed, p_birth_date, p_weight_kg, p_tutor_id);
    COMMIT;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        INSERT INTO CV_ERROR_LOG (procedure_nm, user_nm, error_code, error_msg)
        VALUES ('SP_INSERT_PET', USER, SQLCODE, 'Tutor não encontrado');
        COMMIT;
        RAISE;
    WHEN VALUE_ERROR THEN
        INSERT INTO CV_ERROR_LOG (procedure_nm, user_nm, error_code, error_msg)
        VALUES ('SP_INSERT_PET', USER, SQLCODE, SQLERRM);
        COMMIT;
        RAISE;
    WHEN OTHERS THEN
        INSERT INTO CV_ERROR_LOG (procedure_nm, user_nm, error_code, error_msg)
        VALUES ('SP_INSERT_PET', USER, SQLCODE, SQLERRM);
        COMMIT;
        RAISE;
END SP_INSERT_PET;
/

CREATE OR REPLACE PROCEDURE SP_INSERT_APPOINTMENT (
    p_pet_id       IN CV_APPOINTMENTS.pet_id%TYPE,
    p_clinic_id    IN CV_APPOINTMENTS.clinic_id%TYPE,
    p_scheduled_at IN CV_APPOINTMENTS.scheduled_at%TYPE,
    p_type         IN CV_APPOINTMENTS.type%TYPE,
    p_notes        IN CV_APPOINTMENTS.notes%TYPE
) AS
BEGIN
    INSERT INTO CV_APPOINTMENTS (id, pet_id, clinic_id, scheduled_at, type, notes)
    VALUES (SYS_GUID(), p_pet_id, p_clinic_id, p_scheduled_at, p_type, p_notes);
    COMMIT;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        INSERT INTO CV_ERROR_LOG (procedure_nm, user_nm, error_code, error_msg)
        VALUES ('SP_INSERT_APPOINTMENT', USER, SQLCODE, 'Pet ou Clínica não encontrado');
        COMMIT;
        RAISE;
    WHEN VALUE_ERROR THEN
        INSERT INTO CV_ERROR_LOG (procedure_nm, user_nm, error_code, error_msg)
        VALUES ('SP_INSERT_APPOINTMENT', USER, SQLCODE, SQLERRM);
        COMMIT;
        RAISE;
    WHEN OTHERS THEN
        INSERT INTO CV_ERROR_LOG (procedure_nm, user_nm, error_code, error_msg)
        VALUES ('SP_INSERT_APPOINTMENT', USER, SQLCODE, SQLERRM);
        COMMIT;
        RAISE;
END SP_INSERT_APPOINTMENT;
/

CREATE OR REPLACE PROCEDURE SP_INSERT_VACCINE (
    p_pet_id       IN CV_VACCINES.pet_id%TYPE,
    p_vaccine_name IN CV_VACCINES.vaccine_name%TYPE,
    p_applied_at   IN CV_VACCINES.applied_at%TYPE,
    p_next_dose_at IN CV_VACCINES.next_dose_at%TYPE,
    p_batch        IN CV_VACCINES.batch%TYPE
) AS
BEGIN
    INSERT INTO CV_VACCINES (id, pet_id, vaccine_name, applied_at, next_dose_at, batch)
    VALUES (SYS_GUID(), p_pet_id, p_vaccine_name, p_applied_at, p_next_dose_at, p_batch);
    COMMIT;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        INSERT INTO CV_ERROR_LOG (procedure_nm, user_nm, error_code, error_msg)
        VALUES ('SP_INSERT_VACCINE', USER, SQLCODE, 'Pet não encontrado');
        COMMIT;
        RAISE;
    WHEN VALUE_ERROR THEN
        INSERT INTO CV_ERROR_LOG (procedure_nm, user_nm, error_code, error_msg)
        VALUES ('SP_INSERT_VACCINE', USER, SQLCODE, SQLERRM);
        COMMIT;
        RAISE;
    WHEN OTHERS THEN
        INSERT INTO CV_ERROR_LOG (procedure_nm, user_nm, error_code, error_msg)
        VALUES ('SP_INSERT_VACCINE', USER, SQLCODE, SQLERRM);
        COMMIT;
        RAISE;
END SP_INSERT_VACCINE;
/

CREATE OR REPLACE PROCEDURE SP_INSERT_MEDICATION (
    p_pet_id     IN CV_MEDICATIONS.pet_id%TYPE,
    p_name       IN CV_MEDICATIONS.name%TYPE,
    p_dosage     IN CV_MEDICATIONS.dosage%TYPE,
    p_frequency  IN CV_MEDICATIONS.frequency%TYPE,
    p_start_date IN CV_MEDICATIONS.start_date%TYPE,
    p_end_date   IN CV_MEDICATIONS.end_date%TYPE
) AS
BEGIN
    INSERT INTO CV_MEDICATIONS (id, pet_id, name, dosage, frequency, start_date, end_date)
    VALUES (SYS_GUID(), p_pet_id, p_name, p_dosage, p_frequency, p_start_date, p_end_date);
    COMMIT;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        INSERT INTO CV_ERROR_LOG (procedure_nm, user_nm, error_code, error_msg)
        VALUES ('SP_INSERT_MEDICATION', USER, SQLCODE, 'Pet não encontrado');
        COMMIT;
        RAISE;
    WHEN VALUE_ERROR THEN
        INSERT INTO CV_ERROR_LOG (procedure_nm, user_nm, error_code, error_msg)
        VALUES ('SP_INSERT_MEDICATION', USER, SQLCODE, SQLERRM);
        COMMIT;
        RAISE;
    WHEN OTHERS THEN
        INSERT INTO CV_ERROR_LOG (procedure_nm, user_nm, error_code, error_msg)
        VALUES ('SP_INSERT_MEDICATION', USER, SQLCODE, SQLERRM);
        COMMIT;
        RAISE;
END SP_INSERT_MEDICATION;
/

-- ============================================================
-- 3. CARGA INICIAL DE DADOS (chamada das procedures)
-- ============================================================

DECLARE
    v_tutor1 CV_TUTORS.id%TYPE;
    v_tutor2 CV_TUTORS.id%TYPE;
    v_clinic1 CV_CLINICS.id%TYPE;
    v_clinic2 CV_CLINICS.id%TYPE;
    v_pet1 CV_PETS.id%TYPE;
    v_pet2 CV_PETS.id%TYPE;
    v_pet3 CV_PETS.id%TYPE;
BEGIN
    -- Tutores
    SP_INSERT_TUTOR('Carlos Mendes',  'carlos.mendes@email.com',  '(11) 99001-1111');
    SP_INSERT_TUTOR('Ana Paula Silva','ana.silva@email.com',       '(11) 98002-2222');

    -- Clínicas
    SP_INSERT_CLINIC('Clínica VetSaúde',   'Av. Paulista, 1000 - SP', '(11) 3001-0001', 'contato@vetsaude.com');
    SP_INSERT_CLINIC('Hospital Pet Vida',  'Rua Augusta, 500 - SP',   '(11) 3002-0002', 'contato@petvida.com');

    -- Pega IDs gerados
    SELECT id INTO v_tutor1  FROM CV_TUTORS  WHERE email = 'carlos.mendes@email.com';
    SELECT id INTO v_tutor2  FROM CV_TUTORS  WHERE email = 'ana.silva@email.com';
    SELECT id INTO v_clinic1 FROM CV_CLINICS WHERE name  = 'Clínica VetSaúde';
    SELECT id INTO v_clinic2 FROM CV_CLINICS WHERE name  = 'Hospital Pet Vida';

    -- Pets
    SP_INSERT_PET('Rex',    'DOG', 'Labrador',        DATE '2020-03-15', 28.5, v_tutor1);
    SP_INSERT_PET('Mia',    'CAT', 'Persa',           DATE '2022-07-10',  4.2, v_tutor1);
    SP_INSERT_PET('Bolinha', 'DOG','Bulldog Francês', DATE '2021-01-20', 12.0, v_tutor2);

    SELECT id INTO v_pet1 FROM CV_PETS WHERE name = 'Rex'     AND tutor_id = v_tutor1;
    SELECT id INTO v_pet2 FROM CV_PETS WHERE name = 'Mia'     AND tutor_id = v_tutor1;
    SELECT id INTO v_pet3 FROM CV_PETS WHERE name = 'Bolinha' AND tutor_id = v_tutor2;

    -- Agendamentos
    SP_INSERT_APPOINTMENT(v_pet1, v_clinic1, SYSTIMESTAMP + INTERVAL '10' DAY, 'CHECKUP',      'Check-up anual do Rex');
    SP_INSERT_APPOINTMENT(v_pet2, v_clinic1, SYSTIMESTAMP + INTERVAL '5'  DAY, 'VACCINATION',  'Reforço de vacinas da Mia');
    SP_INSERT_APPOINTMENT(v_pet3, v_clinic2, SYSTIMESTAMP + INTERVAL '15' DAY, 'RETURN',       'Retorno pós-cirurgia');
    SP_INSERT_APPOINTMENT(v_pet1, v_clinic2, SYSTIMESTAMP - INTERVAL '30' DAY, 'CHECKUP',      'Check-up anterior');

    -- Vacinas
    SP_INSERT_VACCINE(v_pet1, 'V10',          DATE '2025-01-10', DATE '2026-01-10', 'LOTE-001');
    SP_INSERT_VACCINE(v_pet1, 'Antirrábica',  DATE '2025-01-10', DATE '2026-01-10', 'LOTE-002');
    SP_INSERT_VACCINE(v_pet2, 'Quádrupla',    DATE '2024-06-20', DATE '2025-06-20', 'LOTE-010');
    SP_INSERT_VACCINE(v_pet3, 'V8',           DATE '2025-03-05', DATE '2026-03-05', 'LOTE-020');
    SP_INSERT_VACCINE(v_pet2, 'FeLV',         DATE '2023-12-01', DATE '2024-12-01', 'LOTE-030');

    -- Medicamentos
    SP_INSERT_MEDICATION(v_pet1, 'Simparica Trio',  '1 comprimido', 'Mensal',     DATE '2025-01-01', DATE '2025-12-31');
    SP_INSERT_MEDICATION(v_pet1, 'Carprofen',       '2,2mg/kg',     'A cada 12h', DATE '2025-04-01', DATE '2025-04-14');
    SP_INSERT_MEDICATION(v_pet2, 'Revolution Plus', '1 pipeta',     'Mensal',     DATE '2025-01-01', DATE '2025-12-31');
    SP_INSERT_MEDICATION(v_pet3, 'Metronidazol',    '15mg/kg',      'A cada 8h',  DATE '2025-03-10', DATE '2025-03-20');
    SP_INSERT_MEDICATION(v_pet3, 'Meloxicam',       '0,1mg/kg',     'A cada 24h', DATE '2025-04-01', DATE '2025-04-10');

    DBMS_OUTPUT.PUT_LINE('Carga inicial concluída com sucesso.');
END;
/

-- ============================================================
-- 4. BLOCO: LINHA ANTERIOR / ATUAL / PRÓXIMA (LAG / LEAD)
-- ============================================================

-- Exibe peso de cada pet com o peso do anterior e do próximo (ordenado por birth_date)

SET SERVEROUTPUT ON;

DECLARE
    CURSOR c_pets IS
        SELECT
            p.name                                                              AS pet_name,
            p.weight_kg                                                         AS peso_atual,
            LAG(p.weight_kg,  1, NULL) OVER (ORDER BY p.birth_date, p.name)    AS peso_anterior,
            LEAD(p.weight_kg, 1, NULL) OVER (ORDER BY p.birth_date, p.name)    AS peso_proximo
        FROM CV_PETS p
        ORDER BY p.birth_date, p.name;

    v_anterior VARCHAR2(10);
    v_proximo  VARCHAR2(10);
BEGIN
    DBMS_OUTPUT.PUT_LINE(RPAD('PET',       20) || RPAD('ANTERIOR', 12) || RPAD('ATUAL', 12) || 'PRÓXIMO');
    DBMS_OUTPUT.PUT_LINE(RPAD('-',        55, '-'));

    FOR r IN c_pets LOOP
        v_anterior := CASE WHEN r.peso_anterior IS NULL THEN 'Vazio' ELSE TO_CHAR(r.peso_anterior) END;
        v_proximo  := CASE WHEN r.peso_proximo  IS NULL THEN 'Vazio' ELSE TO_CHAR(r.peso_proximo)  END;

        DBMS_OUTPUT.PUT_LINE(
            RPAD(r.pet_name,     20) ||
            RPAD(v_anterior,     12) ||
            RPAD(TO_CHAR(r.peso_atual), 12) ||
            v_proximo
        );
    END LOOP;
END;
/

-- ============================================================
-- 5. BLOCOS ANÔNIMOS COM JOINS, GROUP BY E ORDER BY
-- ============================================================

-- Bloco 1: Pets por tutor com total de agendamentos
DECLARE
    CURSOR c_pets_por_tutor IS
        SELECT
            t.name                  AS tutor_name,
            p.name                  AS pet_name,
            p.species,
            COUNT(a.id)             AS total_agendamentos
        FROM CV_TUTORS t
        JOIN CV_PETS p        ON p.tutor_id  = t.id
        LEFT JOIN CV_APPOINTMENTS a ON a.pet_id = p.id
        GROUP BY t.name, p.name, p.species
        ORDER BY t.name, p.name;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== PETS POR TUTOR COM AGENDAMENTOS ===');
    DBMS_OUTPUT.PUT_LINE(RPAD('TUTOR',25) || RPAD('PET',20) || RPAD('ESPÉCIE',10) || 'AGENDAMENTOS');
    FOR r IN c_pets_por_tutor LOOP
        DBMS_OUTPUT.PUT_LINE(RPAD(r.tutor_name,25) || RPAD(r.pet_name,20) || RPAD(r.species,10) || r.total_agendamentos);
    END LOOP;
END;
/

-- Bloco 2: Vacinas por pet com total e mais recente
DECLARE
    CURSOR c_vacinas IS
        SELECT
            p.name               AS pet_name,
            COUNT(v.id)          AS total_vacinas,
            MAX(v.applied_at)    AS ultima_aplicacao,
            MIN(v.next_dose_at)  AS proxima_dose
        FROM CV_PETS p
        JOIN CV_VACCINES v ON v.pet_id = p.id
        GROUP BY p.name
        ORDER BY proxima_dose;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== VACINAS POR PET ===');
    FOR r IN c_vacinas LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD(r.pet_name, 20) ||
            ' | Total: '     || r.total_vacinas ||
            ' | Última: '    || TO_CHAR(r.ultima_aplicacao, 'DD/MM/YYYY') ||
            ' | Próxima: '   || TO_CHAR(r.proxima_dose,     'DD/MM/YYYY')
        );
    END LOOP;
END;
/

-- Bloco 3: Agendamentos por clínica e tipo
DECLARE
    CURSOR c_agenda_clinica IS
        SELECT
            c.name          AS clinic_name,
            a.type,
            COUNT(a.id)     AS total,
            SUM(CASE WHEN a.completed = 1 THEN 1 ELSE 0 END) AS concluidos
        FROM CV_CLINICS c
        JOIN CV_APPOINTMENTS a ON a.clinic_id = c.id
        GROUP BY c.name, a.type
        ORDER BY c.name, a.type;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== AGENDAMENTOS POR CLÍNICA E TIPO ===');
    FOR r IN c_agenda_clinica LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD(r.clinic_name, 25) ||
            RPAD(r.type, 15) ||
            ' | Total: ' || r.total ||
            ' | Concluídos: ' || r.concluidos
        );
    END LOOP;
END;
/

-- ============================================================
-- 6. RELATÓRIOS COM CURSOR EXPLÍCITO E SUBTOTAIS
-- ============================================================

-- Relatório de medicamentos por pet com sub-total por status e total geral

DECLARE
    CURSOR c_med IS
        SELECT
            p.name          AS pet_name,
            m.status,
            m.name          AS med_name,
            m.start_date,
            m.end_date
        FROM CV_MEDICATIONS m
        JOIN CV_PETS p ON p.id = m.pet_id
        ORDER BY p.name, m.status, m.start_date;

    v_prev_pet     CV_PETS.name%TYPE    := NULL;
    v_prev_status  VARCHAR2(20)         := NULL;
    v_subtotal_pet NUMBER               := 0;
    v_total        NUMBER               := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== RELATÓRIO DE MEDICAMENTOS POR PET ===');

    FOR r IN c_med LOOP
        -- Quebra de pet
        IF v_prev_pet IS NOT NULL AND v_prev_pet != r.pet_name THEN
            DBMS_OUTPUT.PUT_LINE(RPAD(' ', 10) || 'Sub-Total ' || v_prev_pet || ': ' || v_subtotal_pet || ' medicamento(s)');
            DBMS_OUTPUT.PUT_LINE('');
            v_subtotal_pet := 0;
        END IF;

        DBMS_OUTPUT.PUT_LINE(
            RPAD(r.pet_name, 15) ||
            RPAD(r.status,   15) ||
            RPAD(r.med_name, 25) ||
            TO_CHAR(r.start_date,'DD/MM/YYYY') || ' - ' || TO_CHAR(r.end_date,'DD/MM/YYYY')
        );

        v_prev_pet    := r.pet_name;
        v_subtotal_pet := v_subtotal_pet + 1;
        v_total        := v_total + 1;
    END LOOP;

    -- Último sub-total
    IF v_prev_pet IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE(RPAD(' ', 10) || 'Sub-Total ' || v_prev_pet || ': ' || v_subtotal_pet || ' medicamento(s)');
    END IF;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('TOTAL GERAL: ' || v_total || ' medicamento(s)');
END;
/

-- Relatório 2: vacinas vencidas com tomada de decisão

DECLARE
    CURSOR c_vac_exp IS
        SELECT
            p.name          AS pet_name,
            v.vaccine_name,
            v.next_dose_at,
            CASE
                WHEN v.next_dose_at < SYSDATE - 365 THEN 'CRÍTICO - mais de 1 ano'
                WHEN v.next_dose_at < SYSDATE - 90  THEN 'GRAVE   - mais de 90 dias'
                WHEN v.next_dose_at < SYSDATE        THEN 'VENCIDA - recente'
                ELSE                                      'EM DIA'
            END AS situacao
        FROM CV_VACCINES v
        JOIN CV_PETS p ON p.id = v.pet_id
        ORDER BY v.next_dose_at;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== SITUAÇÃO DAS VACINAS ===');
    FOR r IN c_vac_exp LOOP
        DBMS_OUTPUT.PUT_LINE(RPAD(r.pet_name,15) || RPAD(r.vaccine_name,20) ||
            TO_CHAR(r.next_dose_at,'DD/MM/YYYY') || '  ' || r.situacao);
    END LOOP;
END;
/

-- Relatório 3: agendamentos pendentes por clínica

DECLARE
    CURSOR c_pend IS
        SELECT
            c.name           AS clinic_name,
            p.name           AS pet_name,
            a.type,
            a.scheduled_at,
            TRUNC(a.scheduled_at - SYSTIMESTAMP) AS dias_ate_consulta
        FROM CV_APPOINTMENTS a
        JOIN CV_PETS    p ON p.id = a.pet_id
        JOIN CV_CLINICS c ON c.id = a.clinic_id
        WHERE a.completed = 0
          AND a.scheduled_at >= SYSTIMESTAMP
        ORDER BY a.scheduled_at;

    v_total NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== AGENDAMENTOS PENDENTES ===');
    FOR r IN c_pend LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD(r.clinic_name, 25) ||
            RPAD(r.pet_name,    15) ||
            RPAD(r.type,        15) ||
            TO_CHAR(r.scheduled_at, 'DD/MM/YYYY HH24:MI') ||
            '  (em ' || r.dias_ate_consulta || ' dias)'
        );
        v_total := v_total + 1;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('Total pendente: ' || v_total);
END;
/

-- Relatório 4: medicamentos ativos com alerta de término próximo

DECLARE
    CURSOR c_med_ativo IS
        SELECT
            p.name       AS pet_name,
            m.name       AS med_name,
            m.frequency,
            m.end_date,
            m.end_date - TRUNC(SYSDATE) AS dias_restantes
        FROM CV_MEDICATIONS m
        JOIN CV_PETS p ON p.id = m.pet_id
        WHERE m.status = 'ACTIVE'
        ORDER BY m.end_date;

    v_alerta VARCHAR2(30);
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== MEDICAMENTOS ATIVOS ===');
    FOR r IN c_med_ativo LOOP
        IF r.dias_restantes <= 0 THEN
            v_alerta := '*** VENCIDO ***';
        ELSIF r.dias_restantes <= 3 THEN
            v_alerta := '! Termina em breve';
        ELSE
            v_alerta := 'OK';
        END IF;

        DBMS_OUTPUT.PUT_LINE(
            RPAD(r.pet_name, 15) ||
            RPAD(r.med_name, 25) ||
            RPAD(r.frequency, 15) ||
            TO_CHAR(r.end_date,'DD/MM/YYYY') ||
            '  ' || r.dias_restantes || ' dias  ' || v_alerta
        );
    END LOOP;
END;
/
