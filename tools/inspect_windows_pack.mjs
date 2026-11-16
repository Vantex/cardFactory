import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';

// Directory fields follow the official Godot 4.7.2 PCK format:
// https://github.com/godotengine/godot/blob/4.7.2-stable/core/io/file_access_pack.cpp
const [filename, reportPath] = process.argv.slice(2);
assert.ok(filename && reportPath, 'Specify the exported PCK and inventory report paths');
const root = path.resolve(import.meta.dirname, '..');
const bytes = fs.readFileSync(filename);
const hash = (algorithm, data) => crypto.createHash(algorithm).update(data).digest('hex');
assert.equal(bytes.readUInt32LE(0), 0x43504447, 'Not a standalone Godot PCK');
const version = bytes.readUInt32LE(4);
assert.ok([3,4].includes(version), `Unsupported package format: ${version}`);
assert.ok((bytes.readUInt32LE(20) & ~2) === 0, 'Encrypted or sparse packages require another inspection method');
const base = Number(bytes.readBigUInt64LE(24));
let cursor = Number(bytes.readBigUInt64LE(32));
const count = bytes.readUInt32LE(cursor);
cursor += 4;
const files = [];
const remaps = [];
for (let index = 0; index < count; index++) {
  const length = bytes.readUInt32LE(cursor);
  cursor += 4;
  const file = bytes.subarray(cursor,cursor+length).toString('utf8').replace(/\0+$/, '').replace(/^res:\/\//,'');
  cursor += length;
  assert.ok(file && !file.split('/').includes('..') && !files.some(row=>row.file===file), 'Invalid or duplicate package path');
  const offset = base + Number(bytes.readBigUInt64LE(cursor));
  const size = Number(bytes.readBigUInt64LE(cursor+8));
  const md5 = bytes.subarray(cursor+16,cursor+32).toString('hex');
  const flags = bytes.readUInt32LE(cursor+32);
  cursor += 36;
  assert.equal(flags, 0, `Unsupported resource flags: ${file}`);
  assert.ok(offset >= 0 && offset + size <= bytes.length, `Resource outside package: ${file}`);
  const content = bytes.subarray(offset,offset+size);
  assert.equal(hash('md5',content),md5,`Corrupt packaged resource: ${file}`);
  assert.ok(!/^(tests|docs|tools|scripts\/test|scenes\/test)(\/|$)/.test(file),`Development resource in package: ${file}`);
  if (file.endsWith('.remap')) {
    const target = content.toString('utf8').match(/path="res:\/\/([^"\r\n]+)"/)?.[1];
    assert.ok(target,`Invalid resource remap: ${file}`);
    remaps.push({file,target});
  }
  files.push({file,bytes:size,sha256:hash('sha256',content)});
}
for (const remap of remaps) assert.ok(files.some(row=>row.file===remap.target),`Missing remap target: ${remap.file} -> ${remap.target}`);
for (const name of ['project.binary','autoload/DataManager.gd.remap']) assert.ok(files.some(row=>row.file===name),`Missing runtime resource: ${name}`);
assert.ok(files.some(row=>['scenes/main/Main.tscn','scenes/main/Main.tscn.remap'].includes(row.file)), 'Missing runtime main scene or its export remap');
const checkData = directory => {
  for (const entry of fs.readdirSync(path.join(root,directory),{withFileTypes:true})) {
    const file = `${directory}/${entry.name}`;
    if (entry.isDirectory()) checkData(file);
    else if (entry.name.endsWith('.json')) {
      const packaged = files.find(row=>row.file===file);
      assert.ok(packaged,`Missing data dependency: ${file}`);
      assert.equal(packaged.sha256,hash('sha256',fs.readFileSync(path.join(root,file))),`Packaged data differs from project: ${file}`);
    }
  }
};
checkData('data');
files.sort((a,b)=>a.file.localeCompare(b.file));
fs.writeFileSync(reportPath,JSON.stringify({format_version:version,pck_sha256:hash('sha256',bytes),files},null,2)+'\n');
console.log(`WINDOWS PACKAGE CONTENTS PASSED: ${files.length} resources; current data verified, development files excluded`);
