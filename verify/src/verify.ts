const BASE_URL = process.env.BASE_URL ?? "http://localhost:3000";

// ---------- Types ----------
interface Product {
  id: string;
  name: string;
  category: string;
  description: string | null;
  price_cents: number;
  inventory_count: number;
}

interface Pagination {
  page: number;
  limit: number;
  total_count: number;
}

interface ProductList {
  products: Product[];
  pagination: Pagination;
}

interface LineItem {
  product_id: string;
  name: string;
  quantity: number;
  unit_price_cents: number;
  total_cents: number;
}

interface Quote {
  items: LineItem[];
  subtotal_cents: number;
  tax_cents: number;
  total_cents: number;
}

interface OrderResult {
  order_id: string;
  total_cents: number;
}

interface ApiError {
  error: { code: string; message: string };
}

// ---------- Runtime shape guards (types vanish at runtime) ----------
const isObject = (v: unknown): v is Record<string, unknown> =>
  typeof v === "object" && v !== null;

function isProduct(v: unknown): v is Product {
  return (
    isObject(v) &&
    typeof v.id === "string" &&
    typeof v.name === "string" &&
    typeof v.category === "string" &&
    (v.description === null || typeof v.description === "string") &&
    typeof v.price_cents === "number" &&
    typeof v.inventory_count === "number"
  );
}

function isProductList(v: unknown): v is ProductList {
  return (
    isObject(v) &&
    Array.isArray(v.products) &&
    v.products.every(isProduct) &&
    isObject(v.pagination) &&
    typeof v.pagination.page === "number" &&
    typeof v.pagination.limit === "number" &&
    typeof v.pagination.total_count === "number"
  );
}

function isLineItem(v: unknown): v is LineItem {
  return (
    isObject(v) &&
    typeof v.product_id === "string" &&
    typeof v.name === "string" &&
    typeof v.quantity === "number" &&
    typeof v.unit_price_cents === "number" &&
    typeof v.total_cents === "number"
  );
}

function isQuote(v: unknown): v is Quote {
  return (
    isObject(v) &&
    Array.isArray(v.items) &&
    v.items.every(isLineItem) &&
    typeof v.subtotal_cents === "number" &&
    typeof v.tax_cents === "number" &&
    typeof v.total_cents === "number"
  );
}

function isOrderResult(v: unknown): v is OrderResult {
  return isObject(v) && typeof v.order_id === "string" && typeof v.total_cents === "number";
}

function isApiError(v: unknown): v is ApiError {
  return (
    isObject(v) &&
    isObject(v.error) &&
    typeof v.error.code === "string" &&
    typeof v.error.message === "string"
  );
}

// ---------- Helpers ----------
let failures = 0;

function check(name: string, condition: boolean, detail?: string): void {
  if (condition) {
    console.log(`  PASS  ${name}`);
  } else {
    failures++;
    console.log(`  FAIL  ${name}${detail ? `  (${detail})` : ""}`);
  }
}

