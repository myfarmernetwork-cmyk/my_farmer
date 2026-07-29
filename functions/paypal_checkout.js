/**
 * PayPal Checkout (Orders v2) — create + capture.
 *
 * Secrets:
 *   PAYPAL_CLIENT_ID
 *   PAYPAL_CLIENT_SECRET
 *   PAYPAL_ENV — "sandbox" (default) or "live"
 */

function paypalBaseUrl() {
  const env = (process.env.PAYPAL_ENV || "sandbox").toLowerCase();
  return env === "live"
    ? "https://api-m.paypal.com"
    : "https://api-m.sandbox.paypal.com";
}

function getPayPalCredentials() {
  const clientId = process.env.PAYPAL_CLIENT_ID || "";
  const clientSecret = process.env.PAYPAL_CLIENT_SECRET || "";
  if (!clientId || !clientSecret) {
    const err = new Error("PayPal credentials are not configured on the server.");
    err.code = "failed-precondition";
    throw err;
  }
  return { clientId, clientSecret };
}

async function getPayPalAccessToken() {
  const { clientId, clientSecret } = getPayPalCredentials();
  const auth = Buffer.from(`${clientId}:${clientSecret}`).toString("base64");

  const response = await fetch(`${paypalBaseUrl()}/v1/oauth2/token`, {
    method: "POST",
    headers: {
      Authorization: `Basic ${auth}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials",
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`PayPal OAuth HTTP ${response.status}: ${text}`);
  }

  const data = await response.json();
  if (!data.access_token) {
    throw new Error("PayPal OAuth: missing access_token");
  }
  return data.access_token;
}

function formatPayPalAmount(amount) {
  const value = Number(amount);
  if (!Number.isFinite(value) || value <= 0) {
    const err = new Error("Invalid payment amount.");
    err.code = "invalid-argument";
    throw err;
  }
  return value.toFixed(2);
}

async function createPayPalOrderBody({ amount, currency, sellerId, buyerId }) {
  const accessToken = await getPayPalAccessToken();
  const currencyCode = (currency || "EUR").toUpperCase();
  const value = formatPayPalAmount(amount);

  const body = {
    intent: "CAPTURE",
    purchase_units: [
      {
        amount: {
          currency_code: currencyCode,
          value,
        },
        custom_id: sellerId || "",
        description: "My Farmer order",
      },
    ],
    application_context: {
      brand_name: "My Farmer",
      landing_page: "NO_PREFERENCE",
      user_action: "PAY_NOW",
      return_url: "myfarmer://paypal-return",
      cancel_url: "myfarmer://paypal-cancel",
    },
  };

  const response = await fetch(`${paypalBaseUrl()}/v2/checkout/orders`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`PayPal create order HTTP ${response.status}: ${text}`);
  }

  const order = await response.json();
  const orderId = order.id;
  const approveLink = (order.links || []).find((link) => link.rel === "approve");
  const approvalUrl = approveLink?.href;

  if (!orderId || !approvalUrl) {
    throw new Error("PayPal create order: missing order id or approval URL");
  }

  return {
    orderId,
    approvalUrl,
    amount: Number(value),
    currency: currencyCode,
    buyerId: buyerId || "",
  };
}

async function capturePayPalOrderBody(orderId) {
  if (!orderId || typeof orderId !== "string") {
    const err = new Error("Missing PayPal order id.");
    err.code = "invalid-argument";
    throw err;
  }

  const accessToken = await getPayPalAccessToken();

  const response = await fetch(
    `${paypalBaseUrl()}/v2/checkout/orders/${encodeURIComponent(orderId)}/capture`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
    },
  );

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`PayPal capture HTTP ${response.status}: ${text}`);
  }

  const capture = await response.json();
  const status = capture.status || "";
  const captureId =
    capture.purchase_units?.[0]?.payments?.captures?.[0]?.id || orderId;

  if (status !== "COMPLETED") {
    throw new Error(`PayPal capture not completed (status: ${status || "unknown"})`);
  }

  return {
    transactionId: captureId,
    paymentStatus: "PAID",
    orderId,
  };
}

module.exports = {
  createPayPalOrderBody,
  capturePayPalOrderBody,
};
