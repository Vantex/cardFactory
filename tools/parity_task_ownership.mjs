// Ownership is a planning default; later verified manual assignments remain authoritative.
export function taskFor(category, id) {
 if (category === 'buildings' && ['accumulator','energy_exchanger','wind_turbine','solar_panel','thermal_power_plant','geothermal_power_station','mini_fusion_power_plant','artificial_star'].includes(id)) return 21;
 if (['items','recipes','buildings','construction','proliferators','matrices'].includes(category)) return 22;
 if (['technologies','campaign','achievements'].includes(category)) return 25;
 if (['difficulties','modes'].includes(category)) return 26;
 if (category === 'belts') return 23;
 if (/ContentPack|Register|Simulation|ExportTemplate|Mod(?!e)/.test(id)) return 26;
 if (/LogisticsManagementPanel|Dyson|Galactic|Quantum|OrbitalCollector|BlackHole|ResourceReserve|TimeWarp|Station|Idle|Warp|Speedrun|Endgame|Galaxy|Planet|StarMap/.test(id)) return 26;
 if (/Save|ImportRescue|Recovery|OfflineReport/.test(id) || /^OperationsWorkspace\..*Snapshot/.test(id)) return 20;
 if (/Power|Grid|Energy|Accumulator|GenerationPriority|Fuel/.test(id)) return 21;
 if (/Blueprint|ConstructionQueue|Bookmark|Region/.test(id)) return 24;
 if (/Craft|craft|Spray|Proliferat|ConstructionCenter|RecipeWorkspace|RecipeFocus|SplitterMode/.test(id)) return 22;
 if (/Technology|Research|Campaign|Achievement|Tutorial/.test(id)) return 25;
 return 23;
}
