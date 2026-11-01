const fs = require('fs');
const path = require('path');

const dir = path.join(__dirname, '..', 'assets', 'translations');

const en = {
  vet_appointment_waiting_title: 'Waiting for veterinarian',
  vet_appointment_waiting_body: 'Record sent to {vet}. A response will arrive soon.',
  vet_appointment_proposed_title: 'Proposed appointment',
  vet_appointment_proposed_label: '{vet} proposes: {datetime}',
  vet_appointment_confirm: 'Confirm appointment',
  vet_appointment_counter: 'Suggest another time',
  vet_appointment_decline: 'Cannot attend',
  vet_appointment_confirmed_title: 'Appointment confirmed',
  vet_appointment_confirmed_label: 'With {vet}: {datetime}',
  vet_appointment_counter_title: 'Suggested time: {datetime}',
  vet_appointment_counter_sheet_title: 'Suggest another appointment',
  vet_appointment_counter_note: 'Note (optional)',
  vet_appointment_counter_send: 'Send suggestion',
  vet_appointment_decline_reason_hint: 'Reason (optional)',
  vet_appointment_owner_preferred_title: 'Owner preferred time',
  vet_appointment_owner_preferred_label: 'Requested: {datetime}',
  vet_appointment_request_preferred: 'Request a preferred appointment time',
  vet_appointment_preferred_note: 'Note about preferred time',
  vet_appointment_vet_propose_checkbox: 'Propose an appointment time',
  vet_appointment_vet_accept_counter: 'Accept owner time',
  vet_appointment_vet_propose_new: 'Propose new time',
  vet_appointment_confirmed_snack: 'Appointment confirmed.',
  vet_appointment_counter_sent_snack: 'Your time suggestion was sent.',
  vet_appointment_declined_snack: 'Appointment declined.',
  vet_appointment_vet_accepted_snack: 'Owner appointment accepted.',
  vet_appointment_select_datetime: 'Select date and time',
  vet_appointment_status_declined: 'Appointment declined',
  vet_appointment_status_counter: 'Waiting for veterinarian response',
};

const hr = {
  vet_appointment_waiting_title: 'Čeka se veterinar',
  vet_appointment_waiting_body: 'Karton poslan veterinari {vet}. Odgovor stiže uskoro.',
  vet_appointment_proposed_title: 'Predloženi termin',
  vet_appointment_proposed_label: '{vet} predlaže: {datetime}',
  vet_appointment_confirm: 'Potvrdi termin',
  vet_appointment_counter: 'Predloži drugi termin',
  vet_appointment_decline: 'Ne mogu doći',
  vet_appointment_confirmed_title: 'Termin potvrđen',
  vet_appointment_confirmed_label: 'S {vet}: {datetime}',
  vet_appointment_counter_title: 'Vaš prijedlog: {datetime}',
  vet_appointment_counter_sheet_title: 'Predloži drugi termin',
  vet_appointment_counter_note: 'Napomena (opcionalno)',
  vet_appointment_counter_send: 'Pošalji prijedlog',
  vet_appointment_decline_reason_hint: 'Razlog (opcionalno)',
  vet_appointment_owner_preferred_title: 'Željeni termin vlasnika',
  vet_appointment_owner_preferred_label: 'Zatraženo: {datetime}',
  vet_appointment_request_preferred: 'Zatraži željeni termin posjeta',
  vet_appointment_preferred_note: 'Napomena o terminu',
  vet_appointment_vet_propose_checkbox: 'Predloži termin posjeta',
  vet_appointment_vet_accept_counter: 'Prihvati termin vlasnika',
  vet_appointment_vet_propose_new: 'Predloži novi termin',
  vet_appointment_confirmed_snack: 'Termin je potvrđen.',
  vet_appointment_counter_sent_snack: 'Prijedlog termina je poslan.',
  vet_appointment_declined_snack: 'Termin je odbijen.',
  vet_appointment_vet_accepted_snack: 'Termin vlasnika je prihvaćen.',
  vet_appointment_select_datetime: 'Odaberite datum i vrijeme',
  vet_appointment_status_declined: 'Termin odbijen',
  vet_appointment_status_counter: 'Čeka se odgovor veterinara',
};

