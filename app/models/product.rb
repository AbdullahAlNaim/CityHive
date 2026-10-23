class Product
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name,            type: String
  field :category,        type: String
  field :description,     type: String
  field :price_cents,     type: Integer
  field :inventory_count, type: Integer, default: 0
  field :active,          type: Boolean, default: true

  validates :name, :category, presence: true
  validates :price_cents, :inventory_count,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  index({ active: 1, category: 1, name: 1 })
  index({ name: 1 })
end
