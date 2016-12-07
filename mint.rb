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
end

helpers do
  def next_id(elements)
    max = elements.map { |element| element[:id] }.max || 0
    max + 1
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
