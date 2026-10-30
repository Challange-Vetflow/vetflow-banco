// ============================================================================
// VetFlow - Challenge FIAP 2026 (Clyvo Vet) - Sprint 4
// mongodb/03_consultas.js - consultas de demonstracao no modelo de documentos
// ============================================================================
// Executar: mongosh "mongodb://localhost:27017" --file mongodb/03_consultas.js
// ============================================================================

const dbName = (typeof process !== 'undefined' && process.env.MONGO_DATABASE) || 'vetflow';
const vetflow = db.getSiblingDB(dbName);
const agora = new Date();

function titulo(t) { print('\n==== ' + t + ' ===='); }

// ---------------------------------------------------------------------------
// 1. Prontuario completo de um pet (uma unica leitura - beneficio do embed)
// ---------------------------------------------------------------------------
titulo('1. Prontuario completo do Rex');
printjson(vetflow.tutores.aggregate([
  { $match: { 'pets.nome': 'Rex' } },
  { $unwind: '$pets' },
  { $match: { 'pets.nome': 'Rex' } },
  { $project: { _id: 0, tutor: '$nome', email: 1, pet: '$pets' } }
]).toArray());

// ---------------------------------------------------------------------------
// 2. Vacinas vencidas ($unwind duplo + $match na data da proxima dose)
// ---------------------------------------------------------------------------
titulo('2. Vacinas vencidas (proximaDose < agora)');
printjson(vetflow.tutores.aggregate([
  { $unwind: '$pets' },
  { $unwind: '$pets.vacinas' },
  { $match: { 'pets.vacinas.proximaDose': { $lt: agora } } },
  { $project: {
      _id: 0,
      tutor: '$nome',
      telefone: 1,
      pet: '$pets.nome',
      vacina: '$pets.vacinas.nome',
      venceuEm: '$pets.vacinas.proximaDose',
      diasAtraso: { $floor: { $divide: [{ $subtract: [agora, '$pets.vacinas.proximaDose'] }, 86400000] } }
  } },
  { $sort: { venceuEm: 1 } }
]).toArray());

// ---------------------------------------------------------------------------
// 3. Proximas consultas com dados da clinica ($lookup consultas -> clinicas)
// ---------------------------------------------------------------------------
titulo('3. Proximas consultas com endereco/telefone da clinica ($lookup)');
printjson(vetflow.tutores.aggregate([
  { $unwind: '$pets' },
  { $unwind: '$pets.consultas' },
  { $match: { 'pets.consultas.concluida': false, 'pets.consultas.agendadaPara': { $gte: agora } } },
  { $lookup: { from: 'clinicas', localField: 'pets.consultas.clinicaId', foreignField: '_id', as: 'clinica' } },
  { $unwind: '$clinica' },
  { $project: {
      _id: 0,
      quando: '$pets.consultas.agendadaPara',
      tipo: '$pets.consultas.tipo',
      pet: '$pets.nome',
      tutor: '$nome',
      clinica: '$clinica.nome',
      endereco: '$clinica.endereco',
      telefoneClinica: '$clinica.telefone'
  } },
  { $sort: { quando: 1 } }
]).toArray());

// ---------------------------------------------------------------------------
// 4. Media de peso por especie ($group)
// ---------------------------------------------------------------------------
titulo('4. Media de peso por especie');
printjson(vetflow.tutores.aggregate([
  { $unwind: '$pets' },
  { $group: {
      _id: '$pets.especie',
      totalPets: { $sum: 1 },
      pesoMedioKg: { $avg: '$pets.pesoKg' },
      pesoTotalKg: { $sum: '$pets.pesoKg' }
  } },
  { $project: { _id: 0, especie: '$_id', totalPets: 1, pesoMedioKg: { $round: ['$pesoMedioKg', 2] }, pesoTotalKg: { $round: ['$pesoTotalKg', 2] } } },
  { $sort: { especie: 1 } }
]).toArray());

// ---------------------------------------------------------------------------
// 5. Update em array aninhado com arrayFilters: marca como COMPLETED os
//    medicamentos ACTIVE cujo fim ja passou (em qualquer pet de qualquer tutor)
// ---------------------------------------------------------------------------
titulo('5. Update com arrayFilters - encerrar medicamentos vencidos');
const r = vetflow.tutores.updateMany(
  { 'pets.medicamentos': { $elemMatch: { status: 'ACTIVE', fim: { $lt: agora } } } },
  { $set: { 'pets.$[].medicamentos.$[med].status': 'COMPLETED' } },
  { arrayFilters: [{ 'med.status': 'ACTIVE', 'med.fim': { $lt: agora } }] }
);
printjson({ documentosEncontrados: r.matchedCount, documentosAlterados: r.modifiedCount });

// 5b. Outro exemplo: atualizar o peso de um pet especifico pelo nome
const r2 = vetflow.tutores.updateOne(
  { email: 'carlos.mendes@email.com' },
  { $set: { 'pets.$[p].pesoKg': 29.0 } },
  { arrayFilters: [{ 'p.nome': 'Rex' }] }
);
printjson({ pesoRexAtualizado: r2.modifiedCount === 1 });

titulo('Medicamentos ativos apos o update');
printjson(vetflow.tutores.aggregate([
  { $unwind: '$pets' },
  { $unwind: '$pets.medicamentos' },
  { $match: { 'pets.medicamentos.status': 'ACTIVE' } },
  { $project: { _id: 0, pet: '$pets.nome', medicamento: '$pets.medicamentos.nome', fim: '$pets.medicamentos.fim' } }
]).toArray());
