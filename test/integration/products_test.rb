require "test_helper"

class ProductsTest < ActionDispatch::IntegrationTest
  def create_product(attrs = {})
    Product.create!({
      name: "Product #{Product.count + 1}",
      category: "coffee",
      price_cents: 500,
      inventory_count: 5,
      active: true
    }.merge(attrs))
  end

  test "index returns active products with pagination" do
    create_product(name: "Alpha")
    create_product(name: "Beta", category: "tea")

    get "/products"

    assert_response :ok
    body = response.parsed_body
    assert_equal 2, body["products"].size
    assert_equal 2, body["pagination"]["total_count"]
    assert_equal %w[id name category description price_cents inventory_count].sort,
                 body["products"].first.keys.sort
  end

  test "index sorts by name ascending" do
    create_product(name: "Charlie")
    create_product(name: "Alpha")
    create_product(name: "Bravo")

    get "/products"

    assert_equal %w[Alpha Bravo Charlie], response.parsed_body["products"].map { |p| p["name"] }
  end

  test "index paginates" do
    3.times { |i| create_product(name: "Item #{i}") }

    get "/products", params: { limit: 2, page: 2 }

    body = response.parsed_body
    assert_equal 1, body["products"].size
    assert_equal 3, body["pagination"]["total_count"]
    assert_equal 2, body["pagination"]["page"]
  end

  test "index clamps limit and page" do
    create_product

    get "/products", params: { limit: 0 }
    assert_equal 1, response.parsed_body["pagination"]["limit"]

    get "/products", params: { limit: 1000 }
    assert_equal 100, response.parsed_body["pagination"]["limit"]

    get "/products", params: { limit: "abc" }
    assert_equal 1, response.parsed_body["pagination"]["limit"]

    get "/products", params: { page: -5 }
    assert_equal 1, response.parsed_body["pagination"]["page"]
  end

  test "index filters by category" do
    create_product(name: "Latte", category: "coffee")
    create_product(name: "Sencha", category: "tea")

    get "/products", params: { category: "tea" }

    names = response.parsed_body["products"].map { |p| p["name"] }
    assert_equal [ "Sencha" ], names
  end

  test "index query is case-insensitive" do
    create_product(name: "Cold Brew")
    create_product(name: "COLD Latte")
    create_product(name: "Espresso")

    get "/products", params: { query: "cold" }

    assert_equal 2, response.parsed_body["pagination"]["total_count"]
  end

  test "index query treats regex characters literally" do
    create_product(name: "Matcha Latte (Large)")
    create_product(name: "Matcha Latte Large")
    create_product(name: "Dr. Fizz")
    create_product(name: "Drx Fizz")

    get "/products", params: { query: "(large)" }
    assert_equal [ "Matcha Latte (Large)" ], response.parsed_body["products"].map { |p| p["name"] }

    get "/products", params: { query: "dr." }
    assert_equal [ "Dr. Fizz" ], response.parsed_body["products"].map { |p| p["name"] }
  end

  test "index excludes inactive products" do
    create_product(name: "Visible")
    create_product(name: "Hidden", active: false)

    get "/products"

    names = response.parsed_body["products"].map { |p| p["name"] }
    assert_equal [ "Visible" ], names
    assert_equal 1, response.parsed_body["pagination"]["total_count"]
  end

  test "show returns a product" do
    product = create_product(name: "Alpha", price_cents: 750)

    get "/products/#{product.id}"

    assert_response :ok
    body = response.parsed_body
    assert_equal product.id.to_s, body["id"]
    assert_equal "Alpha", body["name"]
    assert_equal 750, body["price_cents"]
  end

  test "show returns 404 for an inactive product" do
    product = create_product(active: false)

    get "/products/#{product.id}"

    assert_response :not_found
    assert_equal "not_found", response.parsed_body["error"]["code"]
  end

  test "show returns 404 for unknown and malformed ids" do
    get "/products/000000000000000000000000"
    assert_response :not_found

    get "/products/abc"
    assert_response :not_found
  end
end
