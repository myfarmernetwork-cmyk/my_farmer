const fs = require('fs');
const path = require('path');

const dir = path.join(__dirname, '..', 'assets', 'translations');
const translations = {
  en: {
    chat_time_today: 'Today',
    chat_time_yesterday: 'Yesterday',
    notification_product_unavailable: 'This product is no longer available.',
  },
  hr: {
    chat_time_today: 'Danas',
    chat_time_yesterday: 'Jučer',
    notification_product_unavailable: 'Ovaj proizvod više nije dostupan.',
  },
  'hr-HR': {
    chat_time_today: 'Danas',
    chat_time_yesterday: 'Jučer',
    notification_product_unavailable: 'Ovaj proizvod više nije dostupan.',
  },
  'hr-BA': {
    chat_time_today: 'Danas',
    chat_time_yesterday: 'Jučer',
    notification_product_unavailable: 'Ovaj proizvod više nije dostupan.',
  },
  bs: {
    chat_time_today: 'Danas',
    chat_time_yesterday: 'Jučer',
    notification_product_unavailable: 'Ovaj proizvod više nije dostupan.',
  },
  sr: {
    chat_time_today: 'Danas',
    chat_time_yesterday: 'Juče',
    notification_product_unavailable: 'Ovaj proizvod više nije dostupan.',
  },
  'sr-BA': {
    chat_time_today: 'Danas',
    chat_time_yesterday: 'Juče',
    notification_product_unavailable: 'Ovaj proizvod više nije dostupan.',
  },
  'sr-RS': {
    chat_time_today: 'Danas',
    chat_time_yesterday: 'Juče',
    notification_product_unavailable: 'Ovaj proizvod više nije dostupan.',
  },
  de: {
    chat_time_today: 'Heute',
    chat_time_yesterday: 'Gestern',
    notification_product_unavailable: 'Dieses Produkt ist nicht mehr verfügbar.',
  },
  fr: {
    chat_time_today: "Aujourd'hui",
    chat_time_yesterday: 'Hier',
    notification_product_unavailable: "Ce produit n'est plus disponible.",
  },
  es: {
    chat_time_today: 'Hoy',
    chat_time_yesterday: 'Ayer',
    notification_product_unavailable: 'Este producto ya no está disponible.',
  },
  it: {
    chat_time_today: 'Oggi',
    chat_time_yesterday: 'Ieri',
    notification_product_unavailable: 'Questo prodotto non è più disponibile.',
  },
  pl: {
    chat_time_today: 'Dziś',
    chat_time_yesterday: 'Wczoraj',
    notification_product_unavailable: 'Ten produkt nie jest już dostępny.',
  },
  cs: {
    chat_time_today: 'Dnes',
    chat_time_yesterday: 'Včera',
    notification_product_unavailable: 'Tento produkt již není k dispozici.',
  },
  sv: {
    chat_time_today: 'Idag',
    chat_time_yesterday: 'Igår',
    notification_product_unavailable: 'Den här produkten är inte längre tillgänglig.',
  },
  ru: {
    chat_time_today: 'Сегодня',
    chat_time_yesterday: 'Вчера',
    notification_product_unavailable: 'Этот товар больше недоступен.',
  },
  uk: {
    chat_time_today: 'Сьогодні',
    chat_time_yesterday: 'Вчора',
    notification_product_unavailable: 'Цей товар більше недоступний.',
  },
  ar: {
    chat_time_today: 'اليوم',
    chat_time_yesterday: 'أمس',
    notification_product_unavailable: 'هذا المنتج لم يعد متاحًا.',
  },
  tr: {
    chat_time_today: 'Bugün',
    chat_time_yesterday: 'Dün',
    notification_product_unavailable: 'Bu ürün artık mevcut değil.',
  },
  zh: {
    chat_time_today: '今天',
    chat_time_yesterday: '昨天',
    notification_product_unavailable: '该商品已不可用。',
  },
  hi: {
    chat_time_today: 'आज',
    chat_time_yesterday: 'कल',
    notification_product_unavailable: 'यह उत्पाद अब उपलब्ध नहीं है।',
  },
  id: {
    chat_time_today: 'Hari ini',
    chat_time_yesterday: 'Kemarin',
    notification_product_unavailable: 'Produk ini tidak lagi tersedia.',
  },
  sw: {
    chat_time_today: 'Leo',
    chat_time_yesterday: 'Jana',
    notification_product_unavailable: 'Bidhaa hii haipatikani tena.',
  },
};

for (const file of fs.readdirSync(dir).filter((f) => f.endsWith('.json'))) {
  const lang = file.replace('.json', '');
  const t = translations[lang] || translations.en;
  const fp = path.join(dir, file);
  const data = JSON.parse(fs.readFileSync(fp, 'utf8'));
  let changed = false;
  for (const [key, value] of Object.entries(t)) {
    if (data[key] !== value) {
      data[key] = value;
      changed = true;
    }
  }
  if (changed) {
    fs.writeFileSync(fp, `${JSON.stringify(data, null, 2)}\n`, 'utf8');
    console.log(`updated ${file}`);
  }
}