const de = {
  vet_appointment_waiting_title: 'Warten auf Tierarzt',
  vet_appointment_waiting_body: 'Akte an {vet} gesendet. Antwort folgt in Kürze.',
  vet_appointment_proposed_title: 'Vorgeschlagener Termin',
  vet_appointment_proposed_label: '{vet} schlägt vor: {datetime}',
  vet_appointment_confirm: 'Termin bestätigen',
  vet_appointment_counter: 'Anderen Termin vorschlagen',
  vet_appointment_decline: 'Kann nicht kommen',
  vet_appointment_confirmed_title: 'Termin bestätigt',
  vet_appointment_confirmed_label: 'Mit {vet}: {datetime}',
  vet_appointment_counter_title: 'Ihr Vorschlag: {datetime}',
  vet_appointment_counter_sheet_title: 'Anderen Termin vorschlagen',
  vet_appointment_counter_note: 'Notiz (optional)',
  vet_appointment_counter_send: 'Vorschlag senden',
  vet_appointment_decline_reason_hint: 'Grund (optional)',
  vet_appointment_owner_preferred_title: 'Wunschtermin des Besitzers',
  vet_appointment_owner_preferred_label: 'Angefragt: {datetime}',
  vet_appointment_request_preferred: 'Wunschtermin anfragen',
  vet_appointment_preferred_note: 'Notiz zum Termin',
  vet_appointment_vet_propose_checkbox: 'Besuchstermin vorschlagen',
  vet_appointment_vet_accept_counter: 'Termin des Besitzers annehmen',
  vet_appointment_vet_propose_new: 'Neuen Termin vorschlagen',
  vet_appointment_confirmed_snack: 'Termin bestätigt.',
  vet_appointment_counter_sent_snack: 'Terminvorschlag gesendet.',
  vet_appointment_declined_snack: 'Termin abgelehnt.',
  vet_appointment_vet_accepted_snack: 'Termin des Besitzers angenommen.',
  vet_appointment_select_datetime: 'Datum und Uhrzeit wählen',
  vet_appointment_status_declined: 'Termin abgelehnt',
  vet_appointment_status_counter: 'Warten auf Antwort des Tierarztes',
};

const translations = {
  en,
  hr,
  'hr-HR': hr,
  'hr-BA': hr,
  bs: hr,
  sr: { ...hr, vet_appointment_counter_title: 'Vaš predlog: {datetime}' },
  'sr-BA': { ...hr, vet_appointment_counter_title: 'Vaš predlog: {datetime}' },
  'sr-RS': { ...hr, vet_appointment_counter_title: 'Vaš predlog: {datetime}' },
  de,
  fr: {
    ...en,
    vet_appointment_waiting_title: 'En attente du vétérinaire',
    vet_appointment_confirm: 'Confirmer le rendez-vous',
    vet_appointment_counter: 'Proposer un autre horaire',
  },
  es: {
    ...en,
    vet_appointment_waiting_title: 'Esperando al veterinario',
    vet_appointment_confirm: 'Confirmar cita',
    vet_appointment_counter: 'Proponer otra hora',
  },
  it: {
    ...en,
    vet_appointment_waiting_title: 'In attesa del veterinario',
    vet_appointment_confirm: 'Conferma appuntamento',
    vet_appointment_counter: 'Proponi un altro orario',
  },
  pl: {
    ...en,
    vet_appointment_waiting_title: 'Oczekiwanie na weterynarza',
    vet_appointment_confirm: 'Potwierdź termin',
    vet_appointment_counter: 'Zaproponuj inny termin',
  },
  cs: {
    ...en,
    vet_appointment_waiting_title: 'Čekání na veterináře',
    vet_appointment_confirm: 'Potvrdit termín',
    vet_appointment_counter: 'Navrhnout jiný termín',
  },
  sv: {
    ...en,
    vet_appointment_waiting_title: 'Väntar på veterinär',
    vet_appointment_confirm: 'Bekräfta tid',
    vet_appointment_counter: 'Föreslå annan tid',
  },
  ru: {
    ...en,
    vet_appointment_waiting_title: 'Ожидание ветеринара',
    vet_appointment_confirm: 'Подтвердить запись',
    vet_appointment_counter: 'Предложить другое время',
  },
  uk: {
    ...en,
    vet_appointment_waiting_title: 'Очікування ветеринара',
    vet_appointment_confirm: 'Підтвердити запис',
    vet_appointment_counter: 'Запропонувати інший час',
  },
  ar: en,
  tr: {
    ...en,
    vet_appointment_waiting_title: 'Veteriner bekleniyor',
    vet_appointment_confirm: 'Randevuyu onayla',
    vet_appointment_counter: 'Başka saat öner',
  },
  zh: {
    ...en,
    vet_appointment_waiting_title: '等待兽医回复',
    vet_appointment_confirm: '确认预约',
    vet_appointment_counter: '建议其他时间',
  },
  hi: en,
  id: {
    ...en,
    vet_appointment_waiting_title: 'Menunggu dokter hewan',
    vet_appointment_confirm: 'Konfirmasi janji',
    vet_appointment_counter: 'Usulkan waktu lain',
  },
  sw: en,
};

for (const file of fs.readdirSync(dir).filter((f) => f.endsWith('.json'))) {
  const lang = file.replace('.json', '');
  const t = translations[lang] || en;
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
