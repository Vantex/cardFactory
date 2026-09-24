import fs from 'node:fs';
import crypto from 'node:crypto';
const curves={matrix_compression:[250,1.55,1051,1000,'矩阵压缩'],vein_utilization:[300,1.58,1048,1000,'矿脉极限利用'],galactic_logistics:[350,1.6,1052,1000,'银河物流协议'],stellar_harnessing:[400,1.62,1050,1000,'恒星能量驯化'],continuum_simulation:[500,1.65,1045,23,'连续体演算']};
const definitions={};
for(const [id,[base,growth,numerator,maximum,name]] of Object.entries(curves)){
 const costs=[];
 for(let level=1;level<=maximum;level++)costs.push((level<=10?BigInt(Math.round(base*growth**(level-1)/10)*10):((BigInt(costs.at(-1))*BigInt(numerator)+5000n)/10000n)*10n).toString());
 definitions[id]={id,name,maximum,costs};
}
const files={};
for(const name of ['infiniteResearch.ts','endgame.ts','engine.ts'])files['src/game/'+name]=crypto.createHash('sha256').update(fs.readFileSync('../DSPONLINE/src/game/'+name)).digest('hex');
fs.writeFileSync('data/infinite_research.json',JSON.stringify({line_id:'infinite_research',name:'无限研究',source_commit:'472bf62c76b695852b5577e563c1d113192ac731',source_files:files,definitions},null,2)+'\n');
