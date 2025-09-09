const fs=require('fs'), path=require('path');
const roots=['app','components'];
const files=[];
function walk(p){ if(!fs.existsSync(p)) return;
  for(const f of fs.readdirSync(p)){ const fp=path.join(p,f);
    const st=fs.statSync(fp);
    if(st.isDirectory()) walk(fp);
    else if(/\.(tsx?|jsx?)$/.test(f)) files.push(fp);
  }
}
roots.forEach(walk);
for(const f of files){
  let s=fs.readFileSync(f,'utf8'); let o=s;

  // use normalized lib instead of raw JSON
  s=s.replace(/['"]\.\.?\/data\/store\.json['"]/g,'"../lib/products"');

  // show title fallback
  s=s.replace(/\bproduct\.name\b/g,'(product.title || product.name)');
  s=s.replace(/\bp\.name\b/g,'(p.title || p.name)');

  // single image field
  s=s.replace(/(product|p)\.images\??\[\s*0\s*\]/g,'$1.image');

  // stop dividing by 100
  s=s.replace(/\b(price|p\.price|product\.price)\s*\/\s*100\b/g,'Number($1)');

  if(s!==o){ fs.writeFileSync(f,s); console.log('patched', f); }
}
