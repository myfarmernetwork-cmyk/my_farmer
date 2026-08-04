/**
 * Stripe PaymentIntent — marketplace + subscription checkout.
 *
 * Secrets:
 *   STRIPE_SECRET_KEY
 */

const Stripe = require("stripe");

/** Stripe minimum charge in minor units (common app currencies). */
const STRIPE_MINIMUM_MINOR_UNITS = {
  eur: 50,
  usd: 50,
  chf: 50,
  gbp: 30,
  bam: 100,
  rsd: 100,
  sek: 300,
  pln: 200,
  czk: 1500,
  huf: 175,
  uah: 100,
  rub: 100,
  try: 200,
  inr: 50,
  idr: 10000,
  kes: 100,
  sar: 200,
  cny: 100,
};

function normalizeStripeCurrency(raw) {
  const value = String(raw || "eur")
    .trim()
    .toLowerCase()
    .replace(/[^a-z]/g, "");
  if (!/^[a-z]{3}$/.test(value)) {
    const err = new Error(`Unsupported currency code: ${raw}`);
    err.code = "invalid-argument";
    throw err;
  }
  return value;
}

function minimumMinorUnits(currency) {
  return STRIPE_MINIMUM_MINOR_UNITS[currency] ?? 50;
}

function validateMinorAmount(amount, currency) {
  if (!Number.isFinite(amount) || amount <= 0) {
    const err = new Error("Invalid payment amount.");
    err.code = "invalid-argument";
    throw err;
  }

  const min = minimumMinorUnits(currency);
  if (amount < min) {
    const err = new Error(
      `Payment amount is below the minimum for ${currency.toUpperCase()}.`,
    );
    err.code = "invalid-argument";
    throw err;
  }
}

function resolvePaymentAmount({ amountCents, productId, subscriptionCentsMap }) {
  const productKey = String(productId || "").trim();
  const subscriptionCents =
    productKey.length > 0 ? subscriptionCentsMap[productKey] : undefined;
  if (subscriptionCents != null) {
    return subscriptionCents;
  }
  return Math.round(Number(amountCents));
}

function mapStripeError(error) {
  if (error && (error.code === "invalid-argument" || error.code === "failed-precondition")) {
    return error;
  }

  if (error && error.type === "StripeInvalidRequestError") {
    const mapped = new Error(error.message || "Stripe rejected the payment request.");
    mapped.code = "invalid-argument";
    return mapped;
  }

  if (error && error.type === "StripeAuthenticationError") {
    const mapped = new Error("Stripe secret key is invalid on the server.");
    mapped.code = "failed-precondition";
    return mapped;
  }

  const mapped = new Error(error?.message || "Stripe payment setup failed.");
  mapped.code = "internal";
  return mapped;
}

async function createPaymentIntentBody({
  stripeSecret,
  amountCents,
  currency,
  sellerId,
  buyerId,
  productId,
  subscriptionCentsMap,
}) {
  if (!stripeSecret) {
    const err = new Error("Stripe secret key is not configured on the server.");
    err.code = "failed-precondition";
    throw err;
  }

  const normalizedCurrency = normalizeStripeCurrency(currency);
  const resolvedAmount = resolvePaymentAmount({
    amountCents,
    productId,
    subscriptionCentsMap,
  });
  validateMinorAmount(resolvedAmount, normalizedCurrency);

  const stripe = new Stripe(stripeSecret);
  const intent = await stripe.paymentIntents.create({
    amount: resolvedAmount,
    currency: normalizedCurrency,
    automatic_payment_methods: { enabled: true },
    metadata: {
      sellerId: String(sellerId || ""),
      buyerId: String(buyerId || ""),
      productId: String(productId || ""),
    },
  });

  return {
    clientSecret: intent.client_secret,
    paymentIntentId: intent.id,
  };
}

module.exports = {
  createPaymentIntentBody,
  mapStripeError,
  minimumMinorUnits,
  normalizeStripeCurrency,
  resolvePaymentAmount,
  validateMinorAmount,
};
