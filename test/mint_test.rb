require 'minitest/autorun'
require 'rack/test'

require_relative '../mint'

class MintTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_index
    get '/'
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Monthly Finances'
    assert_includes last_response.body, 'Net Worth'
    assert_includes last_response.body, 'Tax Information'
    assert_includes last_response.body, 'Federal Tax Bracket'
  end

  def test_income_page
    get '/incomes'
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Incomes'
    assert_includes last_response.body, 'Type'
    assert_includes last_response.body, 'Add'
    assert_includes last_response.body, 'Back to Main Menu'
    assert_includes last_response.body, 'Salary'
  end

  def test_expense_page
    get '/expenses'
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Expenses'
    assert_includes last_response.body, 'Type'
    assert_includes last_response.body, 'Add'
    assert_includes last_response.body, 'Back to Main Menu'
    assert_includes last_response.body, 'Mortgage'
  end

  def test_assets_page
    get '/assets'
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Assets'
    assert_includes last_response.body, 'Type'
    assert_includes last_response.body, 'Add'
    assert_includes last_response.body, 'Back to Main Menu'
    assert_includes last_response.body, 'Stocks'
  end

  def test_assets_page
    get '/liabilities'
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Liabilities'
    assert_includes last_response.body, 'Type'
    assert_includes last_response.body, 'Add'
    assert_includes last_response.body, 'Back to Main Menu'
    assert_includes last_response.body, 'Debt'
  end

  def test_add_income
    post '/incomes/add', { type: "Interest", amount: 50 }
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "Interest"
    assert_includes last_response.body, "50"
  end

  def test_invalid_type_add
    post '/incomes/add', { type: '', amount: 50 }
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, 'Please enter a type.'
  end

  def test_invalid_amount_add
    post '/incomes/add', { type: 'salary', amount: "five" }
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, 'Please enter a valid number amount.'
  end

  def test_delete_item
    post '/incomes/add', { type: "Salary", amount: "50" }

    get last_response["Location"]
    assert_includes last_response.body, "Salary"
    assert_includes last_response.body, "50"

    post '/incomes/1/delete'
    refute_includes last_response.body, "Salary"
    refute_includes last_response.body, "50"
  end
end
