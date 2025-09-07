export function filterRestricted(products:any[], restrictedTags:string[]){
  const restrictedNames = new Set(["Nicotine Pouches","Hard Kombucha","CBD Balm","CBD Drinks","Hemp Gummies"]);
  return products.map(p => {
    const isRestricted = restrictedNames.has(p.name) || (p.tags||[]).some((t:string)=>restrictedTags.includes(t));
    return { ...p, enabled: isRestricted ? false : p.enabled !== false };
  });
}
