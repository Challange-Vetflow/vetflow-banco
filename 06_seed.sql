-- ============================================================================
-- VetFlow - Challenge FIAP 2026 (Clyvo Vet)
-- Mastering Relational and Non-Relational Database - Sprint 4
-- 06_seed.sql - carga inicial via PKG_VETFLOW_CADASTRO
-- ============================================================================
-- Mesmos dados da Sprint 3 (5 tutores, 2 clinicas, 6 pets com os mesmos
-- donos, consultas, vacinas e medicamentos), agora inseridos SOMENTE pelas
-- procedures do pacote, com datas ajustadas para out/2026:
--   * vacinas vencidas (Rex V10, Mia Quadrupla, Luna Quadrupla) e em dia;
--   * medicamentos ativos (Status 0) e tratamentos ja concluidos (Status 1);
--   * consultas futuras relativas a SYSTIMESTAMP + 1 consulta ja realizada.
-- + os 3 usuarios de login do contrato (senha "senha123" em BCrypt).
--
-- Tipos de consulta (ordem do contrato): 0=VACCINATION, 1=CHECKUP, 3=RETURN
-- Especies: 0=DOG, 1=CAT
--
-- RODE NUMA BASE LIMPA (logo apos 01 a 05). Se o tutor carlos.mendes ja
-- existir, o script apenas avisa e nao insere nada (nao gera erro).
-- As procedures nao fazem COMMIT: o COMMIT esta no fim deste bloco.
-- ============================================================================

SET DEFINE OFF
SET SERVEROUTPUT ON

DECLARE
    c_hash CONSTANT NVARCHAR2(255) := '$2a$10$jq2BeYtOaA5O6ff.ct9/i.81Kmb5e4GM9OLRWUdDWQ.otPAtmFnAC';

    v_ja_existe NUMBER;

    -- tutores
    v_carlos   RAW(16);
    v_ana      RAW(16);
    v_fernanda RAW(16);
    v_marcos   RAW(16);
    v_juliana  RAW(16);
    -- clinicas
    v_vetsaude RAW(16);
    v_petvida  RAW(16);
    -- pets
    v_rex      RAW(16);
    v_mia      RAW(16);
    v_bolinha  RAW(16);
    v_thor     RAW(16);
    v_luna     RAW(16);
    v_bidu     RAW(16);
    -- auxiliares (ids de filhos que nao precisamos guardar)
    v_id       RAW(16);
    v_consulta_passada RAW(16);
    v_med_carprofen    RAW(16);
    v_med_metronidazol RAW(16);

    -- hoje a meia-noite (base das consultas futuras)
    v_hoje TIMESTAMP := CAST(TRUNC(SYSDATE) AS TIMESTAMP);
