require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'
require 'rack'
require 'yaml'
require 'bcrypt'

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
  def next_id(elements)
    max = elements.map { |element| element[:id] }.max || 0
    max + 1
  end

  def add_commas(amount)
    result = []
    reversed_amount = amount.to_s.chars.reverse
    sign = reversed_amount.pop if amount.to_i < 0
    until reversed_amount.empty?
      result << reversed_amount.shift(3)
      result << [','] unless reversed_amount.empty?
    end
    result << [sign] if sign
    result.flatten.reverse.join
  end

  def load_user_credentials
    credentials = if ENV["RACK_ENV"] == 'test'
      File.expand_path("../test/users.yml", __FILE__)
    else
      File.expand_path("../users.yml", __FILE__)
    end
    YAML.load_file(credentials)
  end

  def update_user_info(data)
    credentials = if ENV["RACK_ENV"] == 'test'
      File.expand_path("../test/users.yml", __FILE__)
    else
      File.expand_path("../users.yml", __FILE__)
    end
    File.open(credentials, 'wb') { |file| YAML.dump(data, file) }
  end

  def load_list_info(list)
    data = load_user_credentials
    list_type = data[session[:username]][list.to_sym]
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
    return "0%" if net < 0
    return "35% - 39.6%" if net >= 415051
    case net
    when (0...9276)        then "0% - 10%"
    when (9276...37651)    then "10% - 15%"
    when (37651...91151)   then "15% - 25%"
    when (91151...190151)  then "25% - 28%"
    when (190151...413351) then "28% - 33%"
    when (413351...415051) then "33-35%"
    end
  end

  def calculate_joint_widow(net)
    return "0%" if net < 0
    return "35% - 39.6%" if net >= 466951
    case net
    when (0...18551)        then "0% - 10%"
    when (18851...75301)    then "10% - 15%"
    when (75301...151901)   then "15% - 25%"
    when (151901...231451)  then "25% - 28%"
    when (231451...413351) then "28% - 33%"
    when (413351...466951) then "33-35%"
    end
  end

  def calculate_separate(net)
    return "0%" if net < 0
    return "35% - 39.6%" if net >= 233476
    case net
    when (0...9276)        then "0% - 10%"
    when (9276...37651)    then "10% - 15%"
    when (37651...75951)   then "15% - 25%"
    when (75951...115726)  then "25% - 28%"
    when (115726...206676) then "28% - 33%"
    when (206676...233476) then "33-35%"
    end
  end

  def calculate_head(net)
    return "0%" if net < 0
    return "35% - 39.6%" if net >= 441001
    case net
    when (0...13251)        then "0% - 10%"
    when (13251...50401)    then "10% - 15%"
    when (50401...130151)   then "15% - 25%"
    when (130151...210801)  then "25% - 28%"
    when (210801...413351) then "28% - 33%"
    when (413351...441001) then "33-35%"
    end
  end
end

def calculate(category)
  category.empty? ? 0 : category.map { |item| item[:amount].to_i }.reduce(:+)
end

# visit main page
get '/' do
  if session[:username]
    data = load_user_credentials
    @incomes = calculate(data[session[:username]][:incomes].compact)
    @expenses = calculate(data[session[:username]][:expenses].compact)
    @assets = calculate(data[session[:username]][:assets].compact)
    @liabilities = calculate(data[session[:username]][:liabilities].compact)
    @tax_bracket = determine_tax_bracket(params[:status], @incomes, @expenses)
    session[params[:status].to_sym] = 'selected' if params[:status]

    erb :index
  else
    session[:message] = "Please login first."
    redirect '/users/signin'
  end
end

# signin page
get '/users/signin' do
  erb :signin
end

# visit incomes page
get '/:page_name' do
  @list, @page_name, @item_description = load_list_info(params[:page_name])
  erb :list_page
end

# add income item
post '/:page_name/add' do
  data = load_user_credentials
  @list, @page_name, @item_description = load_list_info(params[:page_name])
  if params[:type].strip.empty?
    session[:message] = "Please enter a type."
    erb :list_page
  elsif params[:amount].to_i.to_s != params[:amount]
    session[:message] = "Please enter a valid number amount."
    erb :list_page
  else
    finance_type = params[:page_name].to_sym
    data[session[:username]][finance_type] << { type: params[:type], amount: params[:amount].to_i, id: next_id(data[session[:username]][finance_type])}
    update_user_info(data)
    redirect "/#{params[:page_name]}"
  end
end

# Delete Income item
post '/:page_name/:id/delete' do
  data = load_user_credentials
  data[session[:username]][params[:page_name].to_sym].reject! { |item| item[:id] == params[:id].to_i }
  update_user_info(data)
  redirect "/#{params[:page_name]}"
end

def correct_login?(user, password)
  users = load_user_credentials
  if users.key? user
    BCrypt::Password.new(users[user][:password]) == password
  else
    false
  end
end

post "/users/signin" do
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

post "/users/signout" do
  session[:username] = nil
  session[:message] = "You have been logged out."
  redirect "/users/signin"
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

post "/users/signup" do
  data = load_user_credentials
  username = params[:username]
  password = params[:password]
  confirm = params[:con_password]

  if !valid_user?(username, data)
    session[:message] = "Username is either taken or empty."
    erb :signup
  elsif !valid_password?(password, confirm)
    session[:message] = "Passwords either don't match or are empty"
    erb :signup
  elsif valid_user?(username, data) && valid_password?(password, confirm)
    data[username] = {}
    password = BCrypt::Password.create(password)
    data[username][:password] = password
    data[username][:incomes] = []
    data[username][:expenses] = []
    data[username][:assets] = []
    data[username][:liabilities] = []
    update_user_info(data)
    session[:message] = "#{username} was created. Please login."
    redirect '/users/signin'
  end
end
