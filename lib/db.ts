import fs from "fs";
import path from "path";
const dataPath = path.join(process.cwd(), "data", "store.json");
function load(){ try{ return JSON.parse(fs.readFileSync(dataPath,"utf8")); } catch{ return {config:{},products:[],orders:[],events:[]}; } }
function save(obj:any){ if (process.env.READONLY_FS==="1") return; fs.writeFileSync(dataPath, JSON.stringify(obj,null,2)); }
export function getStore(){ return load(); }
export function putStore(s:any){ save(s); }
export function appendEvent(type:string, payload:any={}){ const s=load(); s.events.push({ts:Date.now(), type, payload}); save(s); }
