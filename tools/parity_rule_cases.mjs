import assert from 'node:assert/strict';
import fs from 'node:fs';

const FIELDS = ['acceptance', 'behavior_assertions'];
const FORMAT = 2;

export function readParityRuleCases(file) {
  const data = JSON.parse(fs.readFileSync(file, 'utf8'));
  if (!Object.hasOwn(data, 'format_version')) return data;
  assert.equal(data.format_version, FORMAT, 'Unknown rule case storage format');
  assert.ok(Array.isArray(data.assertion_sets) && data.rules && typeof data.rules === 'object' && !Array.isArray(data.rules), 'Invalid rule case storage');
  for (const [key, rule] of Object.entries(data.rules)) {
    assert.ok(rule && typeof rule === 'object' && !Array.isArray(rule), `Invalid rule case: ${key}`);
    for (const field of FIELDS) {
      if (!Object.hasOwn(rule, field)) continue;
      const index = rule[field];
      assert.ok(Number.isInteger(index) && Array.isArray(data.assertion_sets[index]), `Invalid assertion set: ${key}/${field}`);
      rule[field] = data.assertion_sets[index];
    }
  }
  return data.rules;
}

export function writeParityRuleCases(file, cases) {
  const indexes = new Map();
  const assertionSets = [];
  const rules = {};
  for (const [key, original] of Object.entries(cases)) {
    const rule = {...original};
    for (const field of FIELDS) {
      if (!Object.hasOwn(rule, field)) continue;
      assert.ok(Array.isArray(rule[field]), `Invalid rule assertion list: ${key}/${field}`);
      const contents = JSON.stringify(rule[field]);
      if (!indexes.has(contents)) {
        indexes.set(contents, assertionSets.length);
        assertionSets.push(rule[field]);
      }
      rule[field] = indexes.get(contents);
    }
    rules[key] = rule;
  }
  const payload = `${JSON.stringify({format_version: FORMAT, assertion_sets: assertionSets, rules})}\n`;
  assert.ok(Buffer.byteLength(payload) < 100 * 1024 * 1024, 'Rule case evidence exceeds GitHub blob limit; partition assertion sets before recording');
  fs.writeFileSync(file, payload);
}
