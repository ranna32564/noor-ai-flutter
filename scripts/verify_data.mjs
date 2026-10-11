import fs from 'node:fs';
const read = (name) => JSON.parse(fs.readFileSync(new URL(`../assets/data/${name}`, import.meta.url), 'utf8'));
const quran = read('quran.json');
const duas = read('duas.json');
const adhkar = read('adhkar.json');
const guide = read('guide.json');
const errors = [];
if (quran.length !== 114) errors.push(`Expected 114 surahs; found ${quran.length}`);
const ayahs = quran.reduce((n, s) => n + (Array.isArray(s.v) ? s.v.length : 0), 0);
if (ayahs !== 6236) errors.push(`Expected 6236 ayah records; found ${ayahs}`);
for (let i = 0; i < quran.length; i++) {
  const s = quran[i];
  if (s.n !== i + 1 || !s.t || !Array.isArray(s.v)) errors.push(`Malformed surah at index ${i}`);
  for (let j = 0; j < (s.v || []).length; j++) if (!Array.isArray(s.v[j]) || s.v[j].length < 3) errors.push(`Malformed ayah ${s.n}:${j+1}`);
}
if (!Array.isArray(duas) || !duas.length) errors.push('Dua data is empty');
if (!Array.isArray(adhkar) || !adhkar.length) errors.push('Adhkar data is empty');
if (!guide.HALAL || !Array.isArray(guide.AMOLS)) errors.push('Guide data schema is invalid');
console.log(JSON.stringify({surahs:quran.length,ayahRecords:ayahs,duaRecords:duas.length,adhkarCategories:adhkar.length,guideCategories:Object.keys(guide.HALAL || {})},null,2));
if (errors.length) { console.error(errors.join('\n')); process.exit(1); }
console.log('Structural checks passed. Text accuracy, translations, attribution and licenses still require independent review.');
