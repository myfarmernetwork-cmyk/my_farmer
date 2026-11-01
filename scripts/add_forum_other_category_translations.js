const fs = require('fs');
const path = require('path');

const dir = path.join(__dirname, '..', 'assets', 'translations');

const translations = {
  en: { forum_cat_other: 'Other' },
  hr: { forum_cat_other: 'Ostalo' },
  'hr-HR': { forum_cat_other: 'Ostalo' },
  'hr-BA': { forum_cat_other: 'Ostalo' },
  bs: { forum_cat_other: 'Ostalo' },
  sr: { forum_cat_other: 'Ostalo' },
  'sr-BA': { forum_cat_other: 'Ostalo' },
  'sr-RS': { forum_cat_other: 'Ostalo' },
  de: { forum_cat_other: 'Sonstiges' },
  fr: { forum_cat_other: 'Autre' },
  es: { forum_cat_other: 'Otros' },
  it: { forum_cat_other: 'Altro' },
  pl: { forum_cat_other: 'Inne' },
  cs: { forum_cat_other: 'Ostatní' },
  sv: { forum_cat_other: 'Övrigt' },
  ru: { forum_cat_other: 'Другое' },
  uk: { forum_cat_other: 'Інше' },
  tr: { forum_cat_other: 'Diğer' },
  ar: { forum_cat_other: 'أخرى' },
  hi: { forum_cat_other: 'अन्य' },
  id: { forum_cat_other: 'Lainnya' },
  sw: { forum_cat_other: 'Nyingine' },
  zh: { forum_cat_other: '其他' },
};

for (const [locale, entries] of Object.entries(translations)) {
  const filePath = path.join(dir, `${locale}.json`);
  if (!fs.existsSync(filePath)) {
    console.warn(`Skip missing file: ${filePath}`);
    continue;
  }
  const json = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  Object.assign(json, entries);
  const sorted = Object.fromEntries(
    Object.keys(json)
      .sort()
      .map((key) => [key, json[key]]),
  );
  fs.writeFileSync(filePath, `${JSON.stringify(sorted, null, 2)}\n`, 'utf8');
  console.log(`Updated ${locale}.json`);
}
