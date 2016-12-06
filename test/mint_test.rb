require "minitest/autorun"
require "rack/test"

require_relative "../mint"

class MintTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_index
    get '/'
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Monthly Finances"
    assert_includes last_response.body, "Net Worth"
    assert_includes last_response.body, "Tax Information"
    assert_includes last_response.body, "Federal Tax Bracket"
  end
end
