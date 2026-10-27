const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const logic = {};
vm.createContext(logic);
vm.runInContext(fs.readFileSync(path.join(__dirname, '../DownloadLogic.js'), 'utf8').replace(/^\.pragma library\s*/, ''), logic);
const metadata = {versions: [
  {version: '47.3.0', requires: [{uid: 'net.minecraft', equals: '1.20.1'}]},
  {version: '49.0.0', requires: [{uid: 'net.minecraft', equals: '1.20.4'}]},
  {version: 'unspecified'}
]};
for (const loader of ['Forge', 'NeoForge']) {
  const rows = logic.loaderRows(metadata, loader, '1.20.1');
  assert.equal(rows.length, 1);
  assert.equal(rows[0].loaderVersion, '47.3.0');
  assert.equal(rows[0].id, `${loader}:47.3.0`);
}
for (const loader of ['Fabric', 'Quilt']) {
  const rows = logic.loaderRows({versions: [{version:'0.16.14'}]}, loader, '1.20.1');
  assert.equal(rows[0].loaderVersion, '0.16.14');
}
const releases = logic.projectRows([
  {id:'right', game_versions:['1.20.1'], loaders:['quilt'], files:[]},
  {id:'wrong-loader', game_versions:['1.20.1'], loaders:['forge'], files:[]},
  {id:'wrong-game', game_versions:['1.21.1'], loaders:['quilt'], files:[]}
], '1.20.1', 'Quilt', 'Mods');
assert.equal(releases[0].id, 'right');
assert.equal(releases.filter(r=>r.eligible).length, 1);
console.log('Loader selection identifiers and release compatibility checks passed');

const rawPack = {id:'pack-release', project_id:'pack', game_versions:['1.21.1'], loaders:['fabric'], files:[{filename:'pack.mrpack'}]};
const packs = logic.projectRows([rawPack], '', 'Vanilla', 'Modpacks');
assert.equal(packs.length, 1);
assert.equal(packs[0].eligible, true, 'modpacks create a new instance and do not require an existing target');
assert.equal(packs[0].raw, rawPack, 'installation retains the exact selected release metadata');
for (const category of ['Mods', 'Resource packs', 'Shaders']) {
  assert.equal(logic.projectRows([rawPack], '', 'Fabric', category)[0].eligible, false);
}
console.log('Modpack creation eligibility and exact release payload checks passed');
