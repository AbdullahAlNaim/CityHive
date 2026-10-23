ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    setup do
      Product.delete_all
      Order.delete_all
    end
  end
end
