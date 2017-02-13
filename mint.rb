require 'sinatra'
require 'sinatra/content_for'
require 'tilt/erubis'
require 'rack'
require 'yaml'
require 'bcrypt'
require 'puma'

require_relative 'database_persistence'

configure do
  enable :sessions
  set :session_secret, 'super secret'
end

configure(:development) do
  require 'sinatra/reloader'
  require 'pry'
  also_reload 'sequel_persistence.rb' if development?
end

before do
  @db = SequelPersistence.new(logger, session[:username])
  session[:username] ||= @db.current_username
end

helpers do
  def verify_login
    unless @db.logged_in?
      session[:message] = "You must login."
      redirect "/users/signin"
    end
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

# visit main page
get '/' do
  verify_login

  @incomes = @db.calculate_total('incomes')
  @expenses = @db.calculate_total('expenses')
  @assets = @db.calculate_total('assets')
  @liabilities = @db.calculate_total('liabilities')
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

  finance_type = params[:page_name].to_sym
  @total = @db.calculate_total(finance_type.to_s)
  @list, @page_name, @item_description = @db.load_list_data(params[:page_name])
  erb :list_page
end

# add income item
post '/:page_name/add' do
  finance_type = params[:page_name]
  @total = @db.calculate_total(finance_type)
  @list, @page_name, @item_description = @db.load_list_data(params[:page_name])

  if params[:type].strip.empty?
    session[:message] = 'Please enter a type.'
    status 422
    erb :list_page
  elsif params[:amount].to_i.to_s != params[:amount]
    message = 'Please enter a valid number amount to the nearest dollar.'
    session[:message] = message
    status 422
    erb :list_page
  else
    @db.add_to(finance_type, params[:type], params[:amount].to_i)
    redirect "/#{params[:page_name]}"
  end
end

# Delete Income item
post '/:page_name/:id/delete' do
  finance_type = params[:page_name]
  id = params[:id].to_i
  @db.delete_item(finance_type, id)

  total = @db.calculate_total(finance_type)
  redirect "/#{params[:page_name]}"
end

post '/users/signin' do
  username = params[:username]
  password = params[:password]
  if @db.correct_login?(username, password)
    @db.login(username)
    session[:username] = username
    session[:message] = 'Welcome!'
    redirect '/'
  else
    session[:message] = 'Invalid Credentials'
    erb :signin
  end
end

post '/users/signout' do
  @db.logout
  session[:message] = 'You have been logged out.'
  redirect '/users/signin'
end

get '/users/signup' do
  erb :signup
end

def valid_password?(password, confirm_password)
  (password == confirm_password) && !password.empty?
end

def valid_user?(username)
  !@db.user_exist?(username) && !username.empty?
end

post '/users/signup' do
  username = params[:username]
  password = params[:password]
  confirm = params[:con_password]

  if !valid_user?(username)
    session[:message] = 'Username is either taken or empty.'
    status 422
    erb :signup
  elsif !valid_password?(password, confirm)
    session[:message] = 'Passwords either don\'t match or are empty'
    status 422
    erb :signup
  elsif valid_user?(username) && valid_password?(password, confirm)
    @db.create_new_user(username, password)
    session[:message] = "#{username} was created. Please login."
    redirect '/users/signin'
  end
end