async function request(
  method: "GET" | "POST",
  path: string,
  body?: unknown
): Promise<{ status: number; body: unknown }> {
  const res = await fetch(`${BASE_URL}${path}`, {
    method,
    headers: { "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    parsed = text;
  }
  return { status: res.status, body: parsed };
}

async function fetchProduct(id: string): Promise<Product | null> {
  const res = await request("GET", `/products/${id}`);
  return isProduct(res.body) ? res.body : null;
}

// ---------- Product checks ----------
async function verifyProducts(): Promise<void> {
  console.log("\nProducts");

  const list = await request("GET", "/products");
  check("GET /products returns 200", list.status === 200, `got ${list.status}`);
  check("list has the expected shape", isProductList(list.body));
  if (!isProductList(list.body) || list.body.products.length === 0) {
    check("seed data is present", false, "no products returned; run db:seed");
    return;
  }
  const first = list.body.products[0];

  const one = await request("GET", "/products?limit=1");
  check(
    "limit=1 returns exactly one product",
    isProductList(one.body) && one.body.products.length === 1 && one.body.pagination.limit === 1
  );

  const big = await request("GET", "/products?limit=1000");
  check(
    "limit is clamped to 100",
    isProductList(big.body) && big.body.pagination.limit === 100
  );

  const cat = await request("GET", `/products?category=${encodeURIComponent(first.category)}`);
  check(
    "category filter only returns that category",
    isProductList(cat.body) &&
      cat.body.products.length > 0 &&
      cat.body.products.every((p) => p.category === first.category)
  );

  const needle = first.name.slice(0, 3).toUpperCase();
  const q = await request("GET", `/products?query=${encodeURIComponent(needle)}`);
  check(
    "query is case-insensitive",
    isProductList(q.body) &&
      q.body.products.some((p) => p.id === first.id) &&
      q.body.products.every((p) => p.name.toLowerCase().includes(needle.toLowerCase()))
  );

  const show = await request("GET", `/products/${first.id}`);
  check("GET /products/:id returns 200", show.status === 200, `got ${show.status}`);
  check("show has the expected shape and id", isProduct(show.body) && show.body.id === first.id);

  const missing = await request("GET", "/products/000000000000000000000000");
  check("unknown id returns 404", missing.status === 404, `got ${missing.status}`);
  check("404 uses the error shape", isApiError(missing.body) && missing.body.error.code === "not_found");
}

// ---------- Checkout checks ----------
async function verifyCheckout(): Promise<void> {
  console.log("\nCheckout");

  // Pick targets from live data so the script is rerun-safe.
  const all = await request("GET", "/products?limit=100");
  if (!isProductList(all.body)) {
    check("could load products for checkout checks", false);
    return;
  }
  const products = all.body.products;
  const target = [...products].sort((a, b) => b.inventory_count - a.inventory_count)[0];
  const outOfStock = products.find((p) => p.inventory_count === 0);
  check(
    "found a well-stocked product",
    target !== undefined && target.inventory_count >= 10,
    "run db:seed to reset stock"
  );
  if (!target) return;

  // Quote happy path. Expected values are computed here, not copied from the API.
  const qty = 3;
  const quote = await request("POST", "/checkout/quote", {
    items: [{ product_id: target.id, quantity: qty }],
  });
  check("quote returns 200", quote.status === 200, `got ${quote.status}`);
  check("quote has the expected shape", isQuote(quote.body));
  if (isQuote(quote.body)) {
    const subtotal = target.price_cents * qty;
    const tax = Math.round(subtotal * 0.08);
    check("quote subtotal is price x quantity", quote.body.subtotal_cents === subtotal);
    check(
      "quote tax is 8% rounded",
      quote.body.tax_cents === tax,
      `expected ${tax}, got ${quote.body.tax_cents}`
    );
    check("quote total is subtotal + tax", quote.body.total_cents === subtotal + tax);
  }
  const afterQuote = await fetchProduct(target.id);
  check("quote does not change inventory", afterQuote?.inventory_count === target.inventory_count);

  // Quote sad paths.
  const sad = async (name: string, body: unknown, message: string): Promise<void> => {
    const res = await request("POST", "/checkout/quote", body);
    check(`${name} returns 400`, res.status === 400, `got ${res.status}`);
    check(
      `${name} returns "${message}"`,
      isApiError(res.body) && res.body.error.message === message
    );
  };
  await sad("empty cart", { items: [] }, "Cart is empty");
  await sad("quantity 0", { items: [{ product_id: target.id, quantity: 0 }] }, "Invalid quantity");
  await sad("quantity abc", { items: [{ product_id: target.id, quantity: "abc" }] }, "Invalid quantity");
  await sad(
    "unknown product",
    { items: [{ product_id: "000000000000000000000000", quantity: 1 }] },
    "Product not found"
  );
  await sad(
    "quantity above stock",
    { items: [{ product_id: target.id, quantity: target.inventory_count + 1 }] },
    "Insufficient inventory"
  );
  if (outOfStock) {
    await sad(
      "out-of-stock product",
      { items: [{ product_id: outOfStock.id, quantity: 1 }] },
      "Insufficient inventory"
    );
  }

  // Complete: a bad email must not touch inventory.
  const before = await fetchProduct(target.id);
  const badEmail = await request("POST", "/checkout/complete", {
    email: "not-an-email",
    items: [{ product_id: target.id, quantity: 1 }],
  });
  check("bad email returns 422", badEmail.status === 422, `got ${badEmail.status}`);
  check(
    "422 uses the error shape",
    isApiError(badEmail.body) && badEmail.body.error.code === "validation_failed"
  );
  const afterBad = await fetchProduct(target.id);
  check(
    "bad email leaves inventory unchanged",
    afterBad?.inventory_count === before?.inventory_count
  );

  // Complete: happy path, then confirm inventory dropped by exactly the quantity.
  const done = await request("POST", "/checkout/complete", {
    email: "verify@example.com",
    items: [{ product_id: target.id, quantity: 1 }],
  });
  check("complete returns 201", done.status === 201, `got ${done.status}`);
  check("complete has the expected shape", isOrderResult(done.body));
  if (isOrderResult(done.body) && before) {
    const subtotal = target.price_cents;
    check(
      "order total includes tax",
      done.body.total_cents === subtotal + Math.round(subtotal * 0.08)
    );
    const afterOrder = await fetchProduct(target.id);
    check(
      "inventory dropped by exactly 1",
      afterOrder?.inventory_count === before.inventory_count - 1,
      `before ${before.inventory_count}, after ${afterOrder?.inventory_count}`
    );
  }
}

// ---------- Main ----------
async function main(): Promise<void> {
  console.log(`Verifying API at ${BASE_URL}`);
  await verifyProducts();
  await verifyCheckout();

  console.log(`\n${failures === 0 ? "All checks passed" : `${failures} check(s) FAILED`}`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((err) => {
  console.error("Verification crashed:", err);
  process.exit(1);
});