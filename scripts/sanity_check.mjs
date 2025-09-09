import fs from "fs"; import path from "path";
const p=path.join("data","store.json");
const data=JSON.parse(fs.readFileSync(p,"utf8"));
let bad=0;
for(const x of data){
  if(!(x.image||"").startsWith("/images/")){ x.image="/images/placeholder.png"; x.images=[x.image]; bad++; }
  if(!(x.price>0)){ x.enabled=false; bad++; }
}
fs.writeFileSync(p, JSON.stringify(data,null,2));
console.log("sanity fixed:", bad);
