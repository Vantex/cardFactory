import fs from 'node:fs';
import crypto from 'node:crypto';
import {stripTypeScriptTypes} from 'node:module';
const sourcePath='../DSPONLINE/src/game/infiniteResearch.ts';
const bytes=fs.readFileSync(sourcePath);
const module=await import('data:text/javascript;base64,'+Buffer.from(stripTypeScriptTypes(bytes.toString())).toString('base64'));
const levels=[0,1,9,10,11,22,262,999];
const cases=[];
for(const id of Object.keys(module.INFINITE_RESEARCH_CURVES))for(const level of levels){const max=module.getInfiniteResearchMaximumLevel(id);if(level>=max)continue;cases.push({id,level,cost:module.getInfiniteResearchCostString(id,level)});}
fs.mkdirSync('tests/fixtures/parity/behavior',{recursive:true});
fs.writeFileSync('tests/fixtures/parity/behavior/task25-infinite-costs.json',JSON.stringify({source_commit:'472bf62c76b695852b5577e563c1d113192ac731',source_file:'src/game/infiniteResearch.ts',sha256:crypto.createHash('sha256').update(bytes).digest('hex'),cases},null,2)+'\n');
console.log(cases.length);
