ENV["RACK_ENV"] = "test"

require 'minitest/autorun'
require 'rack/test'

require_relative '../mint'

class MintTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_signin
    {"rack.session" => {username: "admin"}}
  end

  def setup
    credentials = File.expand_path('../users.yml', __FILE__)
    data = YAML.load_file(credentials)

    data['admin'][:password] = "$2a$10$3uQijvygU/v3TdN5eGQFguwmcsZj7R30OEY9l/rStUaADdVXV.zZq"
    data['admin'][:incomes] = []
    data['admin'][:expenses] = []
    data['admin'][:assets] = []
    data['admin'][:liabilities] = []

    File.open(credentials, 'w') { |file| file.write data.to_yaml }
  end

  def teardown
    credentials = File.expand_path('../users.yml', __FILE__)
    data = YAML.load_file(credentials)

    data['admin'][:password] = "$2a$10$3uQijvygU/v3TdN5eGQFguwmcsZj7R30OEY9l/rStUaADdVXV.zZq"
    data['admin'][:incomes] = []
    data['admin'][:expenses] = []
    data['admin'][:assets] = []
    data['admin'][:liabilities] = []
    data.delete('iris')

    File.open(credentials, 'w') { |file| file.write data.to_yaml }
  end

  def test_index
    get '/', {}, admin_signin
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Monthly Finances'
    assert_includes last_response.body, 'Net Worth'
    assert_includes last_response.body, 'Tax Information'
    assert_includes last_response.body, 'Federal Tax Bracket'
  end

  def test_signin_page
    get '/users/signin'
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Username:'
    assert_includes last_response.body, 'Password:'
    assert_includes last_response.body, 'Not Registered?'
  end

  def test_not_logged_in
    get '/'
    assert_equal 302, last_response.status
    assert_equal "You must login.", session[:message]
  end

  def test_signup
    get '/users/signup'
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Choose a Username:"

    post '/users/signup', { username: "iris", password: 'pass', con_password: 'pass' }
    assert_equal 302, last_response.status
    assert_equal 'iris was created. Please login.', session[:message]
  end

  def test_bad_signup_password
    post '/users/signup', { username: "iris", password: 'pass', con_password: 'pass1' }
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Passwords either don\'t match or are empty'
  end

  def test_bad_signup_username
    post '/users/signup', { username: "", password: 'pass', con_password: 'pass' }
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Username is either taken or empty.'
  end

  def test_income_page
    get '/incomes', {}, admin_signin
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Incomes'
    assert_includes last_response.body, 'Type'
    assert_includes last_response.body, 'Add'
    assert_includes last_response.body, 'Back to Main Menu'
    assert_includes last_response.body, 'Salary'
  end

  def test_expense_page
    get '/expenses', {}, admin_signin
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Expenses'
    assert_includes last_response.body, 'Type'
    assert_includes last_response.body, 'Add'
    assert_includes last_response.body, 'Back to Main Menu'
    assert_includes last_response.body, 'Mortgage'
  end

  def test_assets_page
    get '/assets', {}, admin_signin
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Assets'
    assert_includes last_response.body, 'Type'
    assert_includes last_response.body, 'Add'
    assert_includes last_response.body, 'Back to Main Menu'
    assert_includes last_response.body, 'Stocks'
  end

  def test_assets_page
    get '/liabilities', {}, admin_signin
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Liabilities'
    assert_includes last_response.body, 'Type'
    assert_includes last_response.body, 'Add'
    assert_includes last_response.body, 'Back to Main Menu'
    assert_includes last_response.body, 'Debt'
  end

  def test_add_income
    post '/incomes/add', { type: "Interest", amount: 50 }, admin_signin
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "Interest"
    assert_includes last_response.body, "50"
  end

  def test_invalid_type_add
    post '/incomes/add', { type: '', amount: 50 }, admin_signin
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Please enter a type.'
  end

  def test_invalid_amount_add
    post '/incomes/add', { type: 'salary', amount: "five" }, admin_signin
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Please enter a valid number amount to the nearest dollar.'
  end

  def test_delete_item
    post '/incomes/add', { type: "Salary", amount: "50" }, admin_signin

    get last_response["Location"]
    assert_includes last_response.body, "Salary"
    assert_includes last_response.body, "50"

    post '/incomes/1/delete'
    refute_includes last_response.body, "Salary"
    refute_includes last_response.body, "50"
  end

  def test_tax_bracket
    get '/?status=single', {}, admin_signin
    assert_equal 200, last_response.status
    assert_includes last_response.body, '0%'
  end
end
