# CityHive E-commerce API

A small Rails JSON API for a drinks store: browse products, get a checkout quote, and complete an order. It was built around two provided controllers (`ProductsController` and `CheckoutsController`), which were treated as the source of requirements.

**Stack:** Ruby 3.4, Rails 8.1 (API mode), MongoDB 8, Mongoid 9.1, Docker Compose. A TypeScript script in `verify/` exercises the running API.

## Quick start

**Prerequisites:** Docker with Compose (Docker Desktop on Windows/macOS). Node 18+ is only needed for the verification script.

```
git clone <repo-url>
cd CityHive
docker compose up --build
```

The first build takes a few minutes. When it finishes, the API is available at <http://localhost:3000>.

On every start of the web container, the entrypoint (`bin/docker-entrypoint.sh`):

1. removes any stale `server.pid`
2. creates the MongoDB indexes
3. seeds the database (idempotent, safe to run repeatedly)
4. starts Rails on port 3000

Quick check:

```
curl "http://localhost:3000/products?limit=1"
```

You should see one product and `"total_count": 22`.

To stop: press Ctrl+C, or run `docker compose down`. To also delete the database volume and start completely fresh, run `docker compose down -v`.

## API

| Method | Path | Description |
|---|---|---|
| GET | `/products` | List active products (paginated, filterable) |
| GET | `/products/:id` | Show one active product |
| POST | `/checkout/quote` | Price a cart without changing inventory |
| POST | `/checkout/complete` | Create an order and decrement inventory |
| GET | `/up` | Rails health check |

### GET /products

Query parameters (all optional):

| Param | Default | Notes |
|---|---|---|
| `page` | 1 | Values below 1 are treated as 1 |
| `limit` | 25 | Clamped to 1-100 (non-numeric values become 1) |
| `category` | none | Exact match, e.g. `coffee`, `tea`, `juice`, `soda` |
| `query` | none | Case-insensitive substring match on name; special characters are escaped |

Results are sorted by name ascending. Inactive products are never returned.

```
curl "http://localhost:3000/products?category=coffee&limit=5&page=2"
curl "http://localhost:3000/products?query=cold"
```

Response:

```json
{
  "products": [
    {
      "id": "...",
      "name": "Alphonso Mango Juice",
      "category": "juice",
      "description": "Sweet and thick",
      "price_cents": 649,
      "inventory_count": 500
    }
  ],
  "pagination": { "page": 1, "limit": 1, "total_count": 22 }
}
```

### GET /products/:id

Returns a single product (same shape as above). Unknown, malformed, and inactive IDs all return 404.

### POST /checkout/quote

```
curl -X POST http://localhost:3000/checkout/quote \
  -H "Content-Type: application/json" \
  -d '{"items":[{"product_id":"<id>","quantity":2}]}'
```

Response (`200`):

```json
{
  "items": [
    {
      "product_id": "...",
      "name": "...",
      "quantity": 2,
      "unit_price_cents": 500,
      "total_cents": 1000
    }
  ],
  "subtotal_cents": 1000,
  "tax_cents": 80,
  "total_cents": 1080
}
```

### POST /checkout/complete

Same body as the quote, plus a required `email`:

```
curl -X POST http://localhost:3000/checkout/complete \
  -H "Content-Type: application/json" \
  -d '{"email":"buyer@example.com","items":[{"product_id":"<id>","quantity":2}]}'
```

Response (`201`):

```json
{ "order_id": "...", "total_cents": 1080 }
```

Inventory is decremented for each item in the order.

### Errors

Every error uses one JSON shape:

```json
{ "error": { "code": "bad_request", "message": "Cart is empty" } }
```

| Status | `code` | Typical causes |
|---|---|---|
| 400 | `bad_request` | Empty cart, quantity of 0 / negative / non-numeric, unknown or malformed `product_id`, insufficient inventory |
| 404 | `not_found` | Unknown, malformed, or inactive product ID on `GET /products/:id` |
| 422 | `validation_failed` | Missing or invalid email on `POST /checkout/complete` |

## Running the tests

The suite is 22 Minitest integration tests (11 products, 11 checkout). Run it inside the container:

```
docker compose run --rm -e RAILS_ENV=test web bin/rails test
```

Tests use a separate database (`city_hive_test`, configured through `MONGODB_TEST_URI`), so your seeded development data is not touched. Each test starts from an empty database and builds its own data rather than depending on the seed file.

## Running the verification script

The script in `verify/` is TypeScript (run with `tsx`, no build step). It calls the running API and checks status codes and response shapes using typed interfaces plus runtime shape guards. It exits with code `1` if any check fails.

Start the API first (`docker compose up`), then in another terminal:

```
cd verify
npm install
npm run verify
```

Other commands:

```
npm run typecheck                          # type-check the script
BASE_URL=http://localhost:3000 npm run verify   # point it at a different host
```

What it covers:

