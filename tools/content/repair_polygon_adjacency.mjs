// Node 24+: audit by default; --write only changes neighbors and pins old auto seed.
import fs from 'node:fs/promises';
import path from 'node:path';
import { sharedBoundaryLength, SHARED_BOUNDARY_EPSILON } from '../../level-editor/apps/web/src/sharedBoundary.ts';
const root=path.resolve(process.argv.find(a=>a.startsWith('--root='))?.slice(7)||'levels');
const write=process.argv.includes('--write');
async function files(dir) { let out=[];for(const item of await fs.readdir(dir,{withFileTypes:true})){const f=path.join(dir,item.name);if(item.isDirectory())out.push(...await files(f));else if(item.name==='level.json')out.push(f);}return out.sort(); }
function oldSeed(config,pieces) {
 const seed=config.modes.polygon.assist?.seed;
 if(seed?.mode==='manual' && seed.piece_ids?.length)return seed.piece_ids;
 if((seed?.count??1)!==1)throw Error(`Explicit seed migration required: ${config.id}`);
 const center=[config.image.width/2,config.image.height/2], radius=Math.hypot(...center);
 const boundsArea=p=>{const x=p.points.map(v=>v[0]),y=p.points.map(v=>v[1]);return(Math.max(...x)-Math.min(...x))*(Math.max(...y)-Math.min(...y));};
 const score=p=>Math.hypot(p.home[0]-center[0],p.home[1]-center[1])/radius+(4-Math.min(4,p.neighbors.length))*.25;
 return [[...pieces].sort((a,b)=>boundsArea(b)-boundsArea(a)).sort((a,b)=>score(b)-score(a))[0].id];
}
let report=[];
for(const file of await files(root)) {
 const config=JSON.parse(await fs.readFile(file,'utf8'));const mode=config.modes?.polygon;
 if(!mode?.pieces?.length)continue;
 const seeds=oldSeed(config,mode.pieces);let removed=[],added=[];
 const neighbors=new Map(mode.pieces.map(p=>[p.id,[]]));
 for(let i=0;i<mode.pieces.length;i++)for(let j=i+1;j<mode.pieces.length;j++){
  const a=mode.pieces[i],b=mode.pieces[j];
  if(sharedBoundaryLength(a.points,b.points)>SHARED_BOUNDARY_EPSILON){neighbors.get(a.id).push(b.id);neighbors.get(b.id).push(a.id);}
 }
 for(const p of mode.pieces){const actual=neighbors.get(p.id);for(const n of p.neighbors)if(!actual.includes(n))removed.push([p.id,n]);for(const n of actual)if(!p.neighbors.includes(n))added.push([p.id,n]);p.neighbors=actual;}
 const seen=new Set([mode.pieces[0].id]),todo=[mode.pieces[0].id];while(todo.length){for(const id of neighbors.get(todo.pop()))if(!seen.has(id)){seen.add(id);todo.push(id);}}
 if(seen.size!==mode.pieces.length)throw Error(`Disconnected true boundary graph: ${config.id}`);
 mode.assist??={};mode.assist.seed={mode:'manual',count:seeds.length,piece_ids:seeds};
 report.push({level:config.id,pieces:mode.pieces.length,removed_directed:removed,added_directed:added,preserved_seed:seeds,connected:true});
 if(write)await fs.writeFile(file,JSON.stringify(config,null,'\t')+'\n');
}
console.log(JSON.stringify({write,levels:report.length,report},null,2));
