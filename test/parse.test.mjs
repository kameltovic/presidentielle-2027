// Casse quand les éditeurs Wikipédia changent la forme des tableaux.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { parseRows, section } from '../scripts/sync.mjs';

const wt = (f) => readFileSync(new URL(f, import.meta.url), 'utf8');

test('candidats déclarés', () => {
  const rows = parseRows(section(wt('./candidatures.wikitext'), 'Candidats déclarés'));
  assert.ok(rows.length >= 15, `${rows.length} lignes`);
  for (const n of ['Nathalie Arthaud', 'Gabriel Attal', 'Marine Le Pen', 'Jean-Luc Mélenchon']) assert.ok(rows.some((r) => r.name === n), n);
  const lepen = rows.find((r) => r.name === 'Marine Le Pen');
  assert.equal(lepen.party, 'Rassemblement national');
  assert.equal(lepen.sortName, 'Le Pen');
  assert.equal(lepen.birth, '1968-08-05');
  assert.ok(lepen.photo);
});

test('primaires (format [[lien]] sans TriNom)', () => {
  const ps = parseRows(section(wt('./primaire-ps.wikitext'), 'Candidats officiels'));
  assert.ok(ps.some((r) => r.name === 'Olivier Faure' && r.party === 'Parti socialiste'));
  const g = parseRows(section(wt('./primaire-gauche.wikitext'), 'Déclarés'));
  assert.ok(g.some((r) => r.name === 'François Ruffin'));
});

test('fonctions politiques lisibles', () => {
  const attal = parseRows(section(wt('./candidatures.wikitext'), 'Candidats déclarés')).find((r) => r.name === 'Gabriel Attal');
  assert.ok(attal.roles.length >= 2, attal.roles.join(' | '));
  assert.ok(attal.roles.every((r) => !/[{}[\]<>]/.test(r)), attal.roles.join(' | '));
});

test('sondages : hypothèses, substitutions, classement', async () => {
  const { allPolls, aggregatePolls } = await import('../scripts/sync.mjs');
  const polls = allPolls(wt('./sondages.wikitext'));
  assert.ok(polls.length >= 50, `${polls.length} hypothèses`);
  const ifop = polls.find((p) => p.pollster === 'Ifop' && p.date === '2026-09-29');
  assert.equal(ifop.scores['Marine Le Pen'], 32);
  assert.ok(polls.some((p) => p.scores['Olivier Faure'] != null), 'candidat substitué dans une colonne');
  assert.ok(polls.some((p) => p.scores['David Lisnard'] != null), 'colonne Autres');
  const { result } = aggregatePolls(polls);
  assert.equal(result['marine-le-pen'].rank, 1);
});
