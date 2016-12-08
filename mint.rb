require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'
require 'rack'
require 'yaml'
require 'bcrypt'
require 'puma'
require 'pry'

configure do
  enable :sessions
  set :session_secret, 'super secret'
end

before do
  session[:username] ||= nil
  session[:single] = nil
  session[:joint] = nil
  session[:separate] = nil
  session[:head] = nil
  session[:widow] = nil
end

helpers do
  def verify_login
    unless session[:username]
      session[:message] = "You must login."
      redirect "/users/signin"
    end
  end

  def next_id(elements)
    max = elements.map { |element| element[:id] }.max || 0
    max + 1
  end

  def add_commas(amount)
    result = []
    reversed_amount = amount.to_s.chars.reverse
    sign = reversed_amount.pop if amount.to_i < 0
    fill_result(result, reversed_amount)
    result << [sign] if sign
    result.flatten.reverse.join
  end

  def fill_result(result, reversed_amount)
    until reversed_amount.empty?
      result << reversed_amount.shift(3)
      result << [','] unless reversed_amount.empty?
    end
  end

  def load_user_credentials
    credentials = if ENV['RACK_ENV'] == 'test'
                    File.expand_path('../test/users.yml', __FILE__)
                  else
                    File.expand_path('../users.yml', __FILE__)
                  end
    YAML.load_file(credentials)
  end

  def update_user_info(data)
    credentials = if ENV['RACK_ENV'] == 'test'
                    File.expand_path('../test/users.yml', __FILE__)
                  else
                    File.expand_path('../users.yml', __FILE__)
                  end
    File.open(credentials, 'wb') { |file| YAML.dump(data, file) }
  end

  def load_list_info(list)
    user_data = load_user_credentials
    list_type = user_data[session[:username]][list.to_sym]
    list_name = list.capitalize
    description = case list
                  when 'incomes'     then 'Salary, Freelance, etc.'
                  when 'expenses'    then 'Mortgage, Insurance, etc.'
                  when 'assets'      then 'Stocks, Real Estate, etc.'
                  when 'liabilities' then 'Loans, Credit Debt, etc.'
                  end

    [list_type, list_name, description]
  end

  def determine_tax_bracket(status, incomes, expenses)
    net_income = (incomes - expenses) * 12

    retrieve_bracket(status, net_income)
  end

  def retrieve_bracket(status, net_income)
    case status
    when '' || 'pick' then nil
    when 'single' then calculate_single(net_income)
    when 'joint' then calculate_joint_widow(net_income)
    when 'separate' then calculate_separate(net_income)
    when 'head' then calculate_head(net_income)
    when 'widow' then calculate_joint_widow(net_income)
    end
  end

  def calculate_single(net)
    return '0%' if net <= 0
    return '35% - 39.6%' if net >= 415_051
    case net
    when (1...9_276)         then '0% - 10%'
    when (9_276...37_651)    then '10% - 15%'
    when (37_651...91_151)   then '15% - 25%'
    when (91_151...190_151)  then '25% - 28%'
    when (190_151...413_351) then '28% - 33%'
    when (413_351...415_051) then '33-35%'
    end
  end

  def calculate_joint_widow(net)
    return '0%' if net <= 0
    return '35% - 39.6%' if net >= 466_951
    case net
    when (1...18_551)        then '0% - 10%'
    when (18_851...75_301)   then '10% - 15%'
    when (75_301...151_901)  then '15% - 25%'
    when (151_901...231_451) then '25% - 28%'
    when (231_451...413_351) then '28% - 33%'
    when (413_351...466_951) then '33-35%'
    end
  end

  def calculate_separate(net)
    return '0%' if net <= 0
    return '35% - 39.6%' if net >= 233_476
    case net
    when (1...9_276)         then '0% - 10%'
    when (9_276...37_651)    then '10% - 15%'
    when (37_651...75_951)   then '15% - 25%'
    when (75_951...115_726)  then '25% - 28%'
    when (115_726...206_676) then '28% - 33%'
    when (206_676...233_476) then '33-35%'
    end
  end

  def calculate_head(net)
    return '0%' if net <= 0
    return '35% - 39.6%' if net >= 441_001
    case net
    when (1...13_251)        then '0% - 10%'
    when (13_251...50_401)   then '10% - 15%'
    when (50_401...130_151)  then '15% - 25%'
    when (130_151...210_801) then '25% - 28%'
    when (210_801...413_351) then '28% - 33%'
    when (413_351...441_001) then '33-35%'
    end
  end
