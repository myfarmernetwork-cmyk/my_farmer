const fs = require('fs');
const path = require('path');

const dir = path.join(__dirname, '..', 'assets', 'translations');
const translations = {
  en: {
    inbox_notifications_title: 'Notifications',
    inbox_notifications_empty: 'No notifications yet.',
    inbox_mark_all_read: 'Mark all read',
  },
  hr: {
    inbox_notifications_title: 'Obavijesti',
    inbox_notifications_empty: 'Još nema obavijesti.',
    inbox_mark_all_read: 'Označi sve pročitano',
  },
  'hr-HR': {
    inbox_notifications_title: 'Obavijesti',
    inbox_notifications_empty: 'Još nema obavijesti.',
    inbox_mark_all_read: 'Označi sve pročitano',
  },
  'hr-BA': {
    inbox_notifications_title: 'Obavijesti',
    inbox_notifications_empty: 'Još nema obavijesti.',
    inbox_mark_all_read: 'Označi sve pročitano',
  },
  bs: {
    inbox_notifications_title: 'Obavijesti',
    inbox_notifications_empty: 'Još nema obavijesti.',
    inbox_mark_all_read: 'Označi sve pročitano',
  },
  sr: {
    inbox_notifications_title: 'Obaveštenja',
    inbox_notifications_empty: 'Još nema obaveštenja.',
    inbox_mark_all_read: 'Označi sve pročitano',
  },
  'sr-BA': {
    inbox_notifications_title: 'Obavijesti',
    inbox_notifications_empty: 'Još nema obavijesti.',
    inbox_mark_all_read: 'Označi sve pročitano',
  },
  'sr-RS': {
    inbox_notifications_title: 'Obaveštenja',
    inbox_notifications_empty: 'Još nema obaveštenja.',
    inbox_mark_all_read: 'Označi sve pročitano',
  },
  de: {
    inbox_notifications_title: 'Benachrichtigungen',
    inbox_notifications_empty: 'Noch keine Benachrichtigungen.',
    inbox_mark_all_read: 'Alle als gelesen markieren',
  },
  fr: {
    inbox_notifications_title: 'Notifications',
    inbox_notifications_empty: 'Aucune notification pour le moment.',
    inbox_mark_all_read: 'Tout marquer comme lu',
  },
  es: {
    inbox_notifications_title: 'Notificaciones',
    inbox_notifications_empty: 'Aún no hay notificaciones.',
    inbox_mark_all_read: 'Marcar todo como leído',
  },
  it: {
    inbox_notifications_title: 'Notifiche',
    inbox_notifications_empty: 'Nessuna notifica al momento.',
    inbox_mark_all_read: 'Segna tutto come letto',
  },
  pl: {
    inbox_notifications_title: 'Powiadomienia',
    inbox_notifications_empty: 'Brak powiadomień.',
    inbox_mark_all_read: 'Oznacz wszystkie jako przeczytane',
  },
  cs: {
    inbox_notifications_title: 'Oznámení',
    inbox_notifications_empty: 'Zatím žádná oznámení.',
    inbox_mark_all_read: 'Označit vše jako přečtené',
  },
  sv: {
    inbox_notifications_title: 'Aviseringar',
    inbox_notifications_empty: 'Inga aviseringar ännu.',
    inbox_mark_all_read: 'Markera alla som lästa',
  },
  ru: {
    inbox_notifications_title: 'Уведомления',
    inbox_notifications_empty: 'Уведомлений пока нет.',
    inbox_mark_all_read: 'Отметить все как прочитанные',
  },
  uk: {
    inbox_notifications_title: 'Сповіщення',
    inbox_notifications_empty: 'Сповіщень поки немає.',
    inbox_mark_all_read: 'Позначити все прочитаним',
  },
  ar: {
    inbox_notifications_title: 'الإشعارات',
    inbox_notifications_empty: 'لا توجد إشعارات بعد.',
    inbox_mark_all_read: 'تعليم الكل كمقروء',
  },
  tr: {
    inbox_notifications_title: 'Bildirimler',
    inbox_notifications_empty: 'Henüz bildirim yok.',
    inbox_mark_all_read: 'Tümünü okundu işaretle',
  },
  zh: {
    inbox_notifications_title: '通知',
    inbox_notifications_empty: '暂无通知。',
    inbox_mark_all_read: '全部标记为已读',
  },
  hi: {
    inbox_notifications_title: 'सूचनाएँ',
    inbox_notifications_empty: 'अभी कोई सूचना नहीं है।',
    inbox_mark_all_read: 'सभी को पढ़ा हुआ चिह्नित करें',
  },
  id: {
    inbox_notifications_title: 'Notifikasi',
    inbox_notifications_empty: 'Belum ada notifikasi.',
    inbox_mark_all_read: 'Tandai semua sudah dibaca',
  },
  sw: {
    inbox_notifications_title: 'Arifa',
    inbox_notifications_empty: 'Bado hakuna arifa.',
    inbox_mark_all_read: 'Weka zote kama zimesomwa',
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
    console.log(`Updated ${file}`);
  }
}
