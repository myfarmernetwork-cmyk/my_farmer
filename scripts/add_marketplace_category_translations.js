const fs = require('fs');
const path = require('path');

const dir = path.join(__dirname, '..', 'assets', 'translations');

const translations = {
  en: {
    cat_fertilizers_stimulants: 'Fertilizers and stimulants',
    cat_plant_protection: 'Plant protection',
    company_cat_fertilizers_stimulants: 'Fertilizers and stimulants',
    company_cat_plant_protection: 'Plant protection',
    company_cat_farm_machinery: 'Farm machinery and spare parts',
  },
  hr: {
    cat_fertilizers_stimulants: 'Đubriva i stimulansi',
    cat_plant_protection: 'Zaštita bilja',
    company_cat_fertilizers_stimulants: 'Đubriva i stimulansi',
    company_cat_plant_protection: 'Zaštita bilja',
    company_cat_farm_machinery: 'Poljoprivredna mehanizacija i rezervni dijelovi',
  },
  'hr-HR': {
    cat_fertilizers_stimulants: 'Đubriva i stimulansi',
    cat_plant_protection: 'Zaštita bilja',
    company_cat_fertilizers_stimulants: 'Đubriva i stimulansi',
    company_cat_plant_protection: 'Zaštita bilja',
    company_cat_farm_machinery: 'Poljoprivredna mehanizacija i rezervni dijelovi',
  },
  'hr-BA': {
    cat_fertilizers_stimulants: 'Đubriva i stimulansi',
    cat_plant_protection: 'Zaštita bilja',
    company_cat_fertilizers_stimulants: 'Đubriva i stimulansi',
    company_cat_plant_protection: 'Zaštita bilja',
    company_cat_farm_machinery: 'Poljoprivredna mehanizacija i rezervni dijelovi',
  },
  bs: {
    cat_fertilizers_stimulants: 'Đubriva i stimulansi',
    cat_plant_protection: 'Zaštita bilja',
    company_cat_fertilizers_stimulants: 'Đubriva i stimulansi',
    company_cat_plant_protection: 'Zaštita bilja',
    company_cat_farm_machinery: 'Poljoprivredna mehanizacija i rezervni dijelovi',
  },
  sr: {
    cat_fertilizers_stimulants: 'Đubriva i stimulansi',
    cat_plant_protection: 'Zaštita bilja',
    company_cat_fertilizers_stimulants: 'Đubriva i stimulansi',
    company_cat_plant_protection: 'Zaštita bilja',
    company_cat_farm_machinery: 'Poljoprivredna mehanizacija i rezervni dijelovi',
  },
  'sr-BA': {
    cat_fertilizers_stimulants: 'Đubriva i stimulansi',
    cat_plant_protection: 'Zaštita bilja',
    company_cat_fertilizers_stimulants: 'Đubriva i stimulansi',
    company_cat_plant_protection: 'Zaštita bilja',
    company_cat_farm_machinery: 'Poljoprivredna mehanizacija i rezervni dijelovi',
  },
  'sr-RS': {
    cat_fertilizers_stimulants: 'Đubriva i stimulansi',
    cat_plant_protection: 'Zaštita bilja',
    company_cat_fertilizers_stimulants: 'Đubriva i stimulansi',
    company_cat_plant_protection: 'Zaštita bilja',
    company_cat_farm_machinery: 'Poljoprivredna mehanizacija i rezervni dijelovi',
  },
  de: {
    cat_fertilizers_stimulants: 'Düngemittel und Stimulanzien',
    cat_plant_protection: 'Pflanzenschutz',
    company_cat_fertilizers_stimulants: 'Düngemittel und Stimulanzien',
    company_cat_plant_protection: 'Pflanzenschutz',
    company_cat_farm_machinery: 'Landmaschinen und Ersatzteile',
  },
  fr: {
    cat_fertilizers_stimulants: 'Engrais et stimulateurs',
    cat_plant_protection: 'Protection des cultures',
    company_cat_fertilizers_stimulants: 'Engrais et stimulateurs',
    company_cat_plant_protection: 'Protection des cultures',
    company_cat_farm_machinery: 'Machines agricoles et pièces détachées',
  },
  es: {
    cat_fertilizers_stimulants: 'Fertilizantes y estimulantes',
    cat_plant_protection: 'Protección de cultivos',
    company_cat_fertilizers_stimulants: 'Fertilizantes y estimulantes',
    company_cat_plant_protection: 'Protección de cultivos',
    company_cat_farm_machinery: 'Maquinaria agrícola y repuestos',
  },
  it: {
    cat_fertilizers_stimulants: 'Fertilizzanti e stimolanti',
    cat_plant_protection: 'Protezione delle colture',
    company_cat_fertilizers_stimulants: 'Fertilizzanti e stimolanti',
    company_cat_plant_protection: 'Protezione delle colture',
    company_cat_farm_machinery: 'Macchine agricole e ricambi',
  },
  pl: {
    cat_fertilizers_stimulants: 'Nawozy i stymulatory',
    cat_plant_protection: 'Ochrona roślin',
    company_cat_fertilizers_stimulants: 'Nawozy i stymulatory',
    company_cat_plant_protection: 'Ochrona roślin',
    company_cat_farm_machinery: 'Maszyny rolnicze i części zamienne',
  },
  cs: {
    cat_fertilizers_stimulants: 'Hnojiva a stimulátory',
    cat_plant_protection: 'Ochrana rostlin',
    company_cat_fertilizers_stimulants: 'Hnojiva a stimulátory',
    company_cat_plant_protection: 'Ochrana rostlin',
    company_cat_farm_machinery: 'Zemědělské stroje a náhradní díly',
  },
  sv: {
    cat_fertilizers_stimulants: 'Gödsel och stimulanser',
    cat_plant_protection: 'Växtskydd',
    company_cat_fertilizers_stimulants: 'Gödsel och stimulanser',
    company_cat_plant_protection: 'Växtskydd',
    company_cat_farm_machinery: 'Jordbruksmaskiner och reservdelar',
  },
  ru: {
    cat_fertilizers_stimulants: 'Удобрения и стимуляторы',
    cat_plant_protection: 'Защита растений',
    company_cat_fertilizers_stimulants: 'Удобрения и стимуляторы',
    company_cat_plant_protection: 'Защита растений',
    company_cat_farm_machinery: 'Сельхозтехника и запчасти',
  },
  uk: {
    cat_fertilizers_stimulants: 'Добрива та стимулятори',
    cat_plant_protection: 'Захист рослин',
    company_cat_fertilizers_stimulants: 'Добрива та стимулятори',
    company_cat_plant_protection: 'Захист рослин',
    company_cat_farm_machinery: 'Сільськогосподарська техніка та запчастини',
  },
  tr: {
    cat_fertilizers_stimulants: 'Gübreler ve uyarıcılar',
    cat_plant_protection: 'Bitki koruma',
    company_cat_fertilizers_stimulants: 'Gübreler ve uyarıcılar',
    company_cat_plant_protection: 'Bitki koruma',
    company_cat_farm_machinery: 'Tarım makineleri ve yedek parçalar',
  },
  ar: {
    cat_fertilizers_stimulants: 'الأسمدة والمنشطات',
    cat_plant_protection: 'حماية النبات',
    company_cat_fertilizers_stimulants: 'الأسمدة والمنشطات',
    company_cat_plant_protection: 'حماية النبات',
    company_cat_farm_machinery: 'آلات زراعية وقطع غيار',
  },
  hi: {
    cat_fertilizers_stimulants: 'उर्वरक और उत्तेजक',
    cat_plant_protection: 'पौधों की सुरक्षा',
    company_cat_fertilizers_stimulants: 'उर्वरक और उत्तेजक',
    company_cat_plant_protection: 'पौधों की सुरक्षा',
    company_cat_farm_machinery: 'कृषि मशीनरी और अतिरिक्त पुर्जे',
  },
  id: {
    cat_fertilizers_stimulants: 'Pupuk dan stimulan',
    cat_plant_protection: 'Perlindungan tanaman',
    company_cat_fertilizers_stimulants: 'Pupuk dan stimulan',
    company_cat_plant_protection: 'Perlindungan tanaman',
    company_cat_farm_machinery: 'Mesin pertanian dan suku cadang',
  },
  sw: {
    cat_fertilizers_stimulants: 'Mbolea na vichocheo',
    cat_plant_protection: 'Ulinzi wa mimea',
    company_cat_fertilizers_stimulants: 'Mbolea na vichocheo',
    company_cat_plant_protection: 'Ulinzi wa mimea',
    company_cat_farm_machinery: 'Mashine za kilimo na vipuri',
  },
  zh: {
    cat_fertilizers_stimulants: '肥料和刺激剂',
    cat_plant_protection: '植物保护',
    company_cat_fertilizers_stimulants: '肥料和刺激剂',
    company_cat_plant_protection: '植物保护',
    company_cat_farm_machinery: '农业机械和备件',
  },
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
