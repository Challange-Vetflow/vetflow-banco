// ============================================================================
// VetFlow - Challenge FIAP 2026 (Clyvo Vet) - Sprint 4
// mongodb/01_criar_estrutura.js - colecoes com validacao ($jsonSchema) e indices
// ============================================================================
// Modelo de documentos (coerente com o padrao de acesso "prontuario completo"):
//   * tutores  -> 1 documento por tutor, com os pets EMBUTIDOS e, dentro de
//                 cada pet, vacinas / medicamentos / consultas EMBUTIDOS
//                 (dados sempre lidos juntos, crescem pouco por tutor).
//   * clinicas -> colecao propria (entidade compartilhada por muitos tutores),
//                 REFERENCIADA em consultas.clinicaId, com clinicaNome
//                 desnormalizado para leitura rapida.
//
// Idempotente: pode rodar varias vezes (cria se nao existe, senao aplica
// collMod com o schema atualizado; createIndex nao duplica indices).
//
// Executar:  mongosh "mongodb://localhost:27017" --file 01_criar_estrutura.js
// (ou colar no "MONGOSH" do MongoDB Compass)
// ============================================================================

const dbName = (typeof process !== 'undefined' && process.env.MONGO_DATABASE) || 'vetflow';
const vetflow = db.getSiblingDB(dbName);

const hex32 = { bsonType: 'string', pattern: '^[0-9A-Fa-f]{32}$' };

const schemaClinicas = {
  $jsonSchema: {
    bsonType: 'object',
    required: ['_id', 'nome', 'endereco', 'telefone', 'email', 'ativo'],
    properties: {
      _id:      hex32,
      nome:     { bsonType: 'string', minLength: 1, maxLength: 200 },
      endereco: { bsonType: 'string', maxLength: 500 },
      telefone: { bsonType: 'string', maxLength: 20 },
      email:    { bsonType: 'string', pattern: '^.+@.+$' },
      ativo:    { bsonType: 'bool' }
    }
  }
};

const schemaTutores = {
  $jsonSchema: {
    bsonType: 'object',
    required: ['_id', 'nome', 'email', 'ativo', 'pets'],
    properties: {
      _id:      hex32,
      nome:     { bsonType: 'string', minLength: 1, maxLength: 100 },
      email:    { bsonType: 'string', pattern: '^.+@.+$' },
      telefone: { bsonType: 'string', maxLength: 20 },
      ativo:    { bsonType: 'bool' },
      criadoEm: { bsonType: 'date' },
      pets: {
        bsonType: 'array',
        items: {
          bsonType: 'object',
          required: ['petId', 'nome', 'especie', 'pesoKg', 'vacinas', 'medicamentos', 'consultas'],
          properties: {
            petId:          hex32,
            nome:           { bsonType: 'string', minLength: 1 },
            especie:        { enum: ['DOG', 'CAT', 'BIRD', 'RABBIT', 'OTHER'] },
            raca:           { bsonType: 'string' },
            dataNascimento: { bsonType: 'date' },
            pesoKg:         { bsonType: ['double', 'int', 'long', 'decimal'], minimum: 0, exclusiveMinimum: true },
            idadeMeses:     { bsonType: ['int', 'long', 'double'], minimum: 0 },
            ativo:          { bsonType: 'bool' },
            vacinas: {
              bsonType: 'array',
              items: {
                bsonType: 'object',
                required: ['vacinaId', 'nome', 'aplicadaEm', 'proximaDose'],
                properties: {
                  vacinaId:    hex32,
                  nome:        { bsonType: 'string' },
                  aplicadaEm:  { bsonType: 'date' },
                  proximaDose: { bsonType: 'date' },
                  lote:        { bsonType: 'string' }
                }
              }
            },
            medicamentos: {
              bsonType: 'array',
              items: {
                bsonType: 'object',
                required: ['medicamentoId', 'nome', 'status'],
                properties: {
                  medicamentoId: hex32,
                  nome:          { bsonType: 'string' },
                  dosagem:       { bsonType: 'string' },
                  frequencia:    { bsonType: 'string' },
                  inicio:        { bsonType: 'date' },
                  fim:           { bsonType: 'date' },
                  status:        { enum: ['ACTIVE', 'COMPLETED', 'SUSPENDED'] }
                }
              }
            },
            consultas: {
              bsonType: 'array',
              items: {
                bsonType: 'object',
                required: ['consultaId', 'clinicaId', 'agendadaPara', 'tipo', 'concluida'],
                properties: {
                  consultaId:   hex32,
                  clinicaId:    hex32,
                  clinicaNome:  { bsonType: 'string' },
                  agendadaPara: { bsonType: 'date' },
                  tipo:         { enum: ['VACCINATION', 'CHECKUP', 'SURGERY', 'RETURN', 'EMERGENCY', 'OTHER'] },
                  observacoes:  { bsonType: 'string' },
                  concluida:    { bsonType: 'bool' }
                }
              }
            }
          }
        }
      }
    }
  }
};

function criarOuAtualizar(nome, validator) {
  const existe = vetflow.getCollectionNames().includes(nome);
  if (existe) {
    vetflow.runCommand({ collMod: nome, validator: validator, validationLevel: 'strict', validationAction: 'error' });
    print(`colecao ${nome}: ja existia, validador atualizado`);
  } else {
    vetflow.createCollection(nome, { validator: validator, validationLevel: 'strict', validationAction: 'error' });
    print(`colecao ${nome}: criada`);
  }
}

criarOuAtualizar('clinicas', schemaClinicas);
criarOuAtualizar('tutores', schemaTutores);

// ----------------------------------------------------------------- indices
vetflow.clinicas.createIndex({ nome: 1 }, { name: 'ix_clinicas_nome' });

vetflow.tutores.createIndex({ email: 1 }, { name: 'ux_tutores_email', unique: true });
vetflow.tutores.createIndex({ 'pets.petId': 1 }, { name: 'ix_tutores_pets_petId' });
vetflow.tutores.createIndex({ 'pets.nome': 1 }, { name: 'ix_tutores_pets_nome' });
vetflow.tutores.createIndex({ 'pets.especie': 1 }, { name: 'ix_tutores_pets_especie' });
vetflow.tutores.createIndex({ 'pets.vacinas.proximaDose': 1 }, { name: 'ix_tutores_vacinas_proximaDose' });
vetflow.tutores.createIndex({ 'pets.consultas.agendadaPara': 1 }, { name: 'ix_tutores_consultas_agendadaPara' });

print(`Estrutura do banco "${dbName}" pronta: colecoes tutores e clinicas com $jsonSchema e indices.`);