BEGIN
    SELECT COUNT(*) INTO v_ja_existe FROM "CV_Tutors" WHERE "Email" = 'carlos.mendes@email.com';
    IF v_ja_existe > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Seed ja aplicado anteriormente (carlos.mendes@email.com existe). Nada foi inserido.');
        RETURN;
    END IF;

    -- ------------------------------------------------------------------ tutores
    PKG_VETFLOW_CADASTRO.SP_INSERT_TUTOR('Carlos Mendes',   'carlos.mendes@email.com',  '(11) 99001-1111', v_carlos);
    PKG_VETFLOW_CADASTRO.SP_INSERT_TUTOR('Ana Paula Silva', 'ana.silva@email.com',      '(11) 98002-2222', v_ana);
    PKG_VETFLOW_CADASTRO.SP_INSERT_TUTOR('Fernanda Costa',  'fernanda.costa@email.com', '(11) 97003-3333', v_fernanda);
    PKG_VETFLOW_CADASTRO.SP_INSERT_TUTOR('Marcos Rocha',    'marcos.rocha@email.com',   '(11) 96004-4444', v_marcos);
    PKG_VETFLOW_CADASTRO.SP_INSERT_TUTOR('Juliana Alves',   'juliana.alves@email.com',  '(11) 95005-5555', v_juliana);

    -- ----------------------------------------------------------------- clinicas
    PKG_VETFLOW_CADASTRO.SP_INSERT_CLINIC('Clínica VetSaúde',  'Av. Paulista, 1000 - SP', '(11) 3001-0001', 'contato@vetsaude.com', v_vetsaude);
    PKG_VETFLOW_CADASTRO.SP_INSERT_CLINIC('Hospital Pet Vida', 'Rua Augusta, 500 - SP',   '(11) 3002-0002', 'contato@petvida.com',  v_petvida);

    -- --------------------------------------------------------------------- pets
    -- Carlos tem Rex e Thor (ambos DOG) -> somados numa unica linha no
    -- relatorio de peso por tutor+especie (mesma ideia da Sprint 3).
    PKG_VETFLOW_CADASTRO.SP_INSERT_PET('Rex',     0, 'Labrador',         TIMESTAMP '2020-03-15 00:00:00', 28.5, v_carlos,   v_rex);
    PKG_VETFLOW_CADASTRO.SP_INSERT_PET('Mia',     1, 'Persa',            TIMESTAMP '2022-07-10 00:00:00',  4.2, v_carlos,   v_mia);
    PKG_VETFLOW_CADASTRO.SP_INSERT_PET('Bolinha', 0, 'Bulldog Francês',  TIMESTAMP '2021-01-20 00:00:00', 12.0, v_ana,      v_bolinha);
    PKG_VETFLOW_CADASTRO.SP_INSERT_PET('Thor',    0, 'Golden Retriever', TIMESTAMP '2019-05-10 00:00:00', 32.0, v_carlos,   v_thor);
    PKG_VETFLOW_CADASTRO.SP_INSERT_PET('Luna',    1, 'Siamês',           TIMESTAMP '2023-02-14 00:00:00',  3.8, v_carlos,   v_luna);
    PKG_VETFLOW_CADASTRO.SP_INSERT_PET('Bidu',    0, 'Poodle',           TIMESTAMP '2021-08-01 00:00:00',  6.5, v_fernanda, v_bidu);

    -- ---------------------------------------------------------------- consultas
    PKG_VETFLOW_CADASTRO.SP_INSERT_APPOINTMENT(v_rex,     v_vetsaude, v_hoje + INTERVAL '10' DAY + INTERVAL '10' HOUR, 1, 'Check-up anual do Rex', v_id);
    PKG_VETFLOW_CADASTRO.SP_INSERT_APPOINTMENT(v_mia,     v_vetsaude, v_hoje + INTERVAL '5'  DAY + INTERVAL '14' HOUR, 0, 'Reforço de vacinas da Mia', v_id);
    PKG_VETFLOW_CADASTRO.SP_INSERT_APPOINTMENT(v_bolinha, v_petvida,  v_hoje + INTERVAL '15' DAY + INTERVAL '9'  HOUR, 3, 'Retorno pós-cirurgia', v_id);
    PKG_VETFLOW_CADASTRO.SP_INSERT_APPOINTMENT(v_luna,    v_vetsaude, v_hoje + INTERVAL '20' DAY + INTERVAL '11' HOUR, 0, 'Quádrupla felina atrasada', v_id);
    PKG_VETFLOW_CADASTRO.SP_INSERT_APPOINTMENT(v_bidu,    v_petvida,  v_hoje + INTERVAL '8'  DAY + INTERVAL '16' HOUR, 1, 'Avaliação dermatológica', v_id);

    -- Consulta ja realizada (historico): a procedure nao aceita agendamento no
    -- passado, entao ela e agendada e depois "realizada" - o mesmo que a
    -- aplicacao faz ao concluir a consulta (UPDATE de data/Completed).
    PKG_VETFLOW_CADASTRO.SP_INSERT_APPOINTMENT(v_rex, v_petvida, v_hoje + INTERVAL '1' DAY, 1, 'Check-up anterior', v_consulta_passada);
    UPDATE "CV_Appointments"
       SET "ScheduledAt" = v_hoje - INTERVAL '30' DAY + INTERVAL '10' HOUR,
           "Completed"   = 1
     WHERE "Id" = v_consulta_passada;

    -- ------------------------------------------------------------------ vacinas
    PKG_VETFLOW_CADASTRO.SP_INSERT_VACCINE(v_rex,     'V10',         TIMESTAMP '2025-10-10 00:00:00', TIMESTAMP '2026-10-10 00:00:00', 'LOTE-001', v_id); -- vencida
    PKG_VETFLOW_CADASTRO.SP_INSERT_VACCINE(v_rex,     'Antirrábica', TIMESTAMP '2026-03-15 00:00:00', TIMESTAMP '2027-03-15 00:00:00', 'LOTE-002', v_id); -- em dia
    PKG_VETFLOW_CADASTRO.SP_INSERT_VACCINE(v_mia,     'Quádrupla',   TIMESTAMP '2025-06-20 00:00:00', TIMESTAMP '2026-06-20 00:00:00', 'LOTE-010', v_id); -- vencida
    PKG_VETFLOW_CADASTRO.SP_INSERT_VACCINE(v_mia,     'FeLV',        TIMESTAMP '2026-02-01 00:00:00', TIMESTAMP '2027-02-01 00:00:00', 'LOTE-030', v_id); -- em dia
    PKG_VETFLOW_CADASTRO.SP_INSERT_VACCINE(v_bolinha, 'V8',          TIMESTAMP '2026-03-05 00:00:00', TIMESTAMP '2027-03-05 00:00:00', 'LOTE-020', v_id); -- em dia
    PKG_VETFLOW_CADASTRO.SP_INSERT_VACCINE(v_thor,    'V10',         TIMESTAMP '2026-05-12 00:00:00', TIMESTAMP '2027-05-12 00:00:00', 'LOTE-040', v_id); -- em dia
    PKG_VETFLOW_CADASTRO.SP_INSERT_VACCINE(v_luna,    'Quádrupla',   TIMESTAMP '2025-09-01 00:00:00', TIMESTAMP '2026-09-01 00:00:00', 'LOTE-050', v_id); -- vencida
    PKG_VETFLOW_CADASTRO.SP_INSERT_VACCINE(v_bidu,    'Antirrábica', TIMESTAMP '2026-08-20 00:00:00', TIMESTAMP '2027-08-20 00:00:00', 'LOTE-060', v_id); -- em dia

    -- ------------------------------------------------------------- medicamentos
    PKG_VETFLOW_CADASTRO.SP_INSERT_MEDICATION(v_rex,     'Simparica Trio',  '1 comprimido', 'Mensal',     TIMESTAMP '2026-01-01 00:00:00', TIMESTAMP '2026-12-31 00:00:00', v_id);
    PKG_VETFLOW_CADASTRO.SP_INSERT_MEDICATION(v_rex,     'Carprofen',       '2,2mg/kg',     'A cada 12h', TIMESTAMP '2026-04-01 00:00:00', TIMESTAMP '2026-04-14 00:00:00', v_med_carprofen);
    PKG_VETFLOW_CADASTRO.SP_INSERT_MEDICATION(v_mia,     'Revolution Plus', '1 pipeta',     'Mensal',     TIMESTAMP '2026-01-01 00:00:00', TIMESTAMP '2026-12-31 00:00:00', v_id);
    PKG_VETFLOW_CADASTRO.SP_INSERT_MEDICATION(v_bolinha, 'Metronidazol',    '15mg/kg',      'A cada 8h',  TIMESTAMP '2026-03-10 00:00:00', TIMESTAMP '2026-03-20 00:00:00', v_med_metronidazol);
    PKG_VETFLOW_CADASTRO.SP_INSERT_MEDICATION(v_bolinha, 'Meloxicam',       '0,1mg/kg',     'A cada 24h', TIMESTAMP '2026-10-20 00:00:00', TIMESTAMP '2026-11-05 00:00:00', v_id);
    PKG_VETFLOW_CADASTRO.SP_INSERT_MEDICATION(v_thor,    'Condroitina',     '1 comprimido', 'A cada 24h', TIMESTAMP '2026-09-01 00:00:00', TIMESTAMP '2027-02-28 00:00:00', v_id);

    -- Tratamentos ja encerrados: Status 1 = COMPLETED
    UPDATE "CV_Medications"
       SET "Status" = 1
     WHERE "Id" IN (v_med_carprofen, v_med_metronidazol);

    -- ----------------------------------------------------------------- usuarios
    PKG_VETFLOW_CADASTRO.SP_INSERT_USER('Dra. Fernanda Alves', 'vet@vetflow.com',         c_hash, 'VET',   NULL,     v_id);
    PKG_VETFLOW_CADASTRO.SP_INSERT_USER('Carlos Mendes',       'carlos.mendes@email.com', c_hash, 'TUTOR', v_carlos, v_id);
    PKG_VETFLOW_CADASTRO.SP_INSERT_USER('Ana Paula Silva',     'ana.silva@email.com',     c_hash, 'TUTOR', v_ana,    v_id);

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Seed concluido: 5 tutores, 2 clinicas, 6 pets, 6 consultas, 8 vacinas, 6 medicamentos, 3 usuarios.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Falha no seed (nada foi gravado): ' || SQLERRM);
        RAISE;
END;
/

-- Conferencia rapida
SELECT 'CV_Tutors' AS tabela, COUNT(*) AS total FROM "CV_Tutors"
UNION ALL SELECT 'CV_Clinics',      COUNT(*) FROM "CV_Clinics"
UNION ALL SELECT 'CV_Pets',         COUNT(*) FROM "CV_Pets"
UNION ALL SELECT 'CV_Appointments', COUNT(*) FROM "CV_Appointments"
UNION ALL SELECT 'CV_Vaccines',     COUNT(*) FROM "CV_Vaccines"
UNION ALL SELECT 'CV_Medications',  COUNT(*) FROM "CV_Medications"
UNION ALL SELECT 'CV_Users',        COUNT(*) FROM "CV_Users";

PROMPT 06_seed.sql concluido.