end

def calculate(category)
  category.empty? ? 0 : category.map { |item| item[:amount].to_i }.reduce(:+)
end

# visit main page
get '/' do
  verify_login

  user_data = load_user_credentials
  @incomes = calculate(user_data[session[:username]][:incomes])
  @expenses = calculate(user_data[session[:username]][:expenses])
  @assets = calculate(user_data[session[:username]][:assets])
  @liabilities = calculate(user_data[session[:username]][:liabilities])
  @tax_bracket = determine_tax_bracket(params[:status], @incomes, @expenses)
  session[params[:status].to_sym] = 'selected' if params[:status]
  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    "/?status=#{params[:status]}"
  else
    erb :index
  end
end

# signin page
get '/users/signin' do
  erb :signin
end

# visit incomes page
get '/:page_name' do
  verify_login
  user_data = load_user_credentials
  @total = calculate(user_data[session[:username]][params[:page_name].to_sym])
  @list, @page_name, @item_description = load_list_info(params[:page_name])
  erb :list_page
end

# add income item
post '/:page_name/add' do
  user_data = load_user_credentials
  @list, @page_name, @item_description = load_list_info(params[:page_name])
  if params[:type].strip.empty?
    session[:message] = 'Please enter a type.'
    erb :list_page
  elsif params[:amount].to_i.to_s != params[:amount]
    message = 'Please enter a valid number amount to the nearest dollar.'
    session[:message] = message
    erb :list_page
  else
    finance_type = params[:page_name].to_sym
    finances = user_data[session[:username]][finance_type]
    finances << { type: params[:type],
                  amount: params[:amount].to_i,
                  id: next_id(user_data[session[:username]][finance_type]) }
    update_user_info(user_data)
    redirect "/#{params[:page_name]}"
  end
end

# Delete Income item
post '/:page_name/:id/delete' do
  user_data = load_user_credentials
  user_info = user_data[session[:username]][params[:page_name].to_sym]
  user_info.reject! { |item| item[:id] == params[:id].to_i }
  update_user_info(user_data)
  total = calculate(user_data[session[:username]][params[:page_name].to_sym])
  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    status 204
    total
  else
    redirect "/#{params[:page_name]}"
  end
end

def correct_login?(user, password)
  users = load_user_credentials
  if users.key? user
    BCrypt::Password.new(users[user][:password]) == password
  else
    false
  end
end

post '/users/signin' do
  username = params[:username]
  password = params[:password]
  if correct_login?(username, password)
    session[:username] = username
    session[:message] = 'Welcome!'
    redirect '/'
  else
    session[:message] = 'Invalid Credentials'
    erb :signin
  end
end

post '/users/signout' do
  session[:username] = nil
  session[:message] = 'You have been logged out.'
  redirect '/users/signin'
end

get '/users/signup' do
  erb :signup
end

def valid_user?(user, data)
  !data.key?(user) && !user.empty?
end

def valid_password?(password, confirm_password)
  (password == confirm_password) && !password.empty?
end

post '/users/signup' do
  user_data = load_user_credentials
  username = params[:username]
  password = params[:password]
  confirm = params[:con_password]

  if !valid_user?(username, user_data)
    session[:message] = 'Username is either taken or empty.'
    erb :signup
  elsif !valid_password?(password, confirm)
    session[:message] = 'Passwords either don\'t match or are empty'
    erb :signup
  elsif valid_user?(username, user_data) && valid_password?(password, confirm)
    user_data[username] = {}
    password = BCrypt::Password.create(password)
    user_data[username][:password] = password
    user_data[username][:incomes] = []
    user_data[username][:expenses] = []
    user_data[username][:assets] = []
    user_data[username][:liabilities] = []
    update_user_info(user_data)
    session[:message] = "#{username} was created. Please login."
    redirect '/users/signin'
  end
end
