// ============================================================================
// VetFlow - Challenge FIAP 2026 (Clyvo Vet) - Sprint 4
// mongodb/02_importar_dados.js - importa dataset_vetflow.json (export Oracle)
// ============================================================================
// Le o JSON gerado por PKG_VETFLOW_UTIL.FN_EXPORTAR_DATASET_JSON
// (banco/08_exportar_json.sql ou GET /api/v1/export/dataset da API .NET),
// converte as datas ISO (texto) em Date do BSON e grava nas colecoes.
//
// Reimportar e seguro: cada documento e substituido pelo _id (upsert), entao
// rodar de novo nao duplica nada.
//
// Executar (a partir da pasta banco/):
//   mongosh "mongodb://localhost:27017" --file mongodb/02_importar_dados.js
// Outro caminho de arquivo:
//   DATASET=C:\caminho\dataset_vetflow.json mongosh --file mongodb/02_importar_dados.js
//   (PowerShell: $env:DATASET="C:\caminho\dataset_vetflow.json"; mongosh --file ...)
// ============================================================================

const fs = require('fs');
const path = require('path');

const dbName = process.env.MONGO_DATABASE || 'vetflow';
const vetflow = db.getSiblingDB(dbName);

// Procura o arquivo: variavel DATASET, pasta atual, ou pasta-pai do script
const candidatos = [
  process.env.DATASET,
  'dataset_vetflow.json',
  path.join('..', 'dataset_vetflow.json'),
  path.join('banco', 'dataset_vetflow.json')
].filter(Boolean);

const arquivo = candidatos.find(c => fs.existsSync(c));
if (!arquivo) {
  throw new Error('dataset_vetflow.json nao encontrado. Rode a partir da pasta banco/ ou defina DATASET. Tentados: ' + candidatos.join(', '));
}

// O SPOOL do SQL Developer pode deixar linhas em branco/espacos antes do "{"
const texto = fs.readFileSync(arquivo, 'utf8').replace(/^\uFEFF/, '').trim();
const dataset = JSON.parse(texto);

// "2026-10-27" ou "2026-10-27T10:00:00" (sem fuso) -> Date (UTC)
function paraData(valor) {
  if (valor === null || valor === undefined || valor === '') return null;
  const iso = valor.length === 10 ? valor + 'T00:00:00Z' : valor + 'Z';
  const d = new Date(iso);
  if (isNaN(d.getTime())) throw new Error('Data invalida no dataset: ' + valor);
  return d;
}

const tutores = (dataset.tutores || []).map(t => ({
  _id: t._id,
  nome: t.nome,
  email: t.email,
  telefone: t.telefone,
  ativo: t.ativo,
  criadoEm: paraData(t.criadoEm),
  pets: (t.pets || []).map(p => ({
    petId: p.petId,
    nome: p.nome,
    especie: p.especie,
    raca: p.raca,
    dataNascimento: paraData(p.dataNascimento),
    pesoKg: Number(p.pesoKg),
    idadeMeses: p.idadeMeses,
    ativo: p.ativo,
    vacinas: (p.vacinas || []).map(v => ({
      vacinaId: v.vacinaId,
      nome: v.nome,
      aplicadaEm: paraData(v.aplicadaEm),
      proximaDose: paraData(v.proximaDose),
      lote: v.lote
    })),
    medicamentos: (p.medicamentos || []).map(m => ({
      medicamentoId: m.medicamentoId,
      nome: m.nome,
      dosagem: m.dosagem,
      frequencia: m.frequencia,
      inicio: paraData(m.inicio),
      fim: paraData(m.fim),
      status: m.status
    })),
    consultas: (p.consultas || []).map(c => ({
      consultaId: c.consultaId,
      clinicaId: c.clinicaId,
      clinicaNome: c.clinicaNome,
      agendadaPara: paraData(c.agendadaPara),
      tipo: c.tipo,
      observacoes: c.observacoes,
      concluida: c.concluida
    }))
  }))
}));

const clinicas = (dataset.clinicas || []).map(c => ({
  _id: c._id,
  nome: c.nome,
  endereco: c.endereco,
  telefone: c.telefone,
  email: c.email,
  ativo: c.ativo
}));

function upsertTodos(colecao, docs) {
  if (docs.length === 0) return { upserted: 0, modified: 0 };
  const ops = docs.map(d => ({ replaceOne: { filter: { _id: d._id }, replacement: d, upsert: true } }));
  const r = vetflow.getCollection(colecao).bulkWrite(ops, { ordered: true });
  return { upserted: r.upsertedCount, modified: r.modifiedCount };
}

// Clinicas primeiro (sao referenciadas pelas consultas)
const rc = upsertTodos('clinicas', clinicas);
const rt = upsertTodos('tutores', tutores);

print(`Arquivo: ${arquivo}`);
print(`clinicas -> novos: ${rc.upserted}, atualizados: ${rc.modified}`);
print(`tutores  -> novos: ${rt.upserted}, atualizados: ${rt.modified}`);
print(`Total no banco "${dbName}": ${vetflow.tutores.countDocuments()} tutores, ${vetflow.clinicas.countDocuments()} clinicas, ` +
      `${tutores.reduce((s, t) => s + t.pets.length, 0)} pets embutidos no arquivo.`);
