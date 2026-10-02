import fs from 'node:fs';
import crypto from 'node:crypto';
import {stripTypeScriptTypes} from 'node:module';
const files={};
function read(name){const text=fs.readFileSync(`../DSPONLINE/src/game/${name}.ts`,'utf8');files[`src/game/${name}.ts`]=crypto.createHash('sha256').update(text).digest('hex');return stripTypeScriptTypes(text);}
const url=s=>`data:text/javascript;base64,${Buffer.from(s).toString('base64')}`;
const math=url(read('stationMath'));
const source=await import(url(read('stationDecorations').replace('from "./stationMath"',`from "${math}"`)));
const catalog={source_commit:'472bf62c76b695852b5577e563c1d113192ac731',source_files:files,levels:source.STATION_LEVELS,decorations:source.STATION_DECORATIONS,themes:source.STATION_THEMES};
fs.mkdirSync('data/station',{recursive:true});
fs.writeFileSync('data/station/decorations.json',JSON.stringify(catalog,null,2)+'\n');
const checks=[];
for(const reputation of ['0','99','100','799','800','5000','9'.repeat(256)])for(const decoration of source.STATION_DECORATIONS)for(const position of [{x:0,y:0,rotation:0,layer:decoration.layers[0],variant:0},{x:-750,y:400,rotation:90,layer:decoration.layers[0],variant:0},{x:-270,y:-80,rotation:0,layer:decoration.layers[0],variant:0}]){
 const station={status:'operational',economy:{stationReputation:reputation,orbitalMarks:'10000',unlockedDecorationIds:[decoration.id]},layout:{placements:[]}};
 checks.push({reputation,decoration:decoration.id,position,expected:source.getStationDecorationPlacementCheck(station,decoration.id,position)});
}
fs.writeFileSync('tests/fixtures/parity/behavior/task26-decorations.json',JSON.stringify({source_commit:catalog.source_commit,source_files:files,checks},null,2)+'\n');
console.log(`${catalog.decorations.length} decorations, ${catalog.themes.length} themes, ${checks.length} frozen placement cases`);
