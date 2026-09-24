import fs from 'node:fs';
import crypto from 'node:crypto';

const root = new URL('../', import.meta.url);
const read = path => JSON.parse(fs.readFileSync(new URL(path, root), 'utf8'));
const bytes = fs.readFileSync(new URL('tests/fixtures/parity/dsponline_source_catalog.json', root));
const checksum = fs.readFileSync(new URL('tests/fixtures/parity/dsponline_source_catalog.sha256', root), 'utf8').trim();
if (crypto.createHash('sha256').update(bytes).digest('hex') !== checksum) throw Error('Frozen source checksum mismatch');
const source = JSON.parse(bytes);
const production = read('data/production_catalog.json');
const technology = read('data/technologies.json');
for (const id of Object.keys(technology.technologies)) {
  if (technology.technologies[id].source_id) delete technology.technologies[id];
}
for (const { id, definition } of source.catalog.technologies) {
  const unlocks = [];
  for (const [key, building] of Object.entries(production.buildings)) {
    if (building.required_source_technology === id) unlocks.push({ kind: 'building', id: key });
  }
  for (const [key, recipe] of Object.entries(production.recipes)) {
    if (recipe.required_source_technology === id) unlocks.push({ kind: 'recipe', id: key });
  }
  technology.technologies['dsp_' + id] = {
    id: 'dsp_' + id, source_id: id, name: definition.name, description: definition.summary,
    tier: definition.tier >= 18 ? 'dyson' : definition.tier >= 10 ? 'interstellar' : 'planetary',
    source_tier: definition.tier, deprecated: definition.deprecated,
    cost: Object.fromEntries(definition.costs.map(cost => [cost.itemId, cost.amount])),
    duration: 3 * definition.costs.reduce((sum, cost) => sum + cost.amount, 0),
    prerequisites: definition.prerequisites.map(parent => 'dsp_' + parent),
    effects: {}, unlocks, unlock_descriptions: definition.unlocks, source_research_bridge: true,
  };
}
production.technologies = {};
for (const [path, value] of [['data/technologies.json', technology], ['data/production_catalog.json', production]]) {
  fs.writeFileSync(new URL(path, root), JSON.stringify(value, null, 2) + '\n');
}
console.log('Imported 69 active and 7 deprecated frozen technologies; retained legacy IDs.');

const progression = read('data/progression.json');
for (const field of ['chapters', 'objectives', 'achievements']) progression[field] = progression[field].filter(row => !row.source_id);
const chapterNames = {foundation:'母星点火',blue_matrix:'蓝色矩阵',red_matrix:'石油红糖',planetary_logistics:'行星物流',interstellar_logistics:'群星工业',matrix_mastery:'矩阵全谱',dyson_program:'戴森计划',galactic_endgame:'银河终局'};
for (const [id,title] of Object.entries(chapterNames)) progression.chapters.push({id:'dsp_'+id,source_id:id,title,objective_ids:source.catalog.campaign.filter(row=>row.definition.chapterId===id).map(row=>'dsp_'+row.id)});
for (const {id,definition:d} of source.catalog.campaign) {
  const reward={planet_inventory:{},construction_inventory:{}};
  for(const r of d.rewards??[]) {
    if(r.itemId) reward.planet_inventory[r.itemId]=(reward.planet_inventory[r.itemId]??0)+r.amount;
    if(r.constructionId) {
      const key=r.constructionId.startsWith('conveyor_belt_')?r.constructionId:'dsp_'+r.constructionId;
      reward.construction_inventory[key]=(reward.construction_inventory[key]??0)+r.amount;
    }
  }
  progression.objectives.push({id:'dsp_'+id,source_id:id,chapter_id:'dsp_'+d.chapterId,title:d.title,description:d.description,track:d.track,condition:{fact:'source_metric',metric:d.metric},prerequisites:(d.prerequisites??[]).map(id=>'dsp_'+id),navigation:d.navigation??{},requirements:d.requirements??[],reward});
}
const achievementMetrics={first_manual_mine:{kind:'manual-mined'},automated_mining:{kind:'miner'},first_logistics_line:{kind:'belt'},stable_power_grid:{kind:'power',requireGeneration:true},electromagnetic_matrix_online:{kind:'produced',itemId:'electromagnetic_matrix'},energy_matrix_online:{kind:'produced',itemId:'energy_matrix'},six_matrix_mastery:{kind:'matrix-spectrum'},planetary_logistics_online:{kind:'building',buildingId:'planetary_logistics_station'},interstellar_delivery:{kind:'station-trips',buildingId:'interstellar_logistics_station'},rare_resource_harvest:{kind:'rare-resource',excludeOrganic:true},dyson_swarm_online:{kind:'dyson',measure:'sails'},permanent_dyson_structure:{kind:'dyson',measure:'structure'},multi_system_industry:{kind:'industrial-systems'}};
for(const {id,definition:d} of source.catalog.achievements) progression.achievements.push({id:'dsp_'+id,source_id:id,title:d.name,description:d.description,condition:{fact:'source_metric',metric:{...achievementMetrics[id],target:d.target}}});
fs.writeFileSync(new URL('data/progression.json',root),JSON.stringify(progression,null,2)+'\n');
