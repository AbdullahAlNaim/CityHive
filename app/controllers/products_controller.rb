class ProductsController < ApplicationController
  def index
    page = [ params.fetch(:page, 1).to_i, 1 ].max
    limit = [ [ params.fetch(:limit, 25).to_i, 100 ].min, 1 ].max

    products = Product.where(active: true)

    products = products.where(category: params[:category]) if params[:category].present?

    if params[:query].present?
      products = products.where(
        name: /#{Regexp.escape(params[:query])}/i
      )
    end

    total_count = products.count

    products = products.order_by(name: :asc)
                       .skip((page - 1) * limit)
                       .limit(limit)

    render json: {
      products: products.map { |product| serialize_product(product) },
      pagination: {
        page: page,
        limit: limit,
        total_count: total_count
      }
    }
  end

  def show
    product = Product.where(active: true).find(params[:id])

    render json: serialize_product(product)
  end

  private

  def serialize_product(product)
    {
      id: product.id.to_s,
      name: product.name,
      category: product.category,
      description: product.description,
      price_cents: product.price_cents,
      inventory_count: product.inventory_count
    }
  end
end
