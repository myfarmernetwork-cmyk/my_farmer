const WEEKDAY_LABELS = {
  de: {
    mon: "Mo",
    tue: "Di",
    wed: "Mi",
    thu: "Do",
    fri: "Fr",
    sat: "Sa",
    sun: "So",
  },
  en: {
    mon: "Mon",
    tue: "Tue",
    wed: "Wed",
    thu: "Thu",
    fri: "Fri",
    sat: "Sat",
    sun: "Sun",
  },
  hr: {
    mon: "Pon",
    tue: "Uto",
    wed: "Sri",
    thu: "Čet",
    fri: "Pet",
    sat: "Sub",
    sun: "Ned",
  },
  bs: {
    mon: "Pon",
    tue: "Uto",
    wed: "Sri",
    thu: "Čet",
    fri: "Pet",
    sat: "Sub",
    sun: "Ned",
  },
  sr: {
    mon: "Pon",
    tue: "Uto",
    wed: "Sri",
    thu: "Čet",
    fri: "Pet",
    sat: "Sub",
    sun: "Ned",
  },
};

const COPY = {
  de: {
    new_order_title: "Neue Bestellung",
    new_order_body: ({ buyer, summary, total }) =>
      `${buyer} hat bestellt: ${summary} (${total})`,
    preparing_title: "Bestellung angenommen",
    preparing_body: ({ seller }) =>
      `${seller} hat Ihre Bestellung angenommen. Status: In Bearbeitung.`,
    ready_pickup_title: "Bestellung bereit",
    ready_pickup_body: ({ seller }) =>
      `Ihre Bestellung ist fertig — holen Sie sie bei ${seller} ab.`,
    ready_delivery_title: "Bestellung bereit",
    ready_delivery_body: ({ schedule }) =>
      `Ihre Bestellung ist fertig. Lieferung: ${schedule}.`,
  },
  en: {
    new_order_title: "New order",
    new_order_body: ({ buyer, summary, total }) =>
      `${buyer} ordered: ${summary} (${total})`,
    preparing_title: "Order accepted",
    preparing_body: ({ seller }) =>
      `${seller} accepted your order. Status: In progress.`,
    ready_pickup_title: "Order ready",
    ready_pickup_body: ({ seller }) =>
      `Your order is ready — pick it up from ${seller}.`,
    ready_delivery_title: "Order ready",
    ready_delivery_body: ({ schedule }) =>
      `Your order is ready. Delivery: ${schedule}.`,
  },
  hr: {
    new_order_title: "Nova narudžba",
    new_order_body: ({ buyer, summary, total }) =>
      `${buyer} je naručio: ${summary} (${total})`,
    preparing_title: "Narudžba prihvaćena",
    preparing_body: ({ seller }) =>
      `${seller} je prihvatio vašu narudžbu. Status: u pripremi.`,
    ready_pickup_title: "Narudžba spremna",
    ready_pickup_body: ({ seller }) =>
      `Vaša narudžba je gotova — dođite je preuzeti kod ${seller}.`,
    ready_delivery_title: "Narudžba spremna",
    ready_delivery_body: ({ schedule }) =>
      `Vaša narudžba je spremna. Dostava: ${schedule}.`,
  },
  bs: {
    new_order_title: "Nova narudžba",
    new_order_body: ({ buyer, summary, total }) =>
      `${buyer} je naručio: ${summary} (${total})`,
    preparing_title: "Narudžba prihvaćena",
    preparing_body: ({ seller }) =>
      `${seller} je prihvatio vašu narudžbu. Status: u pripremi.`,
    ready_pickup_title: "Narudžba spremna",
    ready_pickup_body: ({ seller }) =>
      `Vaša narudžba je spremna — dođite je preuzeti kod ${seller}.`,
    ready_delivery_title: "Narudžba spremna",
    ready_delivery_body: ({ schedule }) =>
      `Vaša narudžba je spremna. Dostava: ${schedule}.`,
  },
  sr: {
    new_order_title: "Nova porudžbina",
    new_order_body: ({ buyer, summary, total }) =>
      `${buyer} je poručio: ${summary} (${total})`,
    preparing_title: "Porudžbina prihvaćena",
    preparing_body: ({ seller }) =>
      `${seller} je prihvatio vašu porudžbinu. Status: u pripremi.`,
    ready_pickup_title: "Porudžbina spremna",
    ready_pickup_body: ({ seller }) =>
      `Vaša porudžbina je spremna — dođite da je preuzmete kod ${seller}.`,
    ready_delivery_title: "Porudžbina spremna",
    ready_delivery_body: ({ schedule }) =>
      `Vaša porudžbina je spremna. Dostava: ${schedule}.`,
  },
};