- **Products:** list shape, `limit` clamping, category filter, case-insensitive search, show by ID, 404 for an unknown ID, error shape
- **Checkout:** quote math (8% tax with rounding), quote does not change inventory, each 400 case (empty cart, invalid quantity, unknown product, insufficient inventory, out-of-stock product), 422 for a bad email with inventory unchanged, a real order returning 201, and inventory dropping by exactly the ordered quantity

The script is safe to re-run: it picks the best-stocked product from live data instead of hardcoding an ID. Each run does consume one unit of that product. To reset stock to the seeded values:

```
docker compose exec web bin/rails db:seed
```

## Seed data

`db/seeds.rb` defines 24 drinks products and upserts them by name, so running it repeatedly never creates duplicates and resets stock to known values.

| Category | Active | Notes |
|---|---|---|
| coffee | 11 | Includes a low-stock item (2 units), an out-of-stock item (0), and an inactive item |
| tea | 6 | |
| juice | 3 | |
| soda | 2 | Includes an inactive item |

That is 22 active and 2 inactive products. A few names are chosen to exercise search (several contain "cold" in mixed case; others contain parentheses or a period to test regex escaping), and several products have 500+ units so the verification script can run many times.

## Running without Docker (optional)

Requires Ruby 3.4, a local MongoDB 8 on `localhost:27017`, and Bundler.

```
bundle install
bin/rails db:mongoid:create_indexes
bin/rails db:seed
bin/rails server
bin/rails test
```

Connection settings are read from `MONGODB_URI` (development) and `MONGODB_TEST_URI` (test), with localhost defaults in `config/mongoid.yml`. On Windows, use `ruby bin/rails ...` if `bin/rails` does not run directly.

## Project layout

```
app/controllers/    ProductsController, CheckoutsController, ApplicationController (JSON error handling)
app/models/         Product, Order
config/mongoid.yml  Mongo connection (URI from environment variables)
db/seeds.rb         Idempotent seed data
test/integration/   Products and checkout integration tests
verify/             TypeScript API verification script
bin/docker-entrypoint.sh   Container startup (indexes, seed, server)
Dockerfile, docker-compose.yml
```

## Assumptions

- No authentication, rate limiting, or API version prefix; routes are exactly what the controllers imply.
- Money is stored and returned as integer cents. Tax is a fixed 8%, rounded to the nearest cent on the subtotal.
- Orders store a snapshot of each item (name, quantity, unit price, line total), so later price changes do not alter past orders.
- The only order status is `completed`, because that is all the controller sets.
- Email validation is a basic format check performed by the `Order` model; the controller itself does not validate it.
- A product's `active` flag hides it from the API and, as implemented, only affects the products endpoints (see limitations).
- `quantity` is converted with `to_i`, so a value like `1.5` is treated as `1`.
- Errors use a single JSON shape (`{ "error": { "code", "message" } }`), added through `rescue_from` in `ApplicationController`. Unexpected exceptions fall through to Rails' default 500 handling.
- The development database is seeded automatically in Docker; tests use a separate database.

## Known limitations and production improvements

These are behaviors of the provided checkout logic that I left as-is, plus what I would change for production.

- **Inventory race condition.** Stock is read, checked, decremented, and saved in separate steps. Concurrent checkouts can oversell. Fix: a single atomic conditional update (`$inc` guarded by `inventory_count >= quantity`).
- **No transaction.** The order is created before inventory is decremented, so a failure partway through leaves an order with partial stock changes. MongoDB transactions require a replica set; the Compose setup uses a single node.
- **Duplicate lines in one cart.** Each line is checked against stock independently, so the same product listed twice can exceed inventory. Fix: merge lines by `product_id` before validating.
- **Inactive products can be purchased.** Checkout does not filter on `active`, unlike the products endpoints.
- **Redundant work in `complete`.** The cart is built (and inventory checked) and then each product is fetched again, causing extra queries and a gap between check and write.
- **No idempotency key.** A retried `complete` request creates a duplicate order.
- **Pagination cost.** `skip`/`limit` slows down on deep pages and a `count` runs on every list request. Cursor-based pagination would scale better.
- **Float tax math.** `* 0.08` followed by rounding works here, but integer arithmetic is safer.
- **Other production work:** authentication, rate limiting, structured logging and metrics, a catch-all error handler with error reporting, a MongoDB replica set with backups, CI running the tests and verification script, and a production-oriented image (multi-stage build, non-root user).

## Troubleshooting

- **Port 3000 already in use:** stop any local `rails server` before running Docker.
- **`env: 'ruby.exe': No such file or directory` in the container:** a script in `bin/` has a Windows shebang. They should start with `#!/usr/bin/env ruby`.
- **`no such file or directory` when the entrypoint runs:** the script has Windows (CRLF) line endings. `.gitattributes` forces LF for `*.sh` and `bin/*`; re-clone or convert the file to LF.
- **Start from a clean slate:** `docker compose down -v` then `docker compose up --build`.