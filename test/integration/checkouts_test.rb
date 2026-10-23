require "test_helper"

class CheckoutsTest < ActionDispatch::IntegrationTest
  def create_product(attrs = {})
    Product.create!({
      name: "Product #{Product.count + 1}",
      category: "coffee",
      price_cents: 500,
      inventory_count: 5,
      active: true
    }.merge(attrs))
  end

  def post_json(path, body)
    post path, params: body, as: :json
  end

  def error_message
    response.parsed_body.dig("error", "message")
  end

  test "quote calculates line items, 8% tax with rounding, and total" do
    a = create_product(name: "A", price_cents: 999, inventory_count: 10)
    b = create_product(name: "B", price_cents: 250, inventory_count: 10)

    post_json "/checkout/quote", items: [
      { product_id: a.id.to_s, quantity: 3 },
      { product_id: b.id.to_s, quantity: 2 }
    ]

    assert_response :ok
    body = response.parsed_body
    assert_equal 3497, body["subtotal_cents"]   # 2997 + 500
    assert_equal 280,  body["tax_cents"]        # 279.76 rounds up
    assert_equal 3777, body["total_cents"]

    line = body["items"].first
    assert_equal %w[name product_id quantity total_cents unit_price_cents], line.keys.sort
    assert_equal 2997, line["total_cents"]
  end

  test "quote does not change inventory" do
    product = create_product(inventory_count: 5)

    post_json "/checkout/quote", items: [ { product_id: product.id.to_s, quantity: 2 } ]

    assert_response :ok
    assert_equal 5, product.reload.inventory_count
  end

  test "quote rejects an empty cart" do
    post_json "/checkout/quote", {}
    assert_response :bad_request
    assert_equal "Cart is empty", error_message

    post_json "/checkout/quote", items: []
    assert_response :bad_request
    assert_equal "Cart is empty", error_message
  end

  test "quote rejects invalid quantities" do
    product = create_product

    [ 0, -1, "abc" ].each do |quantity|
      post_json "/checkout/quote", items: [ { product_id: product.id.to_s, quantity: quantity } ]

      assert_response :bad_request, "expected 400 for quantity #{quantity.inspect}"
      assert_equal "Invalid quantity", error_message
    end
  end

  test "quote rejects unknown and malformed product ids" do
    post_json "/checkout/quote", items: [ { product_id: "000000000000000000000000", quantity: 1 } ]
    assert_response :bad_request
    assert_equal "Product not found", error_message

    post_json "/checkout/quote", items: [ { product_id: "not-an-id", quantity: 1 } ]
    assert_response :bad_request
    assert_equal "Product not found", error_message
  end

  test "quote rejects insufficient inventory" do
    product = create_product(inventory_count: 5)

    post_json "/checkout/quote", items: [ { product_id: product.id.to_s, quantity: 6 } ]

    assert_response :bad_request
    assert_equal "Insufficient inventory", error_message
  end

  test "complete creates an order and decrements inventory" do
    product = create_product(price_cents: 500, inventory_count: 5)

    post_json "/checkout/complete",
              email: "buyer@example.com",
              items: [ { product_id: product.id.to_s, quantity: 2 } ]

    assert_response :created
    body = response.parsed_body
    assert_equal 1080, body["total_cents"]   # 1000 + 80 tax
    assert body["order_id"].present?

    assert_equal 1, Order.count
    order = Order.first
    assert_equal body["order_id"], order.id.to_s
    assert_equal "buyer@example.com", order.email
    assert_equal "completed", order.status
    assert_equal 1000, order.subtotal_cents
    assert_equal 80, order.tax_cents
    assert_equal product.id.to_s, order.items.first["product_id"]

    assert_equal 3, product.reload.inventory_count
  end

  test "complete rejects an invalid email without touching inventory" do
    product = create_product(inventory_count: 5)

    post_json "/checkout/complete",
              email: "nope",
              items: [ { product_id: product.id.to_s, quantity: 1 } ]

    assert_response :unprocessable_entity
    assert_equal "validation_failed", response.parsed_body.dig("error", "code")
    assert_equal 0, Order.count
    assert_equal 5, product.reload.inventory_count
  end

  test "complete rejects a missing email" do
    product = create_product

    post_json "/checkout/complete", items: [ { product_id: product.id.to_s, quantity: 1 } ]

    assert_response :unprocessable_entity
    assert_equal 0, Order.count
  end

  test "complete rejects insufficient inventory without creating an order" do
    product = create_product(inventory_count: 1)

    post_json "/checkout/complete",
              email: "buyer@example.com",
              items: [ { product_id: product.id.to_s, quantity: 2 } ]

    assert_response :bad_request
    assert_equal 0, Order.count
    assert_equal 1, product.reload.inventory_count
  end

  test "complete rejects an empty cart" do
    post_json "/checkout/complete", email: "buyer@example.com", items: []

    assert_response :bad_request
    assert_equal 0, Order.count
  end
end
