class Order
  include Mongoid::Document
  include Mongoid::Timestamps


  STATUSES = %w[completed].freeze

  field :email,          type: String
  field :status,         type: String
  field :items,          type: Array, default: []
  field :subtotal_cents, type: Integer
  field :tax_cents,      type: Integer
  field :total_cents,    type: Integer

  validates :email, presence: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :status, inclusion: { in: STATUSES }
  validates :subtotal_cents, :tax_cents, :total_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
