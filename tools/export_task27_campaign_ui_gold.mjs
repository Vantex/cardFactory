import vm from 'node:vm';
import {stripTypeScriptTypes} from 'node:module';
import {createFrozenSourceRuntime,writeFrozenFixture} from './frozen_source_runtime.mjs';

const runtime=createFrozenSourceRuntime();
try{
  const engine=await runtime.load('engine');
  const campaign=await runtime.load('campaign');
  const content=await runtime.load('content');
  const app=runtime.readSource('src/App.tsx');
  const workspace=runtime.readSource('src/components/CampaignWorkspace.tsx');
  if(!workspace.includes('disabled={task.status === "locked" || task.status === "complete"}'))throw new Error('Actual source task button contract changed');
  const names=['closeAllWorkspaces','openCampaign','navigateFromCampaign','onSelectCampaignTask'];
  const callbacks=Object.fromEntries(names.map(name=>{
    const start=app.indexOf('  const '+name+' = useCallback(');
    const boundary=app.indexOf('\n  }, [',start);
    const end=app.indexOf(']);',boundary)+3;
    if(start<0||boundary<start||end<=boundary)throw new Error('Actual callback extraction failed '+name);
    return [name,app.slice(start,end)];
  }));
  const selectors=[...new Set(Object.values(callbacks).join('\n').match(/\bset[A-Z]\w+(?=\()/g))];
  const execute=(input,action,args=[])=>{
    const effects={};
    const calls=[];
    const gameRef={current:structuredClone(input)};
    const host={
      gameRef,useCallback:fn=>fn,
      ITEMS:content.ITEMS,getTechnology:content.getTechnology,getPlanet:content.getPlanet,getBuilding:content.getBuilding,
      getPlanetDisplayName:(_state,id)=>id,getStarSystemDisplayName:(_state,id)=>id,
      mobileNavigation:{openWorkspace:id=>calls.push(['mobileWorkspace',id])},
      openCommandWorkspace:id=>calls.push(['commandWorkspace',id]),
      focusEntityIds:ids=>calls.push(['focusEntities',ids]),
      window:{setTimeout:fn=>fn()},
      commitGame:fn=>{gameRef.current=fn(gameRef.current);return true;},
      selectCampaignTask:campaign.selectCampaignTask,
      onPlanetChange:id=>{calls.push(['planetChange',id]);const previous=gameRef.current;gameRef.current=engine.setActivePlanet(previous,id);return gameRef.current!==previous||previous.activePlanetId===id;},
    };
    for(const setter of selectors)host[setter]=value=>{effects[setter]=structuredClone(value);};
    const code=Object.values(callbacks).join('\n')+'\n({'+names.join(',')+'});';
    const compiled=vm.runInNewContext(stripTypeScriptTypes(code,{mode:'transform'}),host,{timeout:1000});
    compiled[action](...structuredClone(args));
    return {effects,calls,campaign:gameRef.current.campaign,activePlanetId:gameRef.current.activePlanetId};
  };
  const initial=engine.createInitialState(240721,false);
  const cases=[];
  const record=(id,input,action,args=[])=>cases.push({id,input,action,args,expected:execute(input,action,args)});
  record('open',initial,'openCampaign');
  for(const task of campaign.CAMPAIGN_TASKS){
    if(task.navigation)record('task:'+task.id,initial,'navigateFromCampaign',[task.navigation,task.id]);
  }
  record('technology',initial,'navigateFromCampaign',[{kind:'technology',techId:'electromagnetism'}]);
  const unlocked=structuredClone(initial);
  engine.completeTechnology(unlocked,'interstellar_logistics');
  record('planet_unlocked',unlocked,'navigateFromCampaign',[{kind:'planet',planetId:'ashen'}]);
  const local=engine.placeBuilding(initial,'arc_smelter',{x:10000,y:10000});
  if(!local.entities.some(row=>row.buildingId==='arc_smelter'))throw new Error('Actual source local route placement missing');
  record('building_local',local,'navigateFromCampaign',[{kind:'building',buildingId:'arc_smelter'}]);
  let remote=engine.setActivePlanet(unlocked,'ashen');
  remote=engine.placeBuilding(remote,'arc_smelter',{x:10000,y:10000});
  if(!remote.entities.some(row=>row.planetId==='ashen'&&row.buildingId==='arc_smelter'))throw new Error('Actual source remote route placement missing');
  remote=engine.setActivePlanet(remote,'home');
  record('building_remote',remote,'navigateFromCampaign',[{kind:'building',buildingId:'arc_smelter'}]);
  for(const id of ['mine_first_ore','side_storage','produce_universe_matrix','unknown_campaign_task']){
    record('select:'+id,initial,'onSelectCampaignTask',[id]);
  }
  writeFrozenFixture(runtime,'task27-campaign-ui.json',{
    scope:'Actual frozen App.tsx desktop open/select/navigation callback bodies executed without React in a bounded host. React setters, workspace opening, camera focus and planet-change calls are recorded; planet changes and campaign selection execute actual frozen engine functions. This proves callback effect contracts, not rendered React layout, physical input, complete growth or human desktop acceptance.',
    callbacks,cases,
  });
  console.log('TASK27 CAMPAIGN UI GOLD: '+cases.length+' actual source callback cases');
}finally{runtime.close();}
