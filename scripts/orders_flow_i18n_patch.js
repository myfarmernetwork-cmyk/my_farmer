const fs = require("fs");
const path = require("path");

const dir = path.join(__dirname, "..", "assets", "translations");

const byLocale = {
  hr: {
    orders_action_accept: "Prihvati narudžbu",
    orders_action_mark_ready_pickup: "Spremno za preuzimanje",
    orders_action_mark_ready_delivery: "Spremno za dostavu",
    orders_flow_step_new: "1. Nova",
    orders_flow_step_preparing: "2. U pripremi",
    orders_flow_step_ready: "3. Spremno",
    orders_status_ready_pickup: "Spremno za preuzimanje",
    orders_status_ready_delivery: "Spremno za dostavu",
    orders_seller_step_hint_new:
      "Korak 1: Prihvatite narudžbu kad ste spremni pripremiti robu.",
    orders_seller_step_hint_preparing:
      "Korak 2: Kad je roba spremna, označite sljedeći korak — kupac tada dobiva poruku.",
    orders_ready_confirm_title: "Potvrdite obavijest kupcu",
    orders_ready_confirm_warning:
      "Kupac će odmah dobiti push poruku. Provjerite je li roba stvarno spremna.",
    orders_ready_confirm_pickup_body:
      "Kupac {buyer} dobiva: „Roba je spremna — dođite po preuzimanje kod {seller}.“",
    orders_ready_confirm_delivery_body:
      "Kupac {buyer} dobiva: „Roba je spremna — dostava prema dogovoru ({schedule}).“",
    orders_ready_confirm_question: "Jeste li sigurni da je roba spremna?",
    orders_seller_notify_sent_pickup:
      "Kupac je obaviješten da može preuzeti robu.",
    orders_seller_notify_sent_delivery:
      "Kupac je obaviješten da je roba spremna za dostavu.",
    orders_change_status_intro: "Sljedeći korak: {status}",
  },
  de: {
    orders_action_accept: "Bestellung annehmen",
    orders_action_mark_ready_pickup: "Abholbereit markieren",
    orders_action_mark_ready_delivery: "Lieferbereit markieren",
    orders_flow_step_new: "1. Neu",
    orders_flow_step_preparing: "2. In Bearbeitung",
    orders_flow_step_ready: "3. Bereit",
    orders_status_ready_pickup: "Abholbereit",
    orders_status_ready_delivery: "Lieferbereit",
    orders_seller_step_hint_new:
      "Schritt 1: Bestellung annehmen, wenn Sie mit der Vorbereitung beginnen.",
    orders_seller_step_hint_preparing:
      "Schritt 2: Wenn die Ware fertig ist, markieren Sie sie als bereit — der Kunde erhält dann eine Nachricht.",
    orders_ready_confirm_title: "Kundenbenachrichtigung bestätigen",
    orders_ready_confirm_warning:
      "Der Kunde erhält sofort eine Push-Nachricht. Ist die Ware wirklich fertig?",
    orders_ready_confirm_pickup_body:
      "Kunde {buyer} erhält: „Ihre Bestellung ist fertig — holen Sie sie bei {seller} ab.“",
    orders_ready_confirm_delivery_body:
      "Kunde {buyer} erhält: „Ihre Bestellung ist fertig. Lieferung: {schedule}.“",
    orders_ready_confirm_question: "Sind Sie sicher, dass die Ware bereit ist?",
    orders_seller_notify_sent_pickup:
      "Der Kunde wurde benachrichtigt, dass er abholen kann.",
    orders_seller_notify_sent_delivery:
      "Der Kunde wurde benachrichtigt, dass die Lieferung vorbereitet ist.",
    orders_change_status_intro: "Nächster Schritt: {status}",
  },
  en: {
    orders_action_accept: "Accept order",
    orders_action_mark_ready_pickup: "Mark ready for pickup",
    orders_action_mark_ready_delivery: "Mark ready for delivery",
    orders_flow_step_new: "1. New",
    orders_flow_step_preparing: "2. Preparing",
    orders_flow_step_ready: "3. Ready",
    orders_status_ready_pickup: "Ready for pickup",
    orders_status_ready_delivery: "Ready for delivery",
    orders_seller_step_hint_new:
      "Step 1: Accept the order when you are ready to prepare it.",
    orders_seller_step_hint_preparing:
      "Step 2: When goods are ready, mark the next step — the buyer is notified then.",
    orders_ready_confirm_title: "Confirm buyer notification",
    orders_ready_confirm_warning:
      "The buyer will receive a push notification immediately. Is the order really ready?",
    orders_ready_confirm_pickup_body:
      "Buyer {buyer} will receive: “Your order is ready — pick it up from {seller}.”",
    orders_ready_confirm_delivery_body:
      "Buyer {buyer} will receive: “Your order is ready. Delivery: {schedule}.”",
    orders_ready_confirm_question: "Are you sure the goods are ready?",
    orders_seller_notify_sent_pickup:
      "The buyer was notified they can pick up the order.",
    orders_seller_notify_sent_delivery:
      "The buyer was notified the order is ready for delivery.",
    orders_change_status_intro: "Next step: {status}",
  },
};

byLocale.bs = byLocale.hr;
byLocale["hr-HR"] = byLocale.hr;
byLocale["hr-BA"] = byLocale.hr;
byLocale.sr = {
  ...byLocale.hr,
  orders_action_accept: "Prihvati porudžbinu",
  orders_ready_confirm_pickup_body:
    "Kupac {buyer} dobija: „Roba je spremna — dođite po preuzimanje kod {seller}.“",
  orders_ready_confirm_delivery_body:
    "Kupac {buyer} dobija: „Roba je spremna — dostava prema dogovoru ({schedule}).“",
  orders_seller_notify_sent_pickup:
    "Kupac je obavešten da može preuzeti robu.",
  orders_seller_notify_sent_delivery:
    "Kupac je obavešten da je roba spremna za dostavu.",
};
byLocale["sr-BA"] = byLocale.sr;
byLocale["sr-RS"] = byLocale.sr;

const fallback = byLocale.en;

for (const file of fs.readdirSync(dir)) {
  if (!file.endsWith(".json")) continue;
  const locale = file.replace(".json", "");
  const keys = byLocale[locale] || fallback;
  const filePath = path.join(dir, file);
  const data = JSON.parse(fs.readFileSync(filePath, "utf8"));
  Object.assign(data, keys);
  const sorted = Object.fromEntries(Object.entries(data).sort(([a], [b]) => a.localeCompare(b)));
  fs.writeFileSync(filePath, JSON.stringify(sorted, null, 2) + "\n");
  console.log("patched", file);
}
