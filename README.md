# VetFlow API — Challenge FIAP 2026

Solução desenvolvida para o **Challenge FIAP 2026** em parceria com a **CLYVO VET**.

## Integrantes do Grupo

| Nome | RM | Turma |
|------|----|-------|
| Andrei de Paiva Gibbini | 563061 | 2TDSPF |
| Pedro Sakai Silva Zambaca | 565956 | 2TDSPF |
| Pedro Santos Pequini | 561842 | 2TDSPF |
| Arthur Câmara | 562310 | 2TDSPG |
| Diogo Cunha | 563654 | 2TDSPF |

## Problema de Negócio

Tutores de pets só acionam clínicas em urgências ou vacinas óbvias. Isso gera baixa recorrência, menor LTV para as clínicas e histórico clínico fragmentado.

## Solução

API REST que centraliza o histórico clínico do pet, organiza agendamentos, registra vacinas e medicamentos, servindo como backend para app mobile, dashboard clínico e integrações via WhatsApp.

## Arquitetura Java
```
src/main/java/fiap/com/br/vetflow/
├── config/       SwaggerConfig
├── controller/   TutorController, PetController, ClinicController,
│                 AppointmentController, VaccineController, MedicationController
├── dto/          TutorDtos, PetDtos, ClinicDtos, AppointmentDtos, VaccineDtos, MedicationDtos
├── entity/       Tutor, Pet, Clinic, Appointment, Vaccine, Medication + Enums
├── repository/   Spring Data JPA com JPQL customizada
└── service/      TutorService, PetService, ClinicService,
                  AppointmentService, VaccineService, MedicationService
```

## Tecnologias
- Spring Boot 3.4, Spring Data JPA, Spring Cache, Lombok
- H2 in-memory (desenvolvimento), Oracle XE (produção)
- Swagger/OpenAPI via springdoc

## Como Executar

```bash
./mvnw spring-boot:run
```

- Swagger: http://localhost:8080/swagger-ui.html
- H2 Console: http://localhost:8080/h2-console (JDBC URL: `jdbc:h2:mem:vetflowdb`)

## Produção com Oracle FIAP

Edite `src/main/resources/application.properties`:
```properties
spring.datasource.url=jdbc:oracle:thin:@oracle.fiap.com.br:1521:orcl
spring.datasource.username=<SEU_RM>
spring.datasource.password=<SUA_SENHA>
spring.datasource.driver-class-name=oracle.jdbc.OracleDriver
spring.jpa.database-platform=org.hibernate.dialect.OracleDialect
spring.jpa.hibernate.ddl-auto=none
spring.h2.console.enabled=false
```

## Rotas Principais

| Recurso | GET lista | GET id | POST | PUT | DELETE |
|---------|-----------|--------|------|-----|--------|
| /api/tutors | paginado+sort | /{id} | criar | /{id} | /{id} |
| /api/pets | paginado+sort | /{id} | criar | /{id} | /{id} |
| /api/clinics | lista | /{id} | criar | /{id} | /{id} |
| /api/appointments | lista | /{id} | criar | /{id} | /{id} |
| /api/vaccines | paginado | /{id} | criar | - | /{id} |
| /api/medications | lista | /{id} | criar | /{id} | /{id} |

Rotas extras: `/api/pets/by-tutor/{id}`, `/api/vaccines/expired`, `/api/vaccines/due-soon`, `/api/appointments/pending`, `/api/medications/active`, `/api/tutors/search`

## Benefícios para o Negócio
- Aumento da recorrência de consultas preventivas
- Redução de vacinas vencidas e abandono de tratamentos
- Histórico longitudinal estruturado por pet
- Base escalável para integração com app mobile e WhatsApp
