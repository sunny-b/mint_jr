require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'tilt/erubis'
require 'rack'
require 'yaml'
require 'bcrypt'
require 'pry'

configure do
  enable :sessions
  set :session_secret, 'super secret'
end

before do
  session[:incomes] ||= []
  session[:expenses] ||= []
  session[:assets] ||= []
  session[:liabilities] ||= []
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
    until reversed_amount.empty?
      result << reversed_amount.shift(3)
      result << [','] unless reversed_amount.empty?
    end
    result.flatten.reverse.join
  end

  def load_list_info(list)
    list_type = session[list.to_sym]
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
    net_income = incomes - expenses

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
  @incomes = calculate(session[:incomes])
  @expenses = calculate(session[:expenses])
  @assets = calculate(session[:assets])
  @liabilities = calculate(session[:liabilities])
  @tax_bracket = determine_tax_bracket(params[:status], @incomes, @expenses)
  if params[:status]
    session[params[:status].to_sym] = 'selected'
  end
  erb :index
end

# visit incomes page
get '/:page_name' do
  @list, @page_name, @item_description = load_list_info(params[:page_name])
  erb :list_page
end

# add income item
post '/:page_name/add' do
  @list, @page_name, @item_description = load_list_info(params[:page_name])
  if params[:type].strip.empty?
    session[:message] = "Please enter a type."
    redirect "/#{params[:page_name]}"
  elsif params[:amount].to_i.to_s != params[:amount]
    session[:message] = "Please enter a valid number amount."
    redirect "/#{params[:page_name]}"
  else
    session[params[:page_name].to_sym] << { type: params[:type], amount: params[:amount].to_i, id: next_id(session[:incomes])}
    redirect "/#{params[:page_name]}"
  end
end

# Delete Income item
post '/:page_name/:id/delete' do
  session[params[:page_name].to_sym].reject! { |item| item[:id] == params[:id].to_i }
  redirect "/#{params[:page_name]}"
end