function resolveLang(preferredLanguage) {
  const raw = (preferredLanguage || "en").toString().toLowerCase().replace("_", "-");
  if (raw.startsWith("de")) return "de";
  if (raw.startsWith("hr")) return "hr";
  if (raw.startsWith("bs")) return "bs";
  if (raw.startsWith("sr")) return "sr";
  return "en";
}

function normalizeOrderStatus(raw) {
  const value = (raw || "").toString().trim().toLowerCase();
  switch (value) {
    case "new":
    case "novo":
    case "na čekanju":
    case "pending":
      return "new";
    case "preparing":
    case "u pripremi":
    case "in_progress":
    case "processing":
      return "preparing";
    case "completed":
    case "isporučeno":
    case "završeno":
    case "zavrseno":
    case "odrađeno":
    case "odradeno":
    case "delivered":
    case "done":
    case "finished":
      return "completed";
    default:
      return value || "new";
  }
}

function formatWeekdays(codes, lang) {
  const labels = WEEKDAY_LABELS[lang] || WEEKDAY_LABELS.en;
  if (!Array.isArray(codes) || codes.length === 0) return "";
  return codes
    .map((code) => labels[(code || "").toString().toLowerCase()] || code)
    .join(", ");
}

function formatDeliverySchedule(sellerData, lang) {
  const days = formatWeekdays(
    sellerData?.deliveryDays?.length
      ? sellerData.deliveryDays
      : sellerData?.workingDays,
    lang,
  );
  const from = sellerData?.deliveryHoursFrom || "";
  const to = sellerData?.deliveryHoursTo || "";
  if (days && from && to) return `${days}, ${from}–${to}`;
  if (days) return days;
  if (from && to) return `${from}–${to}`;
  return "—";
}

function getCopy(lang) {
  return COPY[lang] || COPY.en;
}

function newOrderNotification({ lang, buyer, summary, total, currency = "KM" }) {
  const copy = getCopy(lang);
  const formattedTotal =
    typeof total === "number"
      ? `${total.toFixed(2)} ${currency}`
      : `${total} ${currency}`;
  return {
    title: copy.new_order_title,
    body: copy.new_order_body({
      buyer,
      summary,
      total: formattedTotal,
    }),
  };
}

function buyerStatusNotification({
  lang,
  status,
  sellerName,
  deliveryType,
  sellerData,
}) {
  const copy = getCopy(lang);
  const seller = sellerName || "Farmer";

  if (status === "preparing") {
    return {
      title: copy.preparing_title,
      body: copy.preparing_body({ seller }),
    };
  }

  if (status === "completed") {
    if (deliveryType === "delivery") {
      const schedule = formatDeliverySchedule(sellerData, lang);
      return {
        title: copy.ready_delivery_title,
        body: copy.ready_delivery_body({ schedule }),
      };
    }
    return {
      title: copy.ready_pickup_title,
      body: copy.ready_pickup_body({ seller }),
    };
  }

  return null;
}

module.exports = {
  resolveLang,
  normalizeOrderStatus,
  newOrderNotification,
  buyerStatusNotification,
  formatDeliverySchedule,
};
