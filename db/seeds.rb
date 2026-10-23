PRODUCTS = [
  # Coffee (11 active, 1 inactive)
  { name: "Cold Brew Concentrate 1L",         category: "coffee", description: "Makes 8 servings",           price_cents: 1299, inventory_count: 500, active: true },
  { name: "Nitro Cold Brew Can",              category: "coffee", description: "Smooth and creamy",          price_cents: 449,  inventory_count: 300, active: true },
  { name: "COLD Brew Vanilla Latte",          category: "coffee", description: "Mixed-case search test",     price_cents: 549,  inventory_count: 120, active: true },
  { name: "Cold Brew Coffee Pods (12)",       category: "coffee", description: "Fits standard pod machines", price_cents: 999,  inventory_count: 200, active: true },
  { name: "Dark Roast Ground Coffee 12oz",    category: "coffee", description: "Bold and smoky",             price_cents: 1199, inventory_count: 600, active: true },
  { name: "Decaf Medium Roast",               category: "coffee", description: "Smooth, no caffeine",        price_cents: 1099, inventory_count: 60,  active: true },
  { name: "Single Origin Ethiopia",           category: "coffee", description: "Floral and fruity",          price_cents: 1799, inventory_count: 40,  active: true },
  { name: "Instant Coffee Sticks (20)",       category: "coffee", description: "Just add hot water",         price_cents: 799,  inventory_count: 250, active: true },
  { name: "Espresso Beans 1kg",               category: "coffee", description: "Rich crema blend",           price_cents: 2199, inventory_count: 80,  active: true },
  { name: "Limited Reserve Geisha",           category: "coffee", description: "LOW STOCK test item",        price_cents: 2999, inventory_count: 2,   active: true },
  { name: "Cappuccino Mix Sachets",           category: "coffee", description: "OUT OF STOCK test item",     price_cents: 649,  inventory_count: 0,   active: true },
  { name: "Discontinued Pumpkin Spice Blend", category: "coffee", description: "INACTIVE test item",         price_cents: 1299, inventory_count: 25,  active: false },

  # Tea (6 active)
  { name: "Masala Chai Tea Bags (40)",        category: "tea",    description: "Box of 40",                  price_cents: 899,  inventory_count: 500, active: true },
  { name: "Green Tea Sencha",                 category: "tea",    description: "Light and grassy",           price_cents: 799,  inventory_count: 150, active: true },
  { name: "Matcha Latte (Large)",             category: "tea",    description: "Ceremonial grade blend",     price_cents: 1499, inventory_count: 70,  active: true },
  { name: "Earl Grey Loose Leaf",             category: "tea",    description: "Bergamot black tea",         price_cents: 899,  inventory_count: 100, active: true },
  { name: "Iced Peach Tea Bottle",            category: "tea",    description: "Lightly sweetened",          price_cents: 349,  inventory_count: 90,  active: true },
  { name: "Chamomile Herbal Tea",             category: "tea",    description: "Caffeine free",              price_cents: 649,  inventory_count: 200, active: true },

  # Juice (3 active)
  { name: "Fresh Orange Juice 1L",            category: "juice",  description: "Not from concentrate",       price_cents: 599,  inventory_count: 80,  active: true },
  { name: "Alphonso Mango Juice",             category: "juice",  description: "Sweet and thick",            price_cents: 649,  inventory_count: 500, active: true },
  { name: "Pomegranate Juice",                category: "juice",  description: "Tart and refreshing",        price_cents: 799,  inventory_count: 45,  active: true },

  # Soda (2 active, 1 inactive)
  { name: "Dr. Fizz Cola",                    category: "soda",   description: "Special character test",     price_cents: 249,  inventory_count: 500, active: true },
  { name: "Ginger Beer",                      category: "soda",   description: "Extra spicy",                price_cents: 299,  inventory_count: 90,  active: true },
  { name: "Discontinued Lemon Soda",          category: "soda",   description: "INACTIVE test item",         price_cents: 199,  inventory_count: 15,  active: false }
].freeze

PRODUCTS.each do |attrs|
  product = Product.find_or_initialize_by(name: attrs[:name])
  product.assign_attributes(attrs)
  product.save!
end

puts "Seeded #{Product.count} products (#{Product.where(active: true).count} active)"
